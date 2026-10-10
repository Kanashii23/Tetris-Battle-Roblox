local E=(function()
-- Pure deterministic engine shared by solo and the authoritative battle server.
local E={}
local shape={I={{0,1},{1,1},{2,1},{3,1}},O={{1,0},{2,0},{1,1},{2,1}},T={{1,0},{0,1},{1,1},{2,1}},S={{1,0},{2,0},{0,1},{1,1}},Z={{0,0},{1,0},{1,1},{2,1}},J={{0,0},{0,1},{1,1},{2,1}},L={{2,0},{0,1},{1,1},{2,1}}}
local names={"I","O","T","S","Z","J","L"}
local normal={
	[0]={{0,0},{-1,0},{-1,-1},{0,2},{-1,2}},[1]={{0,0},{1,0},{1,1},{0,-2},{1,-2}},
	[2]={{0,0},{1,0},{1,-1},{0,2},{1,2}},[3]={{0,0},{-1,0},{-1,1},{0,-2},{-1,-2}},
}
local iKick={
	[0]={{0,0},{-2,0},{1,0},{-2,1},{1,-2}},[1]={{0,0},{-1,0},{2,0},{-1,-2},{2,1}},
	[2]={{0,0},{2,0},{-1,0},{2,-1},{-1,2}},[3]={{0,0},{1,0},{-2,0},{1,2},{-2,-1}},
}
local function random(s,key,lo,hi)
	s[key]=(s[key]*48271)%2147483647
	return lo+s[key]%(hi-lo+1)
end
local function emit(s,name,extra)
	s.sequence+=1; table.insert(s.events,{id=s.sequence,name=name,data=extra or {}})
	if #s.events>24 then table.remove(s.events,1) end
end
function E.cells(p)
	local cells={}
	for _,v in ipairs(shape[p.kind]) do
		local x,y=v[1],v[2]
		if p.kind~="O" then for _=1,p.rotation do x,y=(p.kind=="I" and 3 or 2)-y,x end end
		table.insert(cells,{x+p.x,y+p.y})
	end
	return cells
end
function E.fits(s,p)
	for _,v in ipairs(E.cells(p)) do
		if v[1]<1 or v[1]>s.rules.Width or v[2]<1 or v[2]>#s.board or s.board[v[2]][v[1]]~=0 then return false end
	end
	return true
end
local function fillQueue(s)
	while #s.queue<7 do
		local bag=table.clone(names)
		for i=7,2,-1 do local j=random(s,"bagSeed",1,i); bag[i],bag[j]=bag[j],bag[i] end
		for _,name in ipairs(bag) do table.insert(s.queue,name) end
	end
end
function E.spawn(s,kind)
	fillQueue(s); s.piece={kind=kind or table.remove(s.queue,1),x=4,y=s.rules.Hidden,rotation=0}
	s.lockTime=0; s.lockResets=0; s.fallTime=0; s.spin=false; s.kick=0
	fillQueue(s)
	if not E.fits(s,s.piece) then s.alive=false; emit(s,"KO") end
end
function E.new(seed,rules)
	local normalized=math.floor(math.abs(seed))%2147483646+1
	local s={rules=rules,board={},queue={},bagSeed=normalized,garbageSeed=(normalized+777)%2147483646+1,
		alive=true,paused=false,elapsed=0,score=0,lines=0,level=1,combo=-1,b2b=false,hold=false,held=false,
		pending={},controls={},horizontal=0,repeatTime=0,events={},sequence=0,
		stats={TSpins=0,Tetrises=0,PerfectClears=0,Sent=0,KOs=0,BestCombo=0},
	}
	for y=1,rules.Height+rules.Hidden do s.board[y]=table.create(rules.Width,0) end
	E.spawn(s); return s
end
local function grounded(s)
	local p=table.clone(s.piece); p.y+=1; return not E.fits(s,p)
end
local function reset(s,wasGrounded)
	if wasGrounded and s.lockResets<s.rules.MaxLockResets then s.lockTime=0; s.lockResets+=1 end
end
function E.move(s,dx,dy)
	if not s.alive then return false end
	local was=grounded(s); local p=table.clone(s.piece); p.x+=dx; p.y+=dy
	if not E.fits(s,p) then return false end
	s.piece=p; s.spin=false; reset(s,was); if dx~=0 then emit(s,"Move") end; return true
end
function E.rotate(s,dir)
	if not s.alive or s.piece.kind=="O" then return false end
	local was=grounded(s); local old=s.piece.rotation; local target=(old+dir)%4
	local map=s.piece.kind=="I" and iKick or normal
	for index,v in ipairs(map[dir==1 and old or target]) do
		local sign=dir==1 and 1 or -1
		local p=table.clone(s.piece); p.rotation=target; p.x+=v[1]*sign; p.y+=v[2]*sign
		if E.fits(s,p) then s.piece=p; s.spin=true; s.kick=index; reset(s,was); emit(s,"Rotate"); return true end
	end
	return false
end
function E.hold(s)
	if not s.alive or s.held then return false end
	local old=s.hold; s.hold=s.piece.kind; E.spawn(s,old or nil); s.held=true; emit(s,"Hold"); return true
end
function E.pending(s)
	local n=0; for _,packet in ipairs(s.pending) do n+=packet.lines end; return n
end
function E.addGarbage(s,lines)
	lines=math.min(math.max(0,math.floor(lines)),s.rules.MaxPending-E.pending(s))
	if lines>0 then table.insert(s.pending,{lines=lines,ready=s.elapsed+s.rules.GarbageDelay}); emit(s,"GarbageReceive",{lines=lines}) end
end
function E.applyGarbage(s,count)
	local hole=random(s,"garbageSeed",1,s.rules.Width)
	for _=1,count do
		local row=table.remove(s.board,1)
		for _,v in ipairs(row) do if v~=0 then s.alive=false end end
		local garbage=table.create(s.rules.Width,"G"); garbage[hole]=0; table.insert(s.board,garbage)
	end
end
function E.spinType(s)
	if s.piece.kind~="T" or not s.spin then return nil end
	local p=s.piece; local corners={}
	for _,v in ipairs({{0,0},{2,0},{2,2},{0,2}}) do
		local x,y=p.x+v[1],p.y+v[2]
		table.insert(corners,x<1 or x>s.rules.Width or y<1 or y>#s.board or s.board[y][x]~=0)
	end
	local count=0; for _,occupied in ipairs(corners) do if occupied then count+=1 end end
	if count<3 then return nil end
	local fronts=({{1,2},{2,3},{3,4},{4,1}})[p.rotation+1]
	return ((corners[fronts[1]] and corners[fronts[2]]) or s.kick==5) and "Spin" or "Mini"
end
function E.lock(s)
	if not s.alive then return 0 end
	local spin=E.spinType(s)
	local allHidden=true
	for _,v in ipairs(E.cells(s.piece)) do s.board[v[2]][v[1]]=s.piece.kind; if v[2]>s.rules.Hidden then allHidden=false end end
	if allHidden then s.alive=false; emit(s,"KO"); return 0 end
	local cleared=0
	for y=#s.board,1,-1 do
		local full=true; for _,v in ipairs(s.board[y]) do if v==0 then full=false; break end end
		if full then table.remove(s.board,y); cleared+=1 end
	end
	for _=1,cleared do table.insert(s.board,1,table.create(s.rules.Width,0)) end
	if spin=="Mini" and cleared>=2 then spin="Spin" end
	local category=spin or "Normal"
	local score=(s.rules.Score[category][cleared] or 0)*s.level
	local attack=s.rules.Attack[category][cleared] or 0
	local difficult=cleared>0 and (spin~=nil or cleared==4)
	local continued=difficult and s.b2b
	if continued then score=math.floor(score*s.rules.BackToBackScore); attack+=s.rules.BackToBackAttack; emit(s,"BackToBack") end
	if cleared>0 then
		s.combo+=1; if difficult then s.b2b=true else s.b2b=false end
		s.stats.BestCombo=math.max(s.stats.BestCombo,s.combo)
		score+=50*math.max(0,s.combo)*s.level
		attack+=s.rules.ComboAttack[math.min(s.combo+1,#s.rules.ComboAttack)]
		if s.combo>0 then emit(s,"Combo",{combo=s.combo}) end
	else s.combo=-1 end
	if spin then s.stats.TSpins+=1 end
	if cleared==4 then s.stats.Tetrises+=1 end
	local perfect=cleared>0
	for _,row in ipairs(s.board) do for _,v in ipairs(row) do if v~=0 then perfect=false end end end
	if perfect then s.stats.PerfectClears+=1; score+=s.rules.PerfectClearScore*s.level; attack+=s.rules.PerfectClearAttack; emit(s,"PerfectClear") end
	s.score+=score; s.lines+=cleared; s.level=1+math.floor(s.lines/10)
	local eventName=spin and (spin=="Mini" and "TSpinMini" or ({[0]="TSpin",[1]="TSpinSingle",[2]="TSpinDouble",[3]="TSpinTriple"})[cleared]) or ({[0]="Lock","Single","Double","Triple","Tetris"})[cleared]
	emit(s,eventName,{lines=cleared,combo=s.combo,attack=attack,spin=spin or "",perfect=perfect})
	-- Attacks cancel the oldest incoming packets before anything is sent.
	while attack>0 and #s.pending>0 do
		local packet=s.pending[1]; local canceled=math.min(packet.lines,attack)
		packet.lines-=canceled; attack-=canceled; if packet.lines==0 then table.remove(s.pending,1) end
	end
	if cleared==0 then
		while #s.pending>0 and s.pending[1].ready<=s.elapsed do E.applyGarbage(s,s.pending[1].lines); table.remove(s.pending,1) end
	end
	s.stats.Sent+=attack; if attack>0 then emit(s,"GarbageSend",{lines=attack}) end
	s.held=false
	if s.alive then E.spawn(s) else emit(s,"KO") end
	return attack
end
function E.hardDrop(s)
	if not s.alive then return 0 end
	local distance=0
	while true do local p=table.clone(s.piece); p.y+=1; if not E.fits(s,p) then break end; s.piece=p; distance+=1 end
	if distance>0 then s.spin=false end
	s.score+=distance*2; emit(s,"HardDrop",{distance=distance,x=s.piece.x,y=s.piece.y-s.rules.Hidden,kind=s.piece.kind,rotation=s.piece.rotation}); return E.lock(s)
end
function E.release(s)
	s.controls={}; s.horizontal=0; s.repeatTime=0
end
function E.input(s,action,down)
	if not down then
		s.controls[action]=false
		if action=="Left" and s.horizontal==-1 then s.horizontal=s.controls.Right and 1 or 0; s.repeatTime=0 end
		if action=="Right" and s.horizontal==1 then s.horizontal=s.controls.Left and -1 or 0; s.repeatTime=0 end
		return 0
	end
	if not s.alive or s.paused or s.controls[action] then return 0 end
	s.controls[action]=true
	if action=="Left" or action=="Right" then s.horizontal=action=="Left" and -1 or 1; s.repeatTime=-s.rules.DAS+s.rules.ARR; E.move(s,s.horizontal,0)
	elseif action=="CW" then E.rotate(s,1)
	elseif action=="CCW" then E.rotate(s,-1)
	elseif action=="Hold" then E.hold(s)
	elseif action=="HardDrop" then return E.hardDrop(s) end
	return 0
end
function E.step(s,dt)
	if not s.alive or s.paused then return 0 end
	s.elapsed+=dt
	if s.horizontal~=0 then
		s.repeatTime+=dt
		while s.repeatTime>=s.rules.ARR do s.repeatTime-=s.rules.ARR; E.move(s,s.horizontal,0) end
	end
	local gravity=math.max(s.rules.MinGravity,s.rules.Gravity*0.8^(s.level-1))
	local interval=s.controls.SoftDrop and math.min(gravity,s.rules.SoftDropInterval) or gravity
	s.fallTime+=dt
	while s.fallTime>=interval do
		s.fallTime-=interval
		local p=table.clone(s.piece); p.y+=1
		if E.fits(s,p) then s.piece=p; s.spin=false; if s.controls.SoftDrop then s.score+=1; emit(s,"SoftDrop") end else break end
	end
	if grounded(s) then s.lockTime+=dt else s.lockTime=0 end
	if s.lockTime>=s.rules.LockDelay then return E.lock(s) end
	return 0
end
function E.snapshot(s)
	local board={}; for y=1,s.rules.Height do board[y]=table.clone(s.board[y+s.rules.Hidden]) end
	local active=table.clone(s.piece); active.y-=s.rules.Hidden
	local ghost=table.clone(s.piece)
	if s.alive then while true do local p=table.clone(ghost); p.y+=1; if not E.fits(s,p) then break end; ghost=p end end
	ghost.y-=s.rules.Hidden
	local nextPieces={}; for i=1,5 do nextPieces[i]=s.queue[i] end
	return {board=board,piece=active,ghost=ghost,hold=s.hold,next=nextPieces,score=s.score,lines=s.lines,level=s.level,elapsed=s.elapsed,alive=s.alive,paused=s.paused,pending=E.pending(s),combo=s.combo,events=table.clone(s.events),stats=table.clone(s.stats)}
end
local token={ [0]="0",I="I",O="O",T="T",S="S",Z="Z",J="J",L="L",G="G" }
function E.pack(s)
	local view=E.snapshot(s); local chars={}
	for _,row in ipairs(view.board) do for _,v in ipairs(row) do table.insert(chars,token[v]) end end
	view.grid=table.concat(chars); view.board=nil; return view
end
function E.unpack(view)
	if not view or view.board then return view end
	local board={}; local index=1
	for y=1,20 do board[y]={}; for x=1,10 do local c=view.grid:sub(index,index); board[y][x]=c=="0" and 0 or c; index+=1 end end
	view.board=board; return view
end
return E

end)()
local R=(function()
return {
	Width=10, Height=20, Hidden=4, LockDelay=0.5, MaxLockResets=15,
	Gravity=0.8, MinGravity=0.04, SoftDropInterval=0.025, DAS=0.16, ARR=0.045,
	MatchDuration=120, Countdown=3, SnapshotHz=12, GarbageDelay=0.8, MaxPending=40,
	TimedKO=true, KORecovery=2.5, EmoteCooldown=4,
	Emotes={"GG!","Nice!","WOW!","OOPS!","GOOD LUCK!","WELL PLAYED!"},
	Score={Normal={[0]=0,100,300,500,800},Spin={[0]=400,800,1200,1600},Mini={[0]=100,200,400}},
	Attack={Normal={[0]=0,0,1,2,4},Spin={[0]=0,2,4,6},Mini={[0]=0,0,1}},
	BackToBackScore=1.5, BackToBackAttack=1, PerfectClearScore=2000, PerfectClearAttack=6,
	ComboAttack={0,0,1,1,2,2,3,3,4,4,5},
	Gamepad={Left="DPadLeft",Right="DPadRight",SoftDrop="DPadDown",CW="ButtonA",CCW="ButtonB",HardDrop="ButtonY",Hold="ButtonX",Pause="ButtonStart"},
}

end)()
local P=(function()
-- Pure economy and progression. Only the server may persist these mutations.
local P={Ranks={"Rookie","Bronze","Silver","Gold","Platinum","Diamond","Master"},Stars={3,4,5,5,6,7,0}}
P.Daily={{Id="play",Label="Play 3 ranked matches",Stat="Matches",Target=3,Cash=100},{Id="lines",Label="Clear 30 lines",Stat="Lines",Target=30,Cash=75},{Id="spin",Label="Perform 2 T-Spins",Stat="TSpins",Target=2,Energy=1},{Id="wins",Label="Win 2 battles",Stat="Wins",Target=2,Cash=150},{Id="send",Label="Send 20 garbage lines",Stat="Sent",Target=20,Cash=100}}
P.Weekly={{Id="wins",Label="Win 15 battles",Stat="Wins",Target=15,Cash=1000},{Id="lines",Label="Clear 500 lines",Stat="Lines",Target=500,Cash=750},{Id="spins",Label="Perform 25 T-Spins",Stat="TSpins",Target=25,Energy=5},{Id="tetrises",Label="Clear 10 Tetrises",Stat="Tetrises",Target=10,Cash=500},{Id="daily",Label="Complete 20 daily quests",Stat="DailyClaims",Target=20,Cash=1000}}
local function clone(t) if type(t)~="table" then return t end; local out={}; for k,v in pairs(t) do out[k]=clone(v) end; return out end
P.clone=clone
local function int(value,default,max) if type(value)~="number" or value~=value then return default end; return math.clamp(math.floor(value),0,max or 1e9) end
function P.default(now)
	return {SchemaVersion=1,Cash=0,Energy={Current=10,LastRegenTimestamp=now},Rank={Tier=1,Stars=0,Rating=1000},
		Stats={Wins=0,QualifiedWins=0,Losses=0,Draws=0,Matches=0,KOs=0,Lines=0,TSpins=0,Tetrises=0,PerfectClears=0,Sent=0,BestWinStreak=0,CurrentWinStreak=0},
		Inventory={BrickSkins={Default=true},DropEffects={Default=true},GhostEffects={Default=true},SoundPacks={Default=true},Badges={}},
		Equipped={BrickSkin="Default",DropEffect="Default",GhostEffect="Default",SoundPack="Default"},Quests={},SocialRewards={Seen={},Day=0,Count=0},
		Season={Id=0,Rating=1000,Wins=0,History={}},ProcessedMatchIds={},MatchReceipts={},Reservations={},Pairs={},Achievements={},Login={LastDay=-1,Index=0},Settings={Sound=true,ReducedMotion=false,Master=1,MusicVolume=0.5,SFXVolume=0.8,UIScale=1,ClassicHUD=false,SwapRotation=false},CreatedAt=now,
	}
end
function P.validate(data,now,catalog,config)
	assert(type(data)=="table","Invalid profile")
	assert(not data.SchemaVersion or data.SchemaVersion<=1,"Unsupported newer data schema")
	local defaults=P.default(now)
	local function merge(dst,src)
		for k,v in pairs(src) do if dst[k]==nil then dst[k]=clone(v) elseif type(v)=="table" and type(dst[k])=="table" then merge(dst[k],v) elseif type(dst[k])~=type(v) then dst[k]=clone(v) end end
	end
	merge(data,defaults); data.SchemaVersion=1; data.Cash=int(data.Cash,0)
	data.Energy.Current=int(data.Energy.Current,10,config and config.BonusEnergyCap or 20); data.Energy.LastRegenTimestamp=int(data.Energy.LastRegenTimestamp,now,now)
	data.Rank.Tier=math.clamp(int(data.Rank.Tier,1),1,7); data.Rank.Stars=int(data.Rank.Stars,0,7); data.Rank.Rating=int(data.Rank.Rating,1000,100000)
	data.Rank.Stars=data.Rank.Tier==7 and 0 or math.min(data.Rank.Stars,P.Stars[data.Rank.Tier]-1)
	data.Season.Id=int(data.Season.Id,0); data.Season.Wins=int(data.Season.Wins,0); data.Season.Rating=int(data.Season.Rating,1000,100000)
	for key in pairs(defaults.Stats) do data.Stats[key]=int(data.Stats[key],0) end
	for key,pair in pairs(data.Pairs) do
		if type(pair)~="table" then data.Pairs[key]=nil else pair.Day=int(pair.Day,0); pair.Count=int(pair.Count,0); pair.Last=int(pair.Last,0,now) end
	end
	for category,slot in pairs(catalog.Slots) do
		local inventory={Default=true}
		for key,value in pairs(data.Inventory[category]) do
			local id=type(key)=="number" and value or key
			if type(id)=="string" and catalog.Items[category..":"..id] and (type(key)=="number" or value==true) then inventory[id]=true end
		end
		data.Inventory[category]=inventory
		if not data.Inventory[category][data.Equipped[slot]] or not catalog.Items[category..":"..data.Equipped[slot]] then data.Equipped[slot]="Default" end
	end
	return data
end
function P.refresh(d,now,c)
	local e=d.Energy
	if e.Current>=c.EnergyCap then e.LastRegenTimestamp=now else
		local steps=math.max(0,math.floor((now-e.LastRegenTimestamp)/c.EnergyInterval))
		e.Current=math.min(c.EnergyCap,e.Current+steps); e.LastRegenTimestamp+=steps*c.EnergyInterval
		if e.Current==c.EnergyCap then e.LastRegenTimestamp=now end
	end
	local day=math.floor(now/86400); local week=math.floor((day+3)/7)
	for group,window in pairs({Daily=day,Weekly=week}) do
		local state=d.Quests[group]
		if type(state)~="table" or state.Window~=window or type(state.Progress)~="table" or type(state.Claimed)~="table" then d.Quests[group]={Window=window,Progress={},Claimed={}} end
		for _,q in ipairs(P[group]) do d.Quests[group].Progress[q.Id]=int(d.Quests[group].Progress[q.Id],0,q.Target) end
	end
	if d.SocialRewards.Day~=day then d.SocialRewards.Day=day; d.SocialRewards.Count=0 end
	local id=math.max(1,math.floor((now-c.SeasonStart)/(c.SeasonDays*86400))+1)
	if d.Season.Id~=id then
		if d.Season.Id>0 then
			table.insert(d.Season.History,{Id=d.Season.Id,Rating=d.Season.Rating,Wins=d.Season.Wins})
			if #d.Season.History>12 then table.remove(d.Season.History,1) end
			d.Cash+=math.min(c.SeasonCashCap,d.Season.Wins*c.SeasonCashPerWin)
			if d.Season.Wins>0 then d.Inventory.Badges["Season"..d.Season.Id]=true end
		end
		d.Season.Id=id; d.Season.Rating=c.SeasonResetRating; d.Season.Wins=0
	end
	return d
end
function P.nextEnergy(d,now,c) return d.Energy.Current>=c.EnergyCap and 0 or math.max(0,c.EnergyInterval-(now-d.Energy.LastRegenTimestamp)) end
function P.questProgress(d,delta)
	for group,definitions in pairs({Daily=P.Daily,Weekly=P.Weekly}) do
		for _,q in ipairs(definitions) do local p=d.Quests[group].Progress; p[q.Id]=math.min(q.Target,(p[q.Id] or 0)+(delta[q.Stat] or 0)) end
	end
end
local function energy(d,n,c) d.Energy.Current=math.min(c.BonusEnergyCap,d.Energy.Current+n) end
function P.claimQuest(d,group,id,c)
	local state=d.Quests[group]; if not state then return false,"Unknown quest group" end
	for _,q in ipairs(group=="Daily" and P.Daily or P.Weekly) do
		if q.Id==id then
			if state.Claimed[id] then return false,"Already claimed" end
			if (state.Progress[id] or 0)<q.Target then return false,"Quest incomplete" end
			state.Claimed[id]=true; d.Cash+=q.Cash or 0; energy(d,q.Energy or 0,c)
			if group=="Daily" then P.questProgress(d,{DailyClaims=1}) end
			return true,"Quest reward claimed"
		end
	end
	return false,"Unknown quest"
end
function P.login(d,now,c)
	local day=math.floor(now/86400); if d.Login.LastDay==day then return false,"Already claimed today" end
	-- Missed days do not erase progress; the cycle advances only when claimed.
	d.Login.LastDay=day; d.Login.Index=d.Login.Index%7+1
	d.Cash+=c.LoginCash[d.Login.Index]; energy(d,c.LoginEnergy[d.Login.Index],c); return true,"Day "..d.Login.Index.." reward claimed"
end
function P.purchase(d,category,id,catalog,free)
	local item=catalog.Items[category..":"..id]; if not item then return false,"Unknown cosmetic" end
	if d.Inventory[category][id] then return false,"Already owned" end
	local price=free and 0 or item.Price; if d.Cash<price then return false,"Not enough Cash" end
	d.Cash-=price; d.Inventory[category][id]=true; return true,"Purchased "..item.Name
end
function P.equip(d,category,id,catalog,free)
	local slot=type(category)=="string" and catalog.Slots[category]
	if not slot or type(id)~="string" or not catalog.Items[category..":"..id] then return false,"This cosmetic is unavailable.","Unavailable" end
	if not d.Inventory[category] or not d.Inventory[category][id] and not free then return false,"You don't own this cosmetic yet.","NotOwned" end
	d.Equipped[slot]=id; return true,"Equipped "..id
end
function P.settle(d,result,c)
	if d.ProcessedMatchIds[result.id] then return false end
	d.ProcessedMatchIds[result.id]=true; table.insert(d.MatchReceipts,result.id)
	-- Retain receipts for the current and recent seasons; IDs also never reused.
	if #d.MatchReceipts>512 then local old=table.remove(d.MatchReceipts,1); d.ProcessedMatchIds[old]=nil end
	if result.kind=="Refund" then
		if d.Reservations[result.roomId] then energy(d,c.RankedCost,c); d.Reservations[result.roomId]=nil end
		return true
	end
	if result.kind=="Social" then
		local social=d.SocialRewards; local key=tostring(result.friendId)
		if not social.Seen[key] and social.Count<c.SocialDailyLimit then social.Seen[key]=true; social.Count+=1; energy(d,c.SocialEnergy,c) end
		return true
	end
	if result.kind=="Solo" then
		local delta={Lines=result.lines,TSpins=result.spins,Tetrises=result.tetrises,PerfectClears=result.perfect}
		for k,v in pairs(delta) do d.Stats[k]+=v end
		P.questProgress(d,delta); d.BestSoloScore=math.max(d.BestSoloScore or 0,result.score); return true
	end
	local stats=d.Stats; local delta={Matches=1,Lines=result.lines,TSpins=result.spins,Tetrises=result.tetrises,PerfectClears=result.perfect,Sent=result.sent,KOs=result.kos}
	d.Reservations[result.id]=nil
	delta[result.outcome=="Win" and "Wins" or result.outcome=="Lose" and "Losses" or "Draws"]=1
	for k,v in pairs(delta) do stats[k]=(stats[k] or 0)+v end
	if result.outcome=="Win" then stats.CurrentWinStreak+=1; stats.BestWinStreak=math.max(stats.BestWinStreak,stats.CurrentWinStreak) else stats.CurrentWinStreak=0 end
	local reward=result.rewardEligible
	if reward then
		local pair=d.Pairs[tostring(result.opponentId)]
		if not pair or pair.Day~=result.day then pair={Day=result.day,Count=0,Last=0}; d.Pairs[tostring(result.opponentId)]=pair end
		pair.Count+=1; pair.Last=result.timestamp
		if result.outcome=="Win" then
			d.Cash+=c.WinCash[result.startTier]; d.Season.Wins+=1; stats.QualifiedWins+=1
			if d.Rank.Tier<7 then d.Rank.Stars+=1; if d.Rank.Stars>=P.Stars[d.Rank.Tier] then d.Rank.Tier+=1; d.Rank.Stars=0 end end
		elseif result.outcome=="Lose" and d.Rank.Tier<7 then
			if d.Rank.Stars>0 then d.Rank.Stars-=1 elseif d.Rank.Tier>1 and c.AllowDemotion then d.Rank.Tier-=1; d.Rank.Stars=P.Stars[d.Rank.Tier]-1 end
		end
		local actual=result.outcome=="Win" and 1 or result.outcome=="Lose" and 0 or 0.5
		local adjustment=math.floor(c.MasterK*(actual-1/(1+10^((result.opponentRating-result.startRating)/400)))+0.5)
		d.Rank.Rating=math.max(0,d.Rank.Rating+adjustment); d.Season.Rating=math.max(0,d.Season.Rating+adjustment)
		P.questProgress(d,delta)
	end
	for _,a in ipairs({{"FirstWin","Wins",1},{"TenWins","Wins",10},{"HundredWins","Wins",100},{"FirstSpin","TSpins",1},{"HundredSpins","TSpins",100},{"PerfectClear","PerfectClears",1},{"ThousandLines","Lines",1000},{"Streak5","BestWinStreak",5}}) do
		if stats[a[2]]>=a[3] then d.Achievements[a[1]]=true; d.Inventory.Badges[a[1]]=true end
	end
	if d.Rank.Tier>=6 then d.Achievements.Diamond=true; d.Inventory.Badges.Diamond=true end
	if d.Rank.Tier>=7 then d.Achievements.Master=true; d.Inventory.Badges.Master=true end
	return true
end
return P

end)()
local C=(function()
-- Server-only authority. Debug privileges are effective ONLY in Roblox Studio.
return {
	Debug=true, FreeCosmeticsInDebug=true, InfiniteEnergyInDebug=true,
	CosmeticDebugLogging=true, -- Temporary request diagnostics, Roblox Studio only.
	FreeShopPurchasesInDebug=true, TestRankedMatches=true,
	DataStoreName="TetrisBattle_Player_v1", LockLease=180, Autosave=45,
	-- First verify real persistence in a separate published TEST experience.
	-- Live stays on the existing backend until this rollout switch is enabled.
	ProfileStoreLiveEnabled=false, ProfileStoreStudioPersistence=false,
	ProfileStoreTestDataStoreName="TetrisBattle_ProfileStoreTest_v1",
	ProfileStoreMigrateLegacy=true, ProfileLoadTimeout=90, ProfileSaveTimeout=15,
	MaxPlayers=100, MaxMatches=50, AllowDemotion=true,
	EnergyCap=10, BonusEnergyCap=20, EnergyInterval=600, RankedCost=1,
	WinCash={50,75,100,150,225,350,500}, MasterK=24,
	SeasonStart=1791590400, SeasonDays=42, SeasonResetRating=1000,
	SeasonCashPerWin=10, SeasonCashCap=2000,
	MinRewardSeconds=20, OpponentRewardCooldown=600, PairRewardsPerDay=3,
	SocialDailyLimit=2, SocialEnergy=1, SocialMinSeconds=120, SocialMinAccountAge=7,
	LoginCash={25,50,75,100,125,150,250}, LoginEnergy={0,0,1,0,1,0,2},
}

end)()
local Catalog=(function()
local Definition=(function()
-- Stable IDs are save keys. Never rename or remove an existing owned cosmetic.
local Config={Prices={Common=2500,Rare=7500,Epic=20000,Legendary=50000,Mythic=125000},Collections={}}
local sets={
	BrickSkins={{"Default","Default Classic","Common"},{"NeonClub","Neon Club","Rare"},{"CyberCore","Cyber Core","Epic"},{"OceanWave","Ocean Wave","Common"},{"Galaxy","Galaxy","Legendary"},{"GoldElite","Gold Elite","Legendary"},{"Lava","Lava","Epic"},{"CrystalGlass","Crystal Glass","Epic"},{"RetroPixel","Retro Pixel","Common"},{"Holographic","Holographic","Legendary"},{"Glitch","Glitch","Epic"},{"RoyalPrism","Royal Prism","Mythic"}},
	DropEffects={{"Default","Default","Common"},{"NeonSparks","Neon Shockwave","Rare"},{"LightningStrike","Lightning Strike","Epic"},{"Stardust","Galaxy Collapse","Legendary"},{"FireBurst","Inferno Slam","Epic"},{"PixelExplosion","Pixel Impact","Common"},{"CrystalShatter","Crystal Shatter","Epic"},{"CyberGlitch","Cyber Glitch","Rare"},{"GoldenImpact","Golden Impact","Legendary"},{"RoyalPrism","Royal Prism","Mythic"}},
	GhostEffects={{"Default","Classic Outline","Common"},{"NeonOutline","Neon Outline","Rare"},{"Hologram","Hologram","Rare"},{"Pulse","Neon Pulse","Epic"},{"Glitch","Glitch Phantom","Epic"},{"Prism","Prism","Legendary"},{"Electric","Electric","Epic"},{"PixelDotted","Pixel Dotted","Common"},{"CyberScanline","Cyber Scanline","Rare"},{"CrystalOutline","Crystal Outline","Epic"},{"GoldenTrace","Golden Trace","Legendary"},{"GalaxyShadow","Galaxy Shadow","Legendary"},{"RoyalPrism","Royal Prism Ghost","Mythic"}},
	SoundPacks={{"Default","Default 8-Bit","Common"},{"RetroArcade","Retro Arcade","Common"},{"Cyber","Cyber","Rare"},{"Crystal","Crystal","Epic"},{"NeonClub","Neon Club","Rare"},{"GoldenElite","Golden Elite","Legendary"},{"Galaxy","Galaxy","Legendary"}},
}
for category,rows in pairs(sets) do
	Config.Collections[category]={}
	for _,row in ipairs(rows) do table.insert(Config.Collections[category],{Id=row[1],Name=row[2],Rarity=row[3],Price=row[1]=="Default" and 0 or Config.Prices[row[3]],DefaultOwned=row[1]=="Default"}) end
end
return Config

end)()
local Catalog={Items={},Categories={"BrickSkins","DropEffects","GhostEffects","SoundPacks"},Slots={BrickSkins="BrickSkin",DropEffects="DropEffect",GhostEffects="GhostEffect",SoundPacks="SoundPack"},Prices=Definition.Prices}
local hues={{0.15,0.9,1},{0.7,0.4,1},{0.1,0.7,1},{0.8,0.5,1},{1,0.8,0.2},{1,0.3,0.1},{0.7,0.9,1}}
for category,rows in pairs(Definition.Collections) do
	for index,definition in ipairs(rows) do
		local item=table.clone(definition); item.Category=category; item.Description="Cosmetic only. Shared live-board renderer; no gameplay advantages."
		item.Preview={Kind="T",Color=hues[(index-1)%#hues+1]}; item.Visual={Blend=0,Transparency=0,Effect=index}; item.Audio={Pack=item.Id}; Catalog.Items[category..":"..item.Id]=item
	end
end
function Catalog.list(category)
	local out={}; for _,item in pairs(Catalog.Items) do if item.Category==category then table.insert(out,item) end end
	table.sort(out,function(a,b) if a.Price==b.Price then return a.Name<b.Name end; return a.Price<b.Price end); return out
end
return Catalog

end)()
local UIAssetConfig=(function()
-- UI images only. This module does not define or change gameplay or rank progression.
-- Upload PNGs to Roblox, then paste each numeric asset ID as a string.
-- Empty strings intentionally mean that the image has not been uploaded yet.
local Config = {}
Config.Images = {
    menu = {
        shop = "",
        inventory = "",
        quests = "",
        leaderboards = "",
        friends = "",
        login_rewards = "",
        more = "",
        help = "",
        redeem_code = "",
        profile = "",
        mail = "",
        audio = "",
        settings = "",
        emoji = "",
        chat = "",
    },
    shop = {
        cash_small = "",
        cash_large = "",
        energy_small = "",
        cash_medium = "",
        energy_large = "",
        energy_medium = "",
    },
    currency = {
        cash = "",
        energy = "",
    },
    quests = {
        ranked_wins = "",
        t_spins = "",
        send_lines = "",
        practice = "",
        play_time = "",
    },
    battle = {
        attack_arrow = "",
        ko = "",
        garbage_projectile = "",
        countdown_3 = "",
        countdown_2 = "",
        combo = "",
        go = "",
        countdown_1 = "",
        star_filled = "",
        star_empty = "",
    },
    cosmetics = {
        brick_default = "",
        brick_neon_club = "",
        brick_cyber_core = "",
        brick_gold_elite = "",
        brick_ocean_wave = "",
        drop_neon_comet = "",
        drop_plasma = "",
        brick_demon_wave = "",
        drop_solar = "",
        ghost_hologram = "",
        ghost_spectral = "",
        sound_pack = "",
        ghost_gold = "",
    },
}

Config.OptionalReferenceRanks = {
    Enabled = false,
    Images = {
        rookie = "",
        amateur = "",
        expert = "",
        master = "",
        pro = "",
        immortal = "",
    },
}

Config.Images.artwork = {preview="", background="", board_frame_pink="", board_frame_cyan="", perfect_clear=""}
Config.CosmeticArtwork = {BrickSkins={Default="brick_default",NeonClub="brick_neon_club",CyberCore="brick_cyber_core",OceanWave="brick_ocean_wave",GoldElite="brick_gold_elite"},DropEffects={NeonSparks="drop_neon_comet",LightningStrike="drop_plasma",FireBurst="drop_solar"},GhostEffects={Hologram="ghost_hologram",Prism="ghost_spectral",GoldenTrace="ghost_gold"}}
-- Explicit optional display mappings; these never alter actual rank labels or progression.
Config.OptionalReferenceRanks.Mapping = {Rookie="rookie",Master="master"}

function Config.ImageUri(assetId: string): string
    if type(assetId)~="string" then return "" end
    if assetId == "" then return "" end
    if string.match(assetId, "^%d+$") then return "rbxassetid://" .. assetId end
    if string.match(assetId, "^rbxassetid://%d+$") then return assetId end
    return "" -- Invalid/unuploaded IDs fall back safely.
end

return Config

end)()
local UIThemeConfig=(function()
-- Roblox's documented built-in font family; no fabricated uploaded asset ID.
-- Optional authorized font-family override here, then restart Play.
return {FontAsset="rbxasset://fonts/families/PressStart2P.json",Fallback="Arcade",Border=2,Radius=0,Touch=44,
 RarityColors={Common={145,154,175},Rare={63,203,255},Epic={180,92,255},Legendary={255,199,53},Mythic={255,71,162}},
 RarityMotion={Common=0,Rare=0,Epic=0.08,Legendary=0.13,Mythic=0.18}}

end)()
local DeveloperProductConfig=(function()
-- Existing project has no receipt processor. Do not enable purchases until a
-- server-verified, idempotent ProcessReceipt integration exists. UI grants nothing.
return {PurchasesEnabled=false,Cash={},Energy={}}

end)()
local BattleEffectsConfig=(function()
-- Presentation only. These values never change attack, rewards or delivery timing.
return {
	Announcements={Duration=0.85,QueueLimit=4,Scale=1.12,Intensity=0.65,ShakePixels=3},
	Attack={Duration=0.55,MaxProjectiles=10,MaxActive=24,Arc=50,Medium=3,Powerful=6,Intensity=0.7},
	Garbage={MeterMax=40,Width=5,FlashHz=2,Thresholds={1,4,8,12},Colors={{255,206,73},{255,154,52},{255,84,76},{255,42,88}}},
	Results={OutcomeDuration=0.8,KOAfter=0.35,CashAfter=0.7,RankAfter=1.1,RankDuration=1.2,HighlightDuration=1.4,Intensity=0.7},
	Countdown={PopDuration=0.22,GoDuration=0.65},
}

end)()
local ShopPreviewConfig=(function()
return {FPS=20,FallInterval=0.16,HardDropAfter=1.7,NextAfter=2.4,ClearEvery=3,Seed=1985,SoundSampleSeconds=1.6}

end)()
local DropEffectConfig=(function()
return {
	MaxActive=36,Duration=0.45,
	Styles={Default={Style="Pulse",Count=1,Color={210,183,255}},NeonSparks={Style="Wave",Count=5,Color={66,222,255}},LightningStrike={Style="Bolt",Count=6,Color={135,206,255}},Stardust={Style="Orbit",Count=10,Color={184,115,255}},FireBurst={Style="Flame",Count=10,Color={255,116,38}},PixelExplosion={Style="Pixel",Count=8,Color={244,132,211}},CrystalShatter={Style="Shard",Count=8,Color={128,231,249}},CyberGlitch={Style="Glitch",Count=5,Color={71,241,184}},GoldenImpact={Style="Spark",Count=10,Color={255,209,74}},RoyalPrism={Style="Prism",Count=10,Color={216,137,255}}},
}

end)()
local RankIconConfig=(function()
-- Upload original icons, then paste their IDs. Empty uses a drawn arcade badge.
return {Icons={Rookie="",Bronze="",Silver="",Gold="",Platinum="",Diamond="",Master=""},Fallback={Rookie="I",Bronze="II",Silver="III",Gold="IV",Platinum="V",Diamond="VI",Master="M"}}

end)()
local CurrencyIconConfig=(function()
-- Empty IDs render original text/vector fallbacks, never guessed assets.
return {Cash="",Energy="",CashFallback="$",EnergyFallback="E"}

end)()
local BrickSkinConfig=(function()
return {
	Default={Texture="Bevel",Blend=0,Inset=1},NeonClub={Texture="Neon",Blend=0.12,Tint={255,61,143},Inset=1},
	CyberCore={Texture="Circuit",Blend=0.22,Tint={40,60,94},Inset=1},OceanWave={Texture="Wave",Blend=0.18,Tint={24,158,202},Inset=1},
	Galaxy={Texture="Star",Blend=0.23,Tint={113,50,158},Inset=1},GoldElite={Texture="Gold",Blend=0.4,Tint={238,181,63},Inset=1},
	Lava={Texture="Lava",Blend=0.28,Tint={221,63,33},Inset=1},CrystalGlass={Texture="Crystal",Blend=0.15,Tint={178,223,237},Inset=2},
	RetroPixel={Texture="Pixel",Blend=0,Inset=2},Holographic={Texture="Scan",Blend=0.12,Tint={92,225,218},Inset=1},
	Glitch={Texture="Glitch",Blend=0.12,Tint={153,236,242},Inset=1},RoyalPrism={Texture="Prism",Blend=0.12,Tint={189,129,255},Inset=1},
}

end)()
local GhostEffectConfig=(function()
return {Default={Alpha=1},NeonOutline={Alpha=0.95},Hologram={Alpha=0.9},Pulse={Alpha=0.97},Glitch={Alpha=0.97},Prism={Alpha=0.98},Electric={Alpha=0.98},PixelDotted={Alpha=1},CyberScanline={Alpha=0.96},CrystalOutline={Alpha=1},GoldenTrace={Alpha=1},GalaxyShadow={Alpha=0.93},RoyalPrism={Alpha=0.97}}

end)()
local SoundConfig=(function()
-- Paste either numeric IDs as strings or rbxassetid:// IDs. Empty = silent.
local sounds={
	MenuMusic="110330829622733",
	SoloMusic="138979811477380",
	BattleMusic="136554718551564",
	ShopMusic="84359335654997",
	ButtonHover="134814053995019",
	ButtonClick="71353633290091",
	Matchmaking="129670809831175",
	OpponentFound="115988129894109",
	Countdown="87446420241846",
	MatchStart="118359496940699",
	Move="105404106409406",
	Rotate="127019355851900",
	SoftDrop="103715622398309",
	HardDrop="100305878536780",
	Lock="116338379410805",
	Hold="125367569240409",
	Single="103118877484493",
	Double="87238183923829",
	Triple="127061565542592",
	Tetris="83875684367313",
	TSpin="112365864237503",
	TSpinMini="138155773317738",
	TSpinSingle="82975882466353",
	TSpinDouble="120602992102631",
	TSpinTriple="113352039779614",
	Combo="110063633179627",
	BackToBack="103391946920570",
	PerfectClear="122222769612506",
	GarbageSend="80246600043838",
	GarbageReceive="123369851887132",
	KO="72669342410155",
	Victory="85224322429849",
	Defeat="119969616616526",
	Draw="79488496178587",
	RankUp="71714673403876",
	RankDown="138326488423519",
	CashEarned="136747218187542",
	EnergyRestored="119944444710851",
	QuestComplete="108821911840527",
	QuestClaim="94177420329820",
	Purchase="109774926433136",
	Equip="91636886424886",
	SeasonReward="73661580915742",
	-- Upload permitted 8-bit assets; empty IDs are silent until configured.
	GarbageWarningLow="",GarbageWarningMedium="",GarbageWarningHigh="",GarbageWarningCritical="",
	RankProgress="",StarEarned="",StarLost="",VictoryFanfare="",
}
return {
	MasterVolume=1,MusicVolume=0.5,SFXVolume=0.8,Sounds=sounds,
	GarbageWarning={Cooldowns={3,1.8,1.1,0.7},Volumes={0.22,0.3,0.4,0.5},MaxSampleSeconds=0.5,MinimumInterval=0.65},
	CountdownVariants={}, -- Optional [3], [2], [1] sound IDs; falls back to Countdown.
	-- Sound pack overrides are configured here, never in gameplay scripts.
	Packs={Default={Pitch=1,Sounds={}},RetroArcade={Pitch=1.2,Sounds={}},Cyber={Pitch=0.85,Sounds={}},Crystal={Pitch=1.4,Sounds={}},NeonClub={Pitch=1.05,Sounds={}},GoldenElite={Pitch=1,Sounds={}},Galaxy={Pitch=1,Sounds={}}},
}

end)()
local deferred={}; local delayed={}
local function signal()
	local e={Handlers={}}
	function e:Connect(fn) table.insert(self.Handlers,fn); return {Disconnect=function() for i,handler in ipairs(self.Handlers) do if handler==fn then table.remove(self.Handlers,i); break end end end} end
	function e:Once(fn) return self:Connect(fn) end
	function e:fire(...) for _,fn in ipairs(self.Handlers) do fn(...) end end
	return e
end
local task={defer=function(fn) table.insert(deferred,fn) end,delay=function(seconds,fn) table.insert(delayed,{Seconds=seconds,Run=fn}) end,wait=function() coroutine.yield() end,spawn=function(fn) local co=coroutine.create(fn); local ok,err=coroutine.resume(co); assert(ok,err) end}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local UDim={new=function(s,o) return {Scale=s,Offset=o} end}
local UDim2={}
function UDim2.new(xs,xo,ys,yo) return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo)} end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
local Color3={}
function Color3.new(r,g,b) return setmetatable({R=r,G=g,B=b},{__index={Lerp=function(self,other,a) return Color3.new(self.R+(other.R-self.R)*a,self.G+(other.G-self.G)*a,self.B+(other.B-self.B)*a) end}}) end
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
function Color3.fromHSV() return Color3.new(1,0,1) end
local ColorSequence={new=function(v) return v end}
local ColorSequenceKeypoint={new=function(...) return {...} end}
local TweenInfo={new=function(...) return {...} end}
local Enum=setmetatable({},{__index=function(t,key)
	local group=setmetatable({},{__index=function(g,k) local value={Name=k}; rawset(g,k,value); return value end}); rawset(t,key,group); return group
end})
local Font={new=function(family) return {Family=family} end,fromEnum=function(font) return {Name=font.Name} end}
local Instance={}
local methods={}
function methods:GetChildren() return table.clone(self.Children) end
function methods:FindFirstChildOfClass(class) for _,child in ipairs(self.Children) do if child.ClassName==class then return child end end end
function methods:FindFirstChild(name,recursive) for _,c in ipairs(self.Children) do if c.Name==name then return c end; if recursive then local found=c:FindFirstChild(name,true); if found then return found end end end end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),"Missing child "..name.." in "..self.Name) end
function methods:IsA(class) return self.ClassName==class or class=="GuiObject" and ({Frame=true,TextLabel=true,TextButton=true,ImageLabel=true,CanvasGroup=true,ScrollingFrame=true})[self.ClassName] or false end
function methods:SetAttribute(k,v) self.Attributes[k]=v end
function methods:GetAttribute(k) return self.Attributes[k] end
function methods:GetPropertyChangedSignal() return signal() end
function methods:Destroy()
	if self.Destroying then self.Destroying:fire() end
	local parent=self.Parent
	if self.Parent then for i,c in ipairs(self.Parent.Children) do if c==self then table.remove(self.Parent.Children,i); break end end end
	self.Props.Parent=nil
	if parent and parent.ClassName=="ScrollingFrame" then local hasRows=false; for _,child in ipairs(parent.Children) do if child:IsA("GuiObject") then hasRows=true end end; if not hasRows then parent.CanvasPosition=Vector2.new(0,0) end end
end
function methods:Play() self.IsPlaying=true end
function methods:Stop() self.IsPlaying=false end
function Instance.new(class)
	local obj={Props={ClassName=class,Name=class,Visible=true,AbsoluteSize=Vector2.new(1366,768),IsLoaded=true,IsPlaying=false,ZIndex=1},Children={},Attributes={}}
	setmetatable(obj,{__index=function(self,key)
		if methods[key] then return methods[key] end
		if self.Props[key]~=nil then return self.Props[key] end
		if ({MouseEnter=true,MouseLeave=true,SelectionGained=true,SelectionLost=true,Activated=true,InputBegan=true,InputEnded=true,Destroying=true,Loaded=true})[key] then self.Props[key]=signal(); return self.Props[key] end
		return methods.FindFirstChild(self,key)
	end,__newindex=function(self,key,value)
		if key=="CanvasPosition" and self.ClassName=="ScrollingFrame" then local hasRows=false; for _,child in ipairs(self.Children) do if child:IsA("GuiObject") then hasRows=true end end; if not hasRows then value=Vector2.new(0,0) end end
		if key=="Parent" and value~=self.Props.Parent then
 if self.Props.Parent then for i,c in ipairs(self.Props.Parent.Children) do if c==self then table.remove(self.Props.Parent.Children,i); break end end end
 if value then table.insert(value.Children,self) end
end
		self.Props[key]=value
	end})
	return obj
end
local function named(class,name,parent) local obj=Instance.new(class); obj.Name=name; obj.Parent=parent; return obj end
local ReplicatedStorage=named("Folder","ReplicatedStorage")
local Shared=named("Folder","Shared",ReplicatedStorage)
local ConfigFolder=named("Folder","Config",Shared)
for _,name in ipairs({"TetrisEngine","Progression","Catalog"}) do named("ModuleScript",name,Shared) end
for _,name in ipairs({"UIAssetConfig","UIThemeConfig","DeveloperProductConfig","Rules","SoundConfig","BattleEffectsConfig","ShopPreviewConfig","DropEffectConfig","RankIconConfig","CurrencyIconConfig","BrickSkinConfig","GhostEffectConfig"}) do named("ModuleScript",name,ConfigFolder) end
local Network=named("RemoteEvent","Network",Shared); Network.OnClientEvent=signal()
local requests={}; function Network:FireServer(kind,payload) table.insert(requests,{Kind=kind,Payload=payload}) end
local PlayerGui=named("Folder","PlayerGui")
local player=named("Player","LocalPlayer"); player.UserId=123; player.DisplayName="Test Player"; PlayerGui.Parent=player
local Players={LocalPlayer=player,GetPlayers=function() return {player} end}
local UIS={GamepadEnabled=false,InputEnded=signal(),WindowFocusReleased=signal(),InputBegan=signal(),GetFocusedTextBox=function() return nil end}
local CAS={BindActionAtPriority=function() end,UnbindAction=function() end}
local RunService={RenderStepped=signal()}
local SoundService=named("Folder","SoundService")
local TweenService={Create=function(_,obj,_,properties) return {Play=function() for k,v in pairs(properties) do obj[k]=v end end,Cancel=function() end,Completed=signal()} end}
local TextService={GetTextSize=function(_,value,size,_,bounds)
	local lines=0; for _,line in ipairs(string.split(value,"\n")) do lines+=math.max(1,math.ceil(#line*size*0.55/bounds.X)) end
	return Vector2.new(bounds.X,lines*size*1.2)
end}
local services={Players=Players,ReplicatedStorage=ReplicatedStorage,UserInputService=UIS,GuiService={},RunService=RunService,ContextActionService=CAS,SoundService=SoundService,TweenService=TweenService,TextService=TextService,ContentProvider={},SocialService={}}
local game=setmetatable({GetService=function(_,name) return assert(services[name],"Unknown service "..name) end},{__index=services})
local workspace={GetServerTimeNow=function() return 1791590400 end}
local clientFolder=named("Folder","Client")
for _,name in ipairs({"UIAssets","RetroTheme","RetroArtwork","BrickStyles","BrickRenderer","BrickPreviewRenderer","NeonUI","NeonLayout","GameClient","ArcadeFeedback","ArcadeResults","PortalUI","AudioController","InputController","CosmeticRenderer"}) do named("ModuleScript",name,clientFolder) end
local script={Parent=clientFolder}
local modules={UIAssetConfig=UIAssetConfig,UIThemeConfig=UIThemeConfig,DeveloperProductConfig=DeveloperProductConfig,TetrisEngine=E,Rules=R,Progression=P,SoundConfig=SoundConfig,Catalog=Catalog,BattleEffectsConfig=BattleEffectsConfig,ShopPreviewConfig=ShopPreviewConfig,DropEffectConfig=DropEffectConfig,RankIconConfig=RankIconConfig,CurrencyIconConfig=CurrencyIconConfig,BrickSkinConfig=BrickSkinConfig,GhostEffectConfig=GhostEffectConfig}
local require=function(obj) return assert(modules[type(obj)=="string" and obj or obj.Name],"Unknown module") end
local warn=print

modules.UIAssets=(function()
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared:WaitForChild("Config"):WaitForChild("UIAssetConfig"))
local Ranks=require(Shared.Config:WaitForChild("RankIconConfig"))
local Currency=require(Shared.Config:WaitForChild("CurrencyIconConfig"))
local Assets={Config=Config}
function Assets.uri(key)
 local value=Config
 for part in key:gmatch("[^%.]+") do value=type(value)=="table" and value[part] or nil end
 return Config.ImageUri(value)
end
function Assets.rank(name)
 local current=Config.ImageUri(Ranks.Icons[name]); if current~="" then return current end
 local optional=Config.OptionalReferenceRanks
 return optional.Enabled and optional.Mapping[name] and Config.ImageUri(optional.Images[optional.Mapping[name]]) or ""
end
function Assets.currency(name)
 return Assets.uri("Images.currency."..name:lower())~="" and Assets.uri("Images.currency."..name:lower()) or Config.ImageUri(Currency[name])
end
function Assets.cosmetic(item)
 local key=Config.CosmeticArtwork[item.Category] and Config.CosmeticArtwork[item.Category][item.Id]
 if item.Category=="SoundPacks" then key="sound_pack" end
 return key and Assets.uri("Images.cosmetics."..key) or ""
end
function Assets.image(UI,parent,name,uri)
 return UI.new("ImageLabel",name,parent,{BackgroundTransparency=1,Image=uri,Visible=uri~="",ScaleType=Enum.ScaleType.Fit,ResampleMode=Enum.ResamplerMode.Pixelated,ZIndex=parent.ZIndex+1})
end
function Assets.icon(UI,parent,key)
 local icon=Assets.image(UI,parent,"AssetIcon",Assets.uri(key)); icon.Size=UDim2.fromOffset(28,28); icon.Position=UDim2.new(0,10,0.5,-14)
 if icon.Visible and parent:IsA("TextButton") then local pad=UI.new("UIPadding","IconPadding",parent,{PaddingLeft=UDim.new(0,38),PaddingRight=UDim.new(0,6)}); parent.TextSize=math.min(parent.TextSize,13) end
 return icon
end
return Assets

end)()

modules.RetroTheme=(function()
-- One palette/type/spacing source for the complete arcade interface.
local Settings=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIThemeConfig"))
local Theme={RGB={
	background={12,7,20},panel={27,15,42},raised={40,22,58},board={10,7,17},empty={24,16,35},
	text={255,244,228},muted={176,158,191},line={75,43,92},pink={255,61,143},purple={219,49,139},
	cyan={83,213,226},orange={255,152,81},yellow={255,218,137},green={127,222,173},
	I={85,215,230},O={255,212,112},T={185,118,242},S={128,221,171},Z={248,97,143},J={111,146,238},L={255,164,98},G={104,87,124},
},Fonts={Display=Enum.Font.Arcade,Body=Enum.Font.Arcade,Strong=Enum.Font.Arcade,Mono=Enum.Font.Arcade},
Type={Hero=54,Heading=22,Body=16,Label=13,Number=28},Space={Small=8,Medium=16,Large=24,XL=32},Border=Settings.Border,Radius=Settings.Radius,Touch=44,
Motion={Hover=0.12,Page=0.18,Preview=0.7}}
Theme.Colors={}; for name,rgb in pairs(Theme.RGB) do Theme.Colors[name]=Color3.fromRGB(table.unpack(rgb)) end
local ok,face=pcall(function() return Font.new(Settings.FontAsset,Enum.FontWeight.Regular,Enum.FontStyle.Normal) end)
Theme.Face=ok and face or Font.fromEnum(Enum.Font.Arcade)
Theme.FontFamily=ok and Settings.FontAsset or "Roblox Arcade fallback"
return Theme

end)()

modules.NeonUI=(function()
-- Compatibility name; all styling comes from RetroTheme.
local TweenService=game:GetService("TweenService")
local Assets=require(script.Parent:WaitForChild("UIAssets"))
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local UI={reducedMotion=false,theme=Theme,colors=Theme.Colors}
function UI.new(class,name,parent,props)
	local object=Instance.new(class); object.Name=name
	for key,value in pairs(props or {}) do object[key]=value end
	object.Parent=parent; return object
end
function UI.round(object,radius) return UI.new("UICorner","Corner",object,{CornerRadius=UDim.new(0,radius or Theme.Radius)}) end
function UI.stroke(object,color,transparency,thickness)
	return UI.new("UIStroke","Outline",object,{Color=color or UI.colors.line,Transparency=transparency or 0,Thickness=thickness or Theme.Border,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
function UI.panel(name,parent,accent)
	local panel=UI.new("Frame",name,parent,{BackgroundColor3=UI.colors.panel,BorderSizePixel=0})
	UI.round(panel); UI.stroke(panel,accent or UI.colors.line,accent and 0.2 or 0)
 UI.new("Frame","PixelEdge",panel,{Size=UDim2.new(1,-12,0,2),Position=UDim2.fromOffset(6,3),BackgroundColor3=accent or UI.colors.line,BorderSizePixel=0,BackgroundTransparency=0.45})
 return panel
end
function UI.text(name,parent,value,size,color,font)
	return UI.new("TextLabel",name,parent,{BackgroundTransparency=1,Text=tostring(value),TextColor3=color or UI.colors.text,
		FontFace=Theme.Face,TextSize=size or Theme.Type.Body,TextWrapped=true,
		TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center})
end
function UI.rect(object,rect) object.Position=UDim2.fromOffset(rect[1],rect[2]); object.Size=UDim2.fromOffset(rect[3],rect[4]) end
function UI.tween(object,properties,duration)
	if UI.reducedMotion then for key,value in pairs(properties) do object[key]=value end; return nil end
	local tween=TweenService:Create(object,TweenInfo.new(duration or Theme.Motion.Hover,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties); tween:Play(); return tween
end
function UI.enabled(button,value)
	button:SetAttribute("Disabled",not value); button.Interactable=value; button.Selectable=value
	button.TextColor3=value and UI.colors.text or UI.colors.muted; button.BackgroundTransparency=value and 0 or 0.4
end
function UI.button(name,parent,text,accent,clicked)
	accent=accent or UI.colors.pink
	local button=UI.new("TextButton",name,parent,{BackgroundColor3=UI.colors.panel,BorderSizePixel=0,AutoButtonColor=false,
		Text=text,TextSize=12,TextColor3=UI.colors.text,FontFace=Theme.Face,Selectable=true,TextWrapped=true})
	UI.round(button); local outline=UI.stroke(button,accent,0.15)
	local function focus(active)
		if button:GetAttribute("Disabled") or not UI.canInteract(button) then return end
		UI.tween(button,{BackgroundColor3=active and UI.colors.raised or UI.colors.panel}); UI.tween(outline,{Color=active and UI.colors.yellow or accent})
	end
	button.MouseEnter:Connect(function() if UI.canInteract(button) then focus(true); if UI.onHover then UI.onHover() end end end); button.MouseLeave:Connect(function() focus(false) end)
	button.SelectionGained:Connect(function() focus(true) end); button.SelectionLost:Connect(function() focus(false) end)
	button.Activated:Connect(function()
  if not UI.canInteract(button) then return end
  if not button:GetAttribute("Disabled") and clicked then clicked() end
 end)
 button.InputBegan:Connect(function(input) if UI.canInteract(button) and not button:GetAttribute("Disabled") and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then UI.tween(button,{BackgroundColor3=UI.colors.line},0.08) end end)
 button.InputEnded:Connect(function() focus(false) end)
	return button
end
function UI.canInteract(button)
 local node=button; local modal=UI.ActiveModal
 if modal then while node and node~=modal do node=node.Parent end; if node~=modal then return false end end
 return true
end
function UI.divider(parent,name) return UI.new("Frame",name,parent,{BackgroundColor3=UI.colors.line,BorderSizePixel=0,Size=UDim2.new(1,0,0,1)}) end
function UI.focusGroup(object)
	object.SelectionGroup=true
	for _,direction in ipairs({"Up","Down","Left","Right"}) do object["SelectionBehavior"..direction]=Enum.SelectionBehavior.Stop end
end
function UI.icon(parent,key) return Assets.icon(UI,parent,key) end
function UI.image(parent,name,uri) return Assets.image(UI,parent,name,uri) end
function UI.measure(text,size,width)
 local lines=0; for _,line in ipairs(string.split(tostring(text),"\n")) do lines+=math.max(1,math.ceil(#line*size/math.max(1,width))) end
 return lines*size*1.25
end
return UI

end)()

modules.NeonLayout=(function()
-- Physical design pixels: normal device sizes do not shrink readable text.
local Layout={}
function Layout.resolve(width,height,battle)
	local w,h=math.max(320,width),math.max(280,height)
	local compact=h<540 and w>h; local portrait=not compact and w/h<0.9
 local menu={brand={16,12,1,1},status={16,12,1,1}}
 if portrait or compact and w<720 then
  local cw=w-32; menu.header={16,12,cw-100,56}; menu.settings={w-60,12,44,44}; menu.mail={w-112,12,44,44}; menu.cash={16,78,(cw-8)/2,44}; menu.energy={24+(cw-8)/2,78,(cw-8)/2,44}
  menu.kicker={16,142,cw,24}; menu.title={16,176,cw,120}; menu.titleSize=math.min(40,math.floor(cw/8)); menu.solo={16,318,cw,52}; menu.battle={16,382,cw,52}; menu.nav={16,454,cw,232}; menu.navColumns=2; menu.footer={16,700,cw,24}
 elseif compact or h<660 then
  menu.header={16,8,220,56}; menu.settings={w-60,12,44,44}; menu.mail={w-112,12,44,44}; menu.cash={w-420,12,140,44}; menu.energy={w-272,12,152,44}
  menu.kicker={24,76,260,20}; menu.title={24,100,math.max(240,w*0.36),104}; menu.titleSize=30; menu.solo={w*0.47,88,w*0.53-24,48}; menu.battle={w*0.47,148,w*0.53-24,48}; menu.nav={24,h-92,w-48,72}; menu.navColumns=6; menu.footer={0,0,0,0}
 else
  menu.header={24,16,280,64}; menu.settings={w-72,20,48,48}; menu.mail={w-128,20,48,48}; menu.cash={w-492,20,172,48}; menu.energy={w-312,20,176,48}
  local top=math.max(120,h*0.20); menu.kicker={48,top-32,w-96,24}; menu.title={48,top,math.min(520,w-96),140}; menu.titleSize=54
  local by=math.min(h-204,top+190); menu.solo={48,by,(w-112)/2,56}; menu.battle={64+(w-112)/2,by,(w-112)/2,56}; menu.nav={48,by+80,w-96,72}; menu.navColumns=6; menu.footer={48,h-36,w-96,24}
 end
	local game={back={16,12,96,44},heading={128,12,w-256,44},settings={w-112,12,96,44}}
	if portrait then
		local side=math.floor(math.clamp(w*0.2,66,96)); local short=h<660; local singleRow=short and w>=388; local cy=h-(singleRow and 60 or 124)
		local top=short and 128 or 148; local reserve=short and 68 or 80
		local cell=math.max(4,math.floor(math.min((w-32-side*(battle and 2 or 1)-(battle and 20 or 10))/10,(cy-reserve-top-12)/20)))
		local bw,bh=cell*10,cell*20; local x=battle and (w-bw)/2 or (w-side-10-bw)/2+side+10
		game.board={x,top,bw,bh}; game.player={x,top-44,bw,36}; game.hold={x-side-10,top,side,88}
		game.next={x-side-10,top+104,side,math.min(250,math.max(80,bh-104))}
		game.opponent={x+bw+10,top,side,side*2}; game.opponentPlayer={x+bw+10,top-44,side,36}
		game.enemyStats={x+bw+10,top+side*2+12,side,short and 60 or 88}; game.ownStats={16,cy-reserve,w-32,56}
		game.timer={16,58,108,28}; game.banner={136,58,w-152,28}; game.controls={16,cy,w-32,singleRow and 44 or 108}; game.controlColumns=singleRow and 7 or 4
	else
		local top=compact and 88 or 132; local cy=h-60; local side=compact and 160 or 112; local middle=compact and 148 or 180; local gap=compact and 16 or 24
		local available=cy-top-16; local maxWidth=battle and (w-32-side*(compact and 1 or 2)-middle-gap*(compact and 3 or 4))/2 or (w-32-side*2-middle-gap*3)
		local cell=math.max(4,math.floor(math.min(available/20,maxWidth/10))); local bw,bh=cell*10,cell*20
		local bodyW=side+gap+bw+gap+middle+(battle and gap+bw+(compact and 0 or gap+side) or compact and 0 or gap+side); local left=(w-bodyW)/2
		game.hold={left,top,side,compact and 68 or 104}; game.next={battle and left or left+side+gap+bw+gap, battle and top+(compact and 80 or 124) or top,side,battle and bh-(compact and 80 or 124) or bh}
		if compact then game.hold={left+84,top,72,68}; game.next={left,top,72,bh} end
		local x=left+side+gap; local center=(battle or compact) and x+bw+gap or x+bw+gap+side+gap
		game.board={x,top,bw,bh}; game.player={x,top-44,bw,36}
		game.opponent={center+middle+gap,top,bw,bh}; game.enemyHold={center+middle+gap+bw+gap,top,side,104}; game.enemyNext={center+middle+gap+bw+gap,top+124,side,math.max(40,bh-124)}; game.opponentPlayer={center+middle+gap,top-44,bw,36}
		if compact and battle then local ew=math.max(4,cell-1)*10; game.opponent={center+middle+gap,top+(bh-ew*2)/2,ew,ew*2}; game.opponentPlayer[3]=ew end
		game.timer={center,top,middle,compact and 42 or 72}
		game.ownStats={center,top+(compact and 42 or 88),middle,compact and math.min(128,cy-top-50) or 176}
		game.enemyStats={center,top+(compact and 156 or 292),middle,compact and 0 or 140}
		game.banner=compact and {center,58,middle,24} or {16,66,w-32,24}; game.controls={(w-math.min(640,w-32))/2,cy,math.min(640,w-32),44}; game.controlColumns=7
	end
 if not battle and not compact and not portrait then
  local side,gap,top=112,24,132; local cell=math.max(4,math.floor(math.min((h-top-76)/20,(w-32-side*2-gap*2)/10))); local bw,bh=cell*10,cell*20; local x=(w-bw)/2
  game.board={x,top,bw,bh}; game.hold={x-side-gap,top,side,104}; game.next={x+bw+gap,top,side,bh}; game.ownStats={x-side-gap,top+124,side,176}; game.player={x-side-gap,top-64,bw+side*2+gap*2,56}; game.timer={x,12,bw,64}; game.heading={128,12,math.max(1,x-152),44}; game.banner={x,80,bw,32}
 end
 if battle and compact and w>=760 then
  local side,gap,middle,top=60,8,124,88; local cell=math.max(4,math.floor(math.min((h-top-68)/20,(w-32-4*side-middle-6*gap)/20))); local bw,bh=cell*10,cell*20; local left=(w-(4*side+2*bw+middle+6*gap))/2
  local x=left+side+gap; local center=x+bw+gap+side+gap; local eh=center+middle+gap; local ex=eh+side+gap
  game.board={x,top,bw,bh}; game.hold={left,top,side,68}; game.next={x+bw+gap,top,side,bh}; game.ownStats={left,top+80,side,math.max(40,bh-80)}; game.player={left,top-40,side*2+bw+gap*2,36}
  game.opponent={ex,top,bw,bh}; game.enemyHold={eh,top,side,68}; game.enemyNext={ex+bw+gap,top,side,bh}; game.enemyStats={eh,top+80,side,math.max(40,bh-80)}; game.opponentPlayer={eh,top-40,side*2+bw+gap*2,36}; game.timer={center,88,middle,44}; game.banner={center,136,middle,28}
 end
 if battle and not portrait and not compact then
  local side=math.clamp(w*0.065,60,92); local middle=math.clamp(w*0.13,120,220); local gap=12; local top=132
  local cell=math.max(4,math.floor(math.min((h-top-104)/20,(w-48-4*side-middle-6*gap)/20))); local bw,bh=cell*10,cell*20; local left=(w-(4*side+2*bw+middle+6*gap))/2
  local x=left+side+gap; local center=x+bw+gap+side+gap; local eh=center+middle+gap; local ex=eh+side+gap
  game.board={x,top,bw,bh}; game.hold={left,top,side,104}; game.next={x+bw+gap,top,side,bh}; game.ownStats={left,top+120,side,math.min(176,bh-120)}; game.player={left,top-64,side*2+bw+gap*2,56}
  game.opponent={ex,top,bw,bh}; game.enemyHold={eh,top,side,104}; game.enemyNext={ex+bw+gap,top,side,bh}; game.enemyStats={eh,top+120,side,math.min(176,bh-120)}; game.opponentPlayer={eh,top-64,side*2+bw+gap*2,56}; game.timer={center-16,12,middle+32,64}; game.heading={128,12,math.max(1,center-152),44}; game.banner={center-16,82,middle+32,32}
 end
 game.footer={16,h-16,w-32,12}
	return {width=w,height=h,scale=math.min(width/w,height/h),portrait=portrait,compact=compact,menu=menu,game=game}
end
return Layout

end)()

modules.RetroArtwork=(function()
-- Original native-UI artwork; no bitmap or third-party image IDs.
local Assets=require(script.Parent:WaitForChild("UIAssets"))
local Art={}; Art.__index=Art
function Art.new(parent,UI)
	local self=setmetatable({UI=UI,Lines={}},Art); local C=UI.colors
	self.Frame=UI.new("Frame","SynthwaveArtwork",parent,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,BorderSizePixel=0,ClipsDescendants=true})
	self.Sun=UI.new("Frame","StripedSun",self.Frame,{BackgroundTransparency=1})
	for index=0,63 do local y=(index+0.5)/64; local chord=math.sqrt(math.max(0,1-(y*2-1)^2))
		if index<30 or index%6<4 then UI.new("Frame","SunBand"..index,self.Sun,{Position=UDim2.fromScale((1-chord)/2,index/64),Size=UDim2.new(chord,0,1/64,1),BorderSizePixel=0,BackgroundColor3=C.yellow:Lerp(C.orange,y),ZIndex=1}) end
	end
	self.City=UI.new("Frame","DistantCity",self.Frame,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=2})
	for index=0,29 do local height=0.035+(index*7%11)*0.004
		UI.new("Frame","Building"..index,self.City,{Position=UDim2.fromScale(index/30,0.70-height),Size=UDim2.fromScale(0.038,height),BackgroundColor3=Color3.fromRGB(18,10,29),BorderSizePixel=0,ZIndex=2})
		if index%5==0 then UI.new("Frame","Antenna"..index,self.City,{Position=UDim2.fromScale((index+0.45)/30,0.687-height),Size=UDim2.new(0,1,0.018,0),BackgroundColor3=C.line,BorderSizePixel=0,ZIndex=2}) end
	end
	for index=1,23 do self.Lines[index]=UI.new("Frame","PerspectiveLine"..index,self.Frame,{BackgroundColor3=C.purple,BackgroundTransparency=0.78,BorderSizePixel=0,AnchorPoint=Vector2.new(0.5,0.5),ZIndex=3}) end
	self.Background=UI.image(self.Frame,"UploadedBackdrop",Assets.uri("Images.artwork.background")); self.Background.Size=UDim2.fromScale(1,1); self.Background.ScaleType=Enum.ScaleType.Crop; self.Background.ZIndex=3
 self.Dim=UI.new("Frame","ArtworkDim",self.Frame,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4})
	return self
end
function Art:layout(width,height,portrait)
	local size=math.min(width*(portrait and 0.54 or 0.37),height*0.5)
	local cx=width*(self.Battle and not portrait and 0.5 or portrait and 0.79 or 0.76); local cy=height*(portrait and 0.25 or 0.43)
	if self.Battle and not portrait then size=math.min(width*0.26,height*0.44) end
	for _,band in ipairs(self.Sun:GetChildren()) do local y=(tonumber(band.Name:match("%d+"))+0.5)/64; local warm=self.UI.colors.yellow:Lerp(self.UI.colors.orange,y); band.BackgroundColor3=portrait and warm:Lerp(self.UI.colors.background,0.52) or warm end
	self.Sun.Position=UDim2.fromOffset(cx-size/2,cy-size/2); self.Sun.Size=UDim2.fromOffset(size,size)
	local horizon=height*(portrait and 0.42 or 0.70); local center=width*0.63
	self.City.Position=UDim2.fromOffset(0,horizon-height*0.70)
	local function line(index,x1,y1,x2,y2)
		local node=self.Lines[index]; local dx,dy=x2-x1,y2-y1
		node.Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2); node.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),1); node.Rotation=math.deg(math.atan2(dy,dx))
	end
	for index=1,13 do line(index,center+(index-7)*width*0.018,horizon,(index-7)*width*0.16+center,height) end
	for index=1,10 do local y=horizon+(height-horizon)*(index/10)^2; line(index+13,0,y,width,y) end
end
function Art:quiet(value) self.Dim.BackgroundTransparency=value and (self.Classic and 0.12 or 0.7) or 1 end
function Art:destroy() self.Frame:Destroy() end
return Art

end)()

modules.BrickStyles=(function()
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local Config=game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
local Styles={Skins=require(Config:WaitForChild("BrickSkinConfig")),Ghosts=require(Config:WaitForChild("GhostEffectConfig"))}
function Styles.describe(kind,skinId,ghostId,ghost,reduced,clock)
	local C=Theme.Colors; local skin=Styles.Skins[skinId] or Styles.Skins.Default; local base=C[kind] or C.G
	if kind=="G" then skin={Texture="Metal",Inset=1}; base=Color3.fromRGB(99,104,130) end
	if skin.Tint then base=base:Lerp(Color3.fromRGB(table.unpack(skin.Tint)),skin.Blend) end
	local border=base:Lerp(C.text,skin.Texture=="Neon" and 0.65 or 0.3); local fill=0; local time=reduced and 0 or clock or 0
	if ghost then
		local effect=Styles.Ghosts[ghostId] or Styles.Ghosts.Default; fill=effect.Alpha
		if ghostId=="Pulse" then fill+=math.sin(time*4)*0.02 elseif ghostId=="Glitch" then fill+=math.floor(time*6)%2*0.02
		elseif ghostId=="Prism" or ghostId=="RoyalPrism" then border=border:Lerp(Color3.fromHSV(time%6/6,0.6,1),0.35)
		elseif ghostId=="GoldenTrace" then border=Color3.fromRGB(255,207,88) elseif ghostId=="GalaxyShadow" then border=Color3.fromRGB(179,133,245) elseif ghostId=="Electric" then fill+=math.sin(time*12)*0.015 end
	end
	return {Color=base,Edge=border,Transparency=math.clamp(fill,0,1),Texture=ghost and ghostId or skin.Texture,Inset=skin.Inset,Ghost=ghost}
end
return Styles

end)()

modules.AudioController=(function()
local SoundService=game:GetService("SoundService")
local Config=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SoundConfig"))
local Effects=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("BattleEffectsConfig"))
local PreviewConfig=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ShopPreviewConfig"))
local Audio={}; Audio.__index=Audio
function Audio.normalize(value)
	if type(value)~="string" then return "" end
	local id=value:match("^%s*(%d+)%s*$") or value:match("^rbxassetid://(%d+)$")
	return id and "rbxassetid://"..id or ""
end
function Audio.new()
	local self=setmetatable({Pool={},Muted=false,Pack="Default",Master=Config.MasterVolume,MusicVolume=Config.MusicVolume,SFXVolume=Config.SFXVolume,Failed={}},Audio)
	self.Folder=Instance.new("Folder"); self.Folder.Name="TetrisAudio"; self.Folder.Parent=SoundService
	self.Music=Instance.new("Sound"); self.Music.Name="Music"; self.Music.Looped=true; self.Music.Parent=self.Folder
	self.Warning=Instance.new("Sound"); self.Warning.Name="GarbageWarning"; self.Warning.Parent=self.Folder; self.WarningNext=0; self.WarningGeneration=0
	return self
end
function Audio:resolve(key,packId)
	local pack=Config.Packs[packId or self.Pack] or Config.Packs.Default
	return Audio.normalize(pack.Sounds[key] or Config.Sounds[key]),pack.Pitch or 1
end
function Audio:preview(packId)
	if self.Muted then return false,"Sound is muted." end
	for _,key in ipairs({"HardDrop","Rotate","Tetris","Move"}) do
		local id,pitch=self:resolve(key,packId)
		if id~="" and not self.Failed[id] then
			if self.Preview then self.Preview:Destroy() end
			local sample=Instance.new("Sound"); self.Preview=sample; sample.Name="PackPreview"; sample.SoundId=id
			sample.PlaybackSpeed=pitch; sample.Volume=self.Master*self.SFXVolume; sample.Parent=self.Folder
			local started=false; local loaded
			local function finish()
				if loaded then loaded:Disconnect(); loaded=nil end
				if sample.Parent then sample:Stop(); sample:Destroy() end
				if self.Preview==sample then self.Preview=nil end
			end
			local function start()
				if started or self.Preview~=sample or not sample.Parent then return end
				started=true; sample:Play(); task.delay(PreviewConfig.SoundSampleSeconds,finish)
			end
			loaded=sample.Loaded:Connect(start); if sample.IsLoaded then start() end
			task.delay(8,function() if not started then if self.Preview==sample then self.Failed[id]=true; warn("[Tetris Audio] Could not load pack sample: "..id) end; finish() end end)
			return true
		end
	end
	return false,"No audio sample is available yet."
end
function Audio:stopPreview() if self.Preview then self.Preview:Stop(); self.Preview:Destroy(); self.Preview=nil end end
function Audio:play(key,asset)
	if self.Muted then return end
	local id,pitch=self:resolve(key); if asset and asset~="" then id=Audio.normalize(asset) end; if id=="" or self.Failed[id] then return end
	local sound
	for _,s in ipairs(self.Pool) do if not s.IsPlaying then sound=s; break end end
	if not sound then
		if #self.Pool>=16 then return end
		sound=Instance.new("Sound"); sound.Parent=self.Folder; table.insert(self.Pool,sound)
	end
	sound.SoundId=id; sound.PlaybackSpeed=pitch; sound.Volume=self.Master*self.SFXVolume
	sound:Play()
	task.delay(8,function()
		if sound.Parent and sound.SoundId==id and not sound.IsLoaded then self.Failed[id]=true; sound:Stop(); warn("[Tetris Audio] Could not load permitted audio: "..id) end
	end)
end
function Audio:warning(lines,clock)
	local level=0; for i,threshold in ipairs(Effects.Garbage.Thresholds) do if lines>=threshold then level=i end end
	if level==0 or self.Muted or self.SFXVolume==0 then self.Warning:Stop(); self.WarningNext=0; return false end
	if (clock<self.WarningNext and level<=(self.WarningLevel or 0)) or clock<(self.WarningStarted or -1e9)+Config.GarbageWarning.MinimumInterval or self.Warning.IsPlaying then return false end
	local key=({"GarbageWarningLow","GarbageWarningMedium","GarbageWarningHigh","GarbageWarningCritical"})[level]
	local id,pitch=self:resolve(key); if id=="" or self.Failed[id] then return false end
	self.WarningGeneration+=1; local generation=self.WarningGeneration
	self.WarningLevel=level; self.WarningStarted=clock
	self.WarningLevelVolume=Config.GarbageWarning.Volumes[level]
	self.Warning.SoundId=id; self.Warning.Volume=self.Master*self.SFXVolume*self.WarningLevelVolume; self.Warning.PlaybackSpeed=pitch; self.Warning:Play()
	self.WarningNext=clock+Config.GarbageWarning.Cooldowns[level]
	task.delay(Config.GarbageWarning.MaxSampleSeconds,function() if self.WarningGeneration==generation and self.Warning.Parent then self.Warning:Stop() end end)
	return true
end
function Audio:music(key)
	local id=self:resolve(key)
	if self.Failed[id] then id="" end
	if self.Music.SoundId==id then return end
	self.Music:Stop(); self.Music.SoundId=id; self.Music.Volume=self.Muted and 0 or self.Master*self.MusicVolume
	if id~="" then
		self.Music:Play()
		task.delay(8,function()
			if self.Music.Parent and self.Music.SoundId==id and not self.Music.IsLoaded then self.Failed[id]=true; self.Music:Stop(); warn("[Tetris Audio] Could not load permitted music: "..id) end
		end)
	end
end
function Audio:settings(master,music,sfx,muted)
	self.Master=math.clamp(master,0,1); self.MusicVolume=math.clamp(music,0,1); self.SFXVolume=math.clamp(sfx,0,1); self.Muted=muted
	self.Music.Volume=muted and 0 or self.Master*self.MusicVolume
	for _,sound in ipairs(self.Pool) do sound.Volume=muted and 0 or self.Master*self.SFXVolume end
	if self.Preview then self.Preview.Volume=muted and 0 or self.Master*self.SFXVolume end
	self.Warning.Volume=muted and 0 or self.Master*self.SFXVolume*(self.WarningLevelVolume or 0); if muted then self.Warning:Stop() end
end
function Audio:destroy() self.Folder:Destroy() end
return Audio

end)()

modules.InputController=(function()
local CAS=game:GetService("ContextActionService")
local UIS=game:GetService("UserInputService")
local Rules=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Rules"))
local Input={}; Input.__index=Input
function Input.new(callback,pause)
	local self=setmetatable({Callback=callback,Enabled=false,Sources={},Touches={},Connections={},Actions={}},Input)
	local keyboard={Left={Enum.KeyCode.A,Enum.KeyCode.Left},Right={Enum.KeyCode.D,Enum.KeyCode.Right},SoftDrop={Enum.KeyCode.S,Enum.KeyCode.Down},CW={Enum.KeyCode.X,Enum.KeyCode.Up},CCW={Enum.KeyCode.Z},HardDrop={Enum.KeyCode.Space},Hold={Enum.KeyCode.C,Enum.KeyCode.LeftShift}}
	for action,keys in pairs(keyboard) do
		table.insert(keys,Enum.KeyCode[Rules.Gamepad[action]])
		local name="Tetris_"..action; table.insert(self.Actions,name)
		CAS:BindActionAtPriority(name,function(_,state,obj)
			if not self.Enabled or UIS:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
			if state==Enum.UserInputState.Begin then self:set(action,obj.KeyCode.Name,true)
			elseif state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then self:set(action,obj.KeyCode.Name,false) end
			return Enum.ContextActionResult.Sink
		end,false,3000,table.unpack(keys))
	end
	CAS:BindActionAtPriority("Tetris_Pause",function(_,state)
		if self.Enabled and state==Enum.UserInputState.Begin then self:release(); pause(); return Enum.ContextActionResult.Sink end
		return Enum.ContextActionResult.Pass
	end,false,3000,Enum.KeyCode.Escape,Enum.KeyCode[Rules.Gamepad.Pause])
	table.insert(self.Actions,"Tetris_Pause")
	table.insert(self.Connections,UIS.InputEnded:Connect(function(obj)
		if obj.UserInputType==Enum.UserInputType.MouseButton1 then
			-- Mouse release may provide a different InputObject from GuiObject.InputBegan.
			for captured,action in pairs(self.Touches) do if captured.UserInputType==Enum.UserInputType.MouseButton1 then self:set(action,captured,false); self.Touches[captured]=nil end end
		else local action=self.Touches[obj]; if action then self:set(action,obj,false); self.Touches[obj]=nil end end
	end))
	table.insert(self.Connections,UIS.WindowFocusReleased:Connect(function() self:release(); if self.Enabled then pause(true) end end))
	return self
end
function Input:preferences(settings)
	if self.SwapRotation~=settings.SwapRotation then self:release(); self.SwapRotation=settings.SwapRotation end
end
function Input:set(action,source,down)
	if self.SwapRotation then action=action=="CW" and "CCW" or action=="CCW" and "CW" or action end
	local set=self.Sources[action] or {}; self.Sources[action]=set
	local old=next(set)~=nil; if down then set[source]=true else set[source]=nil end
	local new=next(set)~=nil; if old~=new then self.Callback(action,new) end
end
function Input:button(button,action)
	table.insert(self.Connections,button.InputBegan:Connect(function(obj)
		if self.Enabled and (obj.UserInputType==Enum.UserInputType.Touch or obj.UserInputType==Enum.UserInputType.MouseButton1) then self.Touches[obj]=action; self:set(action,obj,true) end
	end))
end
function Input:release()
	for action,sources in pairs(self.Sources) do if next(sources) then self.Callback(action,false) end end
	self.Sources={}; self.Touches={}
end
function Input:enable(value) if not value then self:release() end; self.Enabled=value end
function Input:destroy()
	self:release(); for _,name in ipairs(self.Actions) do CAS:UnbindAction(name) end
	for _,connection in ipairs(self.Connections) do connection:Disconnect() end
end
return Input

end)()

modules.CosmeticRenderer=(function()
-- Bounded temporary layers, all cosmetic. No collision/scoring/attack changes.
local TweenService=game:GetService("TweenService")
local Config=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("DropEffectConfig"))
local Renderer={Active=0,Limit=Config.MaxActive}
function Renderer.drop(board,id,reduced,origin)
	local spec=Config.Styles[id] or Config.Styles.Default; local count=reduced and 1 or spec.Count
	for i=1,count do
		if Renderer.Active>=Renderer.Limit then break end; Renderer.Active+=1
		local p=Instance.new("Frame"); p.Name="CosmeticParticle"; p.BorderSizePixel=0; p.ZIndex=(board.ZIndex or 1)+8; p.AnchorPoint=Vector2.new(0.5,0.5)
		p.BackgroundColor3=Color3.fromRGB(table.unpack(spec.Color)); p.Size=UDim2.fromOffset(6,6)
		local x,y=origin and origin.X or 0.5,origin and origin.Y or 0.9; p.Position=UDim2.fromScale(x,y)
		local target=UDim2.fromScale(math.clamp(x+(i-(count+1)/2)*0.035,0.03,0.97),math.clamp(y-0.1-(i%3)*0.035,0.05,0.97))
		if spec.Style=="Wave" or spec.Style=="Pulse" or reduced then p.Size=UDim2.new(0.65,0,0,2); target=p.Position
		elseif spec.Style=="Bolt" then p.Size=UDim2.new(0,2,0.12,0); p.Position=UDim2.fromScale(x+(i%2)*0.05,y-i*0.08); target=p.Position
		elseif spec.Style=="Shard" then p.Size=UDim2.fromOffset(4,10); p.Rotation=45
		elseif spec.Style=="Flame" then p.Size=UDim2.fromOffset(6,12); target=UDim2.fromScale(x+(i-(count+1)/2)*0.025,math.max(0,y-0.2-(i%3)*0.07))
		elseif spec.Style=="Glitch" then p.Size=UDim2.new(0.25,0,0,2); target=UDim2.fromScale(x+(i%2==0 and 0.1 or -0.1),y-i*0.045)
		elseif spec.Style=="Orbit" then target=UDim2.fromScale(x+math.cos(i/count*math.pi*2)*0.18,y+math.sin(i/count*math.pi*2)*0.1)
		elseif spec.Style=="Prism" then p.Rotation=45; p.BackgroundColor3=Color3.fromHSV(i/count,0.6,1) end
		p.Parent=board; local done=false; local function release() if done then return end; done=true; p:Destroy(); Renderer.Active=math.max(0,Renderer.Active-1) end
		local tween=TweenService:Create(p,TweenInfo.new(reduced and 0.2 or Config.Duration),{Position=target,BackgroundTransparency=1}); tween.Completed:Once(release); tween:Play(); task.delay(1,release)
	end
end
return Renderer

end)()

modules.BrickRenderer=(function()
local Styles=require(script.Parent:WaitForChild("BrickStyles"))
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local E=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("TetrisEngine"))
local Renderer={Styles=Styles}
function Renderer.tile(parent,name,UI)
	local root=UI.new("Frame",name,parent,{BorderSizePixel=0,BackgroundColor3=Theme.Colors.empty,ZIndex=(parent.ZIndex or 1)+1})
	local face=UI.new("Frame","Face",root,{Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-2),BorderSizePixel=0,ZIndex=root.ZIndex+1})
	local edge=UI.stroke(face,Theme.Colors.line,0,1)
	local shine=UI.new("Frame","Highlight",face,{Size=UDim2.new(1,0,0,1),BorderSizePixel=0,BackgroundTransparency=0.35,ZIndex=face.ZIndex+1})
	local detail=UI.new("Frame","Detail",face,{Size=UDim2.fromScale(0.24,0.24),BorderSizePixel=0,Visible=false,ZIndex=face.ZIndex+1})
	local facets={}; for i=1,2 do facets[i]=UI.new("Frame","Facet"..i,face,{BorderSizePixel=0,Visible=false,ZIndex=face.ZIndex+1}) end
	return {Frame=root,Face=face,Edge=edge,Shine=shine,Detail=detail,Facets=facets}
end
function Renderer.paint(tile,kind,skin,ghostId,isGhost,reduced,clock,variation)
	local animate=isGhost or skin=="CyberCore" or skin=="Lava" or skin=="Glitch" or skin=="RoyalPrism"
	local phase=animate and not reduced and math.floor((clock or 0)*6) or 0
	local key=tostring(kind)..":"..(skin or "Default")..":"..(ghostId or "Default")..":"..tostring(isGhost)..":"..phase..":"..tostring(reduced)
	if tile.Key==key then return end; tile.Key=key
	tile.Frame:SetAttribute("SkinId",skin or "Default"); tile.Frame:SetAttribute("PieceKind",tostring(kind)); tile.Frame:SetAttribute("Ghost",isGhost or false)
	if kind==0 then tile.Face.Visible=false; tile.Frame.BackgroundColor3=Theme.Colors.empty; tile.Frame.BackgroundTransparency=0; return end
	local spec=Styles.describe(kind,skin,ghostId,isGhost,reduced,clock)
	tile.Frame:SetAttribute("Texture",spec.Texture)
	tile.Face.Visible=true; tile.Frame.BackgroundColor3=spec.Color:Lerp(Theme.Colors.board,0.55); tile.Frame.BackgroundTransparency=isGhost and 1 or 0
	tile.Face.Position=UDim2.fromOffset(spec.Inset,spec.Inset); tile.Face.Size=UDim2.new(1,-2*spec.Inset,1,-2*spec.Inset)
	tile.Face.BackgroundColor3=spec.Color; tile.Face.BackgroundTransparency=spec.Transparency; tile.Edge.Color=spec.Edge; tile.Edge.Transparency=isGhost and 0.38 or 0.12
	tile.Shine.Visible=not isGhost; tile.Shine.BackgroundColor3=spec.Color:Lerp(Theme.Colors.text,0.5)
	local mark=tile.Detail; mark.Visible=spec.Texture~="Bevel" and spec.Texture~="Default"
	mark.Rotation=0; mark.BackgroundTransparency=0.25; mark.BackgroundColor3=spec.Edge; mark.Position=UDim2.fromScale(0.15,0.2); mark.Size=UDim2.fromScale(0.25,0.25)
	if spec.Texture=="Circuit" then mark.Size=UDim2.new(0.6,0,0,2); mark.Position=UDim2.fromScale(0.2,0.72); mark.BackgroundColor3=Theme.Colors.cyan
	elseif spec.Texture=="Wave" then mark.Size=UDim2.new(0.8,0,0,2); mark.Position=UDim2.fromScale(0.1,0.5)
	elseif spec.Texture=="Star" then mark.Size=UDim2.fromOffset(2,2); mark.Position=UDim2.fromScale(0.2+(variation or 0)%3*0.2,0.25); mark.BackgroundColor3=Theme.Colors.text
	elseif spec.Texture=="Gold" then mark.Size=UDim2.new(0,1,0.6,0); mark.Position=UDim2.fromScale(0.8,0.2); mark.BackgroundColor3=Theme.Colors.yellow
	elseif spec.Texture=="Lava" then mark.Size=UDim2.new(0.7,0,0,2); mark.Position=UDim2.fromScale(0.1,0.65); mark.BackgroundColor3=Theme.Colors.orange
	elseif spec.Texture=="Crystal" then mark.Rotation=45; mark.BackgroundTransparency=0.4
	elseif spec.Texture=="Pixel" then mark.Size=UDim2.fromScale(0.32,0.32); mark.Position=UDim2.fromScale(0.5,0.5); mark.BackgroundTransparency=0.45
	elseif spec.Texture=="Scan" then mark.Size=UDim2.new(0.8,0,0,1); mark.Position=UDim2.fromScale(0.1,0.65); mark.BackgroundColor3=Theme.Colors.cyan end
	local a,b=tile.Facets[1],tile.Facets[2]
	for _,facet in ipairs(tile.Facets) do facet.Visible=kind~=0 and not isGhost; facet.BackgroundColor3=spec.Edge; facet.BackgroundTransparency=0.5; facet.Rotation=0 end
	a.Position=UDim2.fromScale(0.06,0.05); a.Size=UDim2.fromScale(0.08,0.86); b.Position=UDim2.fromScale(0.05,0.85); b.Size=UDim2.fromScale(0.88,0.09); b.BackgroundColor3=spec.Color:Lerp(Theme.Colors.background,0.5)
	if spec.Texture=="Crystal" or spec.Texture=="Prism" then
		a.Position=UDim2.fromScale(0.25,0.08); a.Size=UDim2.fromScale(0.15,0.65); a.Rotation=-35; b.Position=UDim2.fromScale(0.62,0.25); b.Size=UDim2.fromScale(0.12,0.65); b.Rotation=35
		if spec.Texture=="Prism" then a.BackgroundColor3=Color3.fromHSV((phase%24)/24,0.55,1); b.BackgroundColor3=Color3.fromHSV(((variation or 0)%7)/7,0.55,1) end
	elseif spec.Texture=="Circuit" then a.Size=UDim2.new(0,2,0.7,0); a.Position=UDim2.fromScale(0.6,0.15); b.Size=UDim2.fromScale(0.16,0.16); b.Position=UDim2.fromScale(0.48,0.38); a.BackgroundColor3=Theme.Colors.cyan; b.BackgroundColor3=Theme.Colors.cyan; b.BackgroundTransparency=reduced and 0.2 or phase%2*0.35
	elseif spec.Texture=="Star" then a.Size=UDim2.fromOffset(2,2); b.Size=UDim2.fromOffset(1,1); a.Position=UDim2.fromScale(0.65,0.64); b.Position=UDim2.fromScale(0.8,0.2); a.BackgroundColor3=Theme.Colors.text; b.BackgroundColor3=Theme.Colors.text
	elseif spec.Texture=="Gold" then a.Size=UDim2.fromScale(0.13,0.8); a.Rotation=25; b.Size=UDim2.new(0.8,0,0,2); b.Position=UDim2.fromScale(0.1,0.15); b.BackgroundColor3=Theme.Colors.yellow
	elseif spec.Texture=="Lava" then a.Position=UDim2.fromScale(0.2,0.3); a.Size=UDim2.fromScale(0.15,0.6); a.Rotation=35; b.Position=UDim2.fromScale(0.5,0.4); b.Size=UDim2.fromScale(0.12,0.55); b.Rotation=-30; a.BackgroundColor3=Theme.Colors.orange; b.BackgroundColor3=Theme.Colors.yellow; mark.BackgroundTransparency=reduced and 0.2 or 0.2+phase%3*0.1
	elseif spec.Texture=="Wave" or spec.Texture=="Scan" then a.Size=UDim2.new(0.85,0,0,1); b.Size=a.Size; a.Position=UDim2.fromScale(0.08,0.28); b.Position=UDim2.fromScale(0.08,0.75)
	elseif spec.Texture=="Glitch" then a.Size=UDim2.new(0.5,0,0,2); a.Position=UDim2.fromScale(0.1+(phase%2)*0.15,0.35); b.Size=UDim2.new(0.5,0,0,2); b.Position=UDim2.fromScale(0.3,0.7); a.BackgroundColor3=Theme.Colors.pink; b.BackgroundColor3=Theme.Colors.cyan
	elseif spec.Texture=="Neon" then a.Size=UDim2.new(0.85,0,0,1); a.Position=UDim2.fromScale(0.08,0.13); b.Size=UDim2.new(0,1,0.75,0); b.Position=UDim2.fromScale(0.86,0.13); a.BackgroundTransparency=0.1; b.BackgroundTransparency=0.1
	elseif spec.Texture=="Metal" then a.Position=UDim2.fromScale(0.15,0.2); a.Size=UDim2.fromOffset(2,2); b.Position=UDim2.fromScale(0.7,0.65); b.Size=UDim2.fromOffset(2,2) end
	if isGhost then
		mark.Visible=ghostId~="Default"; mark.BackgroundTransparency=0.6; mark.BackgroundColor3=spec.Edge
		if ghostId=="PixelDotted" then mark.Position=UDim2.fromScale(0.03,0.03); mark.Size=UDim2.fromScale(0.16,0.16)
		elseif ghostId=="CyberScanline" or ghostId=="Hologram" then mark.Size=UDim2.new(0.9,0,0,1); mark.Position=UDim2.fromScale(0.05,0.35)
		elseif ghostId=="Glitch" then mark.Size=UDim2.new(0.3,0,0,1); mark.Position=UDim2.fromScale(phase%2*0.4+0.1,0.1)
		elseif ghostId=="CrystalOutline" or ghostId=="RoyalPrism" then mark.Rotation=45; mark.Size=UDim2.fromScale(0.15,0.4) end
	end
end
function Renderer.board(parent,name,columns,rows,UI)
	local frame=UI.new("Frame",name,parent,{BackgroundColor3=Theme.Colors.board,BorderSizePixel=0,ClipsDescendants=true,ZIndex=(parent.ZIndex or 1)+1}); UI.stroke(frame,Theme.Colors.line)
	local view={Frame=frame,Tiles={},Columns=columns,Rows=rows,UI=UI}
	for y=1,rows do view.Tiles[y]={}; for x=1,columns do local tile=Renderer.tile(frame,"Brick_"..x.."_"..y,UI)
		tile.Frame.Position=UDim2.fromScale((x-1)/columns,(y-1)/rows); tile.Frame.Size=UDim2.new(1/columns,-1,1/rows,-1); view.Tiles[y][x]=tile
	end end; return view
end
function Renderer.draw(view,state,loadout,reduced,clock)
	loadout=loadout or {}; local cells={}
	for y=1,view.Rows do cells[y]={}; for x=1,view.Columns do cells[y][x]={kind=state and state.board[y] and state.board[y][x] or 0,ghost=false} end end
	if state and state.alive then for _,field in ipairs({"ghost","piece"}) do if state[field] then for _,point in ipairs(E.cells(state[field])) do
		if cells[point[2]] and cells[point[2]][point[1]] then cells[point[2]][point[1]]={kind=state[field].kind,ghost=field=="ghost"} end
	end end end end
	local previous=view.State
 for y,row in ipairs(view.Tiles) do for x,tile in ipairs(row) do local cell=cells[y][x]; Renderer.paint(tile,cell.kind,loadout.BrickSkin,loadout.GhostEffect,cell.ghost,reduced,clock,y*view.Columns+x); if cell.kind=="G" and previous and previous.board[y] and previous.board[y][x]~="G" and not reduced then local target=tile.Face.BackgroundColor3; tile.Face.BackgroundColor3=target:Lerp(Theme.Colors.cyan,0.55); view.UI.tween(tile.Face,{BackgroundColor3=target},0.28) end end end; view.State=state
end
function Renderer.piece(view,kind,loadout,reduced)
	Renderer.draw(view,{board={},alive=type(kind)=="string",piece=type(kind)=="string" and {kind=kind,x=1,y=1,rotation=0} or nil},loadout,reduced,0)
end
return Renderer

end)()

modules.BrickPreviewRenderer=(function()
-- An isolated deterministic engine; never calls remotes or progression functions.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local E=require(Shared:WaitForChild("TetrisEngine")); local Rules=require(Shared:WaitForChild("Config"):WaitForChild("Rules"))
local Config=require(Shared:WaitForChild("Config"):WaitForChild("ShopPreviewConfig"))
local Bricks=require(script.Parent:WaitForChild("BrickRenderer")); local Effects=require(script.Parent:WaitForChild("CosmeticRenderer"))
local Preview={}; Preview.__index=Preview
function Preview.new(parent,UI)
	local self=setmetatable({UI=UI,Elapsed=0,LastStep=-1,Round=0},Preview)
	self.View=Bricks.board(parent,"CosmeticSampleBoard",10,20,UI); self.Frame=self.View.Frame; self.Frame:SetAttribute("CosmeticSample",true)
	self.ClearLabel=UI.text("DemoClear",self.Frame,"",14,UI.colors.green,UI.theme.Fonts.Display); self.ClearLabel.Size=UDim2.new(1,0,0,40); self.ClearLabel.Position=UDim2.fromScale(0,0.4); self.ClearLabel.TextXAlignment=Enum.TextXAlignment.Center; self.ClearLabel.ZIndex=self.Frame.ZIndex+10; self.ClearLabel.Visible=false
	return self
end
function Preview.thumbnail(parent,UI,item,loadout)
	local view=Bricks.board(parent,"TetrominoPreview",4,2,UI)
	Bricks.piece(view,"T",{BrickSkin=item.Category=="BrickSkins" and item.Id or loadout and loadout.BrickSkin or "Default",GhostEffect="Default"},UI.reducedMotion); return view
end
function Preview:begin()
	self.Round+=1; self.Cycle=0; self.Landed=false; self.Moved=false; self.Frozen=false; self.ClearLabel.Visible=false
	local rules=table.clone(Rules); rules.Gravity=Config.FallInterval; self.Engine=E.new(Config.Seed+self.Round,rules)
	if self.Round%Config.ClearEvery==0 then
		for y=21,24 do for x=1,10 do self.Engine.board[y][x]=x==5 and 0 or ({"J","L","S","Z","O","T","I"})[(x+y)%7+1] end end
		E.spawn(self.Engine,"I"); self.Engine.piece.rotation=1; self.Engine.piece.x=3
	else
		for x=1,10 do if x<3 or x>8 then self.Engine.board[24][x]="J" end end
		E.spawn(self.Engine,({"T","L","S","O"})[(self.Round-1)%4+1])
	end
	self.Engine.piece.y=Rules.Hidden+1
end
function Preview:set(item,equipped)
	self.Item=item; self.Elapsed=0; self.Round=0; self.LastStep=-1
	self.Loadout={BrickSkin=equipped and equipped.BrickSkin or "Default",GhostEffect=equipped and equipped.GhostEffect or "Default",DropEffect=equipped and equipped.DropEffect or "Default"}
	if item.Category=="BrickSkins" then self.Loadout.BrickSkin=item.Id elseif item.Category=="GhostEffects" then self.Loadout.GhostEffect=item.Id elseif item.Category=="DropEffects" then self.Loadout.DropEffect=item.Id end
	self:begin(); self:tick(0,true)
end
function Preview:tick(dt,force)
	if not self.Item or not self.Frame.Visible then return end
	if self.Paused and not force then return end
	dt=dt*(self.Speed or 1)
	if self.UI.reducedMotion then if not self.Frozen or force then Bricks.draw(self.View,E.snapshot(self.Engine),self.Loadout,true,0); self.Frozen=true end; return end
	self.Frozen=false
	self.Elapsed+=math.min(dt,0.1); self.Cycle+=math.min(dt,0.1)
	if not self.Landed then
		if self.Cycle>0.55 and not self.Moved and self.Round%Config.ClearEvery~=0 then self.Moved=true; E.move(self.Engine,self.Round%2==0 and -1 or 1,0); E.rotate(self.Engine,1) end
		if self.Cycle>=Config.HardDropAfter then E.hardDrop(self.Engine); self.Landed=true; Effects.drop(self.Frame,self.Loadout.DropEffect,false,{X=0.5,Y=0.9}); if self.Engine.lines>0 then self.ClearLabel.Text=self.Engine.stats.PerfectClears>0 and "PERFECT CLEAR!" or self.Engine.lines==4 and "TETRIS!" or "LINE CLEAR!"; self.ClearLabel.Visible=true end else E.step(self.Engine,math.min(dt,0.1)) end
	end
	local step=math.floor(self.Elapsed*Config.FPS); if force or step~=self.LastStep then self.LastStep=step; Bricks.draw(self.View,E.snapshot(self.Engine),self.Loadout,false,self.Elapsed) end
	if self.Cycle>=Config.NextAfter then self:begin() end
end
function Preview:control(action)
 if action=="Pause" then self.Paused=not self.Paused
 elseif action=="Replay" then
  self.Round=math.max(0,self.Round-1); self:begin()
  if self.Item.Category=="DropEffects" then E.hardDrop(self.Engine); self.Landed=true; Effects.drop(self.Frame,self.Loadout.DropEffect,self.UI.reducedMotion,{X=0.5,Y=0.9}) end
 elseif action=="Rotate" and not self.Landed then E.rotate(self.Engine,1)
 elseif action=="Next" then self:begin()
 elseif action=="Speed" then self.Speed=(self.Speed or 1)==1 and 0.5 or 1 end
 self:tick(0,true)
end
function Preview:destroy() self.Item=nil; self.Frame:Destroy() end
return Preview

end)()

modules.GameClient=(function()
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Shared=RS:WaitForChild("Shared")
local Engine=require(Shared:WaitForChild("TetrisEngine"))
local Catalog=require(Shared:WaitForChild("Catalog"))
local Audio=require(script.Parent:WaitForChild("AudioController"))
local Input=require(script.Parent:WaitForChild("InputController"))
local Client={}; Client.__index=Client
function Client.new(hooks)
	local self=setmetatable({Hooks=hooks,Mode="Lobby",Profile=nil,LastEvent=0,State=nil,Blocked=false,Audio=Audio.new()},Client)
	self.Network=Shared:WaitForChild("Network")
	self.Input=Input.new(function(action,down)
		self:send("Input",{Action=action,Down=down})
	end,function(force) if self.Mode=="Solo" or self.Mode=="Ranked" or self.Mode=="Challenge" then hooks.Pause(force) end end)
	self.Connection=self.Network.OnClientEvent:Connect(function(kind,data)
		if kind=="Profile" then
			local previous=self.Profile; self.Profile=data
   local pending=self.PendingCosmetic; if pending and data then local slot=Catalog.Slots[pending.Category]; if pending.Kind=="Buy" and data.Inventory[pending.Category][pending.Id] or pending.Kind=="Equip" and data.Equipped[slot]==pending.Id then self.PendingCosmetic=nil end end
			if data then
				self.Audio.Pack=data.Equipped.SoundPack
				if previous then
					if previous.Season.Id~=data.Season.Id and #data.Season.History>#previous.Season.History then self.Audio:play("SeasonReward") end
					if data.Energy.Current>previous.Energy.Current then self.Audio:play("EnergyRestored") end
					for group,quests in pairs(data.Quests) do
						local old=previous.Quests[group]
						if old and old.Window==quests.Window then
							local P=require(Shared:WaitForChild("Progression"))
							for _,q in ipairs(P[group]) do if (quests.Progress[q.Id] or 0)>=q.Target and (old.Progress[q.Id] or 0)<q.Target then self.Audio:play("QuestComplete"); hooks.Message("Quest complete: "..q.Label) end end
						end
					end
				end
				hooks.Profile(data)
			end
		elseif kind=="Lobby" then self.Mode="Lobby"; self.State=nil; self.LastEvent=0; self.Input:enable(false); self.Audio:music("MenuMusic"); hooks.Lobby()
		elseif kind=="Searching" then self.Mode="Searching"; self.Input:enable(false); self.Audio:play("Matchmaking"); hooks.Searching(data)
		elseif kind=="Found" then self.Mode=data.Ranked and "Ranked" or "Challenge"; self.MatchId=data.MatchId; self.LastEvent=0; self.LastBattleEvent=0; self.Audio:play("OpponentFound"); hooks.Found(data)
		elseif kind=="State" then
			Engine.unpack(data.Own); Engine.unpack(data.Opponent)
			local changed=self.Mode~=data.Mode; self.Mode=data.Mode; self.State=data
			if data.MatchId and self.MatchId~=data.MatchId then self.LastEvent=0; self.LastBattleEvent=0; self.MatchId=data.MatchId end
			if changed then self.LastEvent=0 end
			self.Input:enable(data.Own.alive and not data.Own.paused and data.Countdown==0 and not self.Blocked)
			self.Audio:music(data.Mode=="Solo" and "SoloMusic" or "BattleMusic")
			for _,event in ipairs(data.Own.events) do if event.id>self.LastEvent then self.LastEvent=event.id; if event.name~="KO" or data.Mode=="Solo" then self.Audio:play(event.name); if hooks.Event then hooks.Event(event) end end end end
			hooks.State(data)
		elseif kind=="BattleEvent" then
			if data.MatchId==self.MatchId and data.Id>(self.LastBattleEvent or 0) then self.LastBattleEvent=data.Id; if hooks.BattleEvent then hooks.BattleEvent(data) end end
		elseif kind=="Result" then
			if data.Id and self.MatchId and data.Id~=self.MatchId then return end
			if self.LastResultId==data.Id and data.Id then return end; self.LastResultId=data.Id; self.ResultElapsed=0; self.ResultPhases={}
			Engine.unpack(data.Own); Engine.unpack(data.Opponent)
			self.Mode="Result"; self.Input:enable(false); self.Audio:music("MenuMusic"); self.Audio:warning(0,0)
			hooks.Result(data)
		elseif kind=="Leaderboard" then hooks.Leaderboard(data)
		elseif kind=="Challenge" then hooks.Challenge(data)
		elseif kind=="CosmeticResult" then
			self.PendingCosmetic=nil; self.LastCosmeticResult=data -- Profile remains the authority for equipped state.
			if hooks.CosmeticResult then hooks.CosmeticResult(data) end
		elseif kind=="Action" then self.Audio:play(data.Sound)
		elseif kind=="Message" then hooks.Message(data) end
	end)
	self.Alive=true
	task.spawn(function() while self.Alive do task.wait(15); if self.Alive then self:send("Refresh") end end end)
	self:send("Hello")
	return self
end
function Client:send(kind,payload)
	if kind=="Solo" or kind=="Restart" then self.LastEvent=0 end
	self.Network:FireServer(kind,payload)
end
function Client:block(value)
	self.Blocked=value
	local playing=self.Mode=="Solo" or self.Mode=="Ranked" or self.Mode=="Challenge"
	self.Input:enable(playing and not value and self.State and self.State.Own.alive and not self.State.Own.paused and self.State.Countdown==0 or false)
end
function Client:destroy() self.Alive=false; self.Connection:Disconnect(); self.Input:destroy(); self.Audio:destroy() end
function Client:colors(kind,ghost)
	local data=self.Profile
	local item=data and Catalog.Items[(ghost and "GhostEffects:" or "BrickSkins:")..data.Equipped[ghost and "GhostEffect" or "BrickSkin"]]
	return item and item.Visual
end
Client.Engine=Engine
return Client

end)()

modules.ArcadeFeedback=(function()
-- One presentation controller, driven exclusively by replicated state/events.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared:WaitForChild("Config"):WaitForChild("BattleEffectsConfig"))
local SoundConfig=require(Shared:WaitForChild("Config"):WaitForChild("SoundConfig"))
local Assets=require(script.Parent:WaitForChild("UIAssets"))
local Feedback={}; Feedback.__index=Feedback
local labels={Single="SINGLE",Double="DOUBLE",Triple="TRIPLE",Tetris="TETRIS!",TSpin="T-SPIN!",TSpinMini="T-SPIN MINI!",TSpinSingle="T-SPIN SINGLE!",TSpinDouble="T-SPIN DOUBLE!",TSpinTriple="T-SPIN TRIPLE!",BackToBack="BACK-TO-BACK!",PerfectClear="PERFECT CLEAR!",KO="K.O.!"}
function Feedback.new(parent,UI,audio,own,opponent)
	local self=setmetatable({UI=UI,Audio=audio,Own=own,Opponent=opponent,Queues={{},{}},Current={},Particles={},Clock=0,Seen={},CountdownValue=false},Feedback)
	self.Layer=UI.new("Frame","ArcadeFeedback",parent,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=12})
	self.Labels={}; self.Emotes={}
	for i=1,2 do
		local label=UI.text("ArcadeAnnouncement"..i,self.Layer,"",24,UI.colors.yellow,UI.theme.Fonts.Display); label.ZIndex=14; label.TextXAlignment=Enum.TextXAlignment.Center; label.TextStrokeColor3=UI.colors.background; label.TextStrokeTransparency=0; label.Visible=false
		local sticker=UI.image(label,"AnnouncementArtwork",""); sticker.Size=UDim2.fromScale(1,1); self.Labels[i]=label; self.Emotes[i]=UI.text("BattleEmote"..i,self.Layer,"",15,UI.colors.text,UI.theme.Fonts.Strong); self.Emotes[i].ZIndex=16; self.Emotes[i].Visible=false
	end
	self.Countdown=UI.text("ArcadeCountdown",self.Layer,"",48,UI.colors.yellow,UI.theme.Fonts.Display); self.Countdown.ZIndex=18; self.Countdown.TextXAlignment=Enum.TextXAlignment.Center; self.Countdown.TextStrokeColor3=UI.colors.background; self.Countdown.TextStrokeTransparency=0; self.Countdown.Visible=false
	self.CountdownAsset=UI.image(self.Countdown,"CountdownArtwork",""); self.CountdownAsset.Size=UDim2.fromScale(1,1)
 self.Arrow=UI.image(self.Layer,"AttackArrow",Assets.uri("Images.battle.attack_arrow")); self.Arrow.Visible=false
 for i=1,Config.Attack.MaxActive do local p=UI.new("Frame","AttackBlock"..i,self.Layer,{Size=UDim2.fromOffset(8,8),BorderSizePixel=0,BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),Visible=false,ZIndex=13}); local edge=UI.stroke(p,UI.colors.cyan,0.05,2); local glow=UI.new("Frame","Glow",p,{Position=UDim2.fromOffset(-3,-3),Size=UDim2.new(1,6,1,6),BackgroundTransparency=1,ZIndex=12}); UI.stroke(glow,UI.colors.cyan,0.75,3); local texture=UI.image(p,"BlockTexture",Assets.uri("Images.battle.garbage_projectile")); texture.Size=UDim2.fromScale(1,1); if texture.Visible then edge.Transparency=0.6 end; self.Particles[i]={Frame=p,Edge=edge,Glow=glow} end
	self.Rays={}; for i=1,8 do local ray=UI.new("Frame","ClearRay"..i,self.Layer,{BackgroundColor3=UI.colors.green,BackgroundTransparency=0.8,BorderSizePixel=0,Rotation=i*45,Visible=false,ZIndex=12}); self.Rays[i]=ray end
	self.Impacts={}; for i=1,2 do local frame=UI.new("Frame","AttackImpact"..i,self.Layer,{BackgroundTransparency=1,Visible=false,ZIndex=13}); local edge=UI.stroke(frame,UI.colors.orange,0,2); self.Impacts[i]={Frame=frame,Edge=edge} end
	return self
end
function Feedback:layout(layout) self.Layout=layout end
function Feedback:reset(id)
	self.MatchId=id; self.Seen={}; self.OpponentSequence=0; self.ArrowUntil=0; self.Arrow.Visible=false; self.Queues={{},{}}; self.Current={}; self.StartAt=nil; self.CountdownValue=false; self.GoUntil=nil
	for _,p in ipairs(self.Particles) do p.Frame.Visible=false; p.Age=nil end
	for _,label in ipairs(self.Labels) do label.Visible=false end; for _,e in ipairs(self.Emotes) do e.Visible=false end; self.Countdown.Visible=false
	for _,impact in ipairs(self.Impacts) do impact.Age=nil; impact.Frame.Visible=false end; for _,ray in ipairs(self.Rays) do ray.Visible=false end
	self.Audio:warning(0,self.Clock)
end
function Feedback:announce(side,text,priority,color)
	local q=self.Queues[side]; table.insert(q,{Text=text,Priority=priority or 30,Color=color or self.UI.colors.yellow})
	table.sort(q,function(a,b) return a.Priority>b.Priority end); while #q>Config.Announcements.QueueLimit do table.remove(q) end
end
function Feedback:event(event,side)
 side=side or 1
	local name=event.name; local color=name=="PerfectClear" and self.UI.colors.green or name=="KO" and self.UI.colors.pink or (name=="Tetris" or name:find("TSpin")) and self.UI.colors.cyan or self.UI.colors.orange
	if name=="Tetris" then color=self.UI.colors.cyan end
	if labels[name] then self:announce(side,labels[name],name=="PerfectClear" and 90 or name=="KO" and 100 or 50,color)
	elseif name=="Combo" then self:announce(side,"COMBO "..event.data.combo,55,self.UI.colors.orange) end
end
function Feedback:battle(event,localId)
	if event.MatchId~=self.MatchId or self.Seen[event.Id] then return end; self.Seen[event.Id]=true
	-- IDs are monotonic and match-local; keep dedup state bounded.
	if event.Id>64 then self.Seen[event.Id-64]=nil end
	if event.Kind=="Attack" and type(event.Lines)=="number" and event.Lines>0 then
		local side=event.From==localId and 1 or 2; local strength=event.Lines>=Config.Attack.Powerful and 3 or event.Lines>=Config.Attack.Medium and 2 or 1
		self.ArrowUntil=self.Clock+Config.Attack.Duration+0.35; self.ArrowSide=side
  self:announce(side,"+"..event.Lines..(event.Lines==1 and " LINE" or " LINES"),60,self.UI.colors[side==1 and "pink" or "cyan"])
		if self.UI.reducedMotion then self.Impacts[side==1 and 2 or 1].Age=0 end
		if not self.UI.reducedMotion then
			local count=math.min(Config.Attack.MaxProjectiles,math.max(2,event.Lines+1)); local added=0
			for _,p in ipairs(self.Particles) do if not p.Age then
				p.Side=side; p.Frame:SetAttribute("ServerEventId",event.Id); p.Age=-added*0.055; p.Strength=strength; local r=self.Layout and self.Layout.game.board; local size=math.clamp((r and r[3] or 240)/18,7,16)*(0.9+strength*0.06); p.Frame.Size=UDim2.fromOffset(size,size); p.Edge.Color=self.UI.colors[side==1 and "pink" or "cyan"]; p.Glow.Outline.Color=p.Edge.Color; p.Frame.BackgroundColor3=p.Edge.Color; added+=1
				if added>=count then break end
			end end
		end
	elseif event.Kind=="KO" then self:announce(event.Player==localId and 1 or 2,"K.O.!",100,self.UI.colors.pink); self.Audio:play("KO")
	elseif event.Kind=="Emote" then local side=event.From==localId and 1 or 2; self.Emotes[side].Text=event.Text; self.Emotes[side].Visible=true; self.Emotes[side]:SetAttribute("Until",self.Clock+2.5) end
end
function Feedback:state(data)
	if data.MatchId and data.MatchId~=self.MatchId then self:reset(data.MatchId) end
	self.State=data; self.StartAt=data.StartAt
 if data.Opponent then for _,event in ipairs(data.Opponent.events or {}) do if event.id>(self.OpponentSequence or 0) then self.OpponentSequence=event.id; if event.name~="KO" then self:event(event,2) end end end end
end
function Feedback:tick(dt,serverNow)
	self.Clock+=dt; local U=self.UI; if not self.Layout then return end
	local rects={self.Layout.game.board,self.Layout.game.opponent}
	for side,label in ipairs(self.Labels) do
		local r=rects[side]; local event=self.Current[side]
		if not event and #self.Queues[side]>0 then event=table.remove(self.Queues[side],1); event.Age=0; self.Current[side]=event end
		if event then
			event.Age+=dt; label.Visible=true; label.Text=event.Text; label.TextColor3=event.Color
			local pop=U.reducedMotion and 1 or 1+math.sin(math.min(1,event.Age/0.2)*math.pi)*0.12*Config.Announcements.Intensity
			local sticker=label.AnnouncementArtwork; local uri=event.Text=="K.O.!" and Assets.uri("Images.battle.ko") or event.Text:find("^COMBO ") and Assets.uri("Images.battle.combo") or event.Text=="PERFECT CLEAR!" and Assets.uri("Images.artwork.perfect_clear") or ""
   sticker.Image=uri; sticker.Visible=uri~=""; if sticker.Visible then label.Text=event.Text:find("^COMBO ") and event.Text:match("%d+") or "" end
   if event.Text:find("^COMBO ") then sticker.Size=UDim2.fromScale(0.72,1); label.TextXAlignment=Enum.TextXAlignment.Right else sticker.Size=UDim2.fromScale(1,1); label.TextXAlignment=Enum.TextXAlignment.Center end
   label.TextSize=math.clamp((r[3]+16)/math.max(5,#event.Text),14,event.Text=="K.O.!" and 52 or 36)*pop; U.rect(label,{r[1]-8,r[2]+r[4]*0.38,r[3]+16,64})
			label.TextTransparency=U.reducedMotion and 0 or math.clamp((event.Age-0.55)/0.3,0,1); label.TextStrokeTransparency=label.TextTransparency
			if event.Age>=Config.Announcements.Duration then self.Current[side]=nil; label.Visible=false end
		else label.Visible=false end
		local emote=self.Emotes[side]; U.rect(emote,{r[1],r[2]+r[4]+2,r[3],28}); if emote.Visible and self.Clock>(emote:GetAttribute("Until") or 0) then emote.Visible=false end
		local board=side==1 and self.Own or self.Opponent; local shake=event and event.Text=="K.O.!" and not U.reducedMotion and event.Age<0.25 and math.sin(event.Age*60)*Config.Announcements.ShakePixels or 0
		U.rect(board.Frame,{r[1]+shake,r[2],r[3],r[4]})
	end
	local perfectSide=self.Current[1] and self.Current[1].Text=="PERFECT CLEAR!" and 1 or self.Current[2] and self.Current[2].Text=="PERFECT CLEAR!" and 2; local perfect=perfectSide~=nil; local r=rects[perfectSide or 1]
	for i,ray in ipairs(self.Rays) do ray.Visible=perfect and not U.reducedMotion or false; U.rect(ray,{r[1]-r[3]*0.1,r[2]+r[4]*0.48,r[3]*1.2,math.max(4,r[3]*0.08)}) end
	for _,p in ipairs(self.Particles) do if p.Age then
		p.Age+=dt; local t=math.clamp(p.Age/Config.Attack.Duration,0,1); p.Frame.Visible=p.Age>=0 and not U.reducedMotion
		local a,b=rects[p.Side],rects[p.Side==1 and 2 or 1]; local ax,ay=a[1]+a[3]*0.5,a[2]+a[4]*0.4; local bx,by=b[1]+b[3]*0.5,b[2]+b[4]*0.65
		p.Frame.Position=UDim2.fromOffset(ax+(bx-ax)*t,ay+(by-ay)*t-math.sin(t*math.pi)*math.min(Config.Attack.Arc,math.abs(bx-ax)*0.3)*(0.8+p.Strength*0.15))
		if t>=1 or U.reducedMotion then if t>=1 then self.Impacts[p.Side==1 and 2 or 1].Age=0 end; p.Age=nil; p.Frame.Visible=false end
	end end
	for i,impact in ipairs(self.Impacts) do if impact.Age then impact.Age+=dt; U.rect(impact.Frame,rects[i]); impact.Frame.Visible=impact.Age<0.25; impact.Edge.Transparency=math.clamp(impact.Age/0.25,0,1); if self.Meters and self.Meters[i] then local edge=self.Meters[i]:FindFirstChild("ArrivalOutline"); if not edge then edge=U.stroke(self.Meters[i],U.colors.text,0,2); edge.Name="ArrivalOutline" end; edge.Transparency=math.clamp(impact.Age/0.25,0,1) end; if impact.Age>=0.25 then impact.Age=nil end end end
	local arrowR=rects[1]; self.Arrow.Visible=self.Clock<(self.ArrowUntil or 0) and self.Arrow.Image~=""; self.Arrow.Rotation=self.ArrowSide==2 and 180 or 0; U.rect(self.Arrow,{(rects[1][1]+rects[1][3]+rects[2][1])/2-24,arrowR[2]+arrowR[4]*0.38,48,48})
 if self.StartAt then
		local n=math.max(0,math.ceil(self.StartAt-serverNow))
		if n~=self.CountdownValue then
			local first=self.CountdownValue==false; self.CountdownValue=n
			if n>0 then self.Audio:play("Countdown",SoundConfig.CountdownVariants[n]) elseif serverNow-self.StartAt<Config.Countdown.GoDuration then self.GoUntil=self.Clock+Config.Countdown.GoDuration; self.Audio:play("MatchStart") elseif not first then self.GoUntil=nil end
		end
		self.Countdown.Visible=n>0 or self.GoUntil and self.Clock<self.GoUntil or false; self.Countdown.Text=n>0 and tostring(n) or "GO!"
		local countdownKey=n>0 and "countdown_"..n or "go"; self.CountdownAsset.Image=Assets.uri("Images.battle."..countdownKey); self.CountdownAsset.Visible=self.CountdownAsset.Image~=""; if self.CountdownAsset.Visible then self.Countdown.Text="" end
  self.Countdown.TextSize=math.clamp(r[3]*0.2,28,58); U.rect(self.Countdown,{r[1]-8,r[2]+r[4]*0.3,r[3]+16,100})
	end
	if self.State then self.Audio:warning(self.State.Mode~="Solo" and self.State.Own.alive and self.State.Own.pending or 0,self.Clock) end
end
function Feedback:meters(own,other) self.Meters={own,other} end
function Feedback:destroy() self.Audio:warning(0,self.Clock); self.Layer:Destroy() end
return Feedback

end)()

modules.ArcadeResults=(function()
-- Timeline reads one confirmed Result. It cannot grant rewards or mutate profiles.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local P=require(Shared:WaitForChild("Progression")); local Config=Shared:WaitForChild("Config")
local Effects=require(Config:WaitForChild("BattleEffectsConfig")); local RankIcons=require(Config:WaitForChild("RankIconConfig")); local Currency=require(Config:WaitForChild("CurrencyIconConfig"))
local Assets=require(script.Parent:WaitForChild("UIAssets"))
local Results={}; Results.__index=Results
local function ordinal(rank) local n=rank.Stars; for i=1,rank.Tier-1 do n+=P.Stars[i] end; return n end
function Results.new(parent,U,client,result,width)
	local self=setmetatable({UI=U,Client=client,Data=result,Elapsed=client.ResultElapsed or 0},Results)
	self.Frame=U.panel("ArcadeResults",parent); self.Frame.Size=UDim2.new(1,-8,0,530); self.Frame.ZIndex=32
	local C=U.colors; local text=result.Outcome=="Win" and "YOU WIN!" or result.Outcome=="Lose" and "YOU LOSE!" or "DRAW!"
	self.BaseTitleSize=math.min(32,width/12); self.Title=U.text("Outcome",self.Frame,text,self.BaseTitleSize,result.Outcome=="Win" and C.yellow or result.Outcome=="Lose" and C.pink or C.cyan,U.theme.Fonts.Display); U.rect(self.Title,{16,16,width-40,64}); self.Title.ZIndex=33; self.Title.TextStrokeColor3=C.background; self.Title.TextStrokeTransparency=0
	self.KO=U.text("FinalKO",self.Frame,"FINAL K.O.  "..result.Own.stats.KOs.." : "..result.Opponent.stats.KOs,22,C.text,U.theme.Fonts.Mono); U.rect(self.KO,{16,94,width-40,36}); self.KO.ZIndex=33
	local stats=result.Own.stats
	local detail=U.text("FinalStats",self.Frame,string.format("SENT %d   CLEARED %d   BEST COMBO %d",stats.Sent,result.Own.lines,stats.BestCombo or 0),14,C.muted,U.theme.Fonts.Mono); U.rect(detail,{16,134,width-40,40}); detail.ZIndex=33
	self.Coin=U.text("CashIcon",self.Frame,Currency.CashFallback,26,C.yellow,U.theme.Fonts.Display); U.rect(self.Coin,{16,184,32,42}); self.Coin.ZIndex=33
	local cashAsset=Assets.currency("Cash"); if cashAsset~="" then self.Coin.Text=""; local image=U.image(self.Coin,"CashAsset",cashAsset); image.Size=UDim2.fromScale(1,1) end
	self.Cash=U.text("ConfirmedCash",self.Frame,"+"..result.Cash.." CASH",24,C.yellow,U.theme.Fonts.Mono); U.rect(self.Cash,{60,184,width-100,42}); self.Cash.ZIndex=33
	self.RankLabel=U.text("RankLabel",self.Frame,"",20,C.text,U.theme.Fonts.Display); U.rect(self.RankLabel,{60,250,width-100,44}); self.RankLabel.ZIndex=33
	self.Icon=U.text("RankIcon",self.Frame,"",22,C.orange,U.theme.Fonts.Display); U.rect(self.Icon,{16,246,36,48}); self.Icon.ZIndex=33; U.stroke(self.Icon,C.orange,0,1)
	self.Bar=U.new("Frame","StarProgress",self.Frame,{Position=UDim2.fromOffset(16,310),Size=UDim2.new(1,-32,0,12),BackgroundColor3=C.line,BorderSizePixel=0,ZIndex=33})
	self.Fill=U.new("Frame","Fill",self.Bar,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.orange,BorderSizePixel=0,ZIndex=34})
	self.Stars=U.text("StarChange",self.Frame,"",16,C.orange,U.theme.Fonts.Mono); U.rect(self.Stars,{16,336,width-40,52}); self.Stars.ZIndex=33
	local pending=result.SettlementPending and "REWARDS PENDING / RECONNECT TO CHECK" or result.Rewards and "SERVER-CONFIRMED REWARDS" or "NO STANDARD RANKED REWARD"
	local note=U.text("RewardNotice",self.Frame,pending,13,C.muted,U.theme.Fonts.Mono); U.rect(note,{16,396,width-40,40}); note.ZIndex=33
	local rematch=U.button("ResultRematch",self.Frame,"REMATCH",C.pink,function() client:send("Rematch") end); rematch.ZIndex=33; U.rect(rematch,{16,452,(width-48)/2,56})
	local exit=U.button("ResultLobby",self.Frame,"LOBBY",C.cyan,function() client:send("Exit") end); exit.ZIndex=33; U.rect(exit,{24+(width-48)/2,452,(width-48)/2,56})
	client.ResultPhases=client.ResultPhases or {}; self.Phases=client.ResultPhases
	self:tick(0); return self
end
function Results:once(phase,key)
	local id=tostring(self.Data.Id)..":"..phase; if self.Phases[id] then return end; self.Phases[id]=true; if key then self.Client.Audio:play(key) end
end
function Results:tick(dt)
	self.Elapsed+=dt; self.Client.ResultElapsed=self.Elapsed; local U=self.UI; local c=Effects.Results; local t=U.reducedMotion and 100 or self.Elapsed; local d=self.Data
	self.Title.TextSize=self.BaseTitleSize*(U.reducedMotion and 1 or 1+math.sin(math.min(t/c.OutcomeDuration,1)*math.pi)*0.12*c.Intensity)
	self:once("Outcome",d.Outcome=="Win" and "Victory" or d.Outcome=="Lose" and "Defeat" or "Draw")
	self.KO.Visible=t>=c.KOAfter; self.Coin.Visible=t>=c.CashAfter; self.Cash.Visible=self.Coin.Visible
	self.RankLabel.Visible=t>=c.RankAfter; self.Icon.Visible=self.RankLabel.Visible; self.Bar.Visible=self.RankLabel.Visible; self.Stars.Visible=self.RankLabel.Visible
	if self.Cash.Visible and d.Cash>0 then self:once("Cash","CashEarned") end
	if t>=c.CashAfter and d.Outcome=="Win" then self:once("Fanfare","VictoryFanfare") end
	self.Coin.Rotation=U.reducedMotion and 0 or math.sin(math.min(1,math.max(0,t-c.CashAfter)/0.6)*math.pi)*12*c.Intensity
	local before,after=d.BeforeRank,d.AfterRank
	if after then
		local delta=before and ordinal(after)-ordinal(before) or 0; local promoted=before and after.Tier>before.Tier; local demoted=before and after.Tier<before.Tier
		self.RankLabel.Text=(promoted and "RANK UP! / " or demoted and "RANK DOWN / " or "")..P.Ranks[after.Tier]:upper()
		self.Icon.Text=self.IconAsset and "" or RankIcons.Fallback[P.Ranks[after.Tier]] or "*"
		local asset=Assets.rank(P.Ranks[after.Tier])
		if asset and asset~="" and not self.IconAsset then self.Icon.Text=""; self.IconAsset=U.new("ImageLabel","UploadedRankIcon",self.Icon,{Size=UDim2.fromScale(1,1),Image=asset,BackgroundTransparency=1,ZIndex=34}) end
		local required=P.Stars[after.Tier]; local target=required>0 and after.Stars/required or 1
		local start=before and P.Stars[before.Tier]>0 and before.Stars/P.Stars[before.Tier] or 0; local progress=math.clamp((t-c.RankAfter)/c.RankDuration,0,1)
		local fraction=start+(target-start)*progress
		if promoted then fraction=progress<0.5 and start+(1-start)*progress*2 or target*(progress-0.5)*2 elseif demoted then fraction=progress<0.5 and start*(1-progress*2) or target*(progress-0.5)*2 end
		self.Fill.Size=UDim2.fromScale(fraction,1); self.Fill.BackgroundColor3=delta<0 and U.colors.pink or U.colors.orange
		self.Stars.TextColor3=delta<0 and U.colors.pink or U.colors.yellow; self.Icon.Rotation=U.reducedMotion and 0 or (promoted and math.sin(math.clamp((t-c.RankAfter-c.RankDuration)/c.HighlightDuration,0,1)*math.pi)*8*c.Intensity or 0)
		self.Stars.Text=after.Tier==7 and ("RATING "..after.Rating) or (delta>0 and "+"..delta.." STAR"..(delta==1 and "" or "S") or delta<0 and tostring(delta).." STAR"..(delta==-1 and "" or "S") or "STARS UNCHANGED").." / "..after.Stars.." OF "..required
		if self.RankLabel.Visible and delta~=0 then self:once("Progress","RankProgress"); self:once("Star",delta>0 and "StarEarned" or "StarLost") end
		if progress>=1 then if promoted then self:once("Tier","RankUp") elseif demoted then self:once("Tier","RankDown") end end
	else self.RankLabel.Text="RANK UPDATE PENDING"; self.Stars.Text="Reconnect to check saved progression."; self.Bar.Visible=false
	end
end
function Results:destroy() self.Frame:Destroy() end
return Results

end)()

modules.PortalUI=(function()
-- Data-driven lobby screens. All purchases and claims are requested from server.
local Players=game:GetService("Players")
local SocialService=game:GetService("SocialService")
local TextService=game:GetService("TextService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog=require(Shared:WaitForChild("Catalog"))
local P=require(Shared:WaitForChild("Progression"))
local Assets=require(script.Parent:WaitForChild("UIAssets"))
local Products=require(Shared:WaitForChild("Config"):WaitForChild("DeveloperProductConfig"))
local ThemeConfig=require(Shared.Config:WaitForChild("UIThemeConfig"))
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local F=Theme.Fonts
local Preview=require(script.Parent:WaitForChild("BrickPreviewRenderer"))
local Results=require(script.Parent:WaitForChild("ArcadeResults"))
local Portal={}; Portal.__index=Portal
function Portal.new(root,UI,client,closed)
	local self=setmetatable({Root=root,UI=UI,Client=client,Page="Profile",Category="BrickSkins",Inventory=false,Leaderboard="GlobalRating",Closed=closed},Portal)
	local C=UI.colors
	self.Overlay=UI.new("TextButton","LobbyPortal",root,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,Visible=false,ZIndex=30,Active=true,Text="",AutoButtonColor=false,Selectable=false})
	UI.focusGroup(self.Overlay)
	self.Header=UI.text("PortalTitle",self.Overlay,"",20,C.orange,F.Display); self.Header.ZIndex=31
	self.Back=UI.button("ClosePortal",self.Overlay,"BACK",C.cyan,function() self:close() end); self.Back.ZIndex=31
	self.Tabs=UI.new("Frame","Tabs",self.Overlay,{BackgroundTransparency=1,ZIndex=31})
	self.Scroll=UI.new("ScrollingFrame","Items",self.Overlay,{BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=31})
	UI.new("UIListLayout","Rows",self.Scroll,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
	game:GetService("ContextActionService"):BindActionAtPriority("RetroPortalBack",function(_,state)
  if self.Overlay.Visible and state==Enum.UserInputState.Begin then
   if self.PreviewOpen then self.PreviewOpen=false; self:render(true) else self:close() end
   return Enum.ContextActionResult.Sink
  end
  return Enum.ContextActionResult.Pass
 end,false,3200,Enum.KeyCode.ButtonB,Enum.KeyCode.Escape)
 return self
end
function Portal:layout(w,h)
 local old,oldHeight=self.Width,self.Height; self.Width=w; self.Height=h
 local shop=self.Page=="Shop" or self.Page=="Inventory"; self.Sidebar=shop and w>=960; local tabs=w<600 and 96 or 48; self.BodyTop=self.Sidebar and 88 or 76+tabs+12; self.ListX=self.Sidebar and 164 or 20
 self.ListWidth=(self.Page=="Shop" or self.Page=="Inventory") and w>=960 and math.min(440,math.floor((w-220)*0.45)) or w-40
 local U=self.UI; U.rect(self.Header,{20,20,w-156,40}); U.rect(self.Back,{w-116,16,96,44}); U.rect(self.Tabs,{20,76,w-40,tabs})
 self.Header.TextSize=w<640 and 16 or 20
 if self.Sidebar then U.rect(self.Tabs,{20,88,132,h-108}) end
 U.rect(self.Scroll,{self.ListX,self.BodyTop,self.ListWidth,h-self.BodyTop-20})
 if (old~=w or oldHeight~=h) and self.Overlay.Visible then self:render(true) end
end
function Portal:remember()
 self.ScrollPositions=self.ScrollPositions or {}; self.ScrollPositions[self.Page..":"..self.Category]=self.Scroll.CanvasPosition
 self.PageState=self.PageState or {}; self.PageState[self.Page]={Category=self.Category,Selected=self.Selected}
end
function Portal:close(suppressCancel)
 self:remember()
 if not suppressCancel and self.PreviewOpen then self.PreviewOpen=false; self:render(true); return end
 if not suppressCancel and self.Stack and #self.Stack>0 and self.Page~="Searching" and self.Page~="Result" then local prior=table.remove(self.Stack); self.Page=prior.Page; self.Category=prior.Category; self.Selected=prior.Selected; self.PreviewOpen=false; self:render(); self:restoreFocus(); return end
 self.Stack={}
 if self.Page=="Searching" and not suppressCancel then self.Client:send("Cancel") end
 self.PreviewOpen=false; self:clearPreview(); self.Overlay.Visible=false; self.UI.ActiveModal=nil; self.Client:block(false)
 if self.ResultSequence then self.ResultSequence:destroy(); self.ResultSequence=nil end
 self.Client.Audio:music(self.Client.Mode=="Solo" and "SoloMusic" or (self.Client.Mode=="Ranked" or self.Client.Mode=="Challenge") and "BattleMusic" or "MenuMusic")
 if self.Closed then self.Closed() end
end
function Portal:open(page)
 self.Stack=self.Stack or {}
 if self.Overlay.Visible and self.Page~=page and self.Page~="Searching" and self.Page~="Result" and page~="Searching" and page~="Result" then self:remember(); table.insert(self.Stack,{Page=self.Page,Category=self.Category,Selected=self.Selected}) end
 if page=="Searching" or page=="Result" then self.Stack={} end
 local saved=self.PageState and self.PageState[page]; if saved then self.Category=saved.Category; self.Selected=saved.Selected end
 self.UI.ActiveModal=self.Overlay
 self.Page=page; self.PreviewOpen=false; self.Overlay.Visible=true; self.Client:block(true); self.Client.Audio:play("ButtonClick")
 self.Client.Audio:music((page=="Shop" or page=="Inventory") and "ShopMusic" or "MenuMusic")
 self:layout(self.Width or self.Root.AbsoluteSize.X,self.Height or self.Root.AbsoluteSize.Y); self:render(); self:restoreFocus()
end
function Portal:clear(parent)
	for _,child in ipairs(parent:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
end
function Portal:tab(text,index,fn)
 local b=self.UI.button("Tab"..index,self.Tabs,text,self.UI.colors.line,fn); b.ZIndex=32
 if self.Sidebar then self.UI.rect(b,{0,(index-1)*56,132,48}); b.TextSize=10; return b end
 local columns=self.Width<600 and 2 or 4; local width=(self.Width-40-(columns-1)*8)/columns
 self.UI.rect(b,{((index-1)%columns)*(width+8),math.floor((index-1)/columns)*52,width,44})
end
function Portal:row(title,body,action,fn,accent,height)
 local U,C=self.UI,self.UI.colors; local narrow=self.Width<640
 local reserved=action and not narrow and 196 or 28
 local textWidth=math.max(80,self.ListWidth-8-reserved)
 local titleHeight=math.max(28,U.measure(title,14,textWidth)+4)
 local bodyHeight=math.max(44,U.measure(body,12,textWidth)+4)
 local row=U.new("Frame","Row",self.Scroll,{BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=32}); row.Size=UDim2.new(1,-8,0,math.max(height or (action and 112 or 96),8+titleHeight+4+bodyHeight+12+(action and narrow and 54 or 0)))
 U.stroke(row,accent or C.line,0.15,1); local divider=U.divider(row,"RowBorder"); divider.ZIndex=33
 local t=U.text("Title",row,title,14,C.text,F.Strong); t.ZIndex=33; t.Position=UDim2.fromOffset(14,8); t.Size=UDim2.new(1,-reserved,0,titleHeight); t.TextYAlignment=Enum.TextYAlignment.Top
 local d=U.text("Body",row,body,12,C.muted,F.Body); d.ZIndex=33; d.Position=UDim2.fromOffset(14,12+titleHeight); d.Size=UDim2.new(1,-reserved,0,bodyHeight); d.TextYAlignment=Enum.TextYAlignment.Top
 if action then
  self.RowIndex=(self.RowIndex or 0)+1
  local b=U.button("Action"..self.RowIndex,row,action,accent or C.line,function() self.Client.Audio:play("ButtonClick"); fn() end); b.ZIndex=33
  b.Position=narrow and UDim2.new(0,14,1,-54) or UDim2.new(1,-178,0,30); b.Size=narrow and UDim2.new(1,-28,0,44) or UDim2.fromOffset(164,44)
 end
 return row
end
function Portal:rankProgress(row,rank,previous)
	local U=self.UI; local C=U.colors
	local required=P.Stars[rank.Tier]; local fraction=required>0 and rank.Stars/required or 1
	local body=row:FindFirstChild("Body"); local barY=self.Width<640 and body.Position.Y.Offset+body.Size.Y.Offset+4 or row.Size.Y.Offset-12
	local bar=U.new("Frame","RankProgress",row,{Position=UDim2.new(0,14,0,barY),Size=UDim2.new(1,-28,0,8),BackgroundColor3=C.line,BorderSizePixel=0,ZIndex=33})
	U.round(bar,4)
	local start=previous and previous.Tier==rank.Tier and required>0 and previous.Stars/required or 0
	local fill=U.new("Frame","ProgressFill",bar,{Size=UDim2.fromScale(previous and start or fraction,1),BackgroundColor3=C.cyan,BorderSizePixel=0,ZIndex=34}); U.round(fill,4)
	if previous then U.tween(fill,{Size=UDim2.fromScale(fraction,1)},0.65) end
	if previous and (previous.Tier~=rank.Tier or previous.Stars~=rank.Stars) then
		local label=row:FindFirstChild("Title"); label.TextColor3=rank.Tier>previous.Tier and C.green or C.purple
		if rank.Tier>previous.Tier then label.Text="RANK UP / "..P.Ranks[rank.Tier] elseif rank.Tier<previous.Tier then label.Text="RANK DOWN / "..P.Ranks[rank.Tier] end
		U.tween(label,{TextColor3=C.text},1.1)
	end
end
function Portal:render(preserveScroll)
	if not self.Overlay.Visible then return end
	local selected=game:GetService("GuiService").SelectedObject; local focusName=preserveScroll and selected and selected.Name
	local d=self.Client.Profile
	local shop=self.Page=="Shop" or self.Page=="Inventory"
	local view=self.ShopView
	if preserveScroll and self.Page=="Result" and self.ResultSequence and self.ResultSequence.Data.Id==self.ResultData.Id and self.ResultWidth==self.Width then return end
	if preserveScroll and shop and d and view and view.Page==self.Page and view.Category==self.Category and view.Width==self.Width and view.Height==self.Height then
		-- Server profile updates and preview actions never remove the list or its cards.
		self:shop(d,true); self:restoreFocus(focusName); return
	end
	local scroll=preserveScroll and self.Scroll.CanvasPosition or shop and self.ScrollPositions and self.ScrollPositions[self.Page..":"..self.Category] or Vector2.new(0,0)
	if self.ResultSequence then self.ResultSequence:destroy(); self.ResultSequence=nil end
	self.RowIndex=0; self.ClaimButtons={}; self.QuestReset=nil; self.EnergyRow=nil; self:clearPreview()
	self:layout(self.Width or 1120,self.Height or 760)
	self.ShopView=nil
	self:clear(self.Tabs); self:clear(self.Scroll); self.Scroll.CanvasPosition=scroll
	self.Header.Text=self.Page=="ChallengeInvite" and "DUEL INVITE" or self.Page:upper()
 if self.HeaderIcon then self.HeaderIcon:Destroy() end
 local headerKeys={Shop="shop",Inventory="inventory",Quests="quests",Profile="profile",Leaderboards="leaderboards",Login="login_rewards",Friends="friends",Audio="audio",Hub="more",Help="help",Redeem="redeem_code",Emotes="emoji",Controls="settings"}
 local headerUri=self.Page=="Energy" and Assets.currency("Energy") or self.Page=="Cash" and Assets.currency("Cash") or Assets.uri("Images.menu."..(headerKeys[self.Page] or "more"))
 self.HeaderIcon=self.UI.image(self.Overlay,"HeaderAsset",headerUri); self.HeaderIcon.Position=UDim2.fromOffset(20,24); self.HeaderIcon.Size=UDim2.fromOffset(32,32); self.HeaderIcon.ZIndex=32; self.Header.Position=UDim2.fromOffset(headerUri~="" and 62 or 20,20); self.Header.Size=UDim2.fromOffset(self.Width-(headerUri~="" and 198 or 156),40)
	if not d then self:row("Loading profile","Please wait for your server data."); return end
	if self.Page=="Hub" then
  self.Header.Text="YOUR ARCADE"
  local links={{"Profile","profile"},{"Login","login_rewards"},{"Energy","currency.energy"},{"Audio","audio"},{"Help","help"},{"Redeem","redeem_code"},{"Assets","inventory"}}
  self:menuGrid(links)
 elseif self.Page=="Shop" or self.Page=="Inventory" then
  self:shop(d)
	elseif self.Page=="Quests" then
		self:tab("DAILY",1,function() self.QuestGroup="Daily"; self:render() end); self:tab("WEEKLY",2,function() self.QuestGroup="Weekly"; self:render() end)
		local group=self.QuestGroup or "Daily"; self.Header.Text=group:upper().." QUESTS"
  self.QuestReset=self.UI.text("QuestReset",self.Tabs,"",11,self.UI.colors.muted); self.QuestReset.ZIndex=33; self.UI.rect(self.QuestReset,self.Width<600 and {0,56,self.Width-40,24} or {(self.Width-40)/2,8,(self.Width-40)/2,28})
  self.QuestResetAt=group=="Daily" and (d.Quests[group].Window+1)*86400 or ((d.Quests[group].Window+1)*7-3)*86400
		for _,q in ipairs(P[group]) do
			local state=d.Quests[group]; local n=state.Progress[q.Id] or 0
			local row=self:row(q.Label,string.format("%d / %d  |  %s%s\nReset: %s UTC",n,q.Target,q.Cash and q.Cash.." Cash" or "",q.Energy and q.Energy.." Energy" or "",group=="Daily" and "daily at 00:00" or "Monday 00:00"),state.Claimed[q.Id] and "CLAIMED" or "CLAIM",function() self.Client:send("ClaimQuest",{Group=group,Id=q.Id}) end)
   local button=row:FindFirstChildOfClass("TextButton"); local ready=n>=q.Target and not state.Claimed[q.Id]; button.Text=state.Claimed[q.Id] and "CLAIMED" or ready and "CLAIM" or "INCOMPLETE"; self.UI.enabled(button,ready); if ready then table.insert(self.ClaimButtons,button); button.BackgroundColor3=self.UI.colors.orange; button.TextColor3=self.UI.colors.background end
   local key=q.Id:lower():find("spin") and "t_spins" or q.Id:lower():find("send") and "send_lines" or q.Id:lower():find("win") and "ranked_wins" or q.Id:lower():find("minute") and "play_time" or "practice"
   local icon=self.UI.icon(row,"Images.quests."..key); if icon.Visible then row.Title.Position=UDim2.fromOffset(48,8); row.Title.Size=UDim2.new(1,-(self.Width<640 and 62 or 244),0,row.Title.Size.Y.Offset) end
   local bar=self.UI.new("Frame","QuestProgress",row,{Position=UDim2.new(0,14,1,self.Width<640 and -64 or -12),Size=UDim2.new(1,-(self.Width<640 and 28 or 206),0,6),BackgroundColor3=self.UI.colors.line,BorderSizePixel=0,ZIndex=33}); self.UI.new("Frame","Fill",bar,{Size=UDim2.fromScale(math.clamp(n/q.Target,0,1),1),BackgroundColor3=self.UI.colors.cyan,BorderSizePixel=0,ZIndex=34})
  end
 elseif self.Page=="Leaderboards" then
		self.Header.Text=self.Leaderboard:sub(1,6)=="Season" and "SEASON TOP 100" or "GLOBAL TOP 100"
		for i,key in ipairs({"GlobalRating","GlobalWins","SeasonRating","SeasonWins"}) do self:tab(key,i,function() self.Leaderboard=key; self.BoardData=nil; self.Client:send("Leaderboard",key); self:render() end) end
		if not self.BoardData then self:row("Loading Top 100","Getting the latest standings."); self.Client:send("Leaderboard",self.Leaderboard) else
			if self.BoardData.Notice then self:row("Standings",self.BoardData.Notice) end
			local found=false
			for i,entry in ipairs(self.BoardData.Rows) do
				if entry.UserId==Players.LocalPlayer.UserId then found=true end
				local row=self:row(string.format("#%d  %s",entry.Position or i,entry.Name),tostring(entry.Value).." / "..self.BoardData.Kind..(entry.Rank and " / "..entry.Rank or ""),nil,nil,nil,102)
				local avatar=self.UI.new("ImageLabel","Avatar",row,{Position=UDim2.new(1,-66,0,44),Size=UDim2.fromOffset(44,44),BackgroundTransparency=1,Image="rbxthumb://type=AvatarHeadShot&id="..entry.UserId.."&w=150&h=150",ZIndex=33})
			end
			if not found then self:row("Your placement","Your exact position outside the Top 100 is unavailable. No estimated placement is displayed.") end
		end
	elseif self.Page=="Login" then
		local day=math.floor(workspace:GetServerTimeNow()/86400)
		self:row("Seven-day reward cycle","Collected days are kept even if you miss a day. Next reward day: "..(d.Login.Index%7+1),d.Login.LastDay==day and "CLAIMED TODAY" or "CLAIM DAILY LOGIN",function() self.Client:send("Login") end)
		for i=1,7 do self:row("Day "..i,d.Economy.LoginCash[i].." Cash + "..d.Economy.LoginEnergy[i].." Energy",nil,nil,nil,102) end
	elseif self.Page=="Audio" then
		self:row("Audio volumes","Adjust master, music and effects volume separately. Settings are saved with your profile.")
		for _,field in ipairs({"Master","MusicVolume","SFXVolume"}) do
			self:row(field,math.floor(self.Client.Audio[field]*100).."%","CYCLE +20%",function()
				local a=self.Client.Audio; a[field]=(math.floor(a[field]*5+0.5)+1)%6/5
				a:settings(a.Master,a.MusicVolume,a.SFXVolume,a.Muted); self.Client:send("Settings",{[field]=a[field]}); self:render()
			end)
		end
	elseif self.Page=="Emotes" then
		local rules=require(Shared:WaitForChild("Config"):WaitForChild("Rules"))
		for i,text in ipairs(rules.Emotes) do self:row(text,"Battle only / server cooldown "..rules.EmoteCooldown.."s","SEND",function() self.Client:send("Emote",i); self:close() end) end
		self:row("Roblox chat","Use the native filtered chat. Availability follows Roblox account permissions.","OPEN CHAT",function() local ok=pcall(function() local bar=game:GetService("TextChatService").ChatInputBarConfiguration; assert(bar.Enabled and bar.TextBox); bar.TextBox:CaptureFocus() end); if not ok then self.Client.Hooks.Message("Native chat is unavailable; use preset emotes.") end end)
	elseif self.Page=="Controls" then
		for _,field in ipairs({"SwapRotation","ClassicHUD"}) do self:row(field,d.Settings[field] and "ON" or "OFF","TOGGLE",function() self.Client:send("Settings",{[field]=not d.Settings[field]}) end) end
		self:row("UI scale",tostring(d.Settings.UIScale or 1).." / desktop only; touch targets stay full size","CYCLE",function() self.Client:send("Settings",{UIScale=d.Settings.UIScale==0.9 and 1 or 0.9}) end)
		self:row("Keyboard / controller","Arrows or WASD: move. X/Up: clockwise. Z: counterclockwise. C/Shift: hold. Space: hard drop. Swap Rotation exchanges the rotation actions. Gamepad bindings remain in Rules.")
	elseif self.Page=="Friends" then
		self:row("Invite friends","A verified first-time friend who stays "..d.Economy.SocialMinSeconds.."s earns you "..d.Economy.SocialEnergy.." Energy. Limit "..d.Economy.SocialLimit.." daily. Clicking Invite gives no reward.","INVITE FRIENDS",function()
			task.spawn(function() local ok,allowed=pcall(function() return SocialService:CanSendGameInviteAsync(Players.LocalPlayer) end); if ok and allowed then pcall(function() SocialService:PromptGameInvite(Players.LocalPlayer) end) else self.Client.Hooks.Message("Invitations are unavailable on this device or in Studio") end end)
		end)
		for _,other in ipairs(Players:GetPlayers()) do
			if other~=Players.LocalPlayer then self:row(other.DisplayName,"Free unranked challenge; server verifies friendship.","CHALLENGE",function() self.Client:send("Challenge",other.UserId) end) end
		end
	elseif self.Page=="Featured" then
  self:row("COSMETICS","Equip your owned styles or preview before spending Cash.","OPEN COSMETICS",function() self:open("Shop") end)
  self:packCards("Cash",d); self:packCards("Energy",d)
 elseif self.Page=="Cash" then
  self:packCards("Cash",d)
 elseif self.Page=="Energy" then
		self.EnergyRow=self:row("Energy "..d.Energy.Current.." / "..d.Economy.EnergyCap,d.DebugPrivileges and d.DebugPrivileges.InfiniteEnergy and "Unlimited Studio test energy. Test rewards never write to live data." or ("Next regeneration: "..d.Energy.Next.."s. +1 every "..d.Economy.EnergyInterval.."s, including offline. Bonus cap "..d.Economy.BonusCap..". Ranked costs "..d.Economy.RankedCost.."; Solo is free."),"OPEN QUESTS",function() self:open("Quests") end)
	  local energy=self.UI.panel("EnergySegments",self.Scroll,self.UI.colors.cyan); energy.Size=UDim2.new(1,-8,0,72); energy.ZIndex=32
  for i=1,d.Economy.EnergyCap do self.UI.new("Frame","Energy"..i,energy,{Position=UDim2.new((i-1)/d.Economy.EnergyCap,4,0,20),Size=UDim2.new(1/d.Economy.EnergyCap,-8,0,28),BackgroundColor3=i<=d.Energy.Current and self.UI.colors.cyan or self.UI.colors.line,BorderSizePixel=0,ZIndex=33}) end
  self:packCards("Energy",d)
 elseif self.Page=="Help" then self:row("ARCADE CONTROLS","Arrows / WASD move. X/Up rotates, Z reverses, C/Shift holds, Space drops. Ranked uses a server-timed 120 second battle. Settings include touch/gamepad controls and Reduced Motion.","CONTROLS",function() self:open("Controls") end)
 elseif self.Page=="Redeem" then self:row("REDEEM CODE","Code redemption is not available yet.")
 elseif self.Page=="Assets" then self:assetGallery()
 elseif self.Page=="Searching" then
		self:row("FINDING OPPONENT","Searching for a real player in this server.","CANCEL SEARCH",function() self:close() end)
		self.SearchLabel=self.UI.text("Elapsed",self.Scroll,"",18,self.UI.colors.cyan); self.SearchLabel.Size=UDim2.new(1,-8,0,48); self.SearchLabel.ZIndex=32
		local row=self:row(Players.LocalPlayer.DisplayName,"@"..Players.LocalPlayer.Name.." / "..P.Ranks[d.Rank.Tier].." / "..d.Rank.Stars.." stars / "..d.Rank.Rating.." rating")
		self.UI.new("ImageLabel","Avatar",row,{Position=UDim2.new(1,-58,0,8),Size=UDim2.fromOffset(44,44),BackgroundTransparency=1,Image="rbxthumb://type=AvatarHeadShot&id="..Players.LocalPlayer.UserId.."&w=150&h=150",ZIndex=33})
	elseif self.Page=="Result" then
		if self.ResultData then self.ResultSequence=Results.new(self.Scroll,self.UI,self.Client,self.ResultData,self.ListWidth); self.ResultWidth=self.Width end
	elseif self.Page=="ChallengeInvite" then
		self:row("Friend challenge",self.Challenger.DisplayName.." invites you to a free unranked duel.","ACCEPT",function() self.Client:send("AcceptChallenge"); self:close() end)
	else
		self:row(Players.LocalPlayer.DisplayName,P.Ranks[d.Rank.Tier].." / "..d.Rank.Stars.." stars / Rating "..d.Rank.Rating.."\nCash "..d.Cash.." / Energy "..d.Energy.Current)
		local progress=self:row("Rank progression",d.Rank.Tier==7 and "Master progresses by rating." or (d.Rank.Stars.." / "..P.Stars[d.Rank.Tier].." stars to "..P.Ranks[d.Rank.Tier+1]),nil,nil,nil,102)
		self:rankProgress(progress,d.Rank)
		self:row("Lifetime stats",string.format("Wins %d | Losses %d | Matches %d\nLines %d | T-Spins %d | Best streak %d",d.Stats.Wins,d.Stats.Losses,d.Stats.Matches,d.Stats.Lines,d.Stats.TSpins,d.Stats.BestWinStreak))
		self:row("Season "..d.Season.Id,"Season rating "..d.Season.Rating.." / Wins "..d.Season.Wins.."\n"..d.Economy.SeasonDays.."-day seasons. Cash and cosmetics survive season changes.")
		local badges={}; for badge in pairs(d.Inventory.Badges) do table.insert(badges,badge) end; table.sort(badges)
		self:row("Achievements / badges",#badges>0 and table.concat(badges,", ") or "Earn your first win, T-Spin or perfect clear.")
		for _,history in ipairs(d.Season.History) do self:row("Season "..history.Id.." history","Rating "..history.Rating.." / Wins "..history.Wins,nil,nil,nil,102) end
	end
	self.RenderRevision=(self.RenderRevision or 0)+1
	local revision=self.RenderRevision; self.Scroll.CanvasPosition=scroll
	if preserveScroll or shop then task.defer(function() if self.Overlay.Parent and self.Overlay.Visible and self.RenderRevision==revision then self.Scroll.CanvasPosition=scroll end end) end
	self:restoreFocus(focusName)
end
function Portal:clearPreview()
	if self.UI.ActiveModal==self.PreviewPanel then self.UI.ActiveModal=self.Overlay.Visible and self.Overlay or nil end
	self.Client.Audio:stopPreview()
	if self.Sample then self.Sample:destroy(); self.Sample=nil end
	if self.PreviewPanel then self.PreviewPanel:Destroy(); self.PreviewPanel=nil end
	if self.PreviewShade then self.PreviewShade:Destroy(); self.PreviewShade=nil end
	self.DetailId=nil; self.DetailCategory=nil
end
function Portal:restoreFocus(name)
	if not game:GetService("UserInputService").GamepadEnabled then return end
	if self.PreviewOpen and self.PreviewPanel then game:GetService("GuiService").SelectedObject=self.PreviewPanel:FindFirstChild("ClosePreview"); return end
	local object=name and self.Overlay:FindFirstChild(name,true)
	game:GetService("GuiService").SelectedObject=object and object.Selectable and object or self.Back
end
function Portal:sampleAudio(item)
	local ok,text=self.Client.Audio:preview(item.Id)
	if not ok then self.Client.Hooks.Message(text) end
end
function Portal:shop(d,incremental)
	local U,C=self.UI,self.UI.colors
	local captions={"BRICKS","DROP FX","GHOST FX","SOUND PACKS"}
	if not incremental then
  for index,category in ipairs(Catalog.Categories) do self:tab(captions[index],index,function() self.ScrollPositions=self.ScrollPositions or {}; self.ScrollPositions[self.Page..":"..self.Category]=self.Scroll.CanvasPosition; self.Category=category; self.Selected=nil; self.PreviewOpen=false; self:render() end) end
		if self.Sidebar and self.Page=="Shop" then for i,page in ipairs({"Featured","Cash","Energy"}) do self:tab(page:upper(),i+4,function() self:open(page) end) end end
  self.ShopView={Page=self.Page,Category=self.Category,Width=self.Width,Height=self.Height,Cards={}}
		self.ShopView.Balance=self:row("CASH "..d.Cash,"Visuals only. Your purchases and loadout are saved.",nil,nil,nil,88)
	end
	local view=self.ShopView; local seen={}
 if self.Page=="Inventory" and not view.Grid then view.Grid=U.new("Frame","InventoryGrid",self.Scroll,{BackgroundTransparency=1,Size=UDim2.new(1,-8,0,0),ZIndex=32,LayoutOrder=1}); U.new("UIGridLayout","Grid",view.Grid,{CellSize=UDim2.fromOffset((self.ListWidth-20)/2,200),CellPadding=UDim2.fromOffset(10,10),SortOrder=Enum.SortOrder.LayoutOrder,FillDirectionMaxCells=2}) end
 local gridCount=0
	view.Balance:FindFirstChild("Title").Text="CASH "..d.Cash
 if not view.Balance:FindFirstChild("AssetIcon") then U.icon(view.Balance,"Images.currency.cash") end
	self.Header.Text=self.Page=="Inventory" and "INVENTORY" or "COSMETIC SHOP"
	local width=self.ListWidth; local items=Catalog.list(self.Category)
	local selected=self.Selected and Catalog.Items[self.Category..":"..self.Selected] or items[1]
	self.Selected=selected.Id
	for order,item in ipairs(items) do
		local owned=d.Inventory[item.Category][item.Id] or d.DebugPrivileges and d.DebugPrivileges.FreeCosmetics
		local equipped=d.Equipped[Catalog.Slots[item.Category]]==item.Id
		if self.Page=="Shop" or owned then
			seen[item.Id]=true
			local card=view.Cards[item.Id]
			if not card then
			local row=U.panel("Cosmetic_"..item.Id,view.Grid or self.Scroll); row.Size=UDim2.new(1,-8,0,156); row.ZIndex=32; row.LayoutOrder=order
			card={Row=row,Buttons={},Rarity=item.Rarity}; row.Outline.Color=Color3.fromRGB(table.unpack(ThemeConfig.RarityColors[item.Rarity] or ThemeConfig.RarityColors.Common)); view.Cards[item.Id]=card
			local label=U.text("Name",row,item.Name,13,C.text,F.Strong); label.ZIndex=33; U.rect(label,{112,10,width-144,40})
			local rarity=U.text("Rarity",row,item.Rarity:upper(),10,C.orange,F.Mono); rarity.ZIndex=33; U.rect(rarity,{112,50,width-144,20})
			local price=d.DebugPrivileges and d.DebugPrivileges.FreePurchases and 0 or item.Price
			local status=equipped and "EQUIPPED" or owned and "OWNED" or "LOCKED"
			local meta=U.text("Ownership",row,status.." / "..price.." CASH",10,owned and C.green or C.muted,F.Mono); meta.ZIndex=33; U.rect(meta,{112,72,width-144,26})
			if item.Category=="SoundPacks" then
				local text=U.text("SoundPack",row,"SFX",22,C.cyan,F.Mono); text.ZIndex=33; U.rect(text,{16,22,80,54})
			else
				card.Mini=Preview.thumbnail(row,U,item,d.Equipped); U.rect(card.Mini.Frame,{16,28,80,40})
			end
			local art=U.image(row,"CosmeticArtwork",Assets.cosmetic(item)); U.rect(art,{16,6,80,72}); if art.Visible and card.Mini then U.rect(card.Mini.Frame,{28,74,56,28}) end
   if item.Category=="SoundPacks" and art.Visible then row.SoundPack.Visible=false end
   local actions={{"Preview_","PREVIEW",function() self.Selected=item.Id; self.PreviewOpen=self.Width<960; self:render(true) end},
				{"Buy_",owned and "OWNED" or "BUY",function() self:cosmeticRequest("Buy",item) end},
				{"Equip_",equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP",function() local current=self.Client.Profile; local isEquipped=current and current.Equipped[Catalog.Slots[item.Category]]==item.Id; self:cosmeticRequest("Equip",item,isEquipped and "Default" or item.Id) end}}
			local bw=(width-48)/3
			for index,action in ipairs(actions) do local button=U.button(action[1]..item.Id,row,action[2],index==1 and C.cyan or C.line,action[3]); button.ZIndex=33
				card.Buttons[index]=button
				U.rect(button,{16+(index-1)*(bw+8),102,bw,44}); if index==2 then U.enabled(button,not owned) elseif index==3 then U.enabled(button,owned and not (equipped and item.Id=="Default")) end
			end
			end
			local price=d.DebugPrivileges and d.DebugPrivileges.FreePurchases and 0 or item.Price
			local status=equipped and "EQUIPPED" or owned and "OWNED" or "LOCKED"
			if view.Grid then
    gridCount+=1; local row=card.Row; local cw=(self.ListWidth-20)/2; row.Size=UDim2.fromOffset(cw,200)
    U.rect(row:FindFirstChild("Name"),{10,76,cw-20,32}); row:FindFirstChild("Name").TextSize=11; row:FindFirstChild("Name").TextXAlignment=Enum.TextXAlignment.Center
    U.rect(row.Rarity,{10,112,cw-20,18}); U.rect(row.Ownership,{10,132,cw-20,18}); row.Ownership.TextSize=10
    if card.Mini then U.rect(card.Mini.Frame,{(cw-80)/2,16,80,40}) end; local art=row:FindFirstChild("CosmeticArtwork"); if art then U.rect(art,{cw-44,4,36,36}) end
    card.Buttons[2].Visible=false; U.rect(card.Buttons[1],{8,154,(cw-24)/2,44}); U.rect(card.Buttons[3],{16+(cw-24)/2,154,(cw-24)/2,44}); card.Buttons[1].TextSize=10; card.Buttons[3].TextSize=10
   end
   card.Row.Outline.Color=self.Selected==item.Id and C.yellow or Color3.fromRGB(table.unpack(ThemeConfig.RarityColors[item.Rarity] or ThemeConfig.RarityColors.Common))
			local meta=card.Row:FindFirstChild("Ownership"); meta.Text=view.Grid and status or status.." / "..price.." CASH"; meta.TextColor3=owned and C.green or C.muted
			card.Buttons[2].Text=owned and "OWNED" or "BUY"; U.enabled(card.Buttons[2],not owned)
			card.Buttons[3].Text=equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP"; U.enabled(card.Buttons[3],owned and not (equipped and item.Id=="Default"))
			local pending=self.Client.PendingCosmetic; if pending then for i=2,3 do U.enabled(card.Buttons[i],false); if pending.Category==item.Category and (pending.Id==item.Id or pending.Id=="Default" and equipped) then card.Buttons[i].Text="WAIT..." end end end
   if card.Mini then local Bricks=require(script.Parent:WaitForChild("BrickRenderer")); Bricks.piece(card.Mini,"T",{BrickSkin=item.Category=="BrickSkins" and item.Id or d.Equipped.BrickSkin,GhostEffect="Default"},U.reducedMotion) end
		end
	end
	if view.Grid then view.Grid.Size=UDim2.new(1,-8,0,math.ceil(gridCount/2)*210) end
 for id,card in pairs(view.Cards) do if not seen[id] then card.Row:Destroy(); view.Cards[id]=nil end end
	if self.Width>=960 or self.PreviewOpen then
		if self.Sample and self.DetailId==selected.Id and self.DetailCategory==selected.Category then
			for category,slot in pairs(Catalog.Slots) do if category~=selected.Category and slot~="SoundPack" then self.Sample.Loadout[slot]=d.Equipped[slot] end end
			self:updateDetail(selected,d)
		else self:clearPreview(); self:detail(selected,d) end
	else self:clearPreview() end
end
function Portal:detail(item,d)
	local U,C=self.UI,self.UI.colors; local mobile=self.Width<960; local landscape=mobile and self.Height<420 and self.Width>self.Height
	local width,height,x,y
	if mobile then
		width=math.min(landscape and 680 or 480,self.Width-32); height=math.min(520,self.Height-32); x=(self.Width-width)/2; y=(self.Height-height)/2
		self.PreviewShade=U.new("TextButton","PreviewBackdrop",self.Overlay,{Size=UDim2.fromScale(1,1),Text="",AutoButtonColor=false,Selectable=false,BackgroundColor3=C.background,BackgroundTransparency=0.06,ZIndex=38})
	else width=self.Width-20-self.ListX-self.ListWidth-24; height=self.Height-self.BodyTop-20; x=self.ListX+self.ListWidth+24; y=self.BodyTop end
	local panel=U.panel("CosmeticDetail",self.Overlay,C.line); panel.ZIndex=39; U.rect(panel,{x,y,width,height}); self.PreviewPanel=panel
	if mobile then U.focusGroup(panel); U.ActiveModal=panel end
	local title=U.text("PreviewName",panel,item.Name,14,C.orange,F.Display); title.ZIndex=40; U.rect(title,{20,14,width-100,42})
	local close=U.button("ClosePreview",panel,mobile and "BACK" or "SAMPLE",C.line,function() self.PreviewOpen=false; self:render(true) end); close.ZIndex=40; U.rect(close,{width-76,14,56,44}); U.enabled(close,mobile)
	local desc=U.text("PreviewDescription",panel,item.Rarity:upper().." / "..item.Price.." CASH / "..(item.Category=="SoundPacks" and "MANUAL AUDIO SAMPLE" or "LIVE PREVIEW"),11,C.muted); desc.ZIndex=40; U.rect(desc,{20,62,width-40,34})
	local contentWidth=landscape and math.floor(width*0.5) or width
	if landscape then U.rect(title,{20,14,contentWidth-40,42}); U.rect(desc,{20,62,contentWidth-40,40}); U.rect(close,{width-76,4,56,44}) end
	self.DetailId=item.Id; self.DetailCategory=item.Category
	local sample=Preview.new(panel,U); self.Sample=sample
	local bh=landscape and math.min(height-68,(width-contentWidth-48)*2) or math.min(400,height-308,(width-48)*2); local bw=bh/2
	U.rect(sample.Frame,landscape and {contentWidth+(width-contentWidth-bw)/2,28,bw,bh} or {(width-bw)/2,104,bw,bh}); sample:set(item,d.Equipped)
		local caption=U.text("PreviewCaption",panel,U.reducedMotion and "REDUCED MOTION / STILL FRAME" or "LIVE ENGINE DEMO / NO REWARDS",12,C.muted,F.Mono); caption.ZIndex=40; caption.TextXAlignment=Enum.TextXAlignment.Center; U.rect(caption,landscape and {contentWidth+12,32+bh,width-contentWidth-24,20} or {20,108+bh,width-40,20})
	local controls={{"Pause","PAUSE"},{"Replay","REPLAY"},{"Rotate","ROTATE"},{"Next","PIECE"},{"Speed","1x"},{"Audio","SFX"}}
 local cols=3; local cw=(contentWidth-48)/cols; local start=height-164
 for i,spec in ipairs(controls) do local b=U.button("Preview"..spec[1],panel,spec[2],C.cyan,function() if spec[1]=="Audio" then if item.Category=="SoundPacks" then self:sampleAudio(item) end else sample:control(spec[1]); if spec[1]=="Pause" then panel.PreviewPause.Text=sample.Paused and "PLAY" or "PAUSE" elseif spec[1]=="Speed" then panel.PreviewSpeed.Text=tostring(sample.Speed or 1).."x" end end end); b.ZIndex=40; b.TextSize=10; U.rect(b,{20+(i-1)%cols*(cw+4),start+math.floor((i-1)/cols)*52,cw-4,44}); if spec[1]=="Audio" then U.enabled(b,item.Category=="SoundPacks") end end
 local owned=d.Inventory[item.Category][item.Id] or d.DebugPrivileges and d.DebugPrivileges.FreeCosmetics; local equipped=d.Equipped[Catalog.Slots[item.Category]]==item.Id
 local buy=U.button("DetailBuy",panel,owned and "OWNED" or "PURCHASE",C.orange,function() self:cosmeticRequest("Buy",item) end); buy.ZIndex=40
	local equip=U.button("DetailEquip",panel,equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP",C.line,function() local current=self.Client.Profile; local active=current and current.Equipped[Catalog.Slots[item.Category]]==item.Id; self:cosmeticRequest("Equip",item,active and "Default" or item.Id) end); equip.ZIndex=40
	local bw=(contentWidth-48)/2; local by=height-60; U.rect(buy,{20,by,bw,44}); U.rect(equip,{28+bw,by,bw,44}); U.enabled(buy,not owned); U.enabled(equip,owned and not (equipped and item.Id=="Default"))
end
function Portal:updateDetail(item,d)
	local owned=d.Inventory[item.Category][item.Id] or d.DebugPrivileges and d.DebugPrivileges.FreeCosmetics; local equipped=d.Equipped[Catalog.Slots[item.Category]]==item.Id
	local buy=self.PreviewPanel:FindFirstChild("DetailBuy"); local equip=self.PreviewPanel:FindFirstChild("DetailEquip")
	buy.Text=owned and "OWNED" or "PURCHASE"; self.UI.enabled(buy,not owned); equip.Text=equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP"; self.UI.enabled(equip,owned and not (equipped and item.Id=="Default")); if self.Client.PendingCosmetic then self.UI.enabled(buy,false); self.UI.enabled(equip,false); equip.Text="WAIT..." end
end
function Portal:destroy()
	self:clearPreview(); if self.ResultSequence then self.ResultSequence:destroy(); self.ResultSequence=nil end; game:GetService("ContextActionService"):UnbindAction("RetroPortalBack"); self.Overlay:Destroy()
end

function Portal:cosmeticRequest(kind,item,id)
 if self.Client.PendingCosmetic then return end
 self.Client.PendingCosmetic={Kind=kind,Category=item.Category,Id=id or item.Id,At=os.clock()}
 self.Client:send(kind,{Category=item.Category,Id=id or item.Id}); self:render(true)
end
function Portal:packCards(kind,d)
 local U,C=self.UI,self.UI.colors
 for i,size in ipairs({"small","medium","large"}) do
  local product=Products[kind][i]; local row=self:row(kind:upper().." / "..size:upper(),product and product.Quantity and tostring(product.Quantity).." "..kind or "Not available","UNAVAILABLE",function() self.Client.Hooks.Message("No verified Developer Product integration is configured.") end,nil,140)
  local art=U.image(row,"PackArtwork",Assets.uri("Images.shop."..kind:lower().."_"..size)); U.rect(art,{14,28,70,80}); row.Title.Position=UDim2.fromOffset(96,8); row.Title.Size=UDim2.new(1,-(self.Width<640 and 110 or 292),0,36); row.Body.Position=UDim2.fromOffset(96,48); row.Body.Size=UDim2.new(1,-(self.Width<640 and 110 or 292),0,52); U.enabled(row:FindFirstChildOfClass("TextButton"),false)
 end
end
function Portal:menuGrid(links)
 local U=self.UI; local cols=self.Width>=500 and 2 or 1; local cw=(self.ListWidth-8-(cols-1)*10)/cols
 local grid=U.new("Frame","MoreGrid",self.Scroll,{BackgroundTransparency=1,Size=UDim2.new(1,-8,0,math.ceil(#links/cols)*100),ZIndex=32})
 U.new("UIGridLayout","Tiles",grid,{CellSize=UDim2.fromOffset(cw,90),CellPadding=UDim2.fromOffset(10,10),SortOrder=Enum.SortOrder.LayoutOrder,FillDirectionMaxCells=cols})
 for i,link in ipairs(links) do local button=U.button("More"..link[1],grid,link[1]:upper(),U.colors.line,function() self:open(link[1]) end); button.ZIndex=33; button.LayoutOrder=i; U.icon(button,link[2]:find("%.") and "Images."..link[2] or "Images.menu."..link[2]) end
end
function Portal:assetGallery()
 local U=self.UI
 local row=self:row("ARTWORK REFERENCE","Original filenames and upload locations are in ASSET_ID_CHECKLIST.md. These images never replace live boards or alter ownership.")
 for _,key in ipairs({"brick_demon_wave"}) do local r=self:row(key,"Unmatched cosmetic artwork / no catalog item"); local image=U.image(r,"Reference",Assets.uri("Images.cosmetics."..key)); U.rect(image,{self.ListWidth-80,8,64,64}) end
 for _,key in ipairs({"rookie","amateur","pro","expert","master","immortal"}) do local r=self:row("REFERENCE "..key:upper(),"Optional badge / actual rank progression preserved"); local image=U.image(r,"Reference",Assets.uri("OptionalReferenceRanks.Images."..key)); U.rect(image,{self.ListWidth-80,8,64,64}) end
 local r=self:row("PACK CONTACT SHEET","Optional reference only"); local image=U.image(r,"Reference",Assets.uri("Images.artwork.preview")); U.rect(image,{self.ListWidth-80,8,64,64})
end
function Portal:tick(dt)
 local now=workspace:GetServerTimeNow()
 if self.QuestReset and self.QuestReset.Parent then local left=math.max(0,math.floor(self.QuestResetAt-now)); self.QuestReset.Text=string.format("RESET %02d:%02d:%02d",math.floor(left/3600),math.floor(left%3600/60),left%60) end
 if self.EnergyRow and self.EnergyRow.Parent then local d=self.Client.Profile; local left=d.Energy.Current>=d.Economy.EnergyCap and 0 or math.max(0,math.ceil(d.Economy.EnergyInterval-(now-d.Energy.LastRegenTimestamp))); self.EnergyRow.Body.Text=(d.DebugPrivileges and d.DebugPrivileges.InfiniteEnergy and "Studio test energy" or left==0 and "Energy full" or string.format("+1 ENERGY IN %02d:%02d",math.floor(left/60),left%60)).." / SOLO IS FREE" end
 for _,button in ipairs(self.ClaimButtons or {}) do if button.Parent then button.BackgroundColor3=self.UI.reducedMotion and self.UI.colors.orange or self.UI.colors.orange:Lerp(self.UI.colors.yellow,(math.sin(now*3)+1)*0.15) end end
 local pending=self.Client.PendingCosmetic
 if pending and os.clock()-pending.At>12 then self.Client.PendingCosmetic=nil; self.Client.Hooks.Message("Request timed out. Refresh your profile before trying again."); self:render(true) end
 if self.ShopView then for _,card in pairs(self.ShopView.Cards) do local outline=card.Row:FindFirstChild("Outline"); local alpha=ThemeConfig.RarityMotion[card.Rarity] or 0; if outline then outline.Transparency=self.UI.reducedMotion and 0.15 or 0.15+math.sin(os.clock()*2)*alpha end end end
end

return Portal

end)()

local app=(function()
-- Responsive presentation; gameplay and progression remain server-authoritative.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local P=require(Shared:WaitForChild("Progression"))
local UI=require(script.Parent:WaitForChild("NeonUI"))
local Layout=require(script.Parent:WaitForChild("NeonLayout"))
local Artwork=require(script.Parent:WaitForChild("RetroArtwork"))
local Bricks=require(script.Parent:WaitForChild("BrickRenderer"))
local Effects=require(script.Parent:WaitForChild("CosmeticRenderer"))
local GameClient=require(script.Parent:WaitForChild("GameClient"))
local PortalUI=require(script.Parent:WaitForChild("PortalUI"))
local ArcadeFeedback=require(script.Parent:WaitForChild("ArcadeFeedback"))
local BattleEffects=require(Shared:WaitForChild("Config"):WaitForChild("BattleEffectsConfig"))
local Assets=require(script.Parent:WaitForChild("UIAssets"))
local RankIcons=require(Shared:WaitForChild("Config"):WaitForChild("RankIconConfig"))
local Rules=require(Shared:WaitForChild("Config"):WaitForChild("Rules"))
local player=Players.LocalPlayer; local playerGui=player:WaitForChild("PlayerGui")
local C,F=UI.colors,UI.theme.Fonts
for _,name in ipairs({"TetrisBattleUI","TetrisBattleBackdrop"}) do local old=playerGui:FindFirstChild(name); if old then old:Destroy() end end
local backdrop=UI.new("ScreenGui","TetrisBattleBackdrop",playerGui,{ResetOnSpawn=false,DisplayOrder=9,ScreenInsets=Enum.ScreenInsets.None})
local art=Artwork.new(backdrop,UI)
local gui=UI.new("ScreenGui","TetrisBattleUI",playerGui,{ResetOnSpawn=false,DisplayOrder=10,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,ClipToDeviceSafeArea=true})
gui:SetAttribute("UIMilestone","Retro synthwave / live gameplay")
local safe=UI.new("Frame","SafeArea",gui,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
local root=UI.new("Frame","ResponsiveCanvas",safe,{BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5)})
local rootScale=UI.new("UIScale","DeviceScale",root,{Scale=1})
local menu=UI.new("CanvasGroup","MainMenu",root,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
local menuScroll=UI.new("ScrollingFrame","MenuScroll",menu,{BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollingDirection=Enum.ScrollingDirection.Y,CanvasSize=UDim2.fromOffset(0,0),Visible=false})
local gamePage=UI.new("CanvasGroup","Gameplay",root,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false})
local client,portal,layout,openSettings,applyLayout,arcade,notify
local currentPage="Menu"; local settingsOpen=false; local alive=true; local connections={}; local pageTween
local lastCountdown=-1; local notifyUntil=0; local searchStarted=0
local function feedback() if client then client.Audio:play("ButtonClick") end end
local function page(which)
	currentPage=which; menu.Visible=which=="Menu"; gamePage.Visible=which=="Game"; art:quiet(which=="Game")
	if pageTween then pageTween:Cancel() end
	local target=which=="Menu" and menu or gamePage; target.GroupTransparency=UI.reducedMotion and 0 or 1
	pageTween=UI.tween(target,{GroupTransparency=0},UI.theme.Motion.Page); gui:SetAttribute("CurrentScreen",which)
	if UIS.GamepadEnabled then GuiService.SelectedObject=which=="Menu" and menu:FindFirstChild("SoloPractice",true) or nil end
end
local menuObjects={}
menuObjects.brand=UI.text("ArcadeBrand",menu,"TETRIS BATTLE",14,C.muted,F.Mono)
menuObjects.settings=UI.button("MenuSettings",menu,"SET",C.line,function() feedback(); openSettings() end)
menuObjects.kicker=UI.text("Edition",menu,"THE BLOCK ARCADE",13,C.orange,F.Mono)
menuObjects.shadow=UI.text("TitleShadow",menu,"TETRIS\nBATTLE",54,C.pink,F.Display)
menuObjects.title=UI.text("Title",menu,"TETRIS\nBATTLE",54,C.text,F.Display)
menuObjects.title.TextStrokeColor3=C.background; menuObjects.title.TextStrokeTransparency=0.1
menuObjects.solo=UI.button("SoloPractice",menu,"SOLO PRACTICE",C.orange,function() feedback(); if client then client:send("Solo") end end)
menuObjects.battle=UI.button("Battle1v1",menu,"RANKED 1v1 BATTLE",C.pink,function() feedback(); if client then client:send("Queue") end end)
menuObjects.solo.FontFace=UI.theme.Face; menuObjects.solo.TextSize=15
menuObjects.battle.FontFace=UI.theme.Face; menuObjects.battle.TextSize=15
menuObjects.nav=UI.new("Frame","ArcadeNavigation",menu,{BackgroundTransparency=1})
local navButtons={}
local destinations={{"CosmeticShop","SHOP","Shop",nil,"shop"},{"CosmeticInventory","INVENTORY","Inventory",nil,"inventory"},{"DailyQuests","QUESTS","Quests",nil,"quests"},{"GlobalLeaderboard","LEADERBOARDS","Leaderboards","GlobalRating","leaderboards"},{"ArcadeFriends","FRIENDS","Friends",nil,"friends"},{"MoreArcade","MORE","Hub",nil,"more"}}
for index,destination in ipairs(destinations) do
	navButtons[index]=UI.button(destination[1],menuObjects.nav,destination[2],C.line,function()
		if not portal then return end; feedback()
		if destination[4] then portal.Leaderboard=destination[4]; portal.BoardData=nil end
		portal:open(destination[3])
	end)
 local icon=UI.icon(navButtons[index],"Images.menu."..destination[5]); icon.Position=UDim2.new(0.5,-18,0,6); icon.Size=UDim2.fromOffset(36,36); navButtons[index].TextSize=10; if icon.Visible then navButtons[index].TextYAlignment=Enum.TextYAlignment.Bottom; navButtons[index].IconPadding.PaddingLeft=UDim.new(0,4); navButtons[index].IconPadding.PaddingBottom=UDim.new(0,6) end
end
menuObjects.status=UI.text("PlayerBalance",menu,"Loading player profile...",15,C.text,F.Mono)
menuObjects.status.Active=true
menuObjects.header=UI.panel("LobbyHeader",menu,C.line)
menuObjects.avatar=UI.new("ImageLabel","PlayerAvatar",menuObjects.header,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(40,40),BackgroundTransparency=1,Image="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=150&h=150"})
menuObjects.username=UI.text("LobbyUsername",menuObjects.header,player.DisplayName,12,C.text,F.Strong); menuObjects.username.Position=UDim2.fromOffset(58,8); menuObjects.username.Size=UDim2.new(1,-62,0,22); menuObjects.username.TextTruncate=Enum.TextTruncate.AtEnd
menuObjects.rank=UI.text("LobbyRank",menuObjects.header,"LOADING",10,C.orange,F.Mono); menuObjects.rank.Position=UDim2.fromOffset(58,32); menuObjects.rank.Size=UDim2.new(1,-96,0,20)
menuObjects.rankAsset=UI.image(menuObjects.header,"LobbyRankBadge",""); menuObjects.rankAsset.Position=UDim2.new(1,-38,0,28); menuObjects.rankAsset.Size=UDim2.fromOffset(28,28)
menuObjects.cash=UI.button("LobbyCash",menu,"CASH / +",C.yellow,function() if portal then portal:open("Cash") end end); UI.icon(menuObjects.cash,"Images.currency.cash")
menuObjects.energy=UI.button("LobbyEnergy",menu,"ENERGY / +",C.cyan,function() if portal then portal:open("Energy") end end); UI.icon(menuObjects.energy,"Images.currency.energy")
menuObjects.mail=UI.button("LobbyMail",menu,"MAIL",C.line,function() if portal then portal:open("Quests") end end); UI.icon(menuObjects.mail,"Images.menu.mail")
UI.icon(menuObjects.settings,"Images.menu.settings")
menuObjects.footer=UI.text("Footer",menu,"FREE PRACTICE. REAL RIVALS.",13,C.muted,F.Mono)
menuObjects.brand.Visible=false; menuObjects.status.Visible=false
local gameObjects={}
gameObjects.back=UI.button("GameBack",gamePage,"LOBBY",C.line,function() feedback(); if client then client:send("Exit") end end)
gameObjects.settings=UI.button("GameSettings",gamePage,"SETTINGS",C.line,function() feedback(); openSettings() end)
gameObjects.heading=UI.text("GameHeading",gamePage,"SOLO PRACTICE",20,C.text,F.Display)
gameObjects.heading.TextXAlignment=Enum.TextXAlignment.Center
gameObjects.banner=UI.text("MatchStatus",gamePage,"",14,C.orange,F.Mono)
gameObjects.banner.TextXAlignment=Enum.TextXAlignment.Center
gameObjects.timer=UI.text("Timer",gamePage,"00:00",28,C.yellow,F.Mono); gameObjects.timer.TextXAlignment=Enum.TextXAlignment.Center
local ownBoard=Bricks.board(gamePage,"LocalBoard",10,20,UI)
local enemyBoard=Bricks.board(gamePage,"OpponentBoard",10,20,UI)
gameObjects.board=ownBoard.Frame; gameObjects.opponent=enemyBoard.Frame
local boardArt={UI.image(gamePage,"PinkBoardFrame",Assets.uri("Images.artwork.board_frame_pink")),UI.image(gamePage,"CyanBoardFrame",Assets.uri("Images.artwork.board_frame_cyan"))}; for _,image in ipairs(boardArt) do image.ZIndex=11 end
local function profileWidget(name)
	local frame=UI.new("Frame",name,gamePage,{BackgroundColor3=C.panel,BackgroundTransparency=0.12,BorderSizePixel=0}); UI.stroke(frame,name=="LocalProfile" and C.pink or C.cyan,0.15,2)
	local avatar=UI.new("ImageLabel","Avatar",frame,{Position=UDim2.fromOffset(0,3),Size=UDim2.fromOffset(28,28),BackgroundTransparency=1})
	local label=UI.text("Username",frame,"",14,C.text,F.Strong); label.Position=UDim2.fromOffset(36,0); label.Size=UDim2.new(1,-36,0,18); label.TextWrapped=false; label.TextTruncate=Enum.TextTruncate.AtEnd
	local rank=UI.text("RankStars",frame,"",13,C.orange,F.Mono); rank.Position=UDim2.fromOffset(36,18); rank.Size=UDim2.new(1,-36,0,18); rank.TextWrapped=false
	local badge=UI.text("RankBadge",frame,"",15,C.orange,F.Display); badge.Position=UDim2.new(1,-28,0,0); badge.Size=UDim2.fromOffset(28,32)
	local icon=UI.new("ImageLabel","RankIcon",badge,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false})
	local bar=UI.new("Frame","RankStarsBar",frame,{Position=UDim2.new(0,36,1,0),Size=UDim2.new(1,-36,0,3),BackgroundColor3=C.line,BorderSizePixel=0}); local fill=UI.new("Frame","Fill",bar,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.orange,BorderSizePixel=0})
	return {Frame=frame,Avatar=avatar,Name=label,Rank=rank,Badge=badge,Icon=icon,Fill=fill}
end
local ownProfile,opponentProfile=profileWidget("LocalProfile"),profileWidget("OpponentProfile")
for _,widget in ipairs({ownProfile,opponentProfile}) do
 widget.Strip=UI.panel("RankStarStrip",gamePage,C.line); widget.Star=UI.image(widget.Strip,"RankStar",Assets.uri("Images.battle.star_empty")); widget.Star.Position=UDim2.fromOffset(4,2); widget.Star.Size=UDim2.fromOffset(24,24)
 widget.StarText=UI.text("StarCount",widget.Strip,"",10,C.yellow,F.Mono); widget.StarText.Position=UDim2.fromOffset(32,2); widget.StarText.Size=UDim2.new(1,-36,0,24)
end
gameObjects.player=ownProfile.Frame; gameObjects.opponentPlayer=opponentProfile.Frame
local function setProfile(widget,data)
	if not data then return end
	widget.Avatar.Image="rbxthumb://type=AvatarHeadShot&id="..data.UserId.."&w=150&h=150"; widget.Name.Text=data.DisplayName or data.Name
	local tier=data.Tier or 1; if not data.Tier then for i,name in ipairs(P.Ranks) do if name==data.Rank then tier=i end end end
	widget.Badge.Text=RankIcons.Fallback[P.Ranks[tier]]; widget.Fill.Size=UDim2.fromScale(P.Stars[tier]>0 and (data.Stars or 0)/P.Stars[tier] or 1,1)
	local asset=Assets.rank(P.Ranks[tier]); widget.Icon.Image=asset; widget.Icon.Visible=asset~=""; if asset~="" then widget.Badge.Text="" end
	widget.Badge.Visible=widget.Frame.AbsoluteSize.X>=180; local reserve=widget.Badge.Visible and 68 or 36; widget.Name.Size=UDim2.new(1,-reserve,0,18); widget.Rank.Size=UDim2.new(1,-reserve,0,18)
	widget.Star.Image=Assets.uri("Images.battle."..((data.Stars or 0)>0 and "star_filled" or "star_empty")); widget.Star.Visible=widget.Star.Image~=""; widget.StarText.Text=(data.Stars or 0).." / "..P.Stars[tier].." STARS"
 widget.Rank.Text=(layout and (layout.portrait or layout.compact) and (data.Rank or "Rookie"):sub(1,3):upper() or data.Rank or "Rookie").." / "..(data.Stars or 0).."*"
end
local holdPanel=UI.panel("HoldPanel",gamePage); gameObjects.hold=holdPanel
local holdLabel=UI.text("HoldTitle",holdPanel,"HOLD",13,C.muted,F.Mono); UI.rect(holdLabel,{8,4,70,22})
local holdPiece=Bricks.board(holdPanel,"HoldPiece",4,2,UI)
local holdEmpty=UI.text("Empty",holdPanel,"EMPTY",13,C.muted,F.Mono); holdEmpty.Size=UDim2.fromScale(1,1); holdEmpty.TextXAlignment=Enum.TextXAlignment.Center
local nextPanel=UI.panel("NextPanel",gamePage); gameObjects.next=nextPanel
local nextLabel=UI.text("NextTitle",nextPanel,"NEXT",13,C.muted,F.Mono); UI.rect(nextLabel,{8,4,70,22})
local nextPieces={}; for index=1,5 do nextPieces[index]=Bricks.board(nextPanel,"NextPiece"..index,4,2,UI) end
local ownStats=UI.panel("LocalStatistics",gamePage); gameObjects.ownStats=ownStats
local scoreLabel=UI.text("ScoreLabel",ownStats,"SCORE",13,C.muted,F.Mono)
local score=UI.text("Score",ownStats,"0",28,C.text,F.Mono)
local ownDetail=UI.text("LinesLevel",ownStats,"LINES 0 / LV 1",14,C.muted,F.Mono)
local incoming=UI.text("IncomingKO",ownStats,"IN 0 / KO 0",14,C.pink,F.Mono)
local compactOpponent=UI.text("CompactOpponent",ownStats,"",13,C.cyan,F.Mono)
local enemyStats=UI.panel("OpponentStatistics",gamePage); gameObjects.enemyStats=enemyStats
local enemyScore=UI.text("OpponentScore",enemyStats,"0",22,C.text,F.Mono)
local enemyDetail=UI.text("OpponentLines",enemyStats,"",14,C.muted,F.Mono)
local enemyIncoming=UI.text("OpponentIncoming",enemyStats,"",14,C.pink,F.Mono)
local portraitValues={}
for index,label in ipairs({"SCORE","LINES","LEVEL","IN / KO"}) do
	local caption=UI.text("MetricLabel"..index,ownStats,label,13,C.muted,F.Mono)
	local value=UI.text("MetricValue"..index,ownStats,"0",22,C.text,F.Mono)
	value.TextScaled=true; UI.new("UITextSizeConstraint","ReadableNumbers",value,{MinTextSize=16,MaxTextSize=22})
	portraitValues[index]={Label=caption,Value=value}
end
local enemyHoldPanel=UI.panel("OpponentHoldPanel",gamePage,C.cyan); gameObjects.enemyHold=enemyHoldPanel
local enemyHoldLabel=UI.text("Title",enemyHoldPanel,"HOLD",13,C.cyan,F.Mono); UI.rect(enemyHoldLabel,{8,4,80,22}); local enemyHoldPiece=Bricks.board(enemyHoldPanel,"OpponentHoldPiece",4,2,UI)
local enemyNextPanel=UI.panel("OpponentNextPanel",gamePage,C.cyan); gameObjects.enemyNext=enemyNextPanel
local enemyNextLabel=UI.text("Title",enemyNextPanel,"NEXT",13,C.cyan,F.Mono); UI.rect(enemyNextLabel,{8,4,80,22}); local enemyNextPieces={}; for i=1,5 do enemyNextPieces[i]=Bricks.board(enemyNextPanel,"OpponentNext"..i,4,2,UI) end
ownBoard.Frame:FindFirstChildOfClass("UIStroke").Color=C.pink; ownBoard.Frame:FindFirstChildOfClass("UIStroke").Thickness=3
enemyBoard.Frame:FindFirstChildOfClass("UIStroke").Color=C.cyan; enemyBoard.Frame:FindFirstChildOfClass("UIStroke").Thickness=3
local ownMeter=UI.new("Frame","LocalGarbageMeter",gamePage,{BackgroundColor3=C.pink,BorderSizePixel=0})
local enemyMeter=UI.new("Frame","OpponentGarbageMeter",gamePage,{BackgroundColor3=C.pink,BorderSizePixel=0})
local emoteButton=UI.button("Emotes",gamePage,"EMOTE",C.line,function() if portal then portal:open("Emotes") end end)
local chatButton=UI.button("NativeChat",gamePage,"CHAT",C.line,function()
	local ok=pcall(function() local bar=game:GetService("TextChatService").ChatInputBarConfiguration; assert(bar.Enabled and bar.TextBox); bar.TextBox:CaptureFocus() end)
	if not ok then notify("Use Roblox's native chat button. Chat availability follows your account permissions.") end
end)
local controls=UI.new("Frame","ControlTray",gamePage,{BackgroundTransparency=1}); gameObjects.controls=controls
local controlSpecs={{"Left","LEFT"},{"Right","RIGHT"},{"SoftDrop","DOWN"},{"CW","CW"},{"CCW","CCW"},{"Hold","HOLD"},{"HardDrop","DROP"}}
local controlButtons={}
for _,spec in ipairs(controlSpecs) do controlButtons[spec[1]]=UI.button(spec[1],controls,spec[2],spec[1]=="HardDrop" and C.orange or C.line) end
local toast=UI.text("Notification",root,"",16,C.yellow,F.Strong); toast.ZIndex=50; toast.BackgroundColor3=C.panel; toast.BackgroundTransparency=0
toast.AnchorPoint=Vector2.new(0.5,0); toast.Position=UDim2.new(0.5,0,0,58); toast.Size=UDim2.new(1,-32,0,38); toast.Visible=false; toast.TextXAlignment=Enum.TextXAlignment.Center
notify=function(text) toast.Text=tostring(text); toast.Visible=true; notifyUntil=os.clock()+3 end
local overlay=UI.new("TextButton","SettingsOverlay",root,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,BackgroundTransparency=0.1,Text="",Visible=false,ZIndex=20,Selectable=false,AutoButtonColor=false})
local modal=UI.panel("SettingsModal",overlay,C.line); modal.ZIndex=21
UI.focusGroup(modal)
local title=UI.text("SettingsTitle",modal,"SETTINGS",20,C.orange,F.Display); title.ZIndex=22; UI.rect(title,{20,16,260,36})
local note=UI.text("PauseNote",modal,"Solo pauses here. Online battles keep running.",15,C.muted); note.ZIndex=22
local function closeSettings()
	settingsOpen=false; overlay.Visible=false; UI.ActiveModal=portal and portal.Overlay.Visible and portal.Overlay or nil; gui:SetAttribute("SettingsOpen",false)
	if client then if client.Mode=="Solo" then client:send("Pause",false) end; client:block(false) end
	if UIS.GamepadEnabled then GuiService.SelectedObject=currentPage=="Menu" and menuObjects.solo or nil end
end
openSettings=function()
	settingsOpen=true; overlay.Visible=true; UI.ActiveModal=overlay; gui:SetAttribute("SettingsOpen",true)
	if client then client:block(true); if client.Mode=="Solo" then client:send("Pause",true) end end
	if UIS.GamepadEnabled then GuiService.SelectedObject=modal:FindFirstChild("Resume",true) end
end
local soundButton=UI.button("SoundToggle",modal,"SOUND / ON",C.line,function()
	if client then local enabled=client.Audio.Muted; client.Audio:settings(client.Audio.Master,client.Audio.MusicVolume,client.Audio.SFXVolume,not enabled); client:send("Settings",{Sound=enabled}) end
end)
local motionButton=UI.button("MotionToggle",modal,"REDUCED MOTION / OFF",C.line,function()
	UI.reducedMotion=not UI.reducedMotion
	if UI.reducedMotion then if pageTween then pageTween:Cancel() end; menu.GroupTransparency=0; gamePage.GroupTransparency=0 end
	if client then client:send("Settings",{ReducedMotion=UI.reducedMotion}) end
end)
local audioButton=UI.button("AudioSettings",modal,"MUSIC / SFX VOLUMES",C.line,function() if portal then portal:open("Audio") end end)
local resumeButton=UI.button("Resume",modal,"RETURN",C.orange,function() feedback(); closeSettings() end)
local restartButton=UI.button("Restart",modal,"RESTART SOLO",C.line,function() if client and client.Mode=="Solo" then client:send("Restart"); closeSettings() end end)
local exitButton=UI.button("Exit",modal,"EXIT / FORFEIT",C.pink,function() if client then client:send("Exit") end; closeSettings() end)
local preferencesButton=UI.button("ControlPreferences",modal,"CONTROLS / CLASSIC HUD",C.line,function() if portal then portal:open("Controls") end end)
local socialButton=UI.button("BattleSocial",modal,"EMOTES / NATIVE CHAT",C.line,function() if portal then portal:open("Emotes") end end)
local modalButtons={soundButton,motionButton,audioButton,resumeButton,restartButton,exitButton,preferencesButton,socialButton}
for _,button in ipairs(modalButtons) do button.ZIndex=22 end
local settingsScroll=UI.new("ScrollingFrame","SettingsOptions",modal,{BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=22,CanvasSize=UDim2.fromOffset(0,0)})
for _,button in ipairs(modalButtons) do button.Parent=settingsScroll end
game:GetService("ContextActionService"):BindActionAtPriority("RetroSettingsClose",function(_,state)
	if settingsOpen and state==Enum.UserInputState.Begin then closeSettings(); return Enum.ContextActionResult.Sink end
	return Enum.ContextActionResult.Pass
end,false,3100,Enum.KeyCode.Escape,Enum.KeyCode.ButtonStart,Enum.KeyCode.ButtonB)
local function meter(node,rectangle,pending)
	local fraction=math.clamp((pending or 0)/BattleEffects.Garbage.MeterMax,0,1); node.Visible=fraction>0
	local danger=1; for i,threshold in ipairs(BattleEffects.Garbage.Thresholds) do if (pending or 0)>=threshold then danger=i end end
	node:SetAttribute("PendingLines",pending or 0); node:SetAttribute("Danger",danger); node.BackgroundColor3=Color3.fromRGB(table.unpack(BattleEffects.Garbage.Colors[danger]))
	node.BackgroundTransparency=danger==4 and not UI.reducedMotion and (math.sin(os.clock()*math.pi*2*BattleEffects.Garbage.FlashHz)+1)*0.22 or 0
	UI.rect(node,{rectangle[1]-8,rectangle[2]+rectangle[4]*(1-fraction),BattleEffects.Garbage.Width,rectangle[4]*fraction})
end
applyLayout=function()
	local size=safe.AbsoluteSize; if size.X<1 or size.Y<1 then return end
	local battle=client and (client.Mode=="Ranked" or client.Mode=="Challenge") or false
	layout=Layout.resolve(size.X,size.Y,battle); root.Size=UDim2.fromOffset(layout.width,layout.height); rootScale.Scale=layout.scale*((not UIS.TouchEnabled and layout.width>=1100 and client and client.Profile and client.Profile.Settings.UIScale) or 1)
	gui:SetAttribute("LayoutMode",layout.portrait and "Portrait" or layout.compact and "Landscape" or "DesktopTablet")
	for name,rectangle in pairs(layout.menu) do if type(rectangle)=="table" and menuObjects[name] then UI.rect(menuObjects[name],rectangle) end end
	local scrollMenu=layout.portrait and layout.height<760 or layout.compact and layout.width<720
	menuScroll.Visible=scrollMenu; UI.rect(menuScroll,{0,130,layout.width,layout.height-130}); menuScroll.CanvasSize=UDim2.fromOffset(0,layout.menu.footer[2]+24-130)
	for _,name in ipairs({"kicker","title","shadow","solo","battle","nav","status","footer"}) do menuObjects[name].Parent=scrollMenu and menuScroll or menu end
	if scrollMenu then for _,name in ipairs({"kicker","title","solo","battle","nav","status","footer"}) do local r=layout.menu[name]; UI.rect(menuObjects[name],{r[1],r[2]-130,r[3],r[4]}) end end
	local t=layout.menu.title; UI.rect(menuObjects.shadow,{t[1]+2,t[2]+3-(scrollMenu and 130 or 0),t[3],t[4]}); menuObjects.title.TextSize=layout.menu.titleSize; menuObjects.shadow.TextSize=layout.menu.titleSize
	local nr=layout.menu.nav; local columns=layout.menu.navColumns; local bw=(nr[3]-(columns-1)*8)/columns
	menuObjects.status.TextXAlignment=layout.portrait and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
	menuObjects.status.BackgroundColor3=C.background; menuObjects.status.BackgroundTransparency=not layout.portrait and layout.height<660 and 0.08 or 1
	for index,button in ipairs(navButtons) do UI.rect(button,{(index-1)%columns*(bw+8),math.floor((index-1)/columns)*80,bw,72}) end
	for name,rectangle in pairs(layout.game) do if type(rectangle)=="table" and gameObjects[name] then UI.rect(gameObjects[name],rectangle) end end
	gameObjects.heading.TextSize=layout.compact and 14 or layout.portrait and 15 or 20
	for _,widget in ipairs({ownProfile,opponentProfile}) do
		local narrow=layout.compact or layout.portrait and widget==opponentProfile
		UI.rect(widget.Avatar,{0,3,narrow and 16 or 28,narrow and 16 or 28})
		widget.Name.Position=UDim2.fromOffset(narrow and 22 or 36,0); widget.Name.Size=UDim2.new(1,narrow and -22 or -36,0,18)
		widget.Rank.Position=UDim2.fromOffset(narrow and 0 or 36,18); widget.Rank.Size=UDim2.new(1,narrow and 0 or -36,0,18)
	end
	for i,image in ipairs(boardArt) do local r=i==1 and layout.game.board or layout.game.opponent; UI.rect(image,{r[1]-6,r[2]-6,r[3]+12,r[4]+12}); image.Visible=image.Image~="" and (i==1 or battle) end
 if arcade then arcade:layout(layout) end
	UI.rect(emoteButton,{layout.width-180,layout.height-112,76,44}); UI.rect(chatButton,{layout.width-96,layout.height-112,76,44}); emoteButton.Visible=battle and not layout.portrait and not layout.compact; chatButton.Visible=emoteButton.Visible
	gameObjects.timer.TextSize=not layout.compact and not layout.portrait and 40 or 22
	local extra=battle and not layout.portrait and (not layout.compact or layout.width>=760); enemyHoldPanel.Visible=extra; enemyNextPanel.Visible=extra
	if extra then local eh=layout.game.enemyHold; UI.rect(enemyHoldPiece.Frame,{10,30,eh[3]-20,(eh[3]-20)/2}); local en=layout.game.enemyNext; local slot=(en[4]-30)/5; for i,v in ipairs(enemyNextPieces) do local pw=math.min(en[3]-20,(slot-4)*2); UI.rect(v.Frame,{(en[3]-pw)/2,28+(i-1)*slot,pw,pw/2}) end end
	for i,widget in ipairs({ownProfile,opponentProfile}) do widget.Badge.Visible=widget.Frame.Size.X.Offset>=180; local r=i==1 and layout.game.board or layout.game.opponent; UI.rect(widget.Strip,{r[1],r[2]+r[4]+8,r[3],28}); widget.Strip.Visible=battle and not layout.portrait and not layout.compact end
	local hr=layout.game.hold; UI.rect(holdPiece.Frame,{10,30,hr[3]-20,(hr[3]-20)/2})
	local next=layout.game.next; local slot=(next[4]-30)/5
	for index,view in ipairs(nextPieces) do local pw=math.min(next[3]-20,(slot-4)*2); UI.rect(view.Frame,{(next[3]-pw)/2,28+(index-1)*slot,pw,pw/2}) end
	local ow=layout.game.ownStats[3]; local oh=layout.game.ownStats[4]
	for _,node in ipairs({scoreLabel,score,ownDetail,incoming,compactOpponent}) do node.Visible=not layout.portrait end
	for index,metric in ipairs(portraitValues) do metric.Label.Visible=layout.portrait; metric.Value.Visible=layout.portrait; UI.rect(metric.Label,{12+(index-1)*(ow-24)/4,4,(ow-24)/4-4,20}); UI.rect(metric.Value,{12+(index-1)*(ow-24)/4,26,(ow-24)/4-4,30}) end
	UI.rect(scoreLabel,{12,8,ow-24,20}); UI.rect(score,{12,30,ow-24,34}); UI.rect(ownDetail,{12,72,ow-24,36}); UI.rect(incoming,{12,116,ow-24,32})
	if layout.compact then
		score.TextSize=22; UI.rect(score,{10,22,ow-20,26}); UI.rect(ownDetail,{10,50,ow-20,24}); UI.rect(incoming,{10,74,ow-20,20}); UI.rect(compactOpponent,{10,96,ow-20,32})
		if oh<112 then scoreLabel.Visible=false; score.Visible=false; incoming.Visible=false; UI.rect(ownDetail,{8,6,ow-16,44}); UI.rect(compactOpponent,{8,52,ow-16,30}) end
	else score.TextSize=28 end
	compactOpponent.Visible=layout.compact and battle
	local ew=layout.game.enemyStats[3]
	UI.rect(enemyScore,{10,8,ew-20,28}); UI.rect(enemyDetail,{10,40,ew-20,30}); UI.rect(enemyIncoming,{10,76,ew-20,38})
	enemyScore.TextSize=layout.portrait and 16 or 22
	if layout.portrait then enemyScore.TextSize=16; UI.rect(enemyScore,{4,2,ew-8,22}); UI.rect(enemyDetail,{4,26,ew-8,22}); UI.rect(enemyIncoming,{4,50,ew-8,34}) end
	if layout.portrait and layout.game.enemyStats[4]<80 then UI.rect(enemyScore,{4,2,ew-8,18}); UI.rect(enemyDetail,{4,21,ew-8,18}); UI.rect(enemyIncoming,{4,40,ew-8,18}); enemyIncoming.TextSize=13 else enemyIncoming.TextSize=14 end
	gameObjects.opponent.Visible=battle; opponentProfile.Frame.Visible=battle; enemyStats.Visible=battle and layout.game.enemyStats[4]>0
	local cr=layout.game.controls; local cc=layout.game.controlColumns; local gap=8; local bh=cc==4 and 50 or 44; local cw=(cr[3]-(cc-1)*gap)/cc
	for index,spec in ipairs(controlSpecs) do local span=cc==4 and index==7 and 2 or 1; UI.rect(controlButtons[spec[1]],{(index-1)%cc*(cw+gap),math.floor((index-1)/cc)*(bh+gap),cw*span+gap*(span-1),bh}) end
	local mw=math.min(480,layout.width-32); local mh=math.min(480,layout.height-24); UI.rect(modal,{(layout.width-mw)/2,(layout.height-mh)/2,mw,mh})
	local short=mh<420; local start=short and 60 or 72; local spacing=short and 52 or 56
	UI.rect(settingsScroll,{20,start,mw-40,short and mh-start-12 or 332}); settingsScroll.CanvasSize=UDim2.fromOffset(0,(#modalButtons-1)*spacing+48)
	for index,button in ipairs(modalButtons) do UI.rect(button,{0,(index-1)*spacing,mw-40,44}) end
	note.Visible=not short; UI.rect(note,{20,414,mw-40,46}); UI.enabled(restartButton,client and client.Mode=="Solo" or false)
	if not gameObjects.timer:FindFirstChild("AssetIcon") then UI.icon(gameObjects.timer,"Images.quests.play_time") end
 local state=client and client.State; meter(ownMeter,layout.game.board,state and state.Own.pending); meter(enemyMeter,layout.game.opponent,state and state.Opponent and state.Opponent.pending)
	art.Battle=battle; art.Classic=client and client.Profile and client.Profile.Settings.ClassicHUD; art:quiet(currentPage=="Game" or art.Classic); art:layout(layout.width,layout.height,layout.portrait)
	if portal then portal:layout(layout.width,layout.height) end
end
table.insert(connections,safe:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout))
client=GameClient.new({
	Pause=function(force) if not settingsOpen or not force then openSettings() end end,
	Lobby=function() if arcade then arcade:reset(nil) end; if portal then portal:close(true) end; closeSettings(); page("Menu"); applyLayout() end,
	Message=notify,
	Profile=function(data)
		UI.reducedMotion=data.Settings.ReducedMotion; local a=client.Audio; a:settings(data.Settings.Master or a.Master,data.Settings.MusicVolume or a.MusicVolume,data.Settings.SFXVolume or a.SFXVolume,not data.Settings.Sound); client.Input:preferences(data.Settings); art:quiet(data.Settings.ClassicHUD or currentPage=="Game")
		if client.SettingsScale~=data.Settings.UIScale then client.SettingsScale=data.Settings.UIScale; applyLayout() end
		local stars=data.Rank.Tier==7 and (data.Rank.Rating.." RATING") or (data.Rank.Stars.."/"..P.Stars[data.Rank.Tier].." STARS")
		menuObjects.rank.Text=P.Ranks[data.Rank.Tier].." / "..data.Rank.Stars.."*"; menuObjects.rankAsset.Image=Assets.rank(P.Ranks[data.Rank.Tier]); menuObjects.rankAsset.Visible=menuObjects.rankAsset.Image~=""; menuObjects.cash.Text=tostring(data.Cash).." +"
  local energy=data.DebugPrivileges and data.DebugPrivileges.InfiniteEnergy and "TEST" or data.Energy.Current.."/"..data.Economy.EnergyCap
		menuObjects.energy.Text=energy.." +"
  menuObjects.status.Text=P.Ranks[data.Rank.Tier]:upper().." / "..stars.."\nCASH "..data.Cash.."     ENERGY "..energy
		soundButton.Text="SOUND / "..(a.Muted and "OFF" or "ON"); motionButton.Text="REDUCED MOTION / "..(UI.reducedMotion and "ON" or "OFF")
		setProfile(ownProfile,{UserId=player.UserId,DisplayName=player.DisplayName,Rank=P.Ranks[data.Rank.Tier],Tier=data.Rank.Tier,Stars=data.Rank.Stars})
		if portal then portal:render(true) end
	end,
	Searching=function(data) searchStarted=data.StartedAt; portal:open("Searching") end,
	Found=function(data) if arcade then arcade:reset(data.MatchId) end; client.LastBattleEvent=0; portal:close(true); lastCountdown=-1; notify("OPPONENT FOUND / "..data.Profiles[1].DisplayName.." vs "..data.Profiles[2].DisplayName); applyLayout() end,
	State=function(data)
		arcade:state(data)
		if currentPage~="Game" then page("Game"); applyLayout() end
		gameObjects.heading.Text=data.Mode=="Solo" and "SOLO PRACTICE" or data.Mode=="Ranked" and "RANKED 1v1" or "FRIEND DUEL"
		local ownLoadout=client.Profile and client.Profile.Equipped; local otherLoadout
		if data.Profiles then for _,profile in ipairs(data.Profiles) do if profile.UserId==player.UserId then setProfile(ownProfile,profile) else setProfile(opponentProfile,profile); otherLoadout=profile.Equipped end end end
		Bricks.draw(ownBoard,data.Own,ownLoadout,UI.reducedMotion,os.clock()); Bricks.draw(enemyBoard,data.Opponent,otherLoadout,UI.reducedMotion,os.clock())
		Bricks.piece(holdPiece,data.Own.hold,ownLoadout,UI.reducedMotion); holdPiece.Frame.Visible=type(data.Own.hold)=="string"; holdEmpty.Visible=not holdPiece.Frame.Visible
		for index,view in ipairs(nextPieces) do Bricks.piece(view,data.Own.next[index],ownLoadout,UI.reducedMotion) end
		score.Text=tostring(data.Own.score); ownDetail.Text="LINES "..data.Own.lines.." / LV "..data.Own.level; incoming.Text="SENT "..data.Own.stats.Sent.." / IN "..data.Own.pending.."\nK.O. "..data.Own.stats.KOs
		if layout.compact and layout.game.ownStats[4]<112 then ownDetail.Text="YOU "..data.Own.score.."\nL "..data.Own.lines.." / LV "..data.Own.level.."\nIN "..data.Own.pending.." / KO "..data.Own.stats.KOs end
		for index,value in ipairs({data.Own.score,data.Own.lines,data.Own.level,data.Own.pending.." / "..data.Own.stats.KOs}) do portraitValues[index].Value.Text=tostring(value) end
		if data.Opponent then Bricks.piece(enemyHoldPiece,data.Opponent.hold,otherLoadout,UI.reducedMotion); for i,v in ipairs(enemyNextPieces) do Bricks.piece(v,data.Opponent.next[i],otherLoadout,UI.reducedMotion) end end
		if data.Opponent then enemyScore.Text=tostring(data.Opponent.score); enemyDetail.Text=data.Opponent.lines.." LINES"; enemyIncoming.Text="SENT "..data.Opponent.stats.Sent.." / IN "..data.Opponent.pending.."\nK.O. "..data.Opponent.stats.KOs; compactOpponent.Text="VS "..data.Opponent.score.." / "..data.Opponent.lines.."L\nIN "..data.Opponent.pending.." / KO "..data.Opponent.stats.KOs end
		if data.Opponent and layout.compact and layout.width>=760 then ownDetail.Text="SENT "..data.Own.stats.Sent.."\nK.O. "..data.Own.stats.KOs; ownDetail.TextSize=10; compactOpponent.Visible=false; enemyScore.Text="SENT "..data.Opponent.stats.Sent; enemyScore.TextSize=10; enemyDetail.Text="K.O. "..data.Opponent.stats.KOs; enemyDetail.TextSize=10; enemyIncoming.Visible=false else ownDetail.TextSize=14; enemyDetail.TextSize=14; enemyIncoming.Visible=true end
  if data.Opponent and layout.portrait and layout.game.enemyStats[4]<80 then enemyIncoming.Text="IN"..data.Opponent.pending.." KO"..data.Opponent.stats.KOs end
		if data.Mode~="Solo" and not layout.portrait and not layout.compact then scoreLabel.Text="SENT"; score.Text=tostring(data.Own.stats.Sent); ownDetail.Text="K.O.\n"..data.Own.stats.KOs; ownDetail.TextColor3=C.pink; incoming.Text="INCOMING\n"..data.Own.pending; enemyScore.Text="SENT "..data.Opponent.stats.Sent; enemyDetail.Text="K.O. "..data.Opponent.stats.KOs; enemyDetail.TextColor3=C.pink; enemyIncoming.Text="INCOMING\n"..data.Opponent.pending else scoreLabel.Text="SCORE"; ownDetail.TextColor3=C.muted end
		if data.Mode=="Solo" and not layout.portrait and not layout.compact then ownDetail.Text="LINES "..data.Own.lines.."\nLEVEL "..data.Own.level; ownDetail.TextSize=12; incoming.Visible=false end
		if data.Mode=="Solo" then score.TextSize=math.min(layout.compact and 22 or 28,math.max(10,math.floor((layout.game.ownStats[3]-24)/math.max(1,#score.Text)))) end
		local seconds=data.Remaining or data.Own.elapsed; gameObjects.timer.Text=string.format("%02d:%02d",math.floor(seconds/60),math.floor(seconds%60)); gameObjects.timer.TextColor3=data.Remaining and data.Remaining<=30 and C.pink or C.yellow
		gameObjects.banner.Text=data.Countdown>0 and "READY / "..data.Countdown or not data.Own.alive and (data.RespawnAt and "K.O. / RECOVERING" or "TOP OUT / RESTART OR EXIT") or data.Own.paused and "PAUSED" or data.Remaining and data.Remaining<=10 and "FINAL "..math.ceil(data.Remaining).." SECONDS" or data.Remaining and data.Remaining<=30 and "30 SECOND WARNING" or data.Mode~="Solo" and "ROUND "..(data.Round or 1) or "PRACTICE / NO ENERGY COST"
		lastCountdown=data.Countdown
		meter(ownMeter,layout.game.board,data.Own.pending); meter(enemyMeter,layout.game.opponent,data.Opponent and data.Opponent.pending)
	end,
	Event=function(event)
		if arcade then arcade:event(event) end
		if event.name=="HardDrop" then local loadout=client.Profile and client.Profile.Equipped; Effects.drop(ownBoard.Frame,loadout and loadout.DropEffect or "Default",UI.reducedMotion,{X=math.clamp(((event.data.x or 4)+1)/10,0,1),Y=math.clamp(((event.data.y or 18)+1)/20,0,1)}) end
	end,
	BattleEvent=function(event) arcade:battle(event,player.UserId) end,
	Result=function(data) arcade:reset(nil); closeSettings(); portal.ResultData=data; portal:open("Result") end,
	CosmeticResult=function(data) if portal then portal:render(true) end; if not data.Success then notify(data.Message or "Cosmetic operation failed; try again.") end end,
 Leaderboard=function(data) if portal then portal.BoardData=data; portal:render(true) end end,
	Challenge=function(data) portal.Challenger=data; portal:open("ChallengeInvite") end,
})
portal=PortalUI.new(root,UI,client,function()
	if settingsOpen then UI.ActiveModal=overlay; client:block(true); if UIS.GamepadEnabled then GuiService.SelectedObject=resumeButton end
	elseif UIS.GamepadEnabled then GuiService.SelectedObject=currentPage=="Menu" and menuObjects.solo or nil end
end)
arcade=ArcadeFeedback.new(gamePage,UI,client.Audio,ownBoard,enemyBoard); arcade:layout(layout or Layout.resolve(1366,768,false)); arcade:meters(ownMeter,enemyMeter)
UI.icon(emoteButton,"Images.menu.emoji"); UI.icon(chatButton,"Images.menu.chat"); UI.icon(gameObjects.settings,"Images.menu.settings"); UI.icon(audioButton,"Images.menu.audio")
UI.onHover=function() client.Audio:play("ButtonHover") end
for action,button in pairs(controlButtons) do
	client.Input:button(button,action)
	table.insert(connections,button.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then UI.tween(button,{BackgroundColor3=C.raised},0.08); task.delay(0.15,function() if button.Parent then UI.tween(button,{BackgroundColor3=C.panel},0.12) end end) end
	end))
end
table.insert(connections,RunService.RenderStepped:Connect(function(dt)
	if arcade and currentPage=="Game" and client.Mode~="Result" then
		arcade:tick(dt,workspace:GetServerTimeNow()); local state=client.State
		if state then meter(ownMeter,layout.game.board,state.Own.pending); meter(enemyMeter,layout.game.opponent,state.Opponent and state.Opponent.pending); local now=workspace:GetServerTimeNow(); local remaining=state.EndAt and math.max(0,state.EndAt-math.max(now,state.StartAt or now)); if remaining then gameObjects.timer.Text=string.format("%02d:%02d",math.floor(remaining/60),math.floor(remaining%60)) end end
	end
	if portal.ResultSequence and portal.Overlay.Visible then portal.ResultSequence:tick(dt) end
	if toast.Visible and os.clock()>notifyUntil then toast.Visible=false end
	if portal.Overlay.Visible then
  portal:tick(dt)
		if portal.Sample then portal.Sample:tick(dt) end
		if portal.Page=="Searching" and portal.SearchLabel then portal.SearchLabel.Text="SEARCHING"..string.rep(".",math.floor(os.clock()*2)%4).." / "..math.max(0,math.floor(workspace:GetServerTimeNow()-searchStarted)).."s" end
	end
end))
gui.Destroying:Connect(function()
	alive=false; if pageTween then pageTween:Cancel() end
	for _,connection in ipairs(connections) do connection:Disconnect() end
	arcade:destroy(); portal:destroy(); client:destroy(); art:destroy(); backdrop:Destroy(); UI.onHover=nil; game:GetService("ContextActionService"):UnbindAction("RetroSettingsClose")
end)
applyLayout(); task.defer(function() if alive then page("Menu"); applyLayout() end end)
print("[Tetris Battle] Retro synthwave client ready.")

return {gui=gui,menu=menu,portal=portal,root=root,scale=rootScale,safe=safe,layout=applyLayout,own=ownBoard,enemy=enemyBoard,arcade=arcade,client=client,menuObjects=menuObjects,nav=navButtons}
end)()
for _,fn in ipairs(deferred) do fn() end
local d=P.refresh(P.default(1791590400),1791590400,C)
d.Debug=true; d.Energy.Next=0; d.DebugPrivileges={FreeCosmetics=true,InfiniteEnergy=true,FreePurchases=true}; d.Economy={LoginCash=C.LoginCash,LoginEnergy=C.LoginEnergy,SeasonDays=C.SeasonDays,EnergyCap=C.EnergyCap,BonusCap=C.BonusEnergyCap,EnergyInterval=C.EnergyInterval,RankedCost=C.RankedCost,SocialEnergy=C.SocialEnergy,SocialLimit=C.SocialDailyLimit,SocialMinSeconds=C.SocialMinSeconds}
Network.OnClientEvent:fire("Profile",d); Network.OnClientEvent:fire("Lobby",{})
assert(app.gui:GetAttribute("CurrentScreen")=="Menu")
app.menu:FindFirstChild("SoloPractice").Activated:fire(); assert(requests[#requests].Kind=="Solo")
local state={Mode="Solo",Own=E.pack(E.new(42,R)),Countdown=0}
Network.OnClientEvent:fire("State",state); assert(app.gui:GetAttribute("CurrentScreen")=="Game")
print("PASS client boot, profile, real Solo request and engine-state rendering")
for _,size in ipairs({{390,780},{844,326},{1366,768}}) do
	app.safe.AbsoluteSize=Vector2.new(size[1],size[2]); app.layout()
	assert(app.root.Size.X.Offset*app.scale.Scale<=size[1])
end
print("PASS client layout recalculation across portrait, landscape and desktop")
for _,page in ipairs({"Hub","Profile","Shop","Inventory","Quests","Login","Energy","Friends","Audio"}) do app.portal:open(page); assert(app.portal.Overlay.Visible); app.portal:close() end
print("PASS data-driven lobby screens render without runtime errors")
Network.OnClientEvent:fire("Searching",{StartedAt=1791590400}); assert(app.portal.Page=="Searching")
local before=#requests; app.portal:close(); assert(requests[#requests].Kind=="Cancel")
Network.OnClientEvent:fire("Found",{Ranked=true,Profiles={{UserId=123,DisplayName="Test Player"},{UserId=321,DisplayName="Opponent"}}})
assert(not app.portal.Overlay.Visible)
state.Mode="Ranked"; state.Round=1; state.Opponent=E.pack(E.new(99,R)); state.Profiles={{UserId=123,DisplayName="Test Player",Rank="Rookie",Stars=0},{UserId=321,DisplayName="Opponent",Rank="Rookie",Stars=0}}
state.Own=E.pack(E.new(42,R)); state.Remaining=120
Network.OnClientEvent:fire("State",state)
Network.OnClientEvent:fire("Result",{Outcome="Win",Reason="KO",Own=E.pack(E.new(42,R)),Opponent=E.pack(E.new(99,R)),Profiles=state.Profiles,Ranked=true,Rewards=true,Cash=50,BeforeRank={Tier=1,Stars=0},AfterRank={Tier=1,Stars=1,Rating=1012}})
assert(app.portal.Page=="Result")
app.portal:close(); assert(not app.portal.Client.Input.Enabled)
print("PASS search cancellation, real opponent rendering and results screen")
local sizes={{320,568},{360,640},{390,780},{430,932},{844,326},{1024,768},{768,1024},{1366,768},{1920,1080}}
local function bounds(r,w,h,name)
	assert(r[1]>=0 and r[2]>=0 and r[3]>0 and r[4]>0,name.." has invalid geometry")
	assert(r[1]+r[3]<=w+0.01 and r[2]+r[4]<=h+0.01,name.." exceeds usable viewport")
end
local function overlap(a,b)
	return a[1]<b[1]+b[3] and b[1]<a[1]+a[3] and a[2]<b[2]+b[4] and b[2]<a[2]+a[4]
end
for _,size in ipairs(sizes) do for _,battle in ipairs({false,true}) do
	local l=modules.NeonLayout.resolve(size[1],size[2],battle); local g=l.game
	for _,name in ipairs({"board","hold","next","ownStats","controls","player","timer","settings","back"}) do bounds(g[name],l.width,l.height,name) end
	assert(g.board[4]==g.board[3]*2,"10x20 board must preserve square cells")
	for _,name in ipairs({"hold","next","ownStats","controls"}) do assert(not overlap(g.board,g[name]),"Local board overlaps "..name) end
	if battle then bounds(g.opponent,l.width,l.height,"opponent"); assert(g.opponent[4]==g.opponent[3]*2); assert(not overlap(g.board,g.opponent)); assert(not overlap(g.opponent,g.controls)) end
	local cols=g.controlColumns; assert((g.controls[3]-(cols-1)*8)/cols>=44,"Touch targets became too narrow")
end end
print("PASS nine device sizes preserve board aspect, bounds, separation and 44px control targets")
for _,size in ipairs(sizes) do
	app.safe.AbsoluteSize=Vector2.new(size[1],size[2]); app.layout()
	local nextPanel=app.root:FindFirstChild("NextPanel",true); local previous=0
	for index=1,5 do local piece=nextPanel:FindFirstChild("NextPiece"..index); assert(piece.Size.X.Offset>=20 and piece.Size.Y.Offset>=10,"Next piece became illegible"); assert(piece.Position.Y.Offset>=previous); previous=piece.Position.Y.Offset+piece.Size.Y.Offset; assert(previous<=nextPanel.Size.Y.Offset) end
	local settings=app.root:FindFirstChild("SettingsModal",true); assert(settings:FindFirstChild("Resume",true)); assert(settings:FindFirstChild("AudioSettings",true)); assert(settings:FindFirstChild("Restart",true))
end
print("PASS five next pieces and all settings actions remain reachable during resize")
local UI=modules.NeonUI; local Bricks=modules.BrickRenderer; local Preview=modules.BrickPreviewRenderer
local host=UI.new("Frame","TestPreviews",app.root,{ZIndex=39}); local real=Bricks.board(host,"MatchRendering",4,2,UI)
for _,item in ipairs(Catalog.list("BrickSkins")) do
	assert(Bricks.Styles.Skins[item.Id],"Missing skin "..item.Id)
	Bricks.piece(real,"T",{BrickSkin=item.Id,GhostEffect="Default"},false)
	local thumbnail=Preview.thumbnail(host,UI,item,d.Equipped)
	for y=1,2 do for x=1,4 do local a,b=real.Tiles[y][x],thumbnail.Tiles[y][x]
		assert(a.Frame:GetAttribute("SkinId")==b.Frame:GetAttribute("SkinId")); assert(a.Face.Visible==b.Face.Visible)
		if a.Face.Visible then assert(a.Face.BackgroundColor3.R==b.Face.BackgroundColor3.R and a.Face.BackgroundColor3.G==b.Face.BackgroundColor3.G and a.Face.BackgroundColor3.B==b.Face.BackgroundColor3.B); assert(a.Detail.Visible==b.Detail.Visible); assert(a.Face.BackgroundTransparency==b.Face.BackgroundTransparency) end
	end end
	thumbnail.Frame:Destroy()
end
assert(#Catalog.list("BrickSkins")==12)
print("PASS all twelve tetromino thumbnails match the live brick renderer")
local sample=Preview.new(host,UI); local savedSkin=d.Equipped.BrickSkin; local beforePreview=#requests
sample:set(Catalog.Items["BrickSkins:Galaxy"],d.Equipped)
assert(sample.Loadout.BrickSkin=="Galaxy" and d.Equipped.BrickSkin==savedSkin); assert(#requests==beforePreview)
assert(sample.Frame:GetAttribute("CosmeticSample")); assert(sample.Frame.ZIndex>host.ZIndex)
for _,effect in ipairs(Catalog.list("GhostEffects")) do
	sample:set(effect,d.Equipped); UI.reducedMotion=true; sample:tick(0,true); local point=E.cells(sample.View.State.ghost)[1]; local ghost=sample.View.Tiles[point[2]][point[1]]; local alpha=ghost.Face.BackgroundTransparency; local border=ghost.Edge.Color
	sample:tick(5,true); assert(ghost.Face.BackgroundTransparency==alpha and ghost.Edge.Color.R==border.R and ghost.Edge.Color.G==border.G and ghost.Edge.Color.B==border.B)
end
UI.reducedMotion=false
print("PASS preview leaves inventory/network untouched and every ghost freezes with Reduced Motion")
local fx=modules.CosmeticRenderer; local activeBefore=fx.Active
sample:set(Catalog.Items["DropEffects:PixelExplosion"],d.Equipped); local initialY=sample.View.State.piece.y; for _=1,8 do sample:tick(0.05) end; assert(sample.View.State.piece.y>initialY); for _=1,30 do sample:tick(0.05) end; assert(sample.Landed and fx.Active>activeBefore)
for index=1,12 do fx.drop(sample.Frame,"Stardust",false) end; assert(fx.Active<=fx.Limit)
for _,entry in ipairs(delayed) do if entry.Seconds==1 then entry.Run() end end; assert(fx.Active==0,"Drop particles did not release their budget")
UI.reducedMotion=true; sample:set(Catalog.Items["DropEffects:PixelExplosion"],d.Equipped); local frozenY=sample.View.State.piece.y; sample:tick(10,true); assert(sample.View.State.piece.y==frozenY and fx.Active==0)
UI.reducedMotion=false; sample:destroy(); host:Destroy()
print("PASS drop samples fall, land, cap particles, clean up and respect Reduced Motion")
local audio=modules.AudioController.new(); local oldSound=SoundConfig.Sounds.HardDrop; local oldPack=SoundConfig.Packs.Retro
SoundConfig.Sounds.HardDrop="12345"; SoundConfig.Packs.Retro={Pitch=0.9,Sounds={HardDrop="67890"}}
local equippedPack=audio.Pack; assert(audio:preview("Retro")); assert(audio.Preview.SoundId=="rbxassetid://67890" and audio.Preview.IsPlaying); assert(audio.Pack==equippedPack and SoundConfig.Sounds.HardDrop=="12345")
audio:settings(0.5,0.4,0.6,true); assert(audio.Preview.Volume==0 and not audio:preview("Retro")); audio:settings(0.5,0.4,0.6,false)
local oldSample=audio.Preview; audio:preview("Default"); assert(not oldSample.Parent)
for _,entry in ipairs(delayed) do if entry.Seconds==1.6 then entry.Run() end end; assert(audio.Preview==nil)
SoundConfig.Sounds.HardDrop=oldSound; SoundConfig.Packs.Retro=oldPack; audio:destroy()
print("PASS sound preview honors pack overrides, mute and cleanup without changing equipped pack")
local normalNew=Instance.new
Instance.new=function(class) local object=normalNew(class); if class=="Sound" then object.IsLoaded=false end; return object end
local waiting=modules.AudioController.new(); SoundConfig.Sounds.HardDrop="13579"
assert(waiting:preview("Default")); local waitingSample=waiting.Preview; assert(not waitingSample.IsPlaying)
waitingSample.IsLoaded=true; waitingSample.Loaded:fire(); assert(waitingSample.IsPlaying)
for _,entry in ipairs(delayed) do if entry.Seconds==1.6 then entry.Run() end end
assert(not waitingSample.Parent); waiting:destroy(); Instance.new=normalNew; SoundConfig.Sounds.HardDrop=oldSound
print("PASS delayed sound loading starts the sample window after loading")
Network.OnClientEvent:fire("Lobby",{})
UIS.GamepadEnabled=true; app.menuObjects.settings.Activated:fire(); assert(services.GuiService.SelectedObject.Name=="Resume"); assert(services.GuiService.SelectedObject.Parent.Name=="SettingsOptions")
app.root:FindFirstChild("Resume",true).Activated:fire()
app.portal:open("Shop"); app.portal:layout(390,780); local net=#requests
app.portal.Overlay:FindFirstChild("Preview_NeonClub",true).Activated:fire(); assert(app.portal.PreviewOpen and #requests==net); assert(services.GuiService.SelectedObject.Name=="ClosePreview")
local oldHeight=app.portal.PreviewPanel.Size.Y.Offset; app.portal:layout(390,640); assert(app.portal.PreviewPanel.Size.Y.Offset<=608)
assert(app.portal.PreviewPanel.SelectionGroup and app.portal.Overlay.SelectionGroup)
app.portal:close(); UIS.GamepadEnabled=false
print("PASS controller focus enters settings/preview and preview adapts to height-only resize")
app.portal.BoardData={Kind="GlobalRating",Rows={{Position=1,Name="Opponent",UserId=321,Value=1400,Rank="Bronze"}}}; app.portal:open("Leaderboards"); assert(app.portal.Scroll:FindFirstChild("Row"))
app.portal.Challenger={UserId=321,DisplayName="Opponent"}; app.portal:open("ChallengeInvite"); assert(app.portal.Header.Text=="DUEL INVITE"); app.portal:close()
print("PASS populated leaderboard and friend invitation screens consume real payload shapes")
d.DebugPrivileges=nil; app.portal:layout(320,568); app.portal:open("Shop")
local cash=d.Cash; local skin=d.Equipped.BrickSkin
local locked=app.portal.Overlay:FindFirstChild("Cosmetic_NeonClub",true)
assert(locked:FindFirstChild("Ownership").Text:find("LOCKED")); assert(locked:FindFirstChild("Equip_NeonClub"):GetAttribute("Disabled"))
locked:FindFirstChild("Buy_NeonClub").Activated:fire(); assert(requests[#requests].Kind=="Buy" and requests[#requests].Payload.Category=="BrickSkins" and requests[#requests].Payload.Id=="NeonClub")
assert(d.Cash==cash and d.Equipped.BrickSkin==skin and not d.Inventory.BrickSkins.NeonClub)
d.Inventory.BrickSkins.NeonClub=true; Network.OnClientEvent:fire("Profile",d); app.portal.Overlay:FindFirstChild("Equip_NeonClub",true).Activated:fire(); assert(requests[#requests].Kind=="Equip" and requests[#requests].Payload.Id=="NeonClub")
Network.OnClientEvent:fire("CosmeticResult",{Action="Equip",Category="BrickSkins",Id="NeonClub",Success=true})
app.portal:open("Energy"); local energyRow=app.portal.Scroll:FindFirstChild("Row"); local body=energyRow:FindFirstChild("Body"); local action=energyRow:FindFirstChild("Action1"); assert(body.Position.Y.Offset+body.Size.Y.Offset<energyRow.Size.Y.Offset+action.Position.Y.Offset)
app.portal:close()
print("PASS locked/owned shop actions remain server-authoritative and long mobile rows avoid action overlap")
app.portal:layout(1366,768); app.portal:open("Shop"); app.portal.Category="BrickSkins"; app.portal:render()
local scroll=app.portal.Scroll; scroll.CanvasPosition=Vector2.new(0,840)
local card=scroll:FindFirstChild("Cosmetic_Galaxy"); local preview=card:FindFirstChild("Preview_Galaxy")
local tabs=app.portal.Tabs:GetChildren(); preview.Activated:fire()
assert(scroll.CanvasPosition.Y==840 and scroll:FindFirstChild("Cosmetic_Galaxy")==card)
assert(card:FindFirstChild("Preview_Galaxy")==preview and app.portal.Sample.Loadout.BrickSkin=="Galaxy")
for index,tab in ipairs(tabs) do assert(app.portal.Tabs:GetChildren()[index]==tab) end
print("PASS Preview preserves scroll, card instances and tab focus without rebuilding the shop")
local buy=card:FindFirstChild("Buy_Galaxy"); buy.Activated:fire(); assert(requests[#requests].Kind=="Buy")
d.Cash=1000; d.Inventory.BrickSkins.Galaxy=true; Network.OnClientEvent:fire("Profile",d)
assert(scroll.CanvasPosition.Y==840 and scroll:FindFirstChild("Cosmetic_Galaxy")==card and card:FindFirstChild("Buy_Galaxy")==buy)
assert(buy.Text=="OWNED" and buy:GetAttribute("Disabled")); assert(not card:FindFirstChild("Equip_Galaxy"):GetAttribute("Disabled"))
assert(app.portal.ShopView.Balance:FindFirstChild("Title").Text=="CASH 1000")
print("PASS Buy response updates existing ownership/price controls and retains CanvasPosition")
local equip=card:FindFirstChild("Equip_Galaxy"); equip.Activated:fire(); assert(requests[#requests].Payload.Id=="Galaxy")
d.Equipped.BrickSkin="Galaxy"; Network.OnClientEvent:fire("Profile",d)
assert(scroll.CanvasPosition.Y==840 and card:FindFirstChild("Equip_Galaxy")==equip and equip.Text=="UNEQUIP")
equip.Activated:fire(); assert(requests[#requests].Payload.Id=="Default","Equip callback captured stale equipped state")
app.portal:layout(390,780); scroll.CanvasPosition=Vector2.new(0,840); local phoneCard=scroll:FindFirstChild("Cosmetic_Galaxy")
phoneCard:FindFirstChild("Preview_Galaxy").Activated:fire(); assert(app.portal.PreviewOpen and scroll.CanvasPosition.Y==840)
app.portal.PreviewPanel:FindFirstChild("ClosePreview").Activated:fire(); assert(not app.portal.PreviewOpen and scroll.CanvasPosition.Y==840 and scroll:FindFirstChild("Cosmetic_Galaxy")==phoneCard)
app.portal:close()
print("PASS Equip uses current state, and phone preview open/close retains the original scroll position")
print("UI checks use mocked Roblox instances; native rendering, real audio and devices require Studio QA.")
Network.OnClientEvent:fire("CosmeticResult",{Action="Equip",Category="BrickSkins",Id="Missing",Success=false,Code="NotOwned",Message="You don't own this cosmetic yet."})
assert(app.portal.Client.LastCosmeticResult.Code=="NotOwned" and d.Equipped.BrickSkin=="Galaxy")
app.portal:layout(1366,768); app.portal:open("Shop"); app.portal.Scroll.CanvasPosition=Vector2.new(0,840)
local sameCard=app.portal.Scroll:FindFirstChild("Cosmetic_Galaxy"); local sameButton=sameCard:FindFirstChild("Equip_Galaxy")
for _=1,5 do Network.OnClientEvent:fire("Profile",d) end
local count=#requests; sameButton.Activated:fire(); assert(#requests==count+1)
assert(app.portal.Scroll.CanvasPosition.Y==840 and app.portal.Scroll:FindFirstChild("Cosmetic_Galaxy")==sameCard)
app.portal:close()
print("PASS structured failures never equip locally, and repeated profile refreshes keep one button connection and scrolling")
local U=modules.NeonUI; local Feedback=modules.ArcadeFeedback; local Config=BattleEffectsConfig
U.reducedMotion=false; local audio=modules.AudioController.new(); local fx=Feedback.new(app.root,U,audio,app.own,app.enemy)
fx:layout(modules.NeonLayout.resolve(1366,768,true)); fx:reset("test-round")
fx:battle({Id=1,Kind="Attack",MatchId="other",Lines=6,From=123,To=321},123); assert(#fx.Queues[1]==0)
fx:battle({Id=2,Kind="Attack",MatchId="test-round",Lines=0,From=123,To=321},123); assert(#fx.Queues[1]==0)
fx:battle({Id=3,Kind="Attack",MatchId="test-round",Lines=6,From=123,To=321},123)
fx:battle({Id=3,Kind="Attack",MatchId="test-round",Lines=6,From=123,To=321},123); assert(#fx.Queues[1]==1)
fx:tick(0.1,100); assert(fx.Labels[1].Text=="+6 LINES"); local first=fx.Particles[1]; local x=first.Frame.Position.X.Offset
fx:tick(0.1,100); assert(first.Frame.Position.X.Offset>x)
for i=4,15 do fx:battle({Id=i,Kind="Attack",MatchId="test-round",Lines=20,From=321,To=123},123) end
local active=0; for _,v in ipairs(fx.Particles) do if v.Age then active+=1 end end; assert(active<=Config.Attack.MaxActive and #fx.Queues[2]<=Config.Announcements.QueueLimit)
fx:tick(2,100); for _,v in ipairs(fx.Particles) do assert(not v.Age and not v.Frame.Visible) end
U.reducedMotion=true; fx:battle({Id=16,Kind="Attack",MatchId="test-round",Lines=1,From=123,To=321},123); for _,v in ipairs(fx.Particles) do assert(not v.Age) end
fx:reset("next-round"); assert(#fx.Queues[1]==0 and not fx.Labels[1].Visible)
print("PASS confirmed attack direction/count, duplicate/foreign/zero suppression, bounded pools and Reduced Motion")
local old={}; for _,key in ipairs({"GarbageWarningLow","GarbageWarningMedium","GarbageWarningHigh","GarbageWarningCritical"}) do old[key]=SoundConfig.Sounds[key]; SoundConfig.Sounds[key]="12345" end
assert(audio:warning(1,0)); assert(audio.Warning.SoundId=="rbxassetid://12345" and audio.Warning.Volume<=audio.Master*audio.SFXVolume)
assert(not audio:warning(12,0.1)); audio.Warning:Stop(); assert(not audio:warning(12,0.5)); assert(audio:warning(12,3.1))
audio:settings(0.5,0.5,0.2,true); assert(audio.Warning.Volume==0 and not audio.Warning.IsPlaying and not audio:warning(20,8))
audio:settings(1,0.5,0.8,false); audio:warning(0,10); assert(not audio.Warning.IsPlaying)
for key,value in pairs(old) do SoundConfig.Sounds[key]=value end
assert(not audio:warning(12,11))
print("PASS garbage warnings honor thresholds, cooldown, exclusive channel, mute/SFX volume and empty IDs")
fx:reset("countdown"); fx:state({MatchId="countdown",StartAt=103,Mode="Ranked",Own={alive=true,pending=0}})
fx:tick(0.1,100); assert(fx.Countdown.Text=="3"); fx:tick(0.1,101); assert(fx.Countdown.Text=="2"); fx:tick(0.1,102); assert(fx.Countdown.Text=="1"); fx:tick(0.1,103); assert(fx.Countdown.Text=="GO!")
fx:reset("late"); fx:state({MatchId="late",StartAt=100,Mode="Ranked",Own={alive=true,pending=0}}); fx:tick(0.1,110); assert(not fx.Countdown.Visible)
for i=1,10 do fx:event({name=i==10 and "PerfectClear" or "Combo",data={combo=i}}) end; assert(#fx.Queues[1]<=Config.Announcements.QueueLimit and fx.Queues[1][1].Text=="PERFECT CLEAR!")
print("PASS server-time countdown catches up without restarting; announcements prioritize and cap clear feedback")
local host=U.new("Frame","ResultTest",app.root); local sounds={}; local client={Audio={play=function(_,key) table.insert(sounds,key) end},send=function() error("Results attempted to grant/send during animation") end}
local result={Id="verified",Outcome="Win",Cash=50,Rewards=true,Own={lines=4,stats={Sent=6,KOs=2,BestCombo=3}},Opponent={stats={KOs=1}},BeforeRank={Tier=1,Stars=2,Rating=1000},AfterRank={Tier=2,Stars=0,Rating=1012}}
U.reducedMotion=false; local sequence=modules.ArcadeResults.new(host,U,client,result,440); assert(sequence.Title.Text=="YOU WIN!" and not sequence.Cash.Visible)
sequence:tick(3); assert(sequence.KO.Text=="FINAL K.O.  2 : 1" and sequence.Cash.Text=="+50 CASH" and sequence.RankLabel.Text:find("RANK UP!",1,true))
assert(sequence.Stars.Text:find("+1 STAR",1,true)); local count=#sounds; sequence:tick(10); assert(#sounds==count and result.Cash==50)
sequence:destroy(); local repeatView=modules.ArcadeResults.new(host,U,client,result,440); repeatView:tick(5); assert(#sounds==count)
repeatView:destroy(); host:Destroy()
print("PASS confirmed result timeline, real KO/Cash, promotion star delta and once-only sound phases without reward grants")
local sample=modules.BrickPreviewRenderer.new(app.root,U)
for _,category in ipairs(Catalog.Categories) do sample:set(Catalog.list(category)[2],d.Equipped); for _=1,38 do sample:tick(0.05) end; assert(sample.Landed and sample.View.Rows==20 and sample.Engine.score>0) end
sample:set(Catalog.Items["BrickSkins:RoyalPrism"],d.Equipped); for _=1,140 do sample:tick(0.05) end; assert(sample.Round>=3)
sample.Round=2; sample:begin(); for _=1,38 do sample:tick(0.05) end; assert(sample.Engine.lines==4 and sample.Engine.stats.PerfectClears==1)
local elapsed=sample.Elapsed; sample.Frame.Visible=false; sample:tick(10); assert(sample.Elapsed==elapsed)
U.reducedMotion=true; sample.Frame.Visible=true; local y=sample.Engine.piece.y; sample:tick(10); assert(sample.Engine.piece.y==y); sample:destroy()
print("PASS every cosmetic category uses a looping isolated 10x20 engine demo with real hard drops/clears and hidden/frozen cleanup")
fx:destroy(); audio:destroy(); U.reducedMotion=false
local Assets=modules.UIAssets; local U=modules.NeonUI
assert(UIAssetConfig.ImageUri("123")=="rbxassetid://123")
assert(UIAssetConfig.ImageUri("rbxassetid://456")=="rbxassetid://456")
assert(UIAssetConfig.ImageUri("not-an-id")=="" and UIAssetConfig.ImageUri(nil)=="")
assert(Assets.uri("Images.menu.shop")=="")
assert(U.theme.Face.Family=="rbxasset://fonts/families/PressStart2P.json")
UIAssetConfig.Images.menu.shop="123"; assert(Assets.uri("Images.menu.shop")=="rbxassetid://123"); UIAssetConfig.Images.menu.shop=""
local oldRank=RankIconConfig.Icons.Rookie; RankIconConfig.Icons.Rookie="456"; assert(Assets.rank("Rookie")=="rbxassetid://456"); RankIconConfig.Icons.Rookie=oldRank
print("PASS central asset IDs validate/fall back safely, preserve existing rank overrides and use Press Start 2P")

app.portal:close(true); app.portal:layout(1366,768); app.portal:open("Hub")
assert(app.portal.Scroll:FindFirstChild("MoreGrid"):FindFirstChild("Tiles"))
local n=#requests; app.menuObjects.solo.Activated:fire(); assert(#requests==n,"Background Solo action escaped modal")
app.portal:open("Energy"); app.portal:open("Quests"); app.portal:close(); assert(app.portal.Page=="Energy" and app.portal.Overlay.Visible); app.portal:close(); assert(app.portal.Page=="Hub"); app.portal:close(); assert(not app.portal.Overlay.Visible and U.ActiveModal==nil)
print("PASS background modal actions blocked; nested Back returns Quests to Energy to More to its opener")

app.portal:open("Shop"); app.portal.Category="BrickSkins"; app.portal:render(); app.portal.Selected="Galaxy"; app.portal:render(true); app.portal.Scroll.CanvasPosition=Vector2.new(0,700)
app.portal:open("Profile"); app.portal:close(); assert(app.portal.Page=="Shop" and app.portal.Selected=="Galaxy" and app.portal.Scroll.CanvasPosition.Y==700)
app.portal:open("Inventory"); assert(app.portal.Scroll:FindFirstChild("InventoryGrid"):FindFirstChild("Grid")); assert(app.portal.Sidebar); app.portal:close(true)
print("PASS Shop navigation preserves selection/scroll; Inventory uses owned real-rendered grid and category sidebar")

app.portal:open("Shop"); app.portal.Selected="Galaxy"; app.portal:render(true)
local sample=app.portal.Sample; U.reducedMotion=false; local y=sample.Engine.piece.y; sample:control("Pause"); sample:tick(1); assert(sample.Engine.piece.y==y and sample.Paused)
sample:control("Rotate"); assert(sample.Engine.piece.rotation~=0); sample:control("Speed"); assert(sample.Speed==0.5); local round=sample.Round; sample:control("Next"); assert(sample.Round==round+1); sample:control("Pause"); assert(not sample.Paused)
local realBoard=app.client.State and app.client.State.Own; local count=#requests; sample:control("Replay"); assert(#requests==count and (not realBoard or app.client.State.Own==realBoard))
app.portal:layout(390,780); app.portal.PreviewOpen=true; app.portal:render(true); assert(U.ActiveModal==app.portal.PreviewPanel); count=#requests; app.menuObjects.battle.Activated:fire(); assert(#requests==count); app.portal.PreviewPanel.ClosePreview.Activated:fire(); assert(U.ActiveModal==app.portal.Overlay)
app.portal:close(true)
print("PASS preview pause/rotate/piece/replay/speed are isolated; phone preview also blocks underlying actions")

app.portal:layout(1366,768); app.portal:open("Shop"); app.portal.Category="BrickSkins"; app.portal:render()
d.DebugPrivileges=nil; app.client.PendingCosmetic=nil; d.Inventory.BrickSkins.Galaxy=true; d.Equipped.BrickSkin="Default"; Network.OnClientEvent:fire("Profile",d)
local card=app.portal.ShopView.Cards.Galaxy; local current=app.client.Profile.Equipped.BrickSkin
card.Buttons[3].Activated:fire(); assert(app.client.PendingCosmetic and card.Buttons[3]:GetAttribute("Disabled")); local count=#requests; card.Buttons[3].Activated:fire(); assert(#requests==count)
Network.OnClientEvent:fire("CosmeticResult",{Action="Equip",Category="BrickSkins",Id="Galaxy",Success=false,Message="Not ready"}); assert(not app.client.PendingCosmetic and app.client.Profile.Equipped.BrickSkin==current and not card.Buttons[3]:GetAttribute("Disabled"))
app.portal:close(true)
print("PASS pending operations disable duplicates, failed operations keep authoritative ownership and recover controls")

app.portal:open("Quests"); app.portal.QuestGroup="Daily"; d.Quests.Daily.Progress.play=0; d.Quests.Daily.Claimed.play=nil; app.portal:render(); local row=app.portal.Scroll:FindFirstChild("Row"); assert(row.Action1.Text=="INCOMPLETE" and row.Action1:GetAttribute("Disabled")); local count=#requests; row.Action1.Activated:fire(); assert(#requests==count)
d.Quests.Daily.Progress.play=3; Network.OnClientEvent:fire("Profile",d); row=app.portal.Scroll:FindFirstChild("Row"); assert(row.Action1.Text=="CLAIM" and not row.Action1:GetAttribute("Disabled")); assert(row.QuestProgress.Fill.Size.X.Scale==1)
d.Quests.Daily.Claimed.play=true; Network.OnClientEvent:fire("Profile",d); row=app.portal.Scroll:FindFirstChild("Row"); assert(row.Action1.Text=="CLAIMED" and row.Action1:GetAttribute("Disabled")); app.portal:close(true)
for _,page in ipairs({"Cash","Featured","Assets","Help","Redeem"}) do app.portal:open(page); assert(app.portal.Overlay.Visible); app.portal:close(true) end
assert(not DeveloperProductConfig.PurchasesEnabled)
print("PASS quest incomplete/claimable/claimed states follow confirmed profile; cash/energy products remain safely unavailable")

UIAssetConfig.Images.battle.garbage_projectile="12345"; local a=modules.AudioController.new(); local f=modules.ArcadeFeedback.new(app.root,U,a,app.own,app.enemy); f:layout(modules.NeonLayout.resolve(1366,768,true)); f:reset("assets-test")
assert(f.Particles[1].Frame.BlockTexture.Image=="rbxassetid://12345"); f:battle({MatchId="assets-test",Id=1,Kind="Attack",From=123,To=321,Lines=2},123); f:tick(0.1,100)
assert(f.Particles[1].Frame.BackgroundTransparency==1 and f.Particles[1].Frame:GetAttribute("ServerEventId")==1)
local x=f.Particles[1].Frame.Position.X.Offset; f:tick(0.1,100); assert(f.Particles[1].Frame.Position.X.Offset>x)
f:state({Mode="Ranked",MatchId="assets-test",Own={alive=true,pending=0},Opponent={events={{id=1,name="PerfectClear",data={}}}}}); f:tick(0.01,100); assert(f.Labels[2].Text=="PERFECT CLEAR!"); assert(f.Rays[1].Visible)
f:destroy(); a:destroy(); UIAssetConfig.Images.battle.garbage_projectile=""
print("PASS optional projectile textures retain confirmed hollow-square arcs and opponent Perfect Clear uses authoritative events")

for _,size in ipairs({{320,568},{390,780},{568,320},{844,326},{1024,768},{768,1024},{1366,768}}) do
 local l=modules.NeonLayout.resolve(size[1],size[2],true)
 for _,key in ipairs({"header","cash","energy","settings","mail"}) do bounds(l.menu[key],l.width,l.height,key) end
 assert(not overlap(l.menu.header,l.menu.cash) and not overlap(l.menu.cash,l.menu.energy))
 app.portal:layout(size[1],size[2]); app.portal:open("Shop"); app.portal.PreviewOpen=true; app.portal:render(true)
 local p=app.portal.PreviewPanel; local b=app.portal.Sample.Frame; assert(b.Size.X.Offset>0 and b.Size.Y.Offset==b.Size.X.Offset*2)
 for _,key in ipairs({"PreviewPause","PreviewReplay","PreviewRotate","PreviewNext","PreviewSpeed","PreviewAudio","DetailBuy","DetailEquip"}) do local button=p:FindFirstChild(key); assert(button.Size.X.Offset>=44 and button.Size.Y.Offset>=44); assert(button.Position.Y.Offset+button.Size.Y.Offset<=p.Size.Y.Offset) end
 app.portal:close(true)
end
print("PASS reference lobby header and preview controls stay bounded with 44px targets on phones, tablets and desktop")
