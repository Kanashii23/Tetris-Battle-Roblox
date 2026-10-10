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
-- Display/render alias only: existing catalog/save IDs and prices remain unchanged.
function Config.AssetTheme(category,id)
 local ids=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CosmeticsAssetResolver"))
 local keys={BrickSkins="Bricks",GhostEffects="GhostFX",DropEffects="DropFX"}
 return ids.theme(keys[category],id)
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
-- Roblox service doubles only: the supplied ProfileStore implementation executes below.
-- No mock ProfileStore/Profile objects are substituted for the library in these checks.
C.ProfileStoreLiveEnabled=true; C.ProfileStoreStudioPersistence=true
C.DataStoreName="TetrisBattle_ProfileHarness"; C.ProfileSaveTimeout=3; C.ProfileLoadTimeout=5
local realOS=os; local now=0; local epoch=1791590400
local os={time=function() return epoch+math.floor(now) end,clock=function() return now end,date=realOS.date}
local scheduled={}; local task={}
local function resume(co,...)
	local ok,value=coroutine.resume(co,...); assert(ok,value)
	if coroutine.status(co)~="dead" and type(value)=="table" and value.Wait then table.insert(scheduled,{Co=co,At=now+value.Wait}) end
end
function task.wait(seconds) return coroutine.yield({Wait=seconds or 0.01}) end
function task.spawn(fn,...)
	local co=type(fn)=="thread" and fn or coroutine.create(fn); resume(co,...); return co
end
function task.defer(fn,...) local args=table.pack(...); task.delay(0,function() fn(table.unpack(args,1,args.n)) end) end
function task.delay(seconds,fn) local co=coroutine.create(fn); table.insert(scheduled,{Co=co,At=now+seconds}); return co end
local function event()
	local e={Handlers={}}
	function e:Connect(fn) table.insert(self.Handlers,fn); return {Disconnect=function() for i,item in ipairs(self.Handlers) do if item==fn then table.remove(self.Handlers,i); break end end end} end
	function e:fire(...) for _,fn in ipairs(table.clone(self.Handlers)) do task.spawn(fn,...) end end
	return e
end
local RunService={Heartbeat=event(),IsStudio=function() return false end}
local records,versions={},{}; local faults={Reads={},Writes={},Latency={},AfterWrite={}}
local function keyInfo(name,key)
	if records[name][key]==nil then return nil end
	return {Version="version-"..(versions[name][key] or 0),CreatedTime=epoch*1000,UpdatedTime=os.time()*1000,GetMetadata=function() return {} end,GetUserIds=function() return {} end}
end
local DSS={}
function DSS:GetDataStore(name)
	records[name]=records[name] or {}; versions[name]=versions[name] or {}
	return {
		GetAsync=function(_,key)
			if faults.Reads[name] then error("simulated read outage") end
			if faults.Latency[name] then task.wait(faults.Latency[name]) end
			return P.clone(records[name][key]),keyInfo(name,key)
		end,
		UpdateAsync=function(_,key,transform)
			if faults.Writes[name] then error("simulated write outage") end
			if faults.Latency[name] then task.wait(faults.Latency[name]) end
			local nextData=transform(P.clone(records[name][key]),keyInfo(name,key))
			if nextData==nil then return nil end
			records[name][key]=P.clone(nextData); versions[name][key]=(versions[name][key] or 0)+1
			if faults.AfterWrite[name] then faults.AfterWrite[name](key) end
			return P.clone(nextData),keyInfo(name,key)
		end,
		SetAsync=function(_,key,value) records[name][key]=P.clone(value); versions[name][key]=(versions[name][key] or 0)+1 end,
	}
end
local Players={List={}}
function Players:GetPlayers() return self.List end
local guid=0; local Http={GenerateGUID=function() guid+=1; return "profile-test-"..guid end}
local Messaging={SubscribeAsync=function() return {Disconnect=function() end} end,PublishAsync=function() end}
local folder={WaitForChild=function(_,key) return key end}
local shared={WaitForChild=function(_,key) return key=="Config" and folder or key end}
local RS={WaitForChild=function() return shared end}
local closeCallbacks={}
local game={PlaceId=100,JobId="profile-test-server",GetService=function(_,key) return ({DataStoreService=DSS,Players=Players,HttpService=Http,MessagingService=Messaging,RunService=RunService,ReplicatedStorage=RS})[key] end,BindToClose=function(_,fn) table.insert(closeCallbacks,fn) end}
local Instance={new=function(class) assert(class=="DataStoreOptions"); return {SetExperimentalFeatures=function() end} end}
local typeof=type; local Enum={SortDirection={}}
local script={Name="ProfileStore",Parent=folder}
local modules={Progression=P,TetrisEngine=E,Rules=R,Catalog=Catalog,GameConfig=C}
local require=function(name) return assert(modules[name],"Unknown module "..tostring(name)) end
local warningCount=0; local warnings={}; local warn=function(value) warningCount+=1; table.insert(warnings,tostring(value)) end
local function player(uid)
	local p={UserId=uid,Parent=Players,Name="Player"..uid,DisplayName="Player"..uid,Kick=function(self,text) self.Kicked=text end}
	table.insert(Players.List,p); return p
end
local function tick(seconds)
	for _=1,math.ceil(seconds*100) do
		now+=0.01; RunService.Heartbeat:fire()
		local ready={}; for i=#scheduled,1,-1 do if scheduled[i].At<=now then table.insert(ready,table.remove(scheduled,i).Co) end end
		for _,co in ipairs(ready) do if coroutine.status(co)=="suspended" then resume(co) end end
	end
end
local function seed(name,key,value) DSS:GetDataStore(name):SetAsync(tostring(key),value) end
local function async(fn,seconds)
	local result; task.spawn(function() result=table.pack(fn()) end); tick(seconds or 10); assert(result,"Async operation did not finish")
	return table.unpack(result,1,result.n)
end

modules.ProfileStore=(function()
--[[
MAD STUDIO (by loleris)

-[ProfileStore]---------------------------------------

	Periodic DataStore saving solution with session locking
	
	WARNINGS FOR "Profile.Data" VALUES:
	 	! Do not create numeric tables with gaps - attempting to store such tables will result in an error.
		! Do not create mixed tables (some values indexed by number and others by a string key)
			- only numerically indexed  data will be stored.
		! Do not index tables by anything other than numbers and strings.
		! Do not reference Roblox Instances
		! Do not reference userdata (Vector3, Color3, CFrame...) - Serialize userdata before referencing
		! Do not reference functions
		
	Members:
	
		ProfileStore.IsClosing          [bool]
			-- Set to true after a game:BindToClose() trigger
			
		ProfileStore.IsCriticalState    [bool]
			-- Set to true when ProfileStore experiences too many consecutive errors
		
		ProfileStore.OnError            [Signal] (message, store_name, profile_key)
			-- Most ProfileStore errors will be caught and passed to this signal
			
		ProfileStore.OnOverwrite        [Signal] (store_name, profile_key)
			-- Triggered when a DataStore key was likely used to store data that wasn't
			a ProfileStore profile or the ProfileStore structure was invalidly manually
			altered for that DataStore key
			
		ProfileStore.OnCriticalToggle   [Signal] (is_critical)
			-- Triggered when ProfileStore experiences too many consecutive errors
		
		ProfileStore.DataStoreState     [string] ("NotReady", "NoInternet", "NoAccess", "Access")
			-- This value resembles ProfileStore's access to the DataStore; The value starts
			as "NotReady" and will eventually change to one of the other 3 possible values.
	
	Functions:
	
		ProfileStore.New(store_name, template?) --> [ProfileStore]
			store_name   [string] -- DataStore name
			template     [table] or nil -- Profiles will default to given table (hard-copy) when no data was saved previously
			
		ProfileStore.SetConstant(name, value)
			name    [string]
			value   [number]
				
	Members [ProfileStore]:
	
		ProfileStore.Mock   [ProfileStore]
			-- Reflection of ProfileStore methods, but the methods will now query a mock
			DataStore with no relation to the real DataStore
			
		ProfileStore.Name   [string]
		
	Methods [ProfileStore]:
	
		ProfileStore:StartSessionAsync(profile_key, params?) --> [Profile] or nil
			profile_key [string] -- DataStore key
			params      nil or [table]: -- Custom params; E.g. {Steal = true}
				{
					Steal = true, -- Pass this to disregard an existing session lock
					Cancel = fn() -> (boolean), -- Pass this to create a request cancel condition.
						-- If the cancel function returns true, ProfileStore will stop trying to
						-- start the session and return nil
				}
			
		ProfileStore:MessageAsync(profile_key, message) --> is_success [bool]
			profile_key [string] -- DataStore key
			message     [table] -- Data to be messaged to the profile
			
		ProfileStore:GetAsync(profile_key, version?) --> [Profile] or nil
			-- Reads a profile without starting a session - will not autosave
			profile_key   [string] -- DataStore key
			version       nil or [string] -- DataStore key version

		ProfileStore:VersionQuery(profile_key, sort_direction?, min_date?, max_date?) --> [VersionQuery]
			profile_key      [string]
			sort_direction   nil or [Enum.SortDirection]
			min_date         nil or [DateTime]
			max_date         nil or [DateTime]
			
		ProfileStore:RemoveAsync(profile_key) --> is_success [bool]
			-- Completely removes profile data from the DataStore / mock DataStore with no way to recover it.

	Methods [VersionQuery]:

		VersionQuery:NextAsync() --> [Profile] or nil -- (Yields)
			-- Returned profile is similar to profiles returned by ProfileStore:GetAsync()
		
	Members [Profile]:
	
		Profile.Data               [table]
			-- When the profile is active changes to this table are guaranteed to be saved
		Profile.LastSavedData      [table] (Read-only)
			-- Last snapshot of "Profile.Data" that has been successfully saved to the DataStore;
			Useful for proper developer product purchase receipt handling
		
		Profile.FirstSessionTime   [number] (Read-only)
			-- os.time() timestamp of the first profile session
			
		Profile.SessionLoadCount   [number] (Read-only) -- Amount of times a session was started for this profile
			
		Profile.Session            [table] (Read-only) {PlaceId = number, JobId = string} / nil
			-- Set to a table if this profile is in use by a server; nil if released

		Profile.RobloxMetaData     [table] -- Writable table that gets saved automatically and once the profile is released
		Profile.UserIds            [table] -- (Read-only) -- {user_id [number], ...} -- User ids associated with this profile

		Profile.KeyInfo            [DataStoreKeyInfo] -- Changes before OnAfterSave signal
		
		Profile.OnSave             [Signal] ()
			-- Triggered right before changes to Profile.Data are saved to the DataStore
			
		Profile.OnLastSave         [Signal] (reason [string]: "Manual", "External", "Shutdown")
			-- Triggered right before changes to Profile.Data are saved to the DataStore
			for the last time; A reason is provided for the last save:
				- "Manual"   - Profile:EndSession() was called
				- "Shutdown" - The server that has ownership of this profile is shutting down
				- "External" - Another server has started a session for this profile
			Note that this event will not trigger for when a profile session is ended by
			another server trying to take ownership of the session - this is impossible to
			do without compromising on ProfileStore's speed.
			
		Profile.OnSessionEnd       [Signal] ()
			-- Triggered when the profile session is terminated on this server
		
		Profile.OnAfterSave        [Signal] (last_saved_data)
			-- Triggered after a successful save
			last_saved_data [table] -- Profile.LastSavedData
			
		Profile.ProfileStore       [ProfileStore] -- ProfileStore object this profile belongs to
		Profile.Key                [string] -- DataStore key
		
	Methods [Profile]:
	
		Profile:IsActive() --> [bool] -- If "true" is returned, changes to Profile.Data are guaranteed to save;
			This guarantee is only valid until code yields (e.g. task.wait() is used).
			
		Profile:Reconcile() -- Fills in missing (nil) [string_key] = [value] pairs to the Profile.Data structure
			from the "template" argument that was passed to "ProfileStore.New()"
			
		Profile:EndSession() -- Call after the server has finished working with this profile
			e.g., after the player leaves (Profile object will become inactive)

		Profile:AddUserId(user_id) -- Associates user_id with profile (GDPR compliance)
			user_id   [number]

		Profile:RemoveUserId(user_id) -- Removes user_id association with profile (safe function)
			user_id   [number]
			
		Profile:MessageHandler(fn) -- Sets a message handler for this profile
			fn [function] (message [table], processed [function]())
			-- The handler function receives a message table and a callback function;
			The callback function is to be called when a message has been processed
			- this will discard the message from the profile message cache; If the
			callback function is not called, other message handlers will also be triggered
			with unprocessed message data.
			
		Profile:Save() -- If the profile session is still active makes an UpdateAsync call
			to the DataStore to immediately save profile data

		Profile:SetAsync() -- Forcefully saves changes to the profile; Only for profiles
			loaded with ProfileStore:GetAsync() or ProfileStore:VersionQuery()
		
--]]

local AUTO_SAVE_PERIOD = 300 -- (Seconds) Time between when changes to a profile are saved to the DataStore
local LOAD_REPEAT_PERIOD = 10 -- (Seconds) Time between successive profile reads when handling a session conflict
local FIRST_LOAD_REPEAT = 5 -- (Seconds) Time between first and second profile read when handling a session conflict
local SESSION_STEAL = 40 -- (Seconds) Time until a session conflict is resolved with the waiting server stealing the session
local ASSUME_DEAD = 630 -- (Seconds) If a profile hasn't had updates for this long, quickly assume an active session belongs to a crashed server
local START_SESSION_TIMEOUT = 120 -- (Seconds) If a session can't be started for a profile for this long, stop repeating calls to the DataStore

local CRITICAL_STATE_ERROR_COUNT = 5 -- Assume critical state if this many issues happen in a short amount of time
local CRITICAL_STATE_ERROR_EXPIRE = 120 -- (Seconds) Individual issue expiration
local CRITICAL_STATE_EXPIRE = 120 -- (Seconds) Critical state expiration

local MAX_MESSAGE_QUEUE = 1000 -- Max messages saved in a profile that were sent using "ProfileStore:MessageAsync()"

----- Dependencies -----

-- local Util = require(game.ReplicatedStorage.Shared.Util)
-- local Signal = Util.Signal

local Signal do

	local FreeRunnerThread

	--[[
		Yield-safe coroutine reusing by stravant;
		Sources:
		https://devforum.roblox.com/t/lua-signal-class-comparison-optimal-goodsignal-class/1387063
		https://gist.github.com/stravant/b75a322e0919d60dde8a0316d1f09d2f
	--]]

	local function AcquireRunnerThreadAndCallEventHandler(fn, ...)
		local acquired_runner_thread = FreeRunnerThread
		FreeRunnerThread = nil
		fn(...)
		-- The handler finished running, this runner thread is free again.
		FreeRunnerThread = acquired_runner_thread
	end

	local function RunEventHandlerInFreeThread(...)
		AcquireRunnerThreadAndCallEventHandler(...)
		while true do
			AcquireRunnerThreadAndCallEventHandler(coroutine.yield())
		end
	end

	local Connection = {}
	Connection.__index = Connection

	local SignalClass = {}
	SignalClass.__index = SignalClass

	function Connection:Disconnect()

		if self.is_connected == false then
			return
		end

		local signal = self.signal
		self.is_connected = false
		signal.listener_count -= 1

		if signal.head == self then
			signal.head = self.next
		else
			local prev = signal.head
			while prev ~= nil and prev.next ~= self do
				prev = prev.next
			end
			if prev ~= nil then
				prev.next = self.next
			end
		end

	end

	function SignalClass.New()

		local self = {
			head = nil,
			listener_count = 0,
		}
		setmetatable(self, SignalClass)

		return self

	end

	function SignalClass:Connect(listener: (...any) -> ())

		if type(listener) ~= "function" then
			error(`[{script.Name}]: \"listener\" must be a function; Received {typeof(listener)}`)
		end

		local connection = {
			listener = listener,
			signal = self,
			next = self.head,
			is_connected = true,
		}
		setmetatable(connection, Connection)

		self.head = connection
		self.listener_count += 1

		return connection

	end

	function SignalClass:GetListenerCount(): number
		return self.listener_count
	end

	function SignalClass:Fire(...)
		local item = self.head
		while item ~= nil do
			if item.is_connected == true then
				if not FreeRunnerThread then
					FreeRunnerThread = coroutine.create(RunEventHandlerInFreeThread)
				end
				task.spawn(FreeRunnerThread, item.listener, ...)
			end
			item = item.next
		end
	end

	function SignalClass:Wait()
		local co = coroutine.running()
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			task.spawn(co, ...)
		end)
		return coroutine.yield()
	end

	Signal = table.freeze({
		New = SignalClass.New,
	})

end

----- Private -----

local ActiveSessionCheck = {} -- {[session_token] = profile, ...}
local AutoSaveList = {} -- {profile, ...} -- Loaded profile table which will be circularly auto-saved
local IssueQueue = {} -- {issue_time, ...}

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local PlaceId = game.PlaceId
local JobId = game.JobId

local AutoSaveIndex = 1 -- Next profile to auto save
local LastAutoSave = os.clock()

local LoadIndex = 0

local ActiveProfileLoadJobs = 0 -- Number of active threads that are loading in profiles
local ActiveProfileSaveJobs = 0 -- Number of active threads that are saving profiles

local CriticalStateStart = 0 -- os.clock()

local IsStudio = RunService:IsStudio()
local DataStoreState: "NotReady" | "NoInternet" | "NoAccess" | "Access" = "NotReady"

local MockStore = {}
local UserMockStore = {}
local MockFlag = false

local OnError = Signal.New() -- (message, store_name, profile_key)
local OnOverwrite = Signal.New() -- (store_name, profile_key)

local UpdateQueue = { -- For stability sake, we won't do UpdateAsync calls for the same key until all previous calls finish
	--[[
		[session_token] = {
			coroutine, ...
		},
		...
	--]]
}

local function WaitInUpdateQueue(session_token) --> next_in_queue()

	local is_first = false

	if UpdateQueue[session_token] == nil then
		is_first = true
		UpdateQueue[session_token] = {}
	end

	local queue = UpdateQueue[session_token]

	if is_first == false then
		table.insert(queue, coroutine.running())
		coroutine.yield()
	end

	return function()
		local next_co = table.remove(queue, 1)
		if next_co ~= nil then
			coroutine.resume(next_co)
		else
			UpdateQueue[session_token] = nil
		end
	end

end

local function SessionToken(store_name, profile_key, is_mock)

	local session_token = "L_" -- Live

	if is_mock == true then
		session_token = "U_" -- User mock
	elseif DataStoreState ~= "Access" then
		session_token = "M_" -- Mock, cause no DataStore access
	end

	session_token ..= store_name .. "\0" .. profile_key

	return session_token

end

local function DeepCopyTable(t)
	local copy = {}
	for key, value in pairs(t) do
		if type(value) == "table" then
			copy[key] = DeepCopyTable(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function ReconcileTable(target, template)
	for k, v in pairs(template) do
		if type(k) == "string" then -- Only string keys will be reconciled
			if target[k] == nil then
				if type(v) == "table" then
					target[k] = DeepCopyTable(v)
				else
					target[k] = v
				end
			elseif type(target[k]) == "table" and type(v) == "table" then
				ReconcileTable(target[k], v)
			end
		end
	end
end

local function RegisterError(error_message, store_name, profile_key) -- Called when a DataStore API call errors
	warn(`[{script.Name}]: DataStore API error (STORE:{store_name}; KEY:{profile_key}) - {tostring(error_message)}`)
	table.insert(IssueQueue, os.clock()) -- Adding issue time to queue
	OnError:Fire(tostring(error_message), store_name, profile_key)
end

local function RegisterOverwrite(store_name, profile_key) -- Called when a corrupted profile is loaded
	warn(`[{script.Name}]: Invalid profile was overwritten (STORE:{store_name}; KEY:{profile_key})`)
	OnOverwrite:Fire(store_name, profile_key)
end

local function NewMockDataStoreKeyInfo(params)

	local version_id_string = tostring(params.VersionId or 0)
	local meta_data = params.MetaData or {}
	local user_ids = params.UserIds or {}

	return {
		CreatedTime = params.CreatedTime,
		UpdatedTime = params.UpdatedTime,
		Version = string.rep("0", 16) .. "."
			.. string.rep("0", 10 - string.len(version_id_string)) .. version_id_string
			.. "." .. string.rep("0", 16) .. "." .. "01",

		GetMetadata = function()
			return DeepCopyTable(meta_data)
		end,

		GetUserIds = function()
			return DeepCopyTable(user_ids)
		end,
	}

end

local function MockUpdateAsync(mock_data_store, profile_store_name, key, transform_function, is_get_call) --> loaded_data, key_info

	local profile_store = mock_data_store[profile_store_name]

	if profile_store == nil then
		profile_store = {}
		mock_data_store[profile_store_name] = profile_store
	end

	local epoch_time = math.floor(os.time() * 1000)
	local mock_entry = profile_store[key]
	local mock_entry_was_nil = false

	if mock_entry == nil then
		mock_entry_was_nil = true
		if is_get_call ~= true then
			mock_entry = {
				Data = nil,
				CreatedTime = epoch_time,
				UpdatedTime = epoch_time,
				VersionId = 0,
				UserIds = {},
				MetaData = {},
			}
			profile_store[key] = mock_entry
		end
	end

	local mock_key_info = mock_entry_was_nil == false and NewMockDataStoreKeyInfo(mock_entry) or nil

	local transform, user_ids, roblox_meta_data = transform_function(mock_entry and mock_entry.Data, mock_key_info)

	if transform == nil then
		return nil
	else
		if mock_entry ~= nil and is_get_call ~= true then
			mock_entry.Data = DeepCopyTable(transform)
			mock_entry.UserIds = DeepCopyTable(user_ids or {})
			mock_entry.MetaData = DeepCopyTable(roblox_meta_data or {})
			mock_entry.VersionId += 1
			mock_entry.UpdatedTime = epoch_time
		end

		return DeepCopyTable(transform), mock_entry ~= nil and NewMockDataStoreKeyInfo(mock_entry) or nil
	end

end

local function UpdateAsync(profile_store, profile_key, transform_params, is_user_mock, is_get_call, version) --> loaded_data, key_info
	--transform_params = {
	--	ExistingProfileHandle = function(latest_data),
	--	MissingProfileHandle = function(latest_data),
	--	EditProfile = function(latest_data),
	--}

	local loaded_data, key_info

	local next_in_queue = WaitInUpdateQueue(SessionToken(profile_store.Name, profile_key, is_user_mock))

	local success = true

	local success, error_message = pcall(function()
		local transform_function = function(latest_data)

			local missing_profile = false
			local overwritten = false
			local global_updates = {0, {}}

			if latest_data == nil then

				missing_profile = true

			elseif type(latest_data) ~= "table" then

				missing_profile = true
				overwritten = true

			else

				if type(latest_data.Data) == "table" and type(latest_data.MetaData) == "table" and type(latest_data.GlobalUpdates) == "table" then

					-- Regular profile structure detected:

					latest_data.WasOverwritten = false -- Must be set to false if set previously
					global_updates = latest_data.GlobalUpdates

					if transform_params.ExistingProfileHandle ~= nil then
						transform_params.ExistingProfileHandle(latest_data)
					end

				elseif latest_data.Data == nil and latest_data.MetaData == nil and type(latest_data.GlobalUpdates) == "table" then

					-- Regular structure not detected, but GlobalUpdate data exists:

					latest_data.WasOverwritten = false -- Must be set to false if set previously
					global_updates = latest_data.GlobalUpdates or global_updates
					missing_profile = true

				else

					missing_profile = true
					overwritten = true

				end

			end

			-- Profile was not created or corrupted and no GlobalUpdate data exists:
			if missing_profile == true then
				latest_data = {
					-- Data = nil,
					-- MetaData = nil,
					GlobalUpdates = global_updates,
				}
				if transform_params.MissingProfileHandle ~= nil then
					transform_params.MissingProfileHandle(latest_data)
				end
			end

			-- Editing profile:
			if transform_params.EditProfile ~= nil then
				transform_params.EditProfile(latest_data)
			end

			-- Invalid data handling (Silently override with empty profile)
			if overwritten == true then
				latest_data.WasOverwritten = true -- Temporary tag that will be removed on first save
			end

			return latest_data, latest_data.UserIds, latest_data.RobloxMetaData
		end

		if is_user_mock == true then -- Used when the profile is accessed through ProfileStore.Mock

			loaded_data, key_info = MockUpdateAsync(UserMockStore, profile_store.Name, profile_key, transform_function, is_get_call)
			task.wait() -- Simulate API call yield

		elseif DataStoreState ~= "Access" then -- Used when API access is disabled

			loaded_data, key_info = MockUpdateAsync(MockStore, profile_store.Name, profile_key, transform_function, is_get_call)
			task.wait() -- Simulate API call yield

		else

			if is_get_call == true then

				if version ~= nil then

					local success, error_message = pcall(function()
						loaded_data, key_info = profile_store.data_store:GetVersionAsync(profile_key, version)
					end)

					if success == false and type(error_message) == "string" and string.find(error_message, "not valid") ~= nil then
						warn(`[{script.Name}]: Passed version argument is not valid; Traceback:\n` .. debug.traceback())
					end

				else

					loaded_data, key_info = profile_store.data_store:GetAsync(profile_key)

				end

				loaded_data = transform_function(loaded_data)

			else

				loaded_data, key_info = profile_store.data_store:UpdateAsync(profile_key, transform_function)

			end

		end

	end)

	next_in_queue()

	if success == true and type(loaded_data) == "table" then
		-- Invalid data handling:
		if loaded_data.WasOverwritten == true and is_get_call ~= true then
			RegisterOverwrite(
				profile_store.Name,
				profile_key
			)
		end
		-- Return loaded_data:
		return loaded_data, key_info
	else
		-- Error handling:
		RegisterError(
			error_message or "Undefined error",
			profile_store.Name,
			profile_key
		)
		-- Return nothing:
		return nil
	end

end

local function IsThisSession(session_tag)
	return session_tag[1] == PlaceId and session_tag[2] == JobId
end

local function ReadMockFlag(): boolean
	local is_mock = MockFlag
	MockFlag = false
	return is_mock
end

local function WaitForStoreReady(profile_store)
	while profile_store.is_ready == false do
		task.wait()
	end
end

local function AddProfileToAutoSave(profile)

	ActiveSessionCheck[profile.session_token] = profile

	-- Add at AutoSaveIndex and move AutoSaveIndex right:

	table.insert(AutoSaveList, AutoSaveIndex, profile)

	if #AutoSaveList > 1 then
		AutoSaveIndex = AutoSaveIndex + 1
	elseif #AutoSaveList == 1 then
		-- First profile created - make sure it doesn't get immediately auto saved:
		LastAutoSave = os.clock()
	end

end

local function RemoveProfileFromAutoSave(profile)

	ActiveSessionCheck[profile.session_token] = nil

	local auto_save_index = table.find(AutoSaveList, profile)

	if auto_save_index ~= nil then
		table.remove(AutoSaveList, auto_save_index)
		if auto_save_index < AutoSaveIndex then
			AutoSaveIndex = AutoSaveIndex - 1 -- Table contents were moved left before AutoSaveIndex so move AutoSaveIndex left as well
		end
		if AutoSaveList[AutoSaveIndex] == nil then -- AutoSaveIndex was at the end of the AutoSaveList - reset to 1
			AutoSaveIndex = 1
		end
	end

end

local function SaveProfileAsync(profile, is_ending_session, is_overwriting, last_save_reason)

	if type(profile.Data) ~= "table" then
		error(`[{script.Name}]: Developer code likely set "Profile.Data" to a non-table value! (STORE:{profile.ProfileStore.Name}; KEY:{profile.Key})`)
	end

	profile.OnSave:Fire()
	if is_ending_session == true then
		profile.OnLastSave:Fire(last_save_reason or "Manual")
	end

	if is_ending_session == true and is_overwriting ~= true then
		if profile.roblox_message_subscription ~= nil then
			profile.roblox_message_subscription:Disconnect()
		end
		RemoveProfileFromAutoSave(profile)
		profile.OnSessionEnd:Fire()
	end

	ActiveProfileSaveJobs = ActiveProfileSaveJobs + 1

	-- Compare "SessionLoadCount" when writing to profile to prevent a rare case of repeat last save when the profile is loaded on the same server again

	local repeat_save_flag = true -- Released Profile save calls have to repeat until they succeed
	local exp_backoff = 1

	while repeat_save_flag == true do

		if is_ending_session ~= true then
			repeat_save_flag = false
		end

		local loaded_data, key_info = UpdateAsync(
			profile.ProfileStore,
			profile.Key,
			{
				ExistingProfileHandle = nil,
				MissingProfileHandle = nil,
				EditProfile = function(latest_data)

					-- Check if this session still owns the profile:

					local session_owns_profile = false

					if is_overwriting ~= true then

						local active_session = latest_data.MetaData.ActiveSession
						local session_load_count = latest_data.MetaData.SessionLoadCount

						if type(active_session) == "table" then
							session_owns_profile = IsThisSession(active_session) and session_load_count == profile.load_index
						end

					else
						session_owns_profile = true
					end

					-- We may only edit the profile if this server has ownership of the profile:

					if session_owns_profile == true then

						-- Clear processed updates (messages):

						local locked_updates = profile.locked_global_updates -- [index] = true, ...
						local active_updates = latest_data.GlobalUpdates[2]
						-- ProfileService module format: {{update_id, version_id, update_locked, update_data}, ...}
						-- ProfileStore module format: {{update_id, update_data}, ...}

						if next(locked_updates) ~= nil then
							local i = 1
							while i <= #active_updates do
								local update = active_updates[i]
								if locked_updates[update[1]] == true then
									table.remove(active_updates, i)
								else
									i += 1
								end
							end
						end

						-- Save profile data:

						latest_data.Data = profile.Data
						latest_data.RobloxMetaData = profile.RobloxMetaData
						latest_data.UserIds = profile.UserIds

						if is_overwriting ~= true then

							latest_data.MetaData.LastUpdate = os.time()

							if is_ending_session == true then
								latest_data.MetaData.ActiveSession = nil
							end

						else

							latest_data.MetaData.ActiveSession = nil
							latest_data.MetaData.ForceLoadSession = nil

						end

					end

				end,
			},
			profile.is_mock
		)

		if loaded_data ~= nil and key_info ~= nil then

			if is_overwriting == true then
				break
			end

			repeat_save_flag = false

			local active_session = loaded_data.MetaData.ActiveSession
			local session_load_count = loaded_data.MetaData.SessionLoadCount
			local session_owns_profile = false

			if type(active_session) == "table" then
				session_owns_profile = IsThisSession(active_session) and session_load_count == profile.load_index
			end

			local force_load_session = loaded_data.MetaData.ForceLoadSession
			local force_load_pending = false
			if type(force_load_session) == "table" then
				force_load_pending = not IsThisSession(force_load_session)
			end

			local is_active = profile:IsActive()

			-- If another server is trying to start a session for this profile - end the session:

			if force_load_pending == true and session_owns_profile == true then
				if is_active == true then
					SaveProfileAsync(profile, true, false, "External")
				end
				break
			end

			-- Clearing processed update list / Detecting new updates:

			local locked_updates = profile.locked_global_updates -- [index] = true, ...
			local received_updates = profile.received_global_updates -- [index] = true, ...
			local active_updates = loaded_data.GlobalUpdates[2]

			local new_updates = {} -- {}, ...
			local still_pending = {} -- [index] = true, ...

			for _, update in ipairs(active_updates) do
				if locked_updates[update[1]] == true then
					still_pending[update[1]] = true
				elseif received_updates[update[1]] ~= true then
					received_updates[update[1]] = true
					table.insert(new_updates, update)
				end
			end

			for index in pairs(locked_updates) do
				if still_pending[index] ~= true then
					locked_updates[index] = nil
				end
			end

			-- Updating profile values:

			profile.KeyInfo = key_info
			profile.LastSavedData = loaded_data.Data
			profile.global_updates = loaded_data.GlobalUpdates and loaded_data.GlobalUpdates[2] or {}

			if session_owns_profile == true then
				if is_active == true and is_ending_session ~= true then

					-- Processing new global updates (messages):

					for _, update in ipairs(new_updates) do

						local index = update[1]
						local update_data = update[#update] -- Backwards compatibility with ProfileService

						for _, handler in ipairs(profile.message_handlers) do

							local is_processed = false
							local processed_callback = function()
								is_processed = true
								locked_updates[index] = true
							end

							local send_update_data = DeepCopyTable(update_data)

							task.spawn(handler, send_update_data, processed_callback)

							if is_processed == true then
								break
							end

						end

					end

				end
			else

				if profile.roblox_message_subscription ~= nil then
					profile.roblox_message_subscription:Disconnect()
				end

				if is_active == true then
					RemoveProfileFromAutoSave(profile)
					profile.OnSessionEnd:Fire()
				end

			end

			profile.OnAfterSave:Fire(profile.LastSavedData)

		elseif repeat_save_flag == true then

			-- DataStore call likely resulted in an error; Repeat the DataStore call shortly
			task.wait(exp_backoff)
			exp_backoff = math.min(if last_save_reason == "Shutdown" then 8 else 20, exp_backoff * 2)

		end

	end

	ActiveProfileSaveJobs = ActiveProfileSaveJobs - 1

end

----- Public -----

--[[
	Saved profile structure:
	
	{
		Data = {},
		
		MetaData = {
			ProfileCreateTime = 0,
			SessionLoadCount = 0,
			ActiveSession = {place_id, game_job_id, unique_session_id} / nil,
			ForceLoadSession = {place_id, game_job_id} / nil,
			LastUpdate = 0, -- os.time()
			MetaTags = {}, -- Backwards compatibility with ProfileService
		},
		
		RobloxMetaData = {},
		UserIds = {},
		
		GlobalUpdates = {
			update_index,
			{
				{update_index, data}, ...
			},
		},
	}

--]]

export type JSONAcceptable = { JSONAcceptable } | { [string]: JSONAcceptable } | number | string | boolean | buffer

export type Profile<T> = {
	Data: T & JSONAcceptable,
	LastSavedData: T & JSONAcceptable,
	FirstSessionTime: number,
	SessionLoadCount: number,
	Session: {PlaceId: number, JobId: string}?,
	RobloxMetaData: JSONAcceptable,
	UserIds: {number},
	KeyInfo: DataStoreKeyInfo,
	OnSave: {Connect: (self: any, listener: () -> ()) -> ({Disconnect: (self: any) -> ()})},
	OnLastSave: {Connect: (self: any, listener: (reason: "Manual" | "External" | "Shutdown") -> ()) -> ({Disconnect: (self: any) -> ()})},
	OnSessionEnd: {Connect: (self: any, listener: () -> ()) -> ({Disconnect: (self: any) -> ()})},
	OnAfterSave: {Connect: (self: any, listener: (last_saved_data: T & JSONAcceptable) -> ()) -> ({Disconnect: (self: any) -> ()})},
	ProfileStore: JSONAcceptable,
	Key: string,

	IsActive: (self: any) -> (boolean),
	Reconcile: (self: any) -> (),
	EndSession: (self: any) -> (),
	AddUserId: (self: any, user_id: number) -> (),
	RemoveUserId: (self: any, user_id: number) -> (),
	MessageHandler: (self: any, fn: (message: JSONAcceptable, processed: () -> ()) -> ()) -> (),
	Save: (self: any) -> (),
	SetAsync: (self: any) -> (),
}

export type VersionQuery<T> = {
	NextAsync: (self: any) -> (Profile<T>?),
}

type ProfileStoreStandard<T> = {
	Name: string,
	StartSessionAsync: (self: any, profile_key: string, params: {Steal: boolean?}) -> (Profile<T>?),
	MessageAsync: (self: any, profile_key: string, message: JSONAcceptable) -> (boolean),
	GetAsync: (self: any, profile_key: string, version: string?) -> (Profile<T>?),
	VersionQuery: (self: any, profile_key: string, sort_direction: Enum.SortDirection?, min_date: DateTime | number | nil, max_date: DateTime | number | nil) -> (VersionQuery<T>),
	RemoveAsync: (self: any, profile_key: string) -> (boolean),
}

export type ProfileStore<T> = {
	Mock: ProfileStoreStandard<T>,
} & ProfileStoreStandard<T>

type ConstantName = "AUTO_SAVE_PERIOD" | "LOAD_REPEAT_PERIOD" | "FIRST_LOAD_REPEAT" | "SESSION_STEAL"
| "ASSUME_DEAD" | "START_SESSION_TIMEOUT" | "CRITICAL_STATE_ERROR_COUNT" | "CRITICAL_STATE_ERROR_EXPIRE"
| "CRITICAL_STATE_EXPIRE" | "MAX_MESSAGE_QUEUE"

export type ProfileStoreModule = {
	IsClosing: boolean,
	IsCriticalState: boolean,
	OnError: {Connect: (self: any, listener: (message: string, store_name: string, profile_key: string) -> ()) -> ({Disconnect: (self: any) -> ()})},
	OnOverwrite: {Connect: (self: any, listener: (store_name: string, profile_key: string) -> ()) -> ({Disconnect: (self: any) -> ()})},
	OnCriticalToggle: {Connect: (self: any, listener: (is_critical: boolean) -> ()) -> ({Disconnect: (self: any) -> ()})},
	DataStoreState: "NotReady" | "NoInternet" | "NoAccess" | "Access",
	New: <T>(store_name: string, template: (T & JSONAcceptable)?) -> (ProfileStore<T>),
	SetConstant: (name: ConstantName, value: number) -> ()
}

local Profile = {}
Profile.__index = Profile

function Profile.New(raw_data, key_info, profile_store, key, is_mock, session_token)

	local data = raw_data.Data or {}
	local session = raw_data.MetaData and raw_data.MetaData.ActiveSession or nil

	local global_updates = raw_data.GlobalUpdates and raw_data.GlobalUpdates[2] or {}
	local received_global_updates = {}

	for _, update in ipairs(global_updates) do
		received_global_updates[update[1]] = true
	end

	local self = {

		Data = data,
		LastSavedData = DeepCopyTable(data),

		FirstSessionTime = raw_data.MetaData and raw_data.MetaData.ProfileCreateTime or 0,
		SessionLoadCount = raw_data.MetaData and raw_data.MetaData.SessionLoadCount or 0,
		Session = session and {PlaceId = session[1], JobId = session[2]},

		RobloxMetaData = raw_data.RobloxMetaData or {},
		UserIds = raw_data.UserIds or {},
		KeyInfo = key_info,

		OnAfterSave = Signal.New(),
		OnSave = Signal.New(),
		OnLastSave = Signal.New(),
		OnSessionEnd = Signal.New(),

		ProfileStore = profile_store,
		Key = key,

		load_timestamp = os.clock(),
		is_mock = is_mock,
		session_token = session_token or "",
		load_index = raw_data.MetaData and raw_data.MetaData.SessionLoadCount or 0,
		locked_global_updates = {},
		received_global_updates = received_global_updates,
		message_handlers = {},
		global_updates = global_updates,

	}
	setmetatable(self, Profile)

	return self

end

function Profile:IsActive()
	return ActiveSessionCheck[self.session_token] == self
end

function Profile:Reconcile()
	ReconcileTable(self.Data, self.ProfileStore.template)
end

function Profile:EndSession()
	if self:IsActive() == true then
		task.spawn(SaveProfileAsync, self, true, nil, "Manual") -- Call save function in a new thread with release_from_session = true
	end
end

function Profile:AddUserId(user_id) -- Associates user_id with profile (GDPR compliance)

	if type(user_id) ~= "number" or user_id % 1 ~= 0 then
		warn(`[{script.Name}]: Invalid UserId argument for :AddUserId() ({tostring(user_id)}); Traceback:\n` .. debug.traceback())
		return
	end

	if user_id < 0 and self.is_mock ~= true and DataStoreState == "Access" then
		return -- Avoid giving real Roblox APIs negative UserId's
	end

	if table.find(self.UserIds, user_id) == nil then
		table.insert(self.UserIds, user_id)
	end

end

function Profile:RemoveUserId(user_id) -- Removes user_id association with profile (safe function)

	if type(user_id) ~= "number" or user_id % 1 ~= 0 then
		warn(`[{script.Name}]: Invalid UserId argument for :RemoveUserId() ({tostring(user_id)}); Traceback:\n` .. debug.traceback())
		return
	end

	local index = table.find(self.UserIds, user_id)

	if index ~= nil then
		table.remove(self.UserIds, index)
	end

end

function Profile:SetAsync() -- Saves the profile to the DataStore and removes the session lock

	if self.view_mode ~= true then
		error(`[{script.Name}]: :SetAsync() can only be used in view mode`)
	end

	SaveProfileAsync(self, nil, true)

end

function Profile:MessageHandler(fn)

	if type(fn) ~= "function" then
		error(`[{script.Name}]: fn argument is not a function`)
	end

	if self.view_mode ~= true and self:IsActive() ~= true then
		return -- Don't process messages if the profile session was ended
	end

	local locked_updates = self.locked_global_updates
	table.insert(self.message_handlers, fn)

	for _, update in ipairs(self.global_updates) do

		local index = update[1]
		local update_data = update[#update] -- Backwards compatibility with ProfileService

		if locked_updates[index] ~= true then

			local processed_callback = function()
				locked_updates[index] = true
			end

			local send_update_data = DeepCopyTable(update_data)

			task.spawn(fn, send_update_data, processed_callback)

		end

	end

end

function Profile:Save()

	if self.view_mode == true then
		error(`[{script.Name}]: Can't save profile in view mode; Should you be calling :SetAsync() instead?`)
	end

	if self:IsActive() == false then
		warn(`[{script.Name}]: Attempted saving an inactive profile (STORE:{self.ProfileStore.Name}; KEY:{self.Key});`
			.. ` Traceback:\n` .. debug.traceback())
		return
	end

	-- Move the profile right behind the auto save index to delay the next auto save for it:
	RemoveProfileFromAutoSave(self)
	AddProfileToAutoSave(self)

	-- Perform save in new thread:
	task.spawn(SaveProfileAsync, self)

end

local ProfileStore: ProfileStoreModule = {

	IsClosing = false,
	IsCriticalState = false,
	OnError = OnError, -- (message, store_name, profile_key)
	OnOverwrite = OnOverwrite, -- (store_name, profile_key)
	OnCriticalToggle = Signal.New(), -- (is_critical)
	DataStoreState = "NotReady", -- ("NotReady", "NoInternet", "NoAccess", "Access")

}
ProfileStore.__index = ProfileStore

function ProfileStore.SetConstant(name, value)

	if type(value) ~= "number" then
		error(`[{script.Name}]: Invalid value type`)
	end

	if name == "AUTO_SAVE_PERIOD" then
		AUTO_SAVE_PERIOD = value
	elseif name == "LOAD_REPEAT_PERIOD" then
		LOAD_REPEAT_PERIOD = value
	elseif name == "FIRST_LOAD_REPEAT" then
		FIRST_LOAD_REPEAT = value
	elseif name == "SESSION_STEAL" then
		SESSION_STEAL = value
	elseif name == "ASSUME_DEAD" then
		ASSUME_DEAD = value
	elseif name == "START_SESSION_TIMEOUT" then
		START_SESSION_TIMEOUT = value
	elseif name == "CRITICAL_STATE_ERROR_COUNT" then
		CRITICAL_STATE_ERROR_COUNT = value
	elseif name == "CRITICAL_STATE_ERROR_EXPIRE" then
		CRITICAL_STATE_ERROR_EXPIRE = value
	elseif name == "CRITICAL_STATE_EXPIRE" then
		CRITICAL_STATE_EXPIRE = value
	elseif name == "MAX_MESSAGE_QUEUE" then
		MAX_MESSAGE_QUEUE = value
	else
		error(`[{script.Name}]: Invalid constant name was provided`)
	end

end

function ProfileStore.Test()
	return {
		ActiveSessionCheck = ActiveSessionCheck,
		AutoSaveList = AutoSaveList,
		ActiveProfileLoadJobs = ActiveProfileLoadJobs,
		ActiveProfileSaveJobs = ActiveProfileSaveJobs,
		MockStore = MockStore,
		UserMockStore = UserMockStore,
		UpdateQueue = UpdateQueue,
	}
end

function ProfileStore.New(store_name, template)

	template = template or {}

	if type(store_name) ~= "string" then
		error(`[{script.Name}]: Invalid or missing "store_name"`)
	elseif string.len(store_name) == 0 then
		error(`[{script.Name}]: store_name cannot be an empty string`)
	elseif string.len(store_name) > 50 then
		error(`[{script.Name}]: store_name is too long`)
	end

	if type(template) ~= "table" then
		error(`[{script.Name}]: Invalid template argument`)
	end

	local self
	self = {

		Mock = {

			Name = store_name,

			StartSessionAsync = function(_, profile_key)
				MockFlag = true
				return self:StartSessionAsync(profile_key)
			end,
			MessageAsync = function(_, profile_key, message)
				MockFlag = true
				return self:MessageAsync(profile_key, message)
			end,
			GetAsync = function(_, profile_key, version)
				MockFlag = true
				return self:GetAsync(profile_key, version)
			end,
			VersionQuery = function(_, profile_key, sort_direction, min_date, max_date)
				MockFlag = true
				return self:VersionQuery(profile_key, sort_direction, min_date, max_date)
			end,
			RemoveAsync = function(_, profile_key)
				MockFlag = true
				return self:RemoveAsync(profile_key)
			end
		},

		Name = store_name,

		template = template,
		data_store = nil,
		load_jobs = {},
		mock_load_jobs = {},
		is_ready = true,

	}
	setmetatable(self, ProfileStore)

	local options = Instance.new("DataStoreOptions")
	options:SetExperimentalFeatures({v2 = true})

	if DataStoreState == "NotReady" then

		-- The module is not sure whether DataStores are accessible yet:

		self.is_ready = false

		task.spawn(function()

			repeat task.wait() until DataStoreState ~= "NotReady"

			if DataStoreState == "Access" then
				self.data_store = DataStoreService:GetDataStore(store_name, nil, options)
			end

			self.is_ready = true

		end)

	elseif DataStoreState == "Access" then

		self.data_store = DataStoreService:GetDataStore(store_name, nil, options)

	end

	return self

end

local function RobloxMessageSubscription(profile, unique_session_id)

	local last_roblox_message = 0

	local roblox_message_subscription = MessagingService:SubscribeAsync("PS_" .. unique_session_id, function(message)
		if type(message.Data) == "table" and message.Data.LoadCount == profile.SessionLoadCount then
			-- High reaction rate, based on numPlayers × 10 DataStore budget as of writing
			if os.clock() - last_roblox_message > 6 then 
				last_roblox_message = os.clock()
				if profile:IsActive() == true then
					if message.Data.EndSession == true then
						SaveProfileAsync(profile, true, false, "External")
					else
						profile:Save()
					end
				end
			end
		end
	end)

	if profile:IsActive() == true then
		profile.roblox_message_subscription = roblox_message_subscription
	else
		roblox_message_subscription:Disconnect()
	end

end

function ProfileStore:StartSessionAsync(profile_key, params)

	local is_mock = ReadMockFlag()

	if type(profile_key) ~= "string" then
		error(`[{script.Name}]: profile_key must be a string`)
	elseif string.len(profile_key) == 0 then
		error(`[{script.Name}]: Invalid profile_key`)
	elseif string.len(profile_key) > 50 then
		error(`[{script.Name}]: profile_key is too long`)
	end

	if params ~= nil and type(params) ~= "table" then
		error(`[{script.Name}]: Invalid params`)
	end

	params = params or {}

	if ProfileStore.IsClosing == true then
		return nil
	end

	WaitForStoreReady(self)

	local session_token = SessionToken(self.Name, profile_key, is_mock)

	if ActiveSessionCheck[session_token] ~= nil then
		error(`[{script.Name}]: Profile (STORE:{self.Name}; KEY:{profile_key}) is already loaded in this session`)
	end

	ActiveProfileLoadJobs = ActiveProfileLoadJobs + 1

	local is_user_cancel = false

	local function cancel_condition()
		if is_user_cancel == false then
			if params.Cancel ~= nil then
				is_user_cancel = params.Cancel() == true
			end
			return is_user_cancel
		end
		return true
	end

	local user_steal = params.Steal == true

	local force_load_steps = 0 -- Session conflict handling values
	local request_force_load = true
	local steal_session = false

	local start = os.clock()
	local exp_backoff = 1

	while ProfileStore.IsClosing == false and cancel_condition() == false do

		-- Load profile:

		-- SPECIAL CASE - If StartSessionAsync is called for the same key again before another StartSessionAsync finishes,
		-- grab the DataStore return for the new call. The early call will return nil. This is supposed to retain
		-- expected and efficient behavior in cases where a player would quickly rejoin the same server.

		LoadIndex += 1
		local load_id = LoadIndex
		local profile_load_jobs = is_mock == true and self.mock_load_jobs or self.load_jobs
		local profile_load_job = profile_load_jobs[profile_key] -- {load_id, {loaded_data, key_info} or nil}

		local loaded_data, key_info
		local unique_session_id = HttpService:GenerateGUID(false)

		if profile_load_job ~= nil then

			profile_load_job[1] = load_id -- Steal load job
			while profile_load_job[2] == nil do -- Wait for job to finish
				task.wait()
			end
			if profile_load_job[1] == load_id then -- Load job hasn't been double-stolen
				loaded_data, key_info = table.unpack(profile_load_job[2])
				profile_load_jobs[profile_key] = nil
			else
				ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
				return nil
			end

		else

			profile_load_job = {load_id, nil}
			profile_load_jobs[profile_key] = profile_load_job

			profile_load_job[2] = table.pack(UpdateAsync(
				self,
				profile_key,
				{
					ExistingProfileHandle = function(latest_data)

						if ProfileStore.IsClosing == true or cancel_condition() == true then
							return
						end

						local active_session = latest_data.MetaData.ActiveSession
						local force_load_session = latest_data.MetaData.ForceLoadSession

						if active_session == nil then
							latest_data.MetaData.ActiveSession = {PlaceId, JobId, unique_session_id}
							latest_data.MetaData.ForceLoadSession = nil
						elseif type(active_session) == "table" then
							if IsThisSession(active_session) == false then
								local last_update = latest_data.MetaData.LastUpdate
								if last_update ~= nil then
									if os.time() - last_update > ASSUME_DEAD then
										latest_data.MetaData.ActiveSession = {PlaceId, JobId, unique_session_id}
										latest_data.MetaData.ForceLoadSession = nil
										return
									end
								end
								if steal_session == true or user_steal == true then
									local force_load_interrupted = if force_load_session ~= nil then not IsThisSession(force_load_session) else true
									if force_load_interrupted == false or user_steal == true then
										latest_data.MetaData.ActiveSession = {PlaceId, JobId, unique_session_id}
										latest_data.MetaData.ForceLoadSession = nil
									end
								elseif request_force_load == true then
									latest_data.MetaData.ForceLoadSession = {PlaceId, JobId}
								end
							else
								latest_data.MetaData.ForceLoadSession = nil
							end
						end

					end,
					MissingProfileHandle = function(latest_data)

						local is_cancel = ProfileStore.IsClosing == true or cancel_condition() == true

						latest_data.Data = DeepCopyTable(self.template)
						latest_data.MetaData = {
							ProfileCreateTime = os.time(),
							SessionLoadCount = 0,
							ActiveSession = if is_cancel == false then {PlaceId, JobId, unique_session_id} else nil,
							ForceLoadSession = nil,
							MetaTags = {}, -- Backwards compatibility with ProfileService
						}

					end,
					EditProfile = function(latest_data)

						if ProfileStore.IsClosing == true or cancel_condition() == true then
							return
						end

						local active_session = latest_data.MetaData.ActiveSession
						if active_session ~= nil and IsThisSession(active_session) == true then
							latest_data.MetaData.SessionLoadCount = latest_data.MetaData.SessionLoadCount + 1
							latest_data.MetaData.LastUpdate = os.time()
						end

					end,
				},
				is_mock
				))
			if profile_load_job[1] == load_id then -- Load job hasn't been stolen
				loaded_data, key_info = table.unpack(profile_load_job[2])
				profile_load_jobs[profile_key] = nil
			else
				ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
				return nil -- Load job stolen
			end
		end

		-- Handle load_data:

		if loaded_data ~= nil and key_info ~= nil then
			local active_session = loaded_data.MetaData.ActiveSession
			if type(active_session) == "table" then

				if IsThisSession(active_session) == true then

					-- Profile is now taken by this session:

					local profile = Profile.New(loaded_data, key_info, self, profile_key, is_mock, session_token)
					AddProfileToAutoSave(profile)

					if is_mock ~= true and DataStoreState == "Access" then

						-- Use MessagingService to quickly detect session conflicts and resolve them quickly:
						task.spawn(RobloxMessageSubscription, profile, unique_session_id) -- Blocking prevention

					end

					if ProfileStore.IsClosing == true or cancel_condition() == true then
						-- The server has initiated a shutdown by the time this profile was loaded
						SaveProfileAsync(profile, true) -- Release profile and yield until the DataStore call is finished
						profile = nil -- Don't return the profile object
					end

					ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
					return profile

				else

					if ProfileStore.IsClosing == true or cancel_condition() == true then
						ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
						return nil
					end

					-- Profile is taken by some other session:

					local force_load_session = loaded_data.MetaData.ForceLoadSession
					local force_load_interrupted = if force_load_session ~= nil then not IsThisSession(force_load_session) else true

					if force_load_interrupted == false then

						if request_force_load == false then
							force_load_steps = force_load_steps + 1
							if force_load_steps >= math.ceil(SESSION_STEAL / LOAD_REPEAT_PERIOD) then
								steal_session = true
							end
						end

						-- Request the remote server to end its session:
						if type(active_session[3]) == "string" then
							local session_load_count = loaded_data.MetaData.SessionLoadCount or 0
							task.spawn(MessagingService.PublishAsync, MessagingService, "PS_" .. active_session[3], {LoadCount = session_load_count, EndSession = true})
						end

						-- Attempt to load the profile again after a delay
						local wait_until = os.clock() + if request_force_load == true then FIRST_LOAD_REPEAT else LOAD_REPEAT_PERIOD
						repeat task.wait() until os.clock() >= wait_until or ProfileStore.IsClosing == true

					else
						-- Another session tried to load this profile:
						ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
						return nil
					end

					request_force_load = false -- Only request a force load once

				end

			else
				ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
				return nil -- In this scenario it is likely that this server started shutting down
			end
		else

			-- A DataStore call has likely ended in an error:

			local default_timeout = false

			if params.Cancel == nil then
				default_timeout = os.clock() - start >= START_SESSION_TIMEOUT
			end

			if default_timeout == true or ProfileStore.IsClosing == true or cancel_condition() == true then
				ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
				return nil
			end

			task.wait(exp_backoff)  -- Repeat the call shortly
			exp_backoff = math.min(20, exp_backoff * 2)

		end

	end

	ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
	return nil -- Game started shutting down or the request was cancelled - don't return the profile

end

function ProfileStore:MessageAsync(profile_key, message)

	local is_mock = ReadMockFlag()

	if type(profile_key) ~= "string" then
		error(`[{script.Name}]: profile_key must be a string`)
	elseif string.len(profile_key) == 0 then
		error(`[{script.Name}]: Invalid profile_key`)
	elseif string.len(profile_key) > 50 then
		error(`[{script.Name}]: profile_key is too long`)
	end

	if type(message) ~= "table" then
		error(`[{script.Name}]: message must be a table`)
	end

	if ProfileStore.IsClosing == true then
		return false
	end

	WaitForStoreReady(self)

	local exp_backoff = 1

	while ProfileStore.IsClosing == false do

		-- Updating profile:

		local loaded_data = UpdateAsync(
			self,
			profile_key,
			{
				ExistingProfileHandle = nil,
				MissingProfileHandle = nil,
				EditProfile = function(latest_data)

					local global_updates = latest_data.GlobalUpdates
					local update_list = global_updates[2]
					--{
					--	update_index,
					--	{
					--		{update_index, data}, ...
					--	},
					--},

					global_updates[1] += 1
					table.insert(update_list, {global_updates[1], message})

					-- Clearing queue if above limit:

					while #update_list > MAX_MESSAGE_QUEUE do
						table.remove(update_list, 1)
					end

				end,
			},
			is_mock
		)

		if loaded_data ~= nil then

			local session_token = SessionToken(self.Name, profile_key, is_mock)

			local profile = ActiveSessionCheck[session_token]

			if profile ~= nil then

				-- The message was sent to a profile that is active in this server:
				profile:Save()

			else

				local meta_data = loaded_data.MetaData or {}
				local active_session = meta_data.ActiveSession
				local session_load_count = meta_data.SessionLoadCount or 0

				if type(active_session) == "table" and type(active_session[3]) == "string" then
					-- Request the remote server to auto-save sooner and receive the message:
					task.spawn(MessagingService.PublishAsync, MessagingService, "PS_" .. active_session[3], {LoadCount = session_load_count})
				end

			end

			return true

		else

			task.wait(exp_backoff) -- A DataStore call has likely ended in an error - repeat the call shortly
			exp_backoff = math.min(20, exp_backoff * 2)

		end

	end

	return false

end

function ProfileStore:GetAsync(profile_key, version)

	local is_mock = ReadMockFlag()

	if type(profile_key) ~= "string" then
		error(`[{script.Name}]: profile_key must be a string`)
	elseif string.len(profile_key) == 0 then
		error(`[{script.Name}]: Invalid profile_key`)
	elseif string.len(profile_key) > 50 then
		error(`[{script.Name}]: profile_key is too long`)
	end

	if ProfileStore.IsClosing == true then
		return nil
	end

	WaitForStoreReady(self)

	if version ~= nil and (is_mock or DataStoreState ~= "Access") then
		return nil -- No version support in mock mode
	end

	local exp_backoff = 1

	while ProfileStore.IsClosing == false do

		-- Load profile:

		local loaded_data, key_info = UpdateAsync(
			self,
			profile_key,
			{
				ExistingProfileHandle = nil,
				MissingProfileHandle = function(latest_data)

					latest_data.Data = DeepCopyTable(self.template)
					latest_data.MetaData = {
						ProfileCreateTime = os.time(),
						SessionLoadCount = 0,
						ActiveSession = nil,
						ForceLoadSession = nil,
						MetaTags = {}, -- Backwards compatibility with ProfileService
					}

				end,
				EditProfile = nil,
			},
			is_mock,
			true, -- Use :GetAsync()
			version -- DataStore key version
		)

		-- Handle load_data:

		if loaded_data ~= nil then

			if key_info == nil then
				return nil -- Load was successful, but the key was empty - return no profile object
			end

			local profile = Profile.New(loaded_data, key_info, self, profile_key, is_mock)
			profile.view_mode = true

			return profile

		else

			task.wait(exp_backoff) -- A DataStore call has likely ended in an error - repeat the call shortly
			exp_backoff = math.min(20, exp_backoff * 2)

		end

	end

	return nil -- Game started shutting down - don't return the profile

end

function ProfileStore:RemoveAsync(profile_key)

	local is_mock = ReadMockFlag()

	if type(profile_key) ~= "string" or string.len(profile_key) == 0 then
		error(`[{script.Name}]: Invalid profile_key`)
	end

	if ProfileStore.IsClosing == true then
		return false
	end

	WaitForStoreReady(self)

	local wipe_status = false

	local next_in_queue = WaitInUpdateQueue(SessionToken(self.Name, profile_key, is_mock))

	if is_mock == true then -- Used when the profile is accessed through ProfileStore.Mock

		local mock_data_store = UserMockStore[self.Name]

		if mock_data_store ~= nil then
			mock_data_store[profile_key] = nil
			if next(mock_data_store) == nil then
				UserMockStore[self.Name] = nil
			end
		end

		wipe_status = true
		task.wait() -- Simulate API call yield

	elseif DataStoreState ~= "Access" then -- Used when API access is disabled

		local mock_data_store = MockStore[self.Name]

		if mock_data_store ~= nil then
			mock_data_store[profile_key] = nil
			if next(mock_data_store) == nil then
				MockStore[self.Name] = nil
			end
		end

		wipe_status = true
		task.wait() -- Simulate API call yield

	else -- Live DataStore

		wipe_status = pcall(function()
			self.data_store:RemoveAsync(profile_key)
		end)

	end

	next_in_queue()

	return wipe_status

end

local ProfileVersionQuery = {}
ProfileVersionQuery.__index = ProfileVersionQuery

function ProfileVersionQuery.New(profile_store, profile_key, sort_direction, min_date, max_date, is_mock)

	local self = {
		profile_store = profile_store,
		profile_key = profile_key,
		sort_direction = sort_direction,
		min_date = min_date,
		max_date = max_date,

		query_pages = nil,
		query_index = 0,
		query_failure = false,

		is_query_yielded = false,
		query_queue = {},

		is_mock = is_mock,
	}
	setmetatable(self, ProfileVersionQuery)

	return self

end

function MoveVersionQueryQueue(self) -- Hidden ProfileVersionQuery method
	while #self.query_queue > 0 do

		local queue_entry = table.remove(self.query_queue, 1)

		task.spawn(queue_entry)

		if self.is_query_yielded == true then
			break
		end

	end
end

local VersionQueryNextAsyncStackingFlag = false
local WarnAboutVersionQueryOnce = false

function ProfileVersionQuery:NextAsync()

	local is_stacking = VersionQueryNextAsyncStackingFlag == true
	VersionQueryNextAsyncStackingFlag = false

	WaitForStoreReady(self.profile_store)

	if ProfileStore.IsClosing == true then
		return nil -- Silently fail :NextAsync() requests
	end

	if self.is_mock == true or DataStoreState ~= "Access" then
		if IsStudio == true and WarnAboutVersionQueryOnce == false then
			WarnAboutVersionQueryOnce = true
			warn(`[{script.Name}]: :VersionQuery() is not supported in mock mode!`)
		end
		return nil -- Silently fail :NextAsync() requests
	end

	local profile
	local is_finished = false

	local function query_job()

		if self.query_failure == true then
			is_finished = true
			return
		end

		-- First "next" call loads version pages:

		if self.query_pages == nil then

			self.is_query_yielded = true

			task.spawn(function()
				VersionQueryNextAsyncStackingFlag = true
				profile = self:NextAsync()
				is_finished = true
			end)

			local list_success, error_message = pcall(function()
				self.query_pages = self.profile_store.data_store:ListVersionsAsync(
					self.profile_key,
					self.sort_direction,
					self.min_date,
					self.max_date
				)
				self.query_index = 0
			end)

			if list_success == false or self.query_pages == nil then
				warn(`[{script.Name}]: Version query fail - {tostring(error_message)}`)
				self.query_failure = true
			end

			self.is_query_yielded = false

			MoveVersionQueryQueue(self)

			return

		end

		local current_page = self.query_pages:GetCurrentPage()
		local next_item = current_page[self.query_index + 1]

		-- No more entries:

		if self.query_pages.IsFinished == true and next_item == nil then
			is_finished = true
			return
		end

		-- Load next page when this page is over:

		if next_item == nil then

			self.is_query_yielded = true
			task.spawn(function()
				VersionQueryNextAsyncStackingFlag = true
				profile = self:NextAsync()
				is_finished = true
			end)

			local success, error_message = pcall(function()
				self.query_pages:AdvanceToNextPageAsync()
				self.query_index = 0
			end)

			if success == false or #self.query_pages:GetCurrentPage() == 0 then
				self.query_failure = true
			end

			self.is_query_yielded = false
			MoveVersionQueryQueue(self)

			return

		end

		-- Next page item:

		self.query_index += 1
		profile = self.profile_store:GetAsync(self.profile_key, next_item.Version)
		is_finished = true

	end

	if self.is_query_yielded == false then
		query_job()
	else
		if is_stacking == true then
			table.insert(self.query_queue, 1, query_job)
		else
			table.insert(self.query_queue, query_job)
		end
	end

	while is_finished == false do
		task.wait()
	end

	return profile

end

function ProfileStore:VersionQuery(profile_key, sort_direction, min_date, max_date)

	local is_mock = ReadMockFlag()

	if type(profile_key) ~= "string" or string.len(profile_key) == 0 then
		error(`[{script.Name}]: Invalid profile_key`)
	end

	-- Type check:

	if sort_direction ~= nil and (typeof(sort_direction) ~= "EnumItem"
		or sort_direction.EnumType ~= Enum.SortDirection) then
		error(`[{script.Name}]: Invalid sort_direction ({tostring(sort_direction)})`)
	end

	if min_date ~= nil and typeof(min_date) ~= "DateTime" and typeof(min_date) ~= "number" then
		error(`[{script.Name}]: Invalid min_date ({tostring(min_date)})`)
	end

	if max_date ~= nil and typeof(max_date) ~= "DateTime" and typeof(max_date) ~= "number" then
		error(`[{script.Name}]: Invalid max_date ({tostring(max_date)})`)
	end

	min_date = typeof(min_date) == "DateTime" and min_date.UnixTimestampMillis or min_date
	max_date = typeof(max_date) == "DateTime" and max_date.UnixTimestampMillis or max_date

	return ProfileVersionQuery.New(self, profile_key, sort_direction, min_date, max_date, is_mock)

end

-- DataStore API access check:

if IsStudio == true then

	task.spawn(function()

		local new_state = "NoAccess"

		local status, message = pcall(function()
			-- This will error if current instance has no Studio API access:
			DataStoreService:GetDataStore("____PS"):SetAsync("____PS", os.time())
		end)

		local no_internet_access = status == false and string.find(message, "ConnectFail", 1, true) ~= nil

		if no_internet_access == true then
			warn(`[{script.Name}]: No internet access - check your network connection`)
		end

		if status == false and
			(string.find(message, "403", 1, true) ~= nil or -- Cannot write to DataStore from studio if API access is not enabled
				string.find(message, "must publish", 1, true) ~= nil or -- Game must be published to access live keys
				no_internet_access == true) then -- No internet access

			new_state = if no_internet_access == true then "NoInternet" else "NoAccess"
			print(`[{script.Name}]: Roblox API services unavailable - data will not be saved`)
		else
			new_state = "Access"
			print(`[{script.Name}]: Roblox API services available - data will be saved`)
		end

		DataStoreState = new_state
		ProfileStore.DataStoreState = new_state

	end)

else

	DataStoreState = "Access"
	ProfileStore.DataStoreState = "Access"

end

-- Update loop:

RunService.Heartbeat:Connect(function()

	-- Auto saving:

	local auto_save_list_length = #AutoSaveList
	if auto_save_list_length > 0 then
		local auto_save_index_speed = AUTO_SAVE_PERIOD / auto_save_list_length
		local os_clock = os.clock()
		while os_clock - LastAutoSave > auto_save_index_speed do
			LastAutoSave = LastAutoSave + auto_save_index_speed
			local profile = AutoSaveList[AutoSaveIndex]
			if os_clock - profile.load_timestamp < AUTO_SAVE_PERIOD / 2 then
				-- This profile is freshly loaded - auto saving immediately is not necessary:
				profile = nil
				for _ = 1, auto_save_list_length - 1 do
					-- Move auto save index to the right:
					AutoSaveIndex = AutoSaveIndex + 1
					if AutoSaveIndex > auto_save_list_length then
						AutoSaveIndex = 1
					end
					profile = AutoSaveList[AutoSaveIndex]
					if os_clock - profile.load_timestamp >= AUTO_SAVE_PERIOD / 2 then
						break
					else
						profile = nil
					end
				end
			end
			-- Move auto save index to the right:
			AutoSaveIndex = AutoSaveIndex + 1
			if AutoSaveIndex > auto_save_list_length then
				AutoSaveIndex = 1
			end
			-- Perform save call:
			if profile ~= nil then
				task.spawn(SaveProfileAsync, profile) -- Auto save profile in new thread
			end
		end
	end

	-- Critical state handling:

	if ProfileStore.IsCriticalState == false then
		if #IssueQueue >= CRITICAL_STATE_ERROR_COUNT then
			ProfileStore.IsCriticalState = true
			ProfileStore.OnCriticalToggle:Fire(true)
			CriticalStateStart = os.clock()
			warn(`[{script.Name}]: Entered critical state`)
		end
	else
		if #IssueQueue >= CRITICAL_STATE_ERROR_COUNT then
			CriticalStateStart = os.clock()
		elseif os.clock() - CriticalStateStart > CRITICAL_STATE_EXPIRE then
			ProfileStore.IsCriticalState = false
			ProfileStore.OnCriticalToggle:Fire(false)
			warn(`[{script.Name}]: Critical state ended`)
		end
	end

	-- Issue queue:

	while true do
		local issue_time = IssueQueue[1]
		if issue_time == nil then
			break
		elseif os.clock() - issue_time > CRITICAL_STATE_ERROR_EXPIRE then
			table.remove(IssueQueue, 1)
		else
			break
		end
	end

end)

-- Release all loaded profiles when the server is shutting down:

task.spawn(function()

	while DataStoreState == "NotReady" do
		task.wait()
	end

	if DataStoreState ~= "Access" then

		game:BindToClose(function()
			ProfileStore.IsClosing = true
			task.wait() -- Mock shutdown delay
		end)

		return -- Don't wait for profiles to properly save in mock mode so studio could end the simulation faster

	end

	game:BindToClose(function()

		ProfileStore.IsClosing = true

		-- Release all active profiles:
		-- (Clone AutoSaveList to a new table because AutoSaveList changes when profiles are released)

		local on_close_save_job_count = 0
		local active_profiles = {}
		for index, profile in ipairs(AutoSaveList) do
			active_profiles[index] = profile
		end

		-- Release the profiles; Releasing profiles can trigger listeners that release other profiles, so check active state:
		for _, profile in ipairs(active_profiles) do
			if profile:IsActive() == true then
				on_close_save_job_count = on_close_save_job_count + 1
				task.spawn(function() -- Save profile on new thread
					SaveProfileAsync(profile, true, nil, "Shutdown")
					on_close_save_job_count = on_close_save_job_count - 1
				end)
			end
		end

		-- Yield until all active profile jobs are finished:
		while on_close_save_job_count > 0 or ActiveProfileLoadJobs > 0 or ActiveProfileSaveJobs > 0 do
			task.wait()
		end

		return -- We're done!

	end)

end)

return ProfileStore

end)()

modules.ProfileStoreMigration=(function()
-- Converts only recognized legacy envelopes after making an immutable backup.
-- ProfileStore itself is installed unchanged. No cloud calls run from this module on require.
local P=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Progression"))
local Migration={}
local function payloadValid(data)
	if type(data)~="table" then return false,"Profile data is not a table" end
	if data.SchemaVersion~=nil and (type(data.SchemaVersion)~="number" or data.SchemaVersion>1) then return false,"Unsupported profile schema" end
	if data.Cash~=nil and (type(data.Cash)~="number" or data.Cash~=data.Cash or data.Cash<0 or data.Cash==math.huge) then return false,"Invalid Cash data" end
	for _,key in ipairs({"Energy","Rank","Stats","Inventory","Equipped","Season","Quests","Login","Achievements","Settings","ProcessedMatchIds","MatchReceipts","Reservations","Pairs","SocialRewards"}) do
		if data[key]~=nil and type(data[key])~="table" then return false,"Invalid "..key.." data" end
	end
	local function shape(actual,template,path)
		for key,expected in pairs(template) do local value=actual[key]
			if value~=nil then
				if type(value)~=type(expected) then return false,"Invalid "..path..key.." data" end
				if type(value)=="number" and (value~=value or math.abs(value)==math.huge) then return false,"Invalid "..path..key.." number" end
				if type(expected)=="table" then local ok,text=shape(value,expected,path..key.."."); if not ok then return false,text end end
			end
		end
		return true
	end
	local compatible,message=shape(data,P.default(0),""); if not compatible then return false,message end
	return true
end
Migration.payloadValid=payloadValid
function Migration.isProfileStore(record)
	return type(record)=="table" and type(record.Data)=="table" and type(record.MetaData)=="table"
		and type(record.MetaData.SessionLoadCount)=="number" and type(record.GlobalUpdates)=="table"
		and type(record.GlobalUpdates[1])=="number" and type(record.GlobalUpdates[2])=="table"
end
function Migration.prepare(store,backup,key,userId,allowConversion,retry,cancelled)
	local readOK,record,info=retry(function() return store:GetAsync(key) end)
	if not readOK then return false,"Existing save could not be read; no default profile was created." end
	if cancelled() then return false,"Profile loading was cancelled" end
	if record==nil then return true end
	if Migration.isProfileStore(record) then return payloadValid(record.Data) end
	if type(record)~="table" then return false,"Unrecognized save format; existing data was left untouched." end
	if record.MetaData~=nil or record.GlobalUpdates~=nil then return false,"Malformed ProfileStore envelope; restore or inspect it manually. Migration did not replace it." end
	local data=record.Data~=nil and record.Data or record
	local valid,problem=payloadValid(data); if not valid then return false,problem end
	if data.SchemaVersion==nil and data.Cash==nil and data.Rank==nil and data.Energy==nil then return false,"Unrecognized legacy profile; migration refused." end
	if record.Lease~=nil then
		if type(record.Lease)~="table" or type(record.Lease.Expires)~="number" then return false,"Invalid legacy lease; migration refused." end
		if record.Lease.Expires>os.time() then return false,"A legacy server still owns this profile. Reconnect after it closes." end
	end
	if not allowConversion then return false,"Legacy conversion is disabled; existing data was left untouched." end
	local version=info and info.Version
	if type(version)~="string" then return false,"Existing save version could not be verified; migration refused." end
	local backupOK,snapshot=retry(function()
		return backup:UpdateAsync(key,function(old)
			if old~=nil then return old.SourceVersion==version and old or nil end
			return {Original=P.clone(record),SourceVersion=version,BackedUpAt=os.time(),UserId=userId}
		end)
	end)
	if not backupOK or not snapshot or snapshot.SourceVersion~=version then return false,"Legacy backup could not be verified; conversion was not performed." end
	if cancelled() then return false,"Profile loading was cancelled" end
	local migrated=false
	local writeOK,written=retry(function()
		return store:UpdateAsync(key,function(latest,keyInfo)
			migrated=false
			if Migration.isProfileStore(latest) then migrated=true; return latest end
			if not keyInfo or keyInfo.Version~=version or cancelled() then return nil end
			if latest.Lease and latest.Lease.Expires>os.time() then return nil end
			migrated=true
			return {Data=P.clone(data),MetaData={ProfileCreateTime=data.CreatedAt or os.time(),SessionLoadCount=0,LastUpdate=os.time(),MetaTags={}},
				RobloxMetaData={TetrisLegacySourceVersion=version},UserIds={userId},GlobalUpdates={0,{}}}
		end)
	end)
	if not writeOK or not migrated or not written then return false,"Existing save changed during migration; no player data was replaced." end
	return payloadValid(written.Data)
end
return Migration

end)()

modules.PlayerDataService=(function()
-- Central profile authority. Live rollout stays on the original backend until verified.
local DSS=game:GetService("DataStoreService")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local Config=require(script.Parent:WaitForChild("GameConfig"))
local studio=RunService:IsStudio()
if not studio and not Config.ProfileStoreLiveEnabled then
	return require(script.Parent:WaitForChild("LegacyPlayerDataService"))
end
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local P=require(Shared:WaitForChild("Progression"))
local Catalog=require(Shared:WaitForChild("Catalog"))
local ProfileStore=require(script.Parent:WaitForChild("ProfileStore"))
local Migration=require(script.Parent:WaitForChild("ProfileStoreMigration"))
local namespace=studio and Config.ProfileStoreTestDataStoreName or Config.DataStoreName.."_Live"
assert(type(namespace)=="string" and #namespace<=43,"ProfileStore namespace is missing or too long")
local Data={Profiles={},Loading={},Debug=studio and Config.Debug and not Config.ProfileStoreStudioPersistence,Config=Config,Namespace=namespace,Closing=false}
local playerStore=ProfileStore.New(namespace,P.default(0))
local store=DSS:GetDataStore(namespace)
local backup=DSS:GetDataStore(namespace.."_Backup")
local inbox=DSS:GetDataStore(namespace.."_Results")
local function retry(fn)
	local problem
	for attempt=1,4 do
		local values=table.pack(pcall(fn))
		if values[1] then return true,table.unpack(values,2,values.n) end
		problem=values[2]; if attempt<4 then task.wait(0.5*2^(attempt-1)) end
	end
	return false,tostring(problem)
end
local function active(entry) return entry and entry.Active and not entry.Releasing and entry.Profile:IsActive() end
local function endEntry(self,entry,unexpected)
	entry.Ready=false; entry.Active=false; entry.Releasing=true
	if entry.Profile:IsActive() then entry.Profile:EndSession() end
	if self.Profiles[entry.Player.UserId]==entry then self.Profiles[entry.Player.UserId]=nil end
	if unexpected and entry.Player.Parent==Players and not self.Closing and not ProfileStore.IsClosing then entry.Player:Kick("Your data session ended. Please reconnect; your existing save was not reset.") end
end
local function commit(self,entry,nextData)
	if not active(entry) then return false,"Data session closed" end
	local token=Http:GenerateGUID(false); nextData._TetrisSaveToken=token
	entry.Profile.Data=nextData; entry.Data=nextData
	if self.Debug then return true end -- Explicit Studio-only ProfileStore.Mock session.
	local deadline=os.clock()+Config.ProfileSaveTimeout; local nextAttempt=0
	while active(entry) and os.clock()<deadline do
		if entry.Profile.LastSavedData._TetrisSaveToken==token then return true end
		if os.clock()>=nextAttempt then entry.Profile:Save(); nextAttempt=os.clock()+2 end
		if entry.Profile.LastSavedData._TetrisSaveToken==token and active(entry) then return true end
		task.wait(0.05)
	end
	-- The write may already have reached Roblox. Preserve the atomic Cash/item pair,
	-- close access and let ProfileStore finish its final save instead of pretending to roll it back.
	endEntry(self,entry,not entry.Releasing)
	return false,"Save confirmation was interrupted. Reconnect to check the completed operation."
end
function Data:load(player)
	local existing=self.Profiles[player.UserId]
	if active(existing) then return existing.Player==player and existing.Ready,"Data is already active in this server" end
	if self.Loading[player.UserId] then return false,"A profile load is already in progress" end
	self.Loading[player.UserId]=player
	local deadline=os.clock()+Config.ProfileLoadTimeout
	local function cancelled() return self.Closing or ProfileStore.IsClosing or player.Parent~=Players or os.clock()>=deadline end
	local function fail(text,entry)
		if entry then endEntry(self,entry,false) end
		if self.Loading[player.UserId]==player then self.Loading[player.UserId]=nil end
		return false,text
	end
	if cancelled() then return fail("Profile loading was cancelled") end
	if not self.Debug then
		while ProfileStore.DataStoreState=="NotReady" and not cancelled() do task.wait(0.05) end
		if cancelled() or ProfileStore.DataStoreState~="Access" then return fail("Persistent data is unavailable. Enable API access in the separate test experience; no mock production profile was created.") end
		local prepared,text=Migration.prepare(store,backup,tostring(player.UserId),player.UserId,Config.ProfileStoreMigrateLegacy,retry,cancelled)
		if not prepared then return fail(text) end
	end
	local target=self.Debug and playerStore.Mock or playerStore
	local started,profile=pcall(function() return target:StartSessionAsync(tostring(player.UserId),{Cancel=cancelled}) end)
	if not started or not profile then return fail("Your profile could not be loaded. No purchases or rewards were enabled; please reconnect.") end
	local entry={Player=player,Profile=profile,Data=profile.Data,Active=true,Ready=false,Busy=false,Releasing=false}
	self.Profiles[player.UserId]=entry
	profile.OnSessionEnd:Connect(function()
		local unexpected=not entry.Releasing
		entry.Active=false; entry.Ready=false
		if self.Profiles[player.UserId]==entry then self.Profiles[player.UserId]=nil end
		if unexpected and player.Parent==Players and not self.Closing and not ProfileStore.IsClosing then player:Kick("Your data session ended. Please reconnect.") end
	end)
	if cancelled() or not profile:IsActive() then return fail("Profile loading was cancelled",entry) end
	local checked,text=Migration.payloadValid(profile.Data); if not checked then return fail(text,entry) end
	local initialized,problem=pcall(function()
		profile:AddUserId(player.UserId); profile:Reconcile()
		if profile.Data.CreatedAt==0 then profile.Data.CreatedAt=profile.FirstSessionTime end
		entry.Data=P.validate(P.clone(profile.Data),os.time(),Catalog,Config); profile.Data=entry.Data
	end)
	if not initialized then return fail("Your existing profile needs manual inspection; it was not reset. "..tostring(problem),entry) end
	local pending={}
	if not self.Debug then
		local readOK,value=retry(function() return inbox:GetAsync(tostring(player.UserId)) end)
		if not readOK or value~=nil and type(value)~="table" then return fail("Pending results could not be recovered. Please reconnect.",entry) end
		pending=value or {}
	end
	local nextData=P.clone(entry.Data); P.refresh(nextData,os.time(),Config)
	local recovered,recoverError=pcall(function()
		for _,result in pairs(pending) do P.settle(nextData,result,Config) end
		for id in pairs(nextData.Reservations) do P.settle(nextData,{id=id..":refund",kind="Refund",roomId=id},Config) end
	end)
	if not recovered then return fail("Pending results need manual inspection: "..tostring(recoverError),entry) end
	entry.Busy=true; local saved,message=commit(self,entry,nextData); entry.Busy=false
	if not saved then return fail(message,entry) end
	if not self.Debug and next(pending) then
		retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old)
			old=old or {}; for id in pairs(pending) do if entry.Profile.LastSavedData.ProcessedMatchIds[id] then old[id]=nil end end; return old
		end) end)
	end
	if cancelled() or not active(entry) then return fail("Profile loading was cancelled",entry) end
	entry.Ready=true; self.Loading[player.UserId]=nil; return true
end
function Data:get(player)
	local entry=self.Profiles[player.UserId]
	return active(entry) and entry.Ready and entry.Player==player and entry.Data or nil
end
function Data:mutate(player,fn,context)
	local entry=self.Profiles[player.UserId]
	if not active(entry) or not entry.Ready or entry.Player~=player then return false,"Data not loaded" end
	while entry.Busy and active(entry) do task.wait() end
	if not active(entry) or not entry.Ready then return false,"Session closed" end
	entry.Busy=true
	local nextData=P.clone(entry.Data); P.refresh(nextData,os.time(),Config)
	local safe,accepted,message,code=xpcall(function() return fn(nextData) end,function(err) return debug.traceback(tostring(err),2) end)
	if not safe then
		entry.Busy=false
		if studio and Config.CosmeticDebugLogging then warn("[PlayerData] Mutation exception action="..tostring(context and context.Action).." category="..tostring(context and context.Category).." id="..tostring(context and context.Id).."\n"..accepted) end
		return false,"Unable to complete this action right now. Please try again.","InternalError"
	end
	if not accepted then entry.Busy=false; return false,message,code end
	local saved,text=commit(self,entry,nextData); entry.Busy=false
	return saved,saved and message or text
end
function Data:settle(player,result)
	if type(result)~="table" or type(result.id)~="string" then return false end
	if not self.Debug then
		local journaled=retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old) old=old or {}; old[result.id]=P.clone(result); return old end) end)
		if not journaled then return false end
	end
	local saved=self:mutate(player,function(d) P.settle(d,result,Config); return true end)
	if saved and not self.Debug then
		local entry=self.Profiles[player.UserId]
		if entry and entry.Profile.LastSavedData.ProcessedMatchIds[result.id] then
			retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old) old=old or {}; old[result.id]=nil; return old end) end)
		end
	end
	return saved
end
function Data:release(player)
	local entry=self.Profiles[player.UserId]; if not entry or entry.Player~=player then return end
	entry.Ready=false; entry.Releasing=true
	while entry.Busy do task.wait() end
	endEntry(self,entry,false)
end
function Data:public(player)
	local d=self:get(player); if not d then return nil end
	local out=P.refresh(P.clone(d),os.time(),Config); out.ProcessedMatchIds=nil; out.MatchReceipts=nil; out.Reservations=nil; out.Pairs=nil; out.SocialRewards.Seen=nil; out._TetrisSaveToken=nil
	out.Debug=self.Debug; out.Energy.Next=P.nextEnergy(out,os.time(),Config)
	out.DebugPrivileges={FreeCosmetics=self.Debug and Config.FreeCosmeticsInDebug,FreePurchases=self.Debug and Config.FreeShopPurchasesInDebug,InfiniteEnergy=self.Debug and Config.InfiniteEnergyInDebug}
	out.Economy={EnergyCap=Config.EnergyCap,BonusCap=Config.BonusEnergyCap,EnergyInterval=Config.EnergyInterval,RankedCost=Config.RankedCost,SocialEnergy=Config.SocialEnergy,SocialLimit=Config.SocialDailyLimit,SocialMinSeconds=Config.SocialMinSeconds,LoginCash=Config.LoginCash,LoginEnergy=Config.LoginEnergy,SeasonDays=Config.SeasonDays,WinCash=Config.WinCash}
	return out
end
game:BindToClose(function() Data.Closing=true end)
print("[PlayerData] ProfileStore / "..(Data.Debug and "Studio mock" or studio and "isolated persistence test" or "live persistence").." / "..namespace)
return Data

end)()
local Data=modules.PlayerDataService
local ProfileStore=modules.ProfileStore; local ns=Data.Namespace
local a,b=player(101),player(202)
assert(Data:load(a) and Data:load(b)); local pa,pb=Data.Profiles[a.UserId].Profile,Data.Profiles[b.UserId].Profile
assert(pa:IsActive() and pb:IsActive() and pa~=pb and pa.Key=="101" and pb.Key=="202")
assert(table.find(pa.UserIds,101)); assert(records[ns]["101"].Data.Cash==0)
assert(next(ProfileStore.Test().MockStore)==nil and next(ProfileStore.Test().UserMockStore)==nil)
print("PASS supplied ProfileStore creates distinct active sessions with user IDs and real-backend API calls")
assert(Data:mutate(a,function(d)
	d.Cash=125000; d.Rank={Tier=3,Stars=2,Rating=1345}; d.Stats.Wins=9; d.Stats.Losses=4; d.Stats.CurrentWinStreak=3; d.Stats.BestWinStreak=6
	d.Season.Rating=1500; d.Season.Wins=5; d.Quests.Daily.Progress.lines=24; d.Quests.Weekly.Progress.wins=8
	d.Login.Index=4; d.Login.LastDay=math.floor(os.time()/86400); d.Achievements.Test=true; d.Inventory.Badges.Test=true; d.Settings.ReducedMotion=true; d.Settings.Sound=false
	d.Energy.Current=3; d.Energy.LastRegenTimestamp=os.time(); return true
end))
for _,category in ipairs(Catalog.Categories) do local item=Catalog.list(category)[2]
	assert(Data:mutate(a,function(d) return P.purchase(d,category,item.Id,Catalog,false) end))
	assert(Data:mutate(a,function(d) return P.equip(d,category,item.Id,Catalog,false) end))
end
local saved=P.clone(Data:get(a)); Data:release(a); assert(not pa:IsActive() and not Data:get(a)); assert(Data:load(a))
local after=Data:get(a)
assert(after.Cash==saved.Cash and after.Rank.Tier==3 and after.Rank.Stars==2 and after.Rank.Rating==1345)
assert(after.Stats.Wins==9 and after.Stats.Losses==4 and after.Stats.CurrentWinStreak==3 and after.Season.Rating==1500)
assert(after.Quests.Daily.Progress.lines==24 and after.Quests.Weekly.Progress.wins==8 and after.Login.Index==4)
assert(after.Achievements.Test and after.Inventory.Badges.Test and after.Settings.ReducedMotion and not after.Settings.Sound)
for _,category in ipairs(Catalog.Categories) do local item=Catalog.list(category)[2]; assert(after.Inventory[category][item.Id] and after.Equipped[Catalog.Slots[category]]==item.Id) end
assert(Data:get(b).Cash==0 and Data:get(b).Rank.Tier==1)
print("PASS Cash, energy, ranks/stars, stats, seasons, four cosmetic slots, quests, login, achievements and settings survive release/rejoin")
Data:release(a); tick(C.EnergyInterval*2+1); assert(Data:load(a)); assert(Data:get(a).Energy.Current==5)
assert(Data:get(a).Energy.LastRegenTimestamp>=saved.Energy.LastRegenTimestamp+C.EnergyInterval*2)
print("PASS offline energy regeneration uses the saved timestamp and preserves partial interval progress")
local legacyPlayer=player(303); local legacy=P.refresh(P.default(os.time()),os.time(),C); legacy.Cash=4321; legacy.Rank={Tier=4,Stars=2,Rating=1600}
legacy.Inventory.BrickSkins.Galaxy=true; legacy.Equipped.BrickSkin="Galaxy"; legacy.CustomUnrecognizedField={Kept=true}
local original={Data=P.clone(legacy),Lease={Owner="old-server",Expires=os.time()-1}}
seed(ns,303,original); assert(Data:load(legacyPlayer)); assert(Data:get(legacyPlayer).Cash==4321 and Data:get(legacyPlayer).Rank.Tier==4 and Data:get(legacyPlayer).Equipped.BrickSkin=="Galaxy")
assert(Data:get(legacyPlayer).CustomUnrecognizedField.Kept and records[ns.."_Backup"]["303"].Original.Data.Cash==4321)
assert(records[ns.."_Backup"]["303"].Original.Lease.Owner=="old-server" and records[ns]["303"].MetaData and not records[ns]["303"].Lease)
Data:release(legacyPlayer); assert(Data:load(legacyPlayer)); assert(Data:get(legacyPlayer).Cash==4321)
print("PASS legacy conversion backs up the full original envelope, keeps names/keys/data and is idempotent")
local rawPlayer=player(304); legacy.Cash=765; seed(ns,304,legacy); assert(Data:load(rawPlayer)); assert(Data:get(rawPlayer).Cash==765)
print("PASS recognized raw v1 saves migrate without losing balances or purchased skins")
local locked=player(404); original.Lease.Expires=os.time()+180; seed(ns,404,original)
assert(not Data:load(locked) and not Data:get(locked)); assert(records[ns]["404"].Lease.Owner=="old-server" and records[ns.."_Backup"]["404"]==nil)
local corrupt=player(405); seed(ns,405,{Data={Cash="bad"},Lease={Expires=0}}); assert(not Data:load(corrupt)); assert(records[ns]["405"].Data.Cash=="bad")
local future=player(406); seed(ns,406,{Data={SchemaVersion=2,Cash=999}}); assert(not Data:load(future)); assert(records[ns]["406"].Data.Cash==999)
local malformed=player(409); seed(ns,409,{Data=legacy,MetaData={SessionLoadCount="bad"},GlobalUpdates={0,{}}}); assert(not Data:load(malformed)); assert(records[ns]["409"].MetaData.SessionLoadCount=="bad" and records[ns.."_Backup"]["409"]==nil)
print("PASS live legacy leases, invalid balances and future schemas fail closed without replacing saves")
local backupFailed=player(407); seed(ns,407,{Data=legacy}); faults.Writes[ns.."_Backup"]=true
assert(not async(function() return Data:load(backupFailed) end,4)); faults.Writes[ns.."_Backup"]=nil
assert(not records[ns]["407"].MetaData and records[ns]["407"].Data.Cash==765)
print("PASS backup failure prevents conversion and leaves the original player record intact")
local changed=player(408); seed(ns,408,{Data=legacy})
faults.AfterWrite[ns.."_Backup"]=function(key) if key=="408" then local newer=P.clone(legacy); newer.Cash=888; seed(ns,408,{Data=newer}) end end
assert(not Data:load(changed)); faults.AfterWrite[ns.."_Backup"]=nil
assert(records[ns]["408"].Data.Cash==888 and not records[ns]["408"].MetaData)
print("PASS version-checked conversion refuses concurrent legacy edits after backup")
local failed=player(505); faults.Reads[ns]=true
assert(not async(function() return Data:load(failed) end,4)); faults.Reads[ns]=nil
assert(not Data:get(failed) and not records[ns]["505"])
assert(not Data:mutate(failed,function(d) d.Cash+=1000; return true end))
print("PASS failed initial reads never create default records or permit purchases/rewards")
local noAccess=player(506); ProfileStore.DataStoreState="NoAccess"
assert(not Data:load(noAccess) and not Data:get(noAccess)); assert(next(ProfileStore.Test().MockStore)==nil)
ProfileStore.DataStoreState="Access"
print("PASS unavailable API access is rejected instead of falling back to a production mock profile")
local unavailable=player(507); faults.Writes[ns]=true
assert(not async(function() return Data:load(unavailable) end,8)); faults.Writes[ns]=nil
assert(not Data:get(unavailable) and not records[ns]["507"])
print("PASS StartSessionAsync write outages respect cancellation deadlines and never unlock the shop")
local r={id="durable-result",outcome="Win",score=0,lines=0,spins=0,tetrises=0,perfect=0,sent=0,kos=0,startTier=1,startRating=1000,opponentRating=1000,rewardEligible=true,opponentId=999,day=math.floor(os.time()/86400),timestamp=os.time()}
local c=player(606); seed(ns.."_Results",606,{[r.id]=r}); assert(Data:load(c)); assert(Data:get(c).Cash==50 and next(records[ns.."_Results"]["606"])==nil)
assert(Data:settle(c,r) and Data:get(c).Cash==50); Data:release(c); assert(Data:load(c)); assert(Data:get(c).Cash==50)
print("PASS durable result inbox recovery and confirmed-save cleanup grant ranked rewards once")
local recovery=player(607); seed(ns.."_Results",607,{[r.id]=r}); faults.Writes[ns]=true
assert(not async(function() return Data:load(recovery) end,8)); faults.Writes[ns]=nil
assert(records[ns.."_Results"]["607"][r.id] and not Data:get(recovery))
assert(Data:load(recovery) and Data:get(recovery).Cash==50)
print("PASS failed recovery keeps the durable result and blocks play until a successful rejoin")
local loss=player(707); assert(Data:load(loss)); local raw=Data.Profiles[707].Profile
records[ns]["707"].MetaData.ActiveSession={200,"another-server","external"}; raw:Save()
assert(not raw:IsActive() and not Data:get(loss) and loss.Kicked)
assert(not Data:mutate(loss,function(d) d.Cash+=999; return true end))
print("PASS external session loss clears access, kicks safely and rejects later mutations")
local leaving=player(808); faults.Latency[ns]=0.1; local outcome
task.spawn(function() outcome=Data:load(leaving) end); leaving.Parent=nil; tick(1); faults.Latency[ns]=nil
assert(outcome==false and not Data:get(leaving)); local opened=ProfileStore.Test().ActiveSessionCheck; for _,profile in pairs(opened) do assert(profile.Key~="808") end
print("PASS players leaving during load cancel acquisition and cannot retain an active profile")
local reservation=player(809); assert(Data:load(reservation)); assert(Data:mutate(reservation,function(d) d.Energy.Current=8; d.Reservations.abandoned={At=os.time()}; return true end))
Data:release(reservation); assert(Data:load(reservation)); assert(Data:get(reservation).Energy.Current==9 and not next(Data:get(reservation).Reservations))
Data:release(reservation); assert(Data:load(reservation)); assert(Data:get(reservation).Energy.Current==9)
print("PASS abandoned energy reservations refund once and remain cleared after rejoin")
local purchase=player(909); assert(Data:load(purchase)); assert(Data:mutate(purchase,function(d) d.Cash=125000; return true end))
faults.Writes[ns]=true; local skin=Catalog.list("BrickSkins")[2]
assert(not async(function() return Data:mutate(purchase,function(d) return P.purchase(d,"BrickSkins",skin.Id,Catalog,false) end) end,4))
assert(not Data:get(purchase) and purchase.Kicked and not Data:mutate(purchase,function(d) d.Cash+=999; return true end))
faults.Writes[ns]=nil; tick(5); assert(Data:load(purchase))
local recoveredPurchase=Data:get(purchase)
assert(recoveredPurchase.Cash==125000-skin.Price and recoveredPurchase.Inventory.BrickSkins[skin.Id])
assert(not Data:mutate(purchase,function(d) return P.purchase(d,"BrickSkins",skin.Id,Catalog,false) end))
print("PASS ambiguous save failure closes access and preserves the atomic Cash/ownership pair without free or duplicate items")
local duplicate=player(909); assert(not Data:load(duplicate)); assert(Data:get(purchase) and not Data:get(duplicate))
print("PASS duplicate player objects cannot reuse another player's loaded session")
for _,p in ipairs(Players.List) do Data:release(p) end
assert(next(ProfileStore.Test().ActiveSessionCheck)==nil)
print("PASS all normal releases call EndSession and clear active library sessions")
print("ProfileStore checks executed the exact supplied library against simulated Roblox services; no cloud data was read or written.")
-- Remote equip integration uses the supplied library and actual player data service.
Players.List={}; Players.PlayerAdded=event(); Players.PlayerRemoving=event()
function Players:GetPlayerByUserId(uid) for _,p in ipairs(self.List) do if p.UserId==uid then return p end end end
local workspace={GetServerTimeNow=function() return now end}
local sent={}
local remote={OnServerEvent=event(),FireClient=function(_,p,kind,value) sent[p]=sent[p] or {}; sent[p][kind]=P.clone(value) end}
local originalNew=Instance.new
Instance.new=function(class) if class=="RemoteEvent" then return remote end; return originalNew(class) end
modules.LeaderboardService={update=function() end,read=function() return {} end}
local originalFire=RunService.Heartbeat.fire
function RunService.Heartbeat:fire() originalFire(self,0.01) end
local S=(function()
local Catalog=nil -- Require the real module dependency.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local Shared=RS:WaitForChild("Shared")
local E=require(Shared:WaitForChild("TetrisEngine"))
local R=require(Shared:WaitForChild("Config"):WaitForChild("Rules"))
local P=require(Shared:WaitForChild("Progression"))
local Catalog=require(Shared:WaitForChild("Catalog"))
local Data=require(script.Parent:WaitForChild("PlayerDataService"))
local Leaders=require(script.Parent:WaitForChild("LeaderboardService"))
local C=Data.Config
local Network=Instance.new("RemoteEvent"); Network.Name="Network"; Network.Parent=Shared
local S={Sessions={},Rooms={},Queue={},Results={},Invites={},Loading={},Busy={},Buckets={},Closing=false}
local function send(player,kind,payload)
	if player.Parent==Players then Network:FireClient(player,kind,payload) end
end
local function message(player,text) send(player,"Message",text) end
local function profile(player) send(player,"Profile",Data:public(player)) end
local function cosmeticReply(player,kind,category,id,ok,code,text)
	if RunService:IsStudio() and C.CosmeticDebugLogging then
		print(string.format("[Cosmetic] result action=%s category=%s id=%s success=%s code=%s",kind,tostring(category),tostring(id),tostring(ok),tostring(code)))
	end
	send(player,"CosmeticResult",{Action=kind,Category=category,Id=id,Success=ok,Code=code,Message=text})
	message(player,text)
end
local function cosmetic(player,kind,payload)
	local category=type(payload)=="table" and payload.Category or nil
	local id=type(payload)=="table" and payload.Id or nil
	local valid=type(category)=="string" and #category<=32 and type(id)=="string" and #id<=64
	local slot=valid and Catalog.Slots[category] or nil
	local item=slot and Catalog.Items[category..":"..id] or nil
	local d=Data:get(player); local entry=Data.Profiles[player.UserId]
	local isActive=entry and entry.Active and (not entry.Profile or entry.Profile:IsActive()) or false
	local owned=d and slot and d.Inventory[category] and d.Inventory[category][id]==true or false
	local free=Data.Debug and (kind=="Buy" and C.FreeShopPurchasesInDebug or kind=="Equip" and C.FreeCosmeticsInDebug) or false
	if RunService:IsStudio() and C.CosmeticDebugLogging then
		print(string.format("[Cosmetic] request action=%s category=%s id=%s loaded=%s active=%s configured=%s owned=%s debugFree=%s slot=%s fieldExists=%s",kind,valid and category or "invalid",valid and id or "invalid",tostring(d~=nil),tostring(isActive),tostring(item~=nil),tostring(owned),tostring(free),tostring(slot),tostring(d and slot and d.Equipped[slot]~=nil or false)))
	end
	if not d then cosmeticReply(player,kind,valid and category or nil,valid and id or nil,false,"DataNotLoaded","Your player data is still loading."); return end
	if not item then cosmeticReply(player,kind,nil,nil,false,"Unavailable","This cosmetic is unavailable."); return end
	local ok,text,code=Data:mutate(player,function(nextData)
		if kind=="Buy" then return P.purchase(nextData,category,id,Catalog,free) end
		return P.equip(nextData,category,id,Catalog,free)
	end,{Action=kind,Category=category,Id=id})
	profile(player)
	if not ok then
		if RunService:IsStudio() and C.CosmeticDebugLogging then warn("[Cosmetic] rejected internalCode="..tostring(code).." reason="..tostring(text)) end
		code=code or (text=="Data not loaded" and "DataNotLoaded" or "SaveFailed")
		text=code=="NotOwned" and "You don't own this cosmetic yet." or code=="Unavailable" and "This cosmetic is unavailable." or code=="DataNotLoaded" and "Your player data is still loading." or kind=="Equip" and "Unable to equip right now. Please try again." or code=="InternalError" and "Unable to purchase right now. Please try again." or text or "Unable to purchase right now. Please try again."
	end
	cosmeticReply(player,kind,category,id,ok,ok and "OK" or code,text or "Saved")
	if ok then send(player,"Action",{Sound=kind=="Buy" and "Purchase" or "Equip"}) end
end
local function unqueue(player)
	for i=#S.Queue,1,-1 do if S.Queue[i]==player then table.remove(S.Queue,i) end end
end
local function persist(player,result)
	-- Retry the durable inbox. Once written, recovery is idempotent on reconnect.
	for _=1,6 do if Data:settle(player,result) then profile(player); return true end; task.wait(2) end
	warn("[Tetris] Result remains pending or journal unavailable: "..result.id); return false
end
local function playerProfile(player)
	local d=Data:get(player)
	return {UserId=player.UserId,Name=player.Name,DisplayName=player.DisplayName,Rank=d and P.Ranks[d.Rank.Tier] or "Rookie",Tier=d and d.Rank.Tier or 1,Stars=d and d.Rank.Stars or 0,Rating=d and d.Rank.Rating or 1000,Equipped=d and P.clone(d.Equipped) or {}}
end
local function battleEvent(room,kind,values)
	room.EventId=(room.EventId or 0)+1; values.Kind=kind; values.Id=room.EventId; values.MatchId=room.Id
	for _,p in ipairs(room.Players) do send(p,"BattleEvent",values) end
end
local function deliver(room,player,attack)
	if attack<=0 or room.Ended then return end
	local other=room.Players[1]==player and room.Players[2] or room.Players[1]; local target=S.Sessions[other]
	if not target then return end
	E.addGarbage(target.Engine,attack)
	battleEvent(room,"Attack",{From=player.UserId,To=other.UserId,Lines=attack})
end
local function recoverKO(room,player,now)
	local session=S.Sessions[player]; if session.RespawnAt then return end
	local other=room.Players[1]==player and room.Players[2] or room.Players[1]
	S.Sessions[other].Engine.stats.KOs+=1; session.RespawnAt=now+R.KORecovery; E.release(session.Engine)
	battleEvent(room,"KO",{Player=player.UserId,Winner=other.UserId,RecoverAt=session.RespawnAt})
end
local function respawn(session)
	local old=session.Engine; local fresh=E.new(old.bagSeed, R)
	-- Carry cumulative verified statistics and event sequence; reset board/hold/combo/pending.
	fresh.score=old.score; fresh.lines=old.lines; fresh.level=old.level; fresh.elapsed=old.elapsed; fresh.stats=old.stats
	fresh.sequence=old.sequence; fresh.events=old.events; fresh.queue=table.clone(old.queue); fresh.bagSeed=old.bagSeed; fresh.garbageSeed=old.garbageSeed
	E.spawn(fresh); session.Engine=fresh; session.RespawnAt=nil
end
local function refund(room)
	for player,charged in pairs(room.Charged) do if charged then room.Charged[player]=false; persist(player,{id=room.Id..":refund",kind="Refund",roomId=room.Id}) end end
end
local function resultFor(room,player,winner,reason)
	local session=S.Sessions[player]; local start=room.Profiles[player]; local other=room.Players[1]==player and room.Players[2] or room.Players[1]
	local d=Data:get(player); local st=session.Engine.stats
	local outcome=winner==nil and "Draw" or winner==player and "Win" or "Lose"
	local eligible=room.Ranked and (Data.Debug or room.Played>=C.MinRewardSeconds)
	if eligible and not Data.Debug and d then
		local key=tostring(other.UserId); local pair=d.Pairs[key]; local day=math.floor(os.time()/86400)
		if pair and pair.Day==day and (pair.Count>=C.PairRewardsPerDay or os.time()-pair.Last<C.OpponentRewardCooldown) then eligible=false end
	end
	return {id=room.Id,outcome=outcome,score=session.Engine.score,lines=session.Engine.lines,spins=st.TSpins,tetrises=st.Tetrises,perfect=st.PerfectClears,sent=st.Sent,kos=st.KOs,startTier=start.Tier,startRating=start.Rating,opponentRating=room.Profiles[other].Rating,rewardEligible=eligible,opponentId=other.UserId,day=math.floor(os.time()/86400),timestamp=os.time()}
end
local function finish(room,winner,reason)
	if room.Ended then return end
	room.Ended=true; S.Rooms[room.Id]=nil
	if not room.Started then
		refund(room)
		for _,player in ipairs(room.Players) do S.Sessions[player]=nil; send(player,"Lobby",{}); message(player,"Match cancelled before gameplay; energy refunded.") end
		return
	end
	local summaries={}
	if winner and reason=="KO" then S.Sessions[winner].Engine.stats.KOs+=1 end
	for _,player in ipairs(room.Players) do summaries[player]=resultFor(room,player,winner,reason) end
	for _,player in ipairs(room.Players) do
		message(player,"Match finished. Saving results...")
		local session=S.Sessions[player]; local summary=summaries[player]
		local before=Data:get(player) and P.clone(Data:get(player))
		local settled=true
		if room.Ranked then settled=persist(player,summary); if settled then Leaders:update(player) end end
		local after=Data:get(player)
		local other=room.Players[1]==player and room.Players[2] or room.Players[1]
		local payload={Outcome=summary.outcome,Reason=reason,Own=E.pack(session.Engine),Opponent=E.pack(S.Sessions[other].Engine),Profiles=room.PublicProfiles,Ranked=room.Ranked,Rewards=summary.rewardEligible and settled,SettlementPending=not settled,
			Cash=settled and room.Ranked and summary.rewardEligible and summary.outcome=="Win" and C.WinCash[summary.startTier] or 0,BeforeRank=before and before.Rank,AfterRank=after and P.clone(after.Rank),Id=room.Id}
		S.Results[player]={Other=other,Ready=false,Ranked=room.Ranked}; send(player,"Result",payload)
	end
	for _,player in ipairs(room.Players) do S.Sessions[player]=nil end
end
local function startPair(a,b,ranked)
	if S.Sessions[a] or S.Sessions[b] or not Data:get(a) or not Data:get(b) then return end
	local count=0; for _ in pairs(S.Rooms) do count+=1 end
	if count>=C.MaxMatches then
		for _,player in ipairs({a,b}) do send(player,"Lobby",{}); message(player,"All arenas are busy; please search again.") end
		return
	end
	unqueue(a); unqueue(b); S.Results[a]=nil; S.Results[b]=nil
	local room={Id=Http:GenerateGUID(false),Players={a,b},Ranked=ranked,Profiles={},PublicProfiles={playerProfile(a),playerProfile(b)},Charged={},Played=0,Countdown=R.Countdown,Ended=false,Started=false,Preparing=true}
	S.Rooms[room.Id]=room
	local seed=math.random(1,2147483646)
	for _,player in ipairs(room.Players) do
		room.Profiles[player]=P.clone(Data:get(player).Rank)
		S.Sessions[player]={Room=room,Engine=E.new(seed,R),Mode=ranked and "Ranked" or "Challenge"}
		send(player,"Found",{Profiles=room.PublicProfiles,Ranked=ranked,MatchId=room.Id})
	end
	for _,player in ipairs(room.Players) do
		if ranked and not (Data.Debug and C.InfiniteEnergyInDebug) then
			local ok=Data:mutate(player,function(d)
				if d.Energy.Current<C.RankedCost then return false,"Not enough Energy" end
				d.Energy.Current-=C.RankedCost; d.Reservations[room.Id]={At=os.time()}; return true
			end)
			if not ok then finish(room,nil,"Energy unavailable"); return end
			room.Charged[player]=true; profile(player)
		end
		if room.Cancelled or player.Parent~=Players then finish(room,nil,"Cancelled"); return end
	end
	room.Preparing=false; room.StartAt=workspace:GetServerTimeNow()+R.Countdown
end
local function leave(player)
	unqueue(player)
	local session=S.Sessions[player]
	if session then
		if session.Room then
			local room=session.Room; local other=room.Players[1]==player and room.Players[2] or room.Players[1]
			if room.Preparing then room.Cancelled=true else finish(room,other,"Opponent left") end
		else
			persist(player,{id=session.Id,kind="Solo",score=session.Engine.score,lines=session.Engine.lines,spins=session.Engine.stats.TSpins,tetrises=session.Engine.stats.Tetrises,perfect=session.Engine.stats.PerfectClears})
			S.Sessions[player]=nil
		end
	end
end
local function solo(player)
	leave(player); S.Results[player]=nil
	if S.Sessions[player] then return end
	S.Sessions[player]={Id=Http:GenerateGUID(false),Engine=E.new(math.random(1,2147483646),R),Mode="Solo",StartAt=workspace:GetServerTimeNow()+R.Countdown}
end
local function queue(player)
	if S.Sessions[player] then return end
	if Data.Debug and not C.TestRankedMatches then message(player,"Test ranked matches disabled"); return end
	local d=P.refresh(P.clone(Data:get(player)),os.time(),C)
	if not (Data.Debug and C.InfiniteEnergyInDebug) and d.Energy.Current<C.RankedCost then message(player,"No Energy. Regeneration, quests and free Solo are available."); profile(player); return end
	S.Results[player]=nil
	unqueue(player); table.insert(S.Queue,player); send(player,"Searching",{Profile=playerProfile(player),StartedAt=workspace:GetServerTimeNow()})
end
local validInputs={Left=true,Right=true,SoftDrop=true,CW=true,CCW=true,Hold=true,HardDrop=true}
local function command(player,kind,payload)
	if kind=="Buy" or kind=="Equip" then cosmetic(player,kind,payload); return end
	if not Data:get(player) then message(player,"Profile is still loading"); return end
	if kind=="Refresh" then profile(player)
	elseif kind=="Hello" then profile(player); if not S.Sessions[player] then send(player,"Lobby",{}) end
	elseif kind=="Solo" then solo(player)
	elseif kind=="Queue" then queue(player)
	elseif kind=="Cancel" or kind=="Exit" then leave(player); S.Results[player]=nil; send(player,"Lobby",{})
	elseif kind=="Pause" then local s=S.Sessions[player]; if s and s.Mode=="Solo" then s.Engine.paused=payload==true; E.release(s.Engine) end
	elseif kind=="Restart" then local s=S.Sessions[player]; if s and s.Mode=="Solo" then solo(player) end
	elseif kind=="Rematch" then
		local result=S.Results[player]; if not result or result.Other.Parent~=Players then message(player,"Opponent unavailable; use Find Match"); return end
		local other=S.Results[result.Other]
		if not other or other.Other~=player then message(player,"Opponent returned to lobby; use Find Match"); return end
		result.Ready=true; message(player,"Rematch requested. Waiting for opponent.")
		if other and other.Other==player and other.Ready then startPair(player,result.Other,result.Ranked) end
	elseif kind=="ClaimQuest" then
		if type(payload)~="table" or not ({Daily=true,Weekly=true})[payload.Group] or type(payload.Id)~="string" then return end
		local ok,text=Data:mutate(player,function(d) return P.claimQuest(d,payload.Group,payload.Id,C) end); profile(player); message(player,text); if ok then send(player,"Action",{Sound="QuestClaim"}) end
	elseif kind=="Login" then local ok,text=Data:mutate(player,function(d) return P.login(d,os.time(),C) end); profile(player); message(player,text); if ok then send(player,"Action",{Sound="CashEarned"}) end
	elseif kind=="Leaderboard" then
		-- Legacy string requests remain supported. Echo the bounded request identity for race filtering.
		local category=type(payload)=="table" and payload.Kind or payload
		local requestId=type(payload)=="table" and payload.RequestId or nil
		if type(category)~="string" or not ({GlobalRating=true,GlobalWins=true,SeasonRating=true,SeasonWins=true})[category] then return end
		if requestId~=nil and (type(requestId)~="number" or requestId<1 or requestId>2147483647 or requestId%1~=0) then return end
		local rows,text=Leaders:read(player,category); send(player,"Leaderboard",{Rows=rows or {},Kind=category,RequestId=requestId,Notice=text,Unavailable=not rows})
	elseif kind=="Challenge" then
		if type(payload)~="number" or S.Sessions[player] then return end
		local other=Players:GetPlayerByUserId(payload); if not other or other==player or S.Sessions[other] then return end
		local ok,isFriend=pcall(function() return player:IsFriendsWithAsync(other.UserId) end)
		if not ok or not isFriend then message(player,"Choose a friend in this server"); return end
		S.Invites[other]={From=player,Expires=os.clock()+30}; send(other,"Challenge",playerProfile(player)); message(player,"Friend challenge sent")
	elseif kind=="AcceptChallenge" then
		local invitation=S.Invites[player]; S.Invites[player]=nil
		if invitation and invitation.Expires>os.clock() and invitation.From.Parent==Players then startPair(player,invitation.From,false) end
	elseif kind=="Settings" then
		if type(payload)~="table" then return end
		Data:mutate(player,function(d) if type(payload.Sound)=="boolean" then d.Settings.Sound=payload.Sound end; if type(payload.ReducedMotion)=="boolean" then d.Settings.ReducedMotion=payload.ReducedMotion end; for _,field in ipairs({"ClassicHUD","SwapRotation"}) do if type(payload[field])=="boolean" then d.Settings[field]=payload[field] end end; for _,field in ipairs({"Master","MusicVolume","SFXVolume","UIScale"}) do local value=payload[field]; if type(value)=="number" and value==value and math.abs(value)<=1000 then d.Settings[field]=math.clamp(value,field=="UIScale" and 0.9 or 0,1) end end; return true end); profile(player)
	elseif kind=="Emote" then
		local session=S.Sessions[player]; if not session or not session.Room or session.Room.Ended or type(payload)~="number" or payload%1~=0 or not R.Emotes[payload] then return end
		local now=workspace:GetServerTimeNow(); if now<(session.EmoteAt or 0) then return end; session.EmoteAt=now+R.EmoteCooldown
		battleEvent(session.Room,"Emote",{From=player.UserId,Text=R.Emotes[payload]})
	end
end
Network.OnServerEvent:Connect(function(player,kind,payload)
	if S.Closing or type(kind)~="string" or #kind>30 then return end
	local now=os.clock(); local b=S.Buckets[player] or {Time=now,Input=80,Command=8}; S.Buckets[player]=b
	local dt=now-b.Time; b.Time=now; b.Input=math.min(80,b.Input+dt*60); b.Command=math.min(8,b.Command+dt*2)
	if kind=="Input" then
		if type(payload)~="table" or not validInputs[payload.Action] or type(payload.Down)~="boolean" then return end
		local session=S.Sessions[player]
		if not session or (session.Room and (session.Room.Ended or not session.Room.Started or workspace:GetServerTimeNow()>=session.Room.EndAt)) or session.StartAt and workspace:GetServerTimeNow()<session.StartAt or session.RespawnAt then return end
		-- A rate-limited press must never prevent releasing an already held key.
		if not session.Engine or b.Input<1 and (payload.Down or not session.Engine.controls[payload.Action]) then return end
		b.Input=math.max(0,b.Input-1)
		if payload.Action=="HardDrop" and payload.Down then if now-(session.LastDrop or 0)<0.08 then return end; session.LastDrop=now end
		local beforeEvent=session.Engine.sequence
  local equipped=Data:get(player) and Data:get(player).Equipped
  local dropTheme=equipped and equipped.DropEffect
  local attack=E.input(session.Engine,payload.Action,payload.Down)
  if payload.Action=="HardDrop" and payload.Down then
   for _,event in ipairs(session.Engine.events) do if event.id>beforeEvent and event.name=="HardDrop" then event.data.DropEffect=dropTheme end end
  end
		if attack>0 and session.Room then deliver(session.Room,player,attack) end
		return
	end
	if b.Command<1 or S.Busy[player] then
  if kind=="Leaderboard" and type(payload)=="table" and type(payload.Kind)=="string" and type(payload.RequestId)=="number" then
   send(player,"Leaderboard",{Kind=payload.Kind,RequestId=payload.RequestId,Rows={},Unavailable=true,Notice="Server busy. Please retry in a moment.",RetryAfter=0.6})
  end
  return
 end; b.Command-=1; S.Busy[player]=true
	local ok,err=pcall(command,player,kind,payload); S.Busy[player]=nil
	if not ok then warn("[Tetris server] "..tostring(err)); message(player,"Operation failed; please retry") end
end)
local accumulator=0; local snapshotTime=0; local queueTime=0
RunService.Heartbeat:Connect(function(dt)
	accumulator=math.min(0.5,accumulator+dt); snapshotTime+=dt; queueTime+=dt
	local now=workspace:GetServerTimeNow()
	for _,room in pairs(S.Rooms) do if not room.Preparing and not room.Started and now>=room.StartAt then room.Started=true; room.EndAt=room.StartAt+R.MatchDuration end end
	while accumulator>=1/60 do
		accumulator-=1/60
		for player,session in pairs(S.Sessions) do
			local room=session.Room
			if session.Engine and not session.RespawnAt and (not session.StartAt or now>=session.StartAt) and (not room or room.Started and not room.Ended and now<room.EndAt) then
				local attack=E.step(session.Engine,1/60)
				if room and attack>0 then deliver(room,player,attack) end
			end
		end
	end
	for _,room in pairs(S.Rooms) do
		if room.Started and not room.Ended then
			room.Played=math.max(0,now-room.StartAt)
			local a,b=room.Players[1],room.Players[2]; local sa,sb=S.Sessions[a],S.Sessions[b]
			if sa and sb then
				if (not room.Ranked or not R.TimedKO) and (not sa.Engine.alive or not sb.Engine.alive) then
					local winner=sa.Engine.alive and a or sb.Engine.alive and b or nil
					task.spawn(finish,room,winner,"KO")
				elseif now>=room.EndAt then
					-- Deterministic policy: sent garbage, then cleared lines, then score.
					local winner
					for _,values in ipairs({{sa.Engine.stats.KOs,sb.Engine.stats.KOs},{sa.Engine.stats.Sent,sb.Engine.stats.Sent},{sa.Engine.lines,sb.Engine.lines},{sa.Engine.score,sb.Engine.score}}) do if values[1]~=values[2] then winner=values[1]>values[2] and a or b; break end end
					task.spawn(finish,room,winner,"Time expired")
				elseif room.Ranked and R.TimedKO then
					for _,p in ipairs(room.Players) do local session=S.Sessions[p]
						if not session.Engine.alive and not session.RespawnAt then recoverKO(room,p,now) end
						if session.RespawnAt and now>=session.RespawnAt then respawn(session) end
					end
				end
			end
		end
	end
	if snapshotTime>=1/R.SnapshotHz then
		snapshotTime=0
		for player,session in pairs(S.Sessions) do
			local room=session.Room
			if session.Engine and (not room or not room.Ended) then
				local other=room and (room.Players[1]==player and room.Players[2] or room.Players[1]); local osession=other and S.Sessions[other]
				local start=room and room.StartAt or session.StartAt
				send(player,"State",{Mode=session.Mode,MatchId=room and room.Id or session.Id,StartAt=start,EndAt=room and room.EndAt,ServerNow=now,Own=E.pack(session.Engine),Opponent=osession and E.pack(osession.Engine),Profiles=room and room.PublicProfiles,Countdown=start and math.max(0,math.ceil(start-now)) or room and not room.Started and R.Countdown or 0,Remaining=room and (room.Started and math.max(0,room.EndAt-now) or R.MatchDuration) or nil,RespawnAt=session.RespawnAt,Round=1})
			end
		end
	end
	if queueTime>=0.5 then
		queueTime=0
		for i=#S.Queue,1,-1 do local p=S.Queue[i]; if p.Parent~=Players or not Data:get(p) or S.Sessions[p] then table.remove(S.Queue,i) end end
		while #S.Queue>=2 do
			local a=table.remove(S.Queue,1); local b=table.remove(S.Queue,1)
			-- Reserve before a yielding data transaction can let another queue request race.
			S.Sessions[a]={Reserved=true}; S.Sessions[b]={Reserved=true}
			task.spawn(function() S.Sessions[a]=nil; S.Sessions[b]=nil; startPair(a,b,true) end)
		end
	end
end)
local function joined(player)
	if S.Loading[player] or Data:get(player) then return end
	S.Loading[player]=true
	local ok,text=Data:load(player); S.Loading[player]=nil
	if not ok then player:Kick(text); return end
	if player.Parent~=Players then Data:release(player); return end
	profile(player); send(player,"Lobby",{})
	-- Alternative to invite attribution: a verified first-time friend session.
	task.delay(C.SocialMinSeconds,function()
		local newcomer=Data:get(player)
		if player.Parent~=Players or not newcomer or os.time()-newcomer.CreatedAt>600 or player.AccountAge<C.SocialMinAccountAge then return end
		for _,host in ipairs(Players:GetPlayers()) do
			if host~=player and Data:get(host) then
				local success,friend=pcall(function() return host:IsFriendsWithAsync(player.UserId) end)
				local hostData=P.refresh(P.clone(Data:get(host)),os.time(),C)
				if success and friend and not newcomer.SocialRewardHost and hostData.SocialRewards.Count<C.SocialDailyLimit and not hostData.SocialRewards.Seen[tostring(player.UserId)] then
					local reserved=Data:mutate(player,function(d)
						if d.SocialRewardHost then return false end
						d.SocialRewardHost=host.UserId; return true
					end)
					if not reserved then return end
					persist(host,{id="social:"..player.UserId,kind="Social",friendId=player.UserId})
					return
				end
			end
		end
	end)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player) leave(player); Data:release(player); S.Results[player]=nil; S.Invites[player]=nil; S.Buckets[player]=nil; S.Busy[player]=nil end)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(joined,player) end
game:BindToClose(function()
	S.Closing=true
	for _,room in pairs(S.Rooms) do if not room.Started then room.Cancelled=true; if not room.Preparing then finish(room,nil,"Server closing") end end end
	local pending=0
	for _,player in ipairs(Players:GetPlayers()) do pending+=1; task.spawn(function() leave(player); Data:release(player); pending-=1 end) end
	local deadline=os.clock()+25; while pending>0 and os.clock()<deadline do task.wait(0.1) end
end)
S.Matchmaking={Enqueue=queue,Cancel=unqueue,StartPair=startPair}
return S

end)()
local function send(p,kind,data) remote.OnServerEvent:fire(p,kind,data) end
local shopper=player(11001); shopper.AccountAge=365
Players.PlayerAdded:fire(shopper); tick(0.1); assert(Data:get(shopper))
local function request(category,id)
	S.Buckets={}; sent[shopper].CosmeticResult=nil
	send(shopper,"Equip",{Category=category,Id=id}); tick(0.1)
	return assert(sent[shopper].CosmeticResult,"No structured cosmetic response")
end
local balance=Data:get(shopper).Cash
for category,slot in pairs(Catalog.Slots) do
	local reply=request(category,"Default")
	assert(reply.Success and reply.Code=="OK" and Data:get(shopper).Equipped[slot]=="Default")
	assert(Data:get(shopper).Cash==balance)
end
print("PASS all four default cosmetics equip through the real remote without spending Cash")
local chosen={}; assert(Data:mutate(shopper,function(d)
	d.Cash=125000
	for category in pairs(Catalog.Slots) do local item=Catalog.list(category)[2]; chosen[category]=item.Id; d.Inventory[category][item.Id]=true end
	return true
end))
for category,slot in pairs(Catalog.Slots) do
	for _,id in ipairs({chosen[category],"Default",chosen[category]}) do
		local reply=request(category,id); assert(reply.Success and reply.Category==category and reply.Id==id)
		assert(Data:get(shopper).Equipped[slot]==id and Data:get(shopper).Cash==125000)
	end
end
print("PASS repeated owned skin/drop/ghost/sound equips preserve Cash and return accurate success payloads")
local missing=Catalog.list("BrickSkins")[3].Id; local reply=request("BrickSkins",missing)
assert(not reply.Success and reply.Code=="NotOwned" and reply.Message=="You don't own this cosmetic yet.")
assert(Data:get(shopper).Equipped.BrickSkin==chosen.BrickSkins and Data:get(shopper).Cash==125000)
for _,pair in ipairs({{"BrickSkins","Missing"},{"Unknown","Default"},{"HardDropEffects","Default"}}) do
	reply=request(pair[1],pair[2]); assert(not reply.Success and reply.Code=="Unavailable")
end
S.Buckets={}; send(shopper,"Equip",{Category={},Id=5}); assert(sent[shopper].CosmeticResult.Code=="Unavailable")
print("PASS unowned, mismatched and malformed cosmetic requests reject without changing equipped state")
-- Exercise the import on Buy as well; then equip an actually purchased item.
S.Buckets={}; send(shopper,"Buy",{Category="BrickSkins",Id=missing}); tick(0.1)
assert(sent[shopper].CosmeticResult.Success and Data:get(shopper).Inventory.BrickSkins[missing])
balance=125000-Catalog.Items["BrickSkins:"..missing].Price
reply=request("BrickSkins",missing); assert(reply.Success and Data:get(shopper).Cash==balance); chosen.BrickSkins=missing
Data:release(shopper); tick(0.1)
local reloaded; task.spawn(function() reloaded=Data:load(shopper) end); tick(0.3); assert(reloaded)
for category,slot in pairs(Catalog.Slots) do assert(Data:get(shopper).Equipped[slot]==chosen[category]) end
assert(Data:get(shopper).Cash==balance)
print("PASS remote purchase then equip and rejoin preserve ownership, all equipped slots and exact Cash")
local success,text,code=Data:mutate(shopper,function() error("equip-test-private-stack-marker") end,{Action="Equip",Category="BrickSkins",Id="Default"})
assert(not success and code=="InternalError" and not text:find("private%-stack") and Data:get(shopper).Cash==balance)
if RunService:IsStudio() then assert(warnings[#warnings]:find("equip-test-private-stack-marker",1,true) and warnings[#warnings]:find("action=Equip",1,true)) end
print("PASS mutation exceptions return an internal code without exposing server traces or changing data")
Data:release(shopper); reply=request("BrickSkins","Default")
assert(not reply.Success and reply.Code=="DataNotLoaded" and reply.Message=="Your player data is still loading.")
print("PASS unloaded profiles cannot equip or receive false success")

Players.List={}; RunService.IsStudio=function() return true end; C.ProfileStoreStudioPersistence=false; C.FreeCosmeticsInDebug=false; C.FreeShopPurchasesInDebug=false; remote.OnServerEvent=event()
local StudioData=(function()
-- Central profile authority. Live rollout stays on the original backend until verified.
local DSS=game:GetService("DataStoreService")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local Config=require(script.Parent:WaitForChild("GameConfig"))
local studio=RunService:IsStudio()
if not studio and not Config.ProfileStoreLiveEnabled then
	return require(script.Parent:WaitForChild("LegacyPlayerDataService"))
end
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local P=require(Shared:WaitForChild("Progression"))
local Catalog=require(Shared:WaitForChild("Catalog"))
local ProfileStore=require(script.Parent:WaitForChild("ProfileStore"))
local Migration=require(script.Parent:WaitForChild("ProfileStoreMigration"))
local namespace=studio and Config.ProfileStoreTestDataStoreName or Config.DataStoreName.."_Live"
assert(type(namespace)=="string" and #namespace<=43,"ProfileStore namespace is missing or too long")
local Data={Profiles={},Loading={},Debug=studio and Config.Debug and not Config.ProfileStoreStudioPersistence,Config=Config,Namespace=namespace,Closing=false}
local playerStore=ProfileStore.New(namespace,P.default(0))
local store=DSS:GetDataStore(namespace)
local backup=DSS:GetDataStore(namespace.."_Backup")
local inbox=DSS:GetDataStore(namespace.."_Results")
local function retry(fn)
	local problem
	for attempt=1,4 do
		local values=table.pack(pcall(fn))
		if values[1] then return true,table.unpack(values,2,values.n) end
		problem=values[2]; if attempt<4 then task.wait(0.5*2^(attempt-1)) end
	end
	return false,tostring(problem)
end
local function active(entry) return entry and entry.Active and not entry.Releasing and entry.Profile:IsActive() end
local function endEntry(self,entry,unexpected)
	entry.Ready=false; entry.Active=false; entry.Releasing=true
	if entry.Profile:IsActive() then entry.Profile:EndSession() end
	if self.Profiles[entry.Player.UserId]==entry then self.Profiles[entry.Player.UserId]=nil end
	if unexpected and entry.Player.Parent==Players and not self.Closing and not ProfileStore.IsClosing then entry.Player:Kick("Your data session ended. Please reconnect; your existing save was not reset.") end
end
local function commit(self,entry,nextData)
	if not active(entry) then return false,"Data session closed" end
	local token=Http:GenerateGUID(false); nextData._TetrisSaveToken=token
	entry.Profile.Data=nextData; entry.Data=nextData
	if self.Debug then return true end -- Explicit Studio-only ProfileStore.Mock session.
	local deadline=os.clock()+Config.ProfileSaveTimeout; local nextAttempt=0
	while active(entry) and os.clock()<deadline do
		if entry.Profile.LastSavedData._TetrisSaveToken==token then return true end
		if os.clock()>=nextAttempt then entry.Profile:Save(); nextAttempt=os.clock()+2 end
		if entry.Profile.LastSavedData._TetrisSaveToken==token and active(entry) then return true end
		task.wait(0.05)
	end
	-- The write may already have reached Roblox. Preserve the atomic Cash/item pair,
	-- close access and let ProfileStore finish its final save instead of pretending to roll it back.
	endEntry(self,entry,not entry.Releasing)
	return false,"Save confirmation was interrupted. Reconnect to check the completed operation."
end
function Data:load(player)
	local existing=self.Profiles[player.UserId]
	if active(existing) then return existing.Player==player and existing.Ready,"Data is already active in this server" end
	if self.Loading[player.UserId] then return false,"A profile load is already in progress" end
	self.Loading[player.UserId]=player
	local deadline=os.clock()+Config.ProfileLoadTimeout
	local function cancelled() return self.Closing or ProfileStore.IsClosing or player.Parent~=Players or os.clock()>=deadline end
	local function fail(text,entry)
		if entry then endEntry(self,entry,false) end
		if self.Loading[player.UserId]==player then self.Loading[player.UserId]=nil end
		return false,text
	end
	if cancelled() then return fail("Profile loading was cancelled") end
	if not self.Debug then
		while ProfileStore.DataStoreState=="NotReady" and not cancelled() do task.wait(0.05) end
		if cancelled() or ProfileStore.DataStoreState~="Access" then return fail("Persistent data is unavailable. Enable API access in the separate test experience; no mock production profile was created.") end
		local prepared,text=Migration.prepare(store,backup,tostring(player.UserId),player.UserId,Config.ProfileStoreMigrateLegacy,retry,cancelled)
		if not prepared then return fail(text) end
	end
	local target=self.Debug and playerStore.Mock or playerStore
	local started,profile=pcall(function() return target:StartSessionAsync(tostring(player.UserId),{Cancel=cancelled}) end)
	if not started or not profile then return fail("Your profile could not be loaded. No purchases or rewards were enabled; please reconnect.") end
	local entry={Player=player,Profile=profile,Data=profile.Data,Active=true,Ready=false,Busy=false,Releasing=false}
	self.Profiles[player.UserId]=entry
	profile.OnSessionEnd:Connect(function()
		local unexpected=not entry.Releasing
		entry.Active=false; entry.Ready=false
		if self.Profiles[player.UserId]==entry then self.Profiles[player.UserId]=nil end
		if unexpected and player.Parent==Players and not self.Closing and not ProfileStore.IsClosing then player:Kick("Your data session ended. Please reconnect.") end
	end)
	if cancelled() or not profile:IsActive() then return fail("Profile loading was cancelled",entry) end
	local checked,text=Migration.payloadValid(profile.Data); if not checked then return fail(text,entry) end
	local initialized,problem=pcall(function()
		profile:AddUserId(player.UserId); profile:Reconcile()
		if profile.Data.CreatedAt==0 then profile.Data.CreatedAt=profile.FirstSessionTime end
		entry.Data=P.validate(P.clone(profile.Data),os.time(),Catalog,Config); profile.Data=entry.Data
	end)
	if not initialized then return fail("Your existing profile needs manual inspection; it was not reset. "..tostring(problem),entry) end
	local pending={}
	if not self.Debug then
		local readOK,value=retry(function() return inbox:GetAsync(tostring(player.UserId)) end)
		if not readOK or value~=nil and type(value)~="table" then return fail("Pending results could not be recovered. Please reconnect.",entry) end
		pending=value or {}
	end
	local nextData=P.clone(entry.Data); P.refresh(nextData,os.time(),Config)
	local recovered,recoverError=pcall(function()
		for _,result in pairs(pending) do P.settle(nextData,result,Config) end
		for id in pairs(nextData.Reservations) do P.settle(nextData,{id=id..":refund",kind="Refund",roomId=id},Config) end
	end)
	if not recovered then return fail("Pending results need manual inspection: "..tostring(recoverError),entry) end
	entry.Busy=true; local saved,message=commit(self,entry,nextData); entry.Busy=false
	if not saved then return fail(message,entry) end
	if not self.Debug and next(pending) then
		retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old)
			old=old or {}; for id in pairs(pending) do if entry.Profile.LastSavedData.ProcessedMatchIds[id] then old[id]=nil end end; return old
		end) end)
	end
	if cancelled() or not active(entry) then return fail("Profile loading was cancelled",entry) end
	entry.Ready=true; self.Loading[player.UserId]=nil; return true
end
function Data:get(player)
	local entry=self.Profiles[player.UserId]
	return active(entry) and entry.Ready and entry.Player==player and entry.Data or nil
end
function Data:mutate(player,fn,context)
	local entry=self.Profiles[player.UserId]
	if not active(entry) or not entry.Ready or entry.Player~=player then return false,"Data not loaded" end
	while entry.Busy and active(entry) do task.wait() end
	if not active(entry) or not entry.Ready then return false,"Session closed" end
	entry.Busy=true
	local nextData=P.clone(entry.Data); P.refresh(nextData,os.time(),Config)
	local safe,accepted,message,code=xpcall(function() return fn(nextData) end,function(err) return debug.traceback(tostring(err),2) end)
	if not safe then
		entry.Busy=false
		if studio and Config.CosmeticDebugLogging then warn("[PlayerData] Mutation exception action="..tostring(context and context.Action).." category="..tostring(context and context.Category).." id="..tostring(context and context.Id).."\n"..accepted) end
		return false,"Unable to complete this action right now. Please try again.","InternalError"
	end
	if not accepted then entry.Busy=false; return false,message,code end
	local saved,text=commit(self,entry,nextData); entry.Busy=false
	return saved,saved and message or text
end
function Data:settle(player,result)
	if type(result)~="table" or type(result.id)~="string" then return false end
	if not self.Debug then
		local journaled=retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old) old=old or {}; old[result.id]=P.clone(result); return old end) end)
		if not journaled then return false end
	end
	local saved=self:mutate(player,function(d) P.settle(d,result,Config); return true end)
	if saved and not self.Debug then
		local entry=self.Profiles[player.UserId]
		if entry and entry.Profile.LastSavedData.ProcessedMatchIds[result.id] then
			retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old) old=old or {}; old[result.id]=nil; return old end) end)
		end
	end
	return saved
end
function Data:release(player)
	local entry=self.Profiles[player.UserId]; if not entry or entry.Player~=player then return end
	entry.Ready=false; entry.Releasing=true
	while entry.Busy do task.wait() end
	endEntry(self,entry,false)
end
function Data:public(player)
	local d=self:get(player); if not d then return nil end
	local out=P.refresh(P.clone(d),os.time(),Config); out.ProcessedMatchIds=nil; out.MatchReceipts=nil; out.Reservations=nil; out.Pairs=nil; out.SocialRewards.Seen=nil; out._TetrisSaveToken=nil
	out.Debug=self.Debug; out.Energy.Next=P.nextEnergy(out,os.time(),Config)
	out.DebugPrivileges={FreeCosmetics=self.Debug and Config.FreeCosmeticsInDebug,FreePurchases=self.Debug and Config.FreeShopPurchasesInDebug,InfiniteEnergy=self.Debug and Config.InfiniteEnergyInDebug}
	out.Economy={EnergyCap=Config.EnergyCap,BonusCap=Config.BonusEnergyCap,EnergyInterval=Config.EnergyInterval,RankedCost=Config.RankedCost,SocialEnergy=Config.SocialEnergy,SocialLimit=Config.SocialDailyLimit,SocialMinSeconds=Config.SocialMinSeconds,LoginCash=Config.LoginCash,LoginEnergy=Config.LoginEnergy,SeasonDays=Config.SeasonDays,WinCash=Config.WinCash}
	return out
end
game:BindToClose(function() Data.Closing=true end)
print("[PlayerData] ProfileStore / "..(Data.Debug and "Studio mock" or studio and "isolated persistence test" or "live persistence").." / "..namespace)
return Data

end)()
modules.PlayerDataService=StudioData; Data=StudioData; assert(Data.Debug)
local StudioS=(function()
local Catalog=nil
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local Shared=RS:WaitForChild("Shared")
local E=require(Shared:WaitForChild("TetrisEngine"))
local R=require(Shared:WaitForChild("Config"):WaitForChild("Rules"))
local P=require(Shared:WaitForChild("Progression"))
local Catalog=require(Shared:WaitForChild("Catalog"))
local Data=require(script.Parent:WaitForChild("PlayerDataService"))
local Leaders=require(script.Parent:WaitForChild("LeaderboardService"))
local C=Data.Config
local Network=Instance.new("RemoteEvent"); Network.Name="Network"; Network.Parent=Shared
local S={Sessions={},Rooms={},Queue={},Results={},Invites={},Loading={},Busy={},Buckets={},Closing=false}
local function send(player,kind,payload)
	if player.Parent==Players then Network:FireClient(player,kind,payload) end
end
local function message(player,text) send(player,"Message",text) end
local function profile(player) send(player,"Profile",Data:public(player)) end
local function cosmeticReply(player,kind,category,id,ok,code,text)
	if RunService:IsStudio() and C.CosmeticDebugLogging then
		print(string.format("[Cosmetic] result action=%s category=%s id=%s success=%s code=%s",kind,tostring(category),tostring(id),tostring(ok),tostring(code)))
	end
	send(player,"CosmeticResult",{Action=kind,Category=category,Id=id,Success=ok,Code=code,Message=text})
	message(player,text)
end
local function cosmetic(player,kind,payload)
	local category=type(payload)=="table" and payload.Category or nil
	local id=type(payload)=="table" and payload.Id or nil
	local valid=type(category)=="string" and #category<=32 and type(id)=="string" and #id<=64
	local slot=valid and Catalog.Slots[category] or nil
	local item=slot and Catalog.Items[category..":"..id] or nil
	local d=Data:get(player); local entry=Data.Profiles[player.UserId]
	local isActive=entry and entry.Active and (not entry.Profile or entry.Profile:IsActive()) or false
	local owned=d and slot and d.Inventory[category] and d.Inventory[category][id]==true or false
	local free=Data.Debug and (kind=="Buy" and C.FreeShopPurchasesInDebug or kind=="Equip" and C.FreeCosmeticsInDebug) or false
	if RunService:IsStudio() and C.CosmeticDebugLogging then
		print(string.format("[Cosmetic] request action=%s category=%s id=%s loaded=%s active=%s configured=%s owned=%s debugFree=%s slot=%s fieldExists=%s",kind,valid and category or "invalid",valid and id or "invalid",tostring(d~=nil),tostring(isActive),tostring(item~=nil),tostring(owned),tostring(free),tostring(slot),tostring(d and slot and d.Equipped[slot]~=nil or false)))
	end
	if not d then cosmeticReply(player,kind,valid and category or nil,valid and id or nil,false,"DataNotLoaded","Your player data is still loading."); return end
	if not item then cosmeticReply(player,kind,nil,nil,false,"Unavailable","This cosmetic is unavailable."); return end
	local ok,text,code=Data:mutate(player,function(nextData)
		if kind=="Buy" then return P.purchase(nextData,category,id,Catalog,free) end
		return P.equip(nextData,category,id,Catalog,free)
	end,{Action=kind,Category=category,Id=id})
	profile(player)
	if not ok then
		if RunService:IsStudio() and C.CosmeticDebugLogging then warn("[Cosmetic] rejected internalCode="..tostring(code).." reason="..tostring(text)) end
		code=code or (text=="Data not loaded" and "DataNotLoaded" or "SaveFailed")
		text=code=="NotOwned" and "You don't own this cosmetic yet." or code=="Unavailable" and "This cosmetic is unavailable." or code=="DataNotLoaded" and "Your player data is still loading." or kind=="Equip" and "Unable to equip right now. Please try again." or code=="InternalError" and "Unable to purchase right now. Please try again." or text or "Unable to purchase right now. Please try again."
	end
	cosmeticReply(player,kind,category,id,ok,ok and "OK" or code,text or "Saved")
	if ok then send(player,"Action",{Sound=kind=="Buy" and "Purchase" or "Equip"}) end
end
local function unqueue(player)
	for i=#S.Queue,1,-1 do if S.Queue[i]==player then table.remove(S.Queue,i) end end
end
local function persist(player,result)
	-- Retry the durable inbox. Once written, recovery is idempotent on reconnect.
	for _=1,6 do if Data:settle(player,result) then profile(player); return true end; task.wait(2) end
	warn("[Tetris] Result remains pending or journal unavailable: "..result.id); return false
end
local function playerProfile(player)
	local d=Data:get(player)
	return {UserId=player.UserId,Name=player.Name,DisplayName=player.DisplayName,Rank=d and P.Ranks[d.Rank.Tier] or "Rookie",Tier=d and d.Rank.Tier or 1,Stars=d and d.Rank.Stars or 0,Rating=d and d.Rank.Rating or 1000,Equipped=d and P.clone(d.Equipped) or {}}
end
local function battleEvent(room,kind,values)
	room.EventId=(room.EventId or 0)+1; values.Kind=kind; values.Id=room.EventId; values.MatchId=room.Id
	for _,p in ipairs(room.Players) do send(p,"BattleEvent",values) end
end
local function deliver(room,player,attack)
	if attack<=0 or room.Ended then return end
	local other=room.Players[1]==player and room.Players[2] or room.Players[1]; local target=S.Sessions[other]
	if not target then return end
	E.addGarbage(target.Engine,attack)
	battleEvent(room,"Attack",{From=player.UserId,To=other.UserId,Lines=attack})
end
local function recoverKO(room,player,now)
	local session=S.Sessions[player]; if session.RespawnAt then return end
	local other=room.Players[1]==player and room.Players[2] or room.Players[1]
	S.Sessions[other].Engine.stats.KOs+=1; session.RespawnAt=now+R.KORecovery; E.release(session.Engine)
	battleEvent(room,"KO",{Player=player.UserId,Winner=other.UserId,RecoverAt=session.RespawnAt})
end
local function respawn(session)
	local old=session.Engine; local fresh=E.new(old.bagSeed, R)
	-- Carry cumulative verified statistics and event sequence; reset board/hold/combo/pending.
	fresh.score=old.score; fresh.lines=old.lines; fresh.level=old.level; fresh.elapsed=old.elapsed; fresh.stats=old.stats
	fresh.sequence=old.sequence; fresh.events=old.events; fresh.queue=table.clone(old.queue); fresh.bagSeed=old.bagSeed; fresh.garbageSeed=old.garbageSeed
	E.spawn(fresh); session.Engine=fresh; session.RespawnAt=nil
end
local function refund(room)
	for player,charged in pairs(room.Charged) do if charged then room.Charged[player]=false; persist(player,{id=room.Id..":refund",kind="Refund",roomId=room.Id}) end end
end
local function resultFor(room,player,winner,reason)
	local session=S.Sessions[player]; local start=room.Profiles[player]; local other=room.Players[1]==player and room.Players[2] or room.Players[1]
	local d=Data:get(player); local st=session.Engine.stats
	local outcome=winner==nil and "Draw" or winner==player and "Win" or "Lose"
	local eligible=room.Ranked and (Data.Debug or room.Played>=C.MinRewardSeconds)
	if eligible and not Data.Debug and d then
		local key=tostring(other.UserId); local pair=d.Pairs[key]; local day=math.floor(os.time()/86400)
		if pair and pair.Day==day and (pair.Count>=C.PairRewardsPerDay or os.time()-pair.Last<C.OpponentRewardCooldown) then eligible=false end
	end
	return {id=room.Id,outcome=outcome,score=session.Engine.score,lines=session.Engine.lines,spins=st.TSpins,tetrises=st.Tetrises,perfect=st.PerfectClears,sent=st.Sent,kos=st.KOs,startTier=start.Tier,startRating=start.Rating,opponentRating=room.Profiles[other].Rating,rewardEligible=eligible,opponentId=other.UserId,day=math.floor(os.time()/86400),timestamp=os.time()}
end
local function finish(room,winner,reason)
	if room.Ended then return end
	room.Ended=true; S.Rooms[room.Id]=nil
	if not room.Started then
		refund(room)
		for _,player in ipairs(room.Players) do S.Sessions[player]=nil; send(player,"Lobby",{}); message(player,"Match cancelled before gameplay; energy refunded.") end
		return
	end
	local summaries={}
	if winner and reason=="KO" then S.Sessions[winner].Engine.stats.KOs+=1 end
	for _,player in ipairs(room.Players) do summaries[player]=resultFor(room,player,winner,reason) end
	for _,player in ipairs(room.Players) do
		message(player,"Match finished. Saving results...")
		local session=S.Sessions[player]; local summary=summaries[player]
		local before=Data:get(player) and P.clone(Data:get(player))
		local settled=true
		if room.Ranked then settled=persist(player,summary); if settled then Leaders:update(player) end end
		local after=Data:get(player)
		local other=room.Players[1]==player and room.Players[2] or room.Players[1]
		local payload={Outcome=summary.outcome,Reason=reason,Own=E.pack(session.Engine),Opponent=E.pack(S.Sessions[other].Engine),Profiles=room.PublicProfiles,Ranked=room.Ranked,Rewards=summary.rewardEligible and settled,SettlementPending=not settled,
			Cash=settled and room.Ranked and summary.rewardEligible and summary.outcome=="Win" and C.WinCash[summary.startTier] or 0,BeforeRank=before and before.Rank,AfterRank=after and P.clone(after.Rank),Id=room.Id}
		S.Results[player]={Other=other,Ready=false,Ranked=room.Ranked}; send(player,"Result",payload)
	end
	for _,player in ipairs(room.Players) do S.Sessions[player]=nil end
end
local function startPair(a,b,ranked)
	if S.Sessions[a] or S.Sessions[b] or not Data:get(a) or not Data:get(b) then return end
	local count=0; for _ in pairs(S.Rooms) do count+=1 end
	if count>=C.MaxMatches then
		for _,player in ipairs({a,b}) do send(player,"Lobby",{}); message(player,"All arenas are busy; please search again.") end
		return
	end
	unqueue(a); unqueue(b); S.Results[a]=nil; S.Results[b]=nil
	local room={Id=Http:GenerateGUID(false),Players={a,b},Ranked=ranked,Profiles={},PublicProfiles={playerProfile(a),playerProfile(b)},Charged={},Played=0,Countdown=R.Countdown,Ended=false,Started=false,Preparing=true}
	S.Rooms[room.Id]=room
	local seed=math.random(1,2147483646)
	for _,player in ipairs(room.Players) do
		room.Profiles[player]=P.clone(Data:get(player).Rank)
		S.Sessions[player]={Room=room,Engine=E.new(seed,R),Mode=ranked and "Ranked" or "Challenge"}
		send(player,"Found",{Profiles=room.PublicProfiles,Ranked=ranked,MatchId=room.Id})
	end
	for _,player in ipairs(room.Players) do
		if ranked and not (Data.Debug and C.InfiniteEnergyInDebug) then
			local ok=Data:mutate(player,function(d)
				if d.Energy.Current<C.RankedCost then return false,"Not enough Energy" end
				d.Energy.Current-=C.RankedCost; d.Reservations[room.Id]={At=os.time()}; return true
			end)
			if not ok then finish(room,nil,"Energy unavailable"); return end
			room.Charged[player]=true; profile(player)
		end
		if room.Cancelled or player.Parent~=Players then finish(room,nil,"Cancelled"); return end
	end
	room.Preparing=false; room.StartAt=workspace:GetServerTimeNow()+R.Countdown
end
local function leave(player)
	unqueue(player)
	local session=S.Sessions[player]
	if session then
		if session.Room then
			local room=session.Room; local other=room.Players[1]==player and room.Players[2] or room.Players[1]
			if room.Preparing then room.Cancelled=true else finish(room,other,"Opponent left") end
		else
			persist(player,{id=session.Id,kind="Solo",score=session.Engine.score,lines=session.Engine.lines,spins=session.Engine.stats.TSpins,tetrises=session.Engine.stats.Tetrises,perfect=session.Engine.stats.PerfectClears})
			S.Sessions[player]=nil
		end
	end
end
local function solo(player)
	leave(player); S.Results[player]=nil
	if S.Sessions[player] then return end
	S.Sessions[player]={Id=Http:GenerateGUID(false),Engine=E.new(math.random(1,2147483646),R),Mode="Solo",StartAt=workspace:GetServerTimeNow()+R.Countdown}
end
local function queue(player)
	if S.Sessions[player] then return end
	if Data.Debug and not C.TestRankedMatches then message(player,"Test ranked matches disabled"); return end
	local d=P.refresh(P.clone(Data:get(player)),os.time(),C)
	if not (Data.Debug and C.InfiniteEnergyInDebug) and d.Energy.Current<C.RankedCost then message(player,"No Energy. Regeneration, quests and free Solo are available."); profile(player); return end
	S.Results[player]=nil
	unqueue(player); table.insert(S.Queue,player); send(player,"Searching",{Profile=playerProfile(player),StartedAt=workspace:GetServerTimeNow()})
end
local validInputs={Left=true,Right=true,SoftDrop=true,CW=true,CCW=true,Hold=true,HardDrop=true}
local function command(player,kind,payload)
	if kind=="Buy" or kind=="Equip" then cosmetic(player,kind,payload); return end
	if not Data:get(player) then message(player,"Profile is still loading"); return end
	if kind=="Refresh" then profile(player)
	elseif kind=="Hello" then profile(player); if not S.Sessions[player] then send(player,"Lobby",{}) end
	elseif kind=="Solo" then solo(player)
	elseif kind=="Queue" then queue(player)
	elseif kind=="Cancel" or kind=="Exit" then leave(player); S.Results[player]=nil; send(player,"Lobby",{})
	elseif kind=="Pause" then local s=S.Sessions[player]; if s and s.Mode=="Solo" then s.Engine.paused=payload==true; E.release(s.Engine) end
	elseif kind=="Restart" then local s=S.Sessions[player]; if s and s.Mode=="Solo" then solo(player) end
	elseif kind=="Rematch" then
		local result=S.Results[player]; if not result or result.Other.Parent~=Players then message(player,"Opponent unavailable; use Find Match"); return end
		local other=S.Results[result.Other]
		if not other or other.Other~=player then message(player,"Opponent returned to lobby; use Find Match"); return end
		result.Ready=true; message(player,"Rematch requested. Waiting for opponent.")
		if other and other.Other==player and other.Ready then startPair(player,result.Other,result.Ranked) end
	elseif kind=="ClaimQuest" then
		if type(payload)~="table" or not ({Daily=true,Weekly=true})[payload.Group] or type(payload.Id)~="string" then return end
		local ok,text=Data:mutate(player,function(d) return P.claimQuest(d,payload.Group,payload.Id,C) end); profile(player); message(player,text); if ok then send(player,"Action",{Sound="QuestClaim"}) end
	elseif kind=="Login" then local ok,text=Data:mutate(player,function(d) return P.login(d,os.time(),C) end); profile(player); message(player,text); if ok then send(player,"Action",{Sound="CashEarned"}) end
	elseif kind=="Leaderboard" then
		-- Legacy string requests remain supported. Echo the bounded request identity for race filtering.
		local category=type(payload)=="table" and payload.Kind or payload
		local requestId=type(payload)=="table" and payload.RequestId or nil
		if type(category)~="string" or not ({GlobalRating=true,GlobalWins=true,SeasonRating=true,SeasonWins=true})[category] then return end
		if requestId~=nil and (type(requestId)~="number" or requestId<1 or requestId>2147483647 or requestId%1~=0) then return end
		local rows,text=Leaders:read(player,category); send(player,"Leaderboard",{Rows=rows or {},Kind=category,RequestId=requestId,Notice=text,Unavailable=not rows})
	elseif kind=="Challenge" then
		if type(payload)~="number" or S.Sessions[player] then return end
		local other=Players:GetPlayerByUserId(payload); if not other or other==player or S.Sessions[other] then return end
		local ok,isFriend=pcall(function() return player:IsFriendsWithAsync(other.UserId) end)
		if not ok or not isFriend then message(player,"Choose a friend in this server"); return end
		S.Invites[other]={From=player,Expires=os.clock()+30}; send(other,"Challenge",playerProfile(player)); message(player,"Friend challenge sent")
	elseif kind=="AcceptChallenge" then
		local invitation=S.Invites[player]; S.Invites[player]=nil
		if invitation and invitation.Expires>os.clock() and invitation.From.Parent==Players then startPair(player,invitation.From,false) end
	elseif kind=="Settings" then
		if type(payload)~="table" then return end
		Data:mutate(player,function(d) if type(payload.Sound)=="boolean" then d.Settings.Sound=payload.Sound end; if type(payload.ReducedMotion)=="boolean" then d.Settings.ReducedMotion=payload.ReducedMotion end; for _,field in ipairs({"ClassicHUD","SwapRotation"}) do if type(payload[field])=="boolean" then d.Settings[field]=payload[field] end end; for _,field in ipairs({"Master","MusicVolume","SFXVolume","UIScale"}) do local value=payload[field]; if type(value)=="number" and value==value and math.abs(value)<=1000 then d.Settings[field]=math.clamp(value,field=="UIScale" and 0.9 or 0,1) end end; return true end); profile(player)
	elseif kind=="Emote" then
		local session=S.Sessions[player]; if not session or not session.Room or session.Room.Ended or type(payload)~="number" or payload%1~=0 or not R.Emotes[payload] then return end
		local now=workspace:GetServerTimeNow(); if now<(session.EmoteAt or 0) then return end; session.EmoteAt=now+R.EmoteCooldown
		battleEvent(session.Room,"Emote",{From=player.UserId,Text=R.Emotes[payload]})
	end
end
Network.OnServerEvent:Connect(function(player,kind,payload)
	if S.Closing or type(kind)~="string" or #kind>30 then return end
	local now=os.clock(); local b=S.Buckets[player] or {Time=now,Input=80,Command=8}; S.Buckets[player]=b
	local dt=now-b.Time; b.Time=now; b.Input=math.min(80,b.Input+dt*60); b.Command=math.min(8,b.Command+dt*2)
	if kind=="Input" then
		if type(payload)~="table" or not validInputs[payload.Action] or type(payload.Down)~="boolean" then return end
		local session=S.Sessions[player]
		if not session or (session.Room and (session.Room.Ended or not session.Room.Started or workspace:GetServerTimeNow()>=session.Room.EndAt)) or session.StartAt and workspace:GetServerTimeNow()<session.StartAt or session.RespawnAt then return end
		-- A rate-limited press must never prevent releasing an already held key.
		if not session.Engine or b.Input<1 and (payload.Down or not session.Engine.controls[payload.Action]) then return end
		b.Input=math.max(0,b.Input-1)
		if payload.Action=="HardDrop" and payload.Down then if now-(session.LastDrop or 0)<0.08 then return end; session.LastDrop=now end
		local beforeEvent=session.Engine.sequence
  local equipped=Data:get(player) and Data:get(player).Equipped
  local dropTheme=equipped and equipped.DropEffect
  local attack=E.input(session.Engine,payload.Action,payload.Down)
  if payload.Action=="HardDrop" and payload.Down then
   for _,event in ipairs(session.Engine.events) do if event.id>beforeEvent and event.name=="HardDrop" then event.data.DropEffect=dropTheme end end
  end
		if attack>0 and session.Room then deliver(session.Room,player,attack) end
		return
	end
	if b.Command<1 or S.Busy[player] then
  if kind=="Leaderboard" and type(payload)=="table" and type(payload.Kind)=="string" and type(payload.RequestId)=="number" then
   send(player,"Leaderboard",{Kind=payload.Kind,RequestId=payload.RequestId,Rows={},Unavailable=true,Notice="Server busy. Please retry in a moment.",RetryAfter=0.6})
  end
  return
 end; b.Command-=1; S.Busy[player]=true
	local ok,err=pcall(command,player,kind,payload); S.Busy[player]=nil
	if not ok then warn("[Tetris server] "..tostring(err)); message(player,"Operation failed; please retry") end
end)
local accumulator=0; local snapshotTime=0; local queueTime=0
RunService.Heartbeat:Connect(function(dt)
	accumulator=math.min(0.5,accumulator+dt); snapshotTime+=dt; queueTime+=dt
	local now=workspace:GetServerTimeNow()
	for _,room in pairs(S.Rooms) do if not room.Preparing and not room.Started and now>=room.StartAt then room.Started=true; room.EndAt=room.StartAt+R.MatchDuration end end
	while accumulator>=1/60 do
		accumulator-=1/60
		for player,session in pairs(S.Sessions) do
			local room=session.Room
			if session.Engine and not session.RespawnAt and (not session.StartAt or now>=session.StartAt) and (not room or room.Started and not room.Ended and now<room.EndAt) then
				local attack=E.step(session.Engine,1/60)
				if room and attack>0 then deliver(room,player,attack) end
			end
		end
	end
	for _,room in pairs(S.Rooms) do
		if room.Started and not room.Ended then
			room.Played=math.max(0,now-room.StartAt)
			local a,b=room.Players[1],room.Players[2]; local sa,sb=S.Sessions[a],S.Sessions[b]
			if sa and sb then
				if (not room.Ranked or not R.TimedKO) and (not sa.Engine.alive or not sb.Engine.alive) then
					local winner=sa.Engine.alive and a or sb.Engine.alive and b or nil
					task.spawn(finish,room,winner,"KO")
				elseif now>=room.EndAt then
					-- Deterministic policy: sent garbage, then cleared lines, then score.
					local winner
					for _,values in ipairs({{sa.Engine.stats.KOs,sb.Engine.stats.KOs},{sa.Engine.stats.Sent,sb.Engine.stats.Sent},{sa.Engine.lines,sb.Engine.lines},{sa.Engine.score,sb.Engine.score}}) do if values[1]~=values[2] then winner=values[1]>values[2] and a or b; break end end
					task.spawn(finish,room,winner,"Time expired")
				elseif room.Ranked and R.TimedKO then
					for _,p in ipairs(room.Players) do local session=S.Sessions[p]
						if not session.Engine.alive and not session.RespawnAt then recoverKO(room,p,now) end
						if session.RespawnAt and now>=session.RespawnAt then respawn(session) end
					end
				end
			end
		end
	end
	if snapshotTime>=1/R.SnapshotHz then
		snapshotTime=0
		for player,session in pairs(S.Sessions) do
			local room=session.Room
			if session.Engine and (not room or not room.Ended) then
				local other=room and (room.Players[1]==player and room.Players[2] or room.Players[1]); local osession=other and S.Sessions[other]
				local start=room and room.StartAt or session.StartAt
				send(player,"State",{Mode=session.Mode,MatchId=room and room.Id or session.Id,StartAt=start,EndAt=room and room.EndAt,ServerNow=now,Own=E.pack(session.Engine),Opponent=osession and E.pack(osession.Engine),Profiles=room and room.PublicProfiles,Countdown=start and math.max(0,math.ceil(start-now)) or room and not room.Started and R.Countdown or 0,Remaining=room and (room.Started and math.max(0,room.EndAt-now) or R.MatchDuration) or nil,RespawnAt=session.RespawnAt,Round=1})
			end
		end
	end
	if queueTime>=0.5 then
		queueTime=0
		for i=#S.Queue,1,-1 do local p=S.Queue[i]; if p.Parent~=Players or not Data:get(p) or S.Sessions[p] then table.remove(S.Queue,i) end end
		while #S.Queue>=2 do
			local a=table.remove(S.Queue,1); local b=table.remove(S.Queue,1)
			-- Reserve before a yielding data transaction can let another queue request race.
			S.Sessions[a]={Reserved=true}; S.Sessions[b]={Reserved=true}
			task.spawn(function() S.Sessions[a]=nil; S.Sessions[b]=nil; startPair(a,b,true) end)
		end
	end
end)
local function joined(player)
	if S.Loading[player] or Data:get(player) then return end
	S.Loading[player]=true
	local ok,text=Data:load(player); S.Loading[player]=nil
	if not ok then player:Kick(text); return end
	if player.Parent~=Players then Data:release(player); return end
	profile(player); send(player,"Lobby",{})
	-- Alternative to invite attribution: a verified first-time friend session.
	task.delay(C.SocialMinSeconds,function()
		local newcomer=Data:get(player)
		if player.Parent~=Players or not newcomer or os.time()-newcomer.CreatedAt>600 or player.AccountAge<C.SocialMinAccountAge then return end
		for _,host in ipairs(Players:GetPlayers()) do
			if host~=player and Data:get(host) then
				local success,friend=pcall(function() return host:IsFriendsWithAsync(player.UserId) end)
				local hostData=P.refresh(P.clone(Data:get(host)),os.time(),C)
				if success and friend and not newcomer.SocialRewardHost and hostData.SocialRewards.Count<C.SocialDailyLimit and not hostData.SocialRewards.Seen[tostring(player.UserId)] then
					local reserved=Data:mutate(player,function(d)
						if d.SocialRewardHost then return false end
						d.SocialRewardHost=host.UserId; return true
					end)
					if not reserved then return end
					persist(host,{id="social:"..player.UserId,kind="Social",friendId=player.UserId})
					return
				end
			end
		end
	end)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player) leave(player); Data:release(player); S.Results[player]=nil; S.Invites[player]=nil; S.Buckets[player]=nil; S.Busy[player]=nil end)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(joined,player) end
game:BindToClose(function()
	S.Closing=true
	for _,room in pairs(S.Rooms) do if not room.Started then room.Cancelled=true; if not room.Preparing then finish(room,nil,"Server closing") end end end
	local pending=0
	for _,player in ipairs(Players:GetPlayers()) do pending+=1; task.spawn(function() leave(player); Data:release(player); pending-=1 end) end
	local deadline=os.clock()+25; while pending>0 and os.clock()<deadline do task.wait(0.1) end
end)
S.Matchmaking={Enqueue=queue,Cancel=unqueue,StartPair=startPair}
return S

end)()
S=StudioS
local shopper=player(11001); shopper.AccountAge=365
Players.PlayerAdded:fire(shopper); tick(0.1); assert(Data:get(shopper))
local function request(category,id)
	S.Buckets={}; sent[shopper].CosmeticResult=nil
	send(shopper,"Equip",{Category=category,Id=id}); tick(0.1)
	return assert(sent[shopper].CosmeticResult,"No structured cosmetic response")
end
local balance=Data:get(shopper).Cash
for category,slot in pairs(Catalog.Slots) do
	local reply=request(category,"Default")
	assert(reply.Success and reply.Code=="OK" and Data:get(shopper).Equipped[slot]=="Default")
	assert(Data:get(shopper).Cash==balance)
end
print("PASS all four default cosmetics equip through the real remote without spending Cash")
local chosen={}; assert(Data:mutate(shopper,function(d)
	d.Cash=125000
	for category in pairs(Catalog.Slots) do local item=Catalog.list(category)[2]; chosen[category]=item.Id; d.Inventory[category][item.Id]=true end
	return true
end))
for category,slot in pairs(Catalog.Slots) do
	for _,id in ipairs({chosen[category],"Default",chosen[category]}) do
		local reply=request(category,id); assert(reply.Success and reply.Category==category and reply.Id==id)
		assert(Data:get(shopper).Equipped[slot]==id and Data:get(shopper).Cash==125000)
	end
end
print("PASS repeated owned skin/drop/ghost/sound equips preserve Cash and return accurate success payloads")
local missing=Catalog.list("BrickSkins")[3].Id; local reply=request("BrickSkins",missing)
assert(not reply.Success and reply.Code=="NotOwned" and reply.Message=="You don't own this cosmetic yet.")
assert(Data:get(shopper).Equipped.BrickSkin==chosen.BrickSkins and Data:get(shopper).Cash==125000)
for _,pair in ipairs({{"BrickSkins","Missing"},{"Unknown","Default"},{"HardDropEffects","Default"}}) do
	reply=request(pair[1],pair[2]); assert(not reply.Success and reply.Code=="Unavailable")
end
S.Buckets={}; send(shopper,"Equip",{Category={},Id=5}); assert(sent[shopper].CosmeticResult.Code=="Unavailable")
print("PASS unowned, mismatched and malformed cosmetic requests reject without changing equipped state")
-- Exercise the import on Buy as well; then equip an actually purchased item.
S.Buckets={}; send(shopper,"Buy",{Category="BrickSkins",Id=missing}); tick(0.1)
assert(sent[shopper].CosmeticResult.Success and Data:get(shopper).Inventory.BrickSkins[missing])
balance=125000-Catalog.Items["BrickSkins:"..missing].Price
reply=request("BrickSkins",missing); assert(reply.Success and Data:get(shopper).Cash==balance); chosen.BrickSkins=missing
Data:release(shopper); tick(0.1)
local reloaded; task.spawn(function() reloaded=Data:load(shopper) end); tick(0.3); assert(reloaded)
for category,slot in pairs(Catalog.Slots) do assert(Data:get(shopper).Equipped[slot]==chosen[category]) end
assert(Data:get(shopper).Cash==balance)
print("PASS remote purchase then equip and rejoin preserve ownership, all equipped slots and exact Cash")
local success,text,code=Data:mutate(shopper,function() error("equip-test-private-stack-marker") end,{Action="Equip",Category="BrickSkins",Id="Default"})
assert(not success and code=="InternalError" and not text:find("private%-stack") and Data:get(shopper).Cash==balance)
if RunService:IsStudio() then assert(warnings[#warnings]:find("equip-test-private-stack-marker",1,true) and warnings[#warnings]:find("action=Equip",1,true)) end
print("PASS mutation exceptions return an internal code without exposing server traces or changing data")
Data:release(shopper); reply=request("BrickSkins","Default")
assert(not reply.Success and reply.Code=="DataNotLoaded" and reply.Message=="Your player data is still loading.")
print("PASS unloaded profiles cannot equip or receive false success")

Players.List={}; C.ProfileStoreStudioPersistence=true; remote.OnServerEvent=event()
local StudioPersistentData=(function()
-- Central profile authority. Live rollout stays on the original backend until verified.
local DSS=game:GetService("DataStoreService")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local Config=require(script.Parent:WaitForChild("GameConfig"))
local studio=RunService:IsStudio()
if not studio and not Config.ProfileStoreLiveEnabled then
	return require(script.Parent:WaitForChild("LegacyPlayerDataService"))
end
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local P=require(Shared:WaitForChild("Progression"))
local Catalog=require(Shared:WaitForChild("Catalog"))
local ProfileStore=require(script.Parent:WaitForChild("ProfileStore"))
local Migration=require(script.Parent:WaitForChild("ProfileStoreMigration"))
local namespace=studio and Config.ProfileStoreTestDataStoreName or Config.DataStoreName.."_Live"
assert(type(namespace)=="string" and #namespace<=43,"ProfileStore namespace is missing or too long")
local Data={Profiles={},Loading={},Debug=studio and Config.Debug and not Config.ProfileStoreStudioPersistence,Config=Config,Namespace=namespace,Closing=false}
local playerStore=ProfileStore.New(namespace,P.default(0))
local store=DSS:GetDataStore(namespace)
local backup=DSS:GetDataStore(namespace.."_Backup")
local inbox=DSS:GetDataStore(namespace.."_Results")
local function retry(fn)
	local problem
	for attempt=1,4 do
		local values=table.pack(pcall(fn))
		if values[1] then return true,table.unpack(values,2,values.n) end
		problem=values[2]; if attempt<4 then task.wait(0.5*2^(attempt-1)) end
	end
	return false,tostring(problem)
end
local function active(entry) return entry and entry.Active and not entry.Releasing and entry.Profile:IsActive() end
local function endEntry(self,entry,unexpected)
	entry.Ready=false; entry.Active=false; entry.Releasing=true
	if entry.Profile:IsActive() then entry.Profile:EndSession() end
	if self.Profiles[entry.Player.UserId]==entry then self.Profiles[entry.Player.UserId]=nil end
	if unexpected and entry.Player.Parent==Players and not self.Closing and not ProfileStore.IsClosing then entry.Player:Kick("Your data session ended. Please reconnect; your existing save was not reset.") end
end
local function commit(self,entry,nextData)
	if not active(entry) then return false,"Data session closed" end
	local token=Http:GenerateGUID(false); nextData._TetrisSaveToken=token
	entry.Profile.Data=nextData; entry.Data=nextData
	if self.Debug then return true end -- Explicit Studio-only ProfileStore.Mock session.
	local deadline=os.clock()+Config.ProfileSaveTimeout; local nextAttempt=0
	while active(entry) and os.clock()<deadline do
		if entry.Profile.LastSavedData._TetrisSaveToken==token then return true end
		if os.clock()>=nextAttempt then entry.Profile:Save(); nextAttempt=os.clock()+2 end
		if entry.Profile.LastSavedData._TetrisSaveToken==token and active(entry) then return true end
		task.wait(0.05)
	end
	-- The write may already have reached Roblox. Preserve the atomic Cash/item pair,
	-- close access and let ProfileStore finish its final save instead of pretending to roll it back.
	endEntry(self,entry,not entry.Releasing)
	return false,"Save confirmation was interrupted. Reconnect to check the completed operation."
end
function Data:load(player)
	local existing=self.Profiles[player.UserId]
	if active(existing) then return existing.Player==player and existing.Ready,"Data is already active in this server" end
	if self.Loading[player.UserId] then return false,"A profile load is already in progress" end
	self.Loading[player.UserId]=player
	local deadline=os.clock()+Config.ProfileLoadTimeout
	local function cancelled() return self.Closing or ProfileStore.IsClosing or player.Parent~=Players or os.clock()>=deadline end
	local function fail(text,entry)
		if entry then endEntry(self,entry,false) end
		if self.Loading[player.UserId]==player then self.Loading[player.UserId]=nil end
		return false,text
	end
	if cancelled() then return fail("Profile loading was cancelled") end
	if not self.Debug then
		while ProfileStore.DataStoreState=="NotReady" and not cancelled() do task.wait(0.05) end
		if cancelled() or ProfileStore.DataStoreState~="Access" then return fail("Persistent data is unavailable. Enable API access in the separate test experience; no mock production profile was created.") end
		local prepared,text=Migration.prepare(store,backup,tostring(player.UserId),player.UserId,Config.ProfileStoreMigrateLegacy,retry,cancelled)
		if not prepared then return fail(text) end
	end
	local target=self.Debug and playerStore.Mock or playerStore
	local started,profile=pcall(function() return target:StartSessionAsync(tostring(player.UserId),{Cancel=cancelled}) end)
	if not started or not profile then return fail("Your profile could not be loaded. No purchases or rewards were enabled; please reconnect.") end
	local entry={Player=player,Profile=profile,Data=profile.Data,Active=true,Ready=false,Busy=false,Releasing=false}
	self.Profiles[player.UserId]=entry
	profile.OnSessionEnd:Connect(function()
		local unexpected=not entry.Releasing
		entry.Active=false; entry.Ready=false
		if self.Profiles[player.UserId]==entry then self.Profiles[player.UserId]=nil end
		if unexpected and player.Parent==Players and not self.Closing and not ProfileStore.IsClosing then player:Kick("Your data session ended. Please reconnect.") end
	end)
	if cancelled() or not profile:IsActive() then return fail("Profile loading was cancelled",entry) end
	local checked,text=Migration.payloadValid(profile.Data); if not checked then return fail(text,entry) end
	local initialized,problem=pcall(function()
		profile:AddUserId(player.UserId); profile:Reconcile()
		if profile.Data.CreatedAt==0 then profile.Data.CreatedAt=profile.FirstSessionTime end
		entry.Data=P.validate(P.clone(profile.Data),os.time(),Catalog,Config); profile.Data=entry.Data
	end)
	if not initialized then return fail("Your existing profile needs manual inspection; it was not reset. "..tostring(problem),entry) end
	local pending={}
	if not self.Debug then
		local readOK,value=retry(function() return inbox:GetAsync(tostring(player.UserId)) end)
		if not readOK or value~=nil and type(value)~="table" then return fail("Pending results could not be recovered. Please reconnect.",entry) end
		pending=value or {}
	end
	local nextData=P.clone(entry.Data); P.refresh(nextData,os.time(),Config)
	local recovered,recoverError=pcall(function()
		for _,result in pairs(pending) do P.settle(nextData,result,Config) end
		for id in pairs(nextData.Reservations) do P.settle(nextData,{id=id..":refund",kind="Refund",roomId=id},Config) end
	end)
	if not recovered then return fail("Pending results need manual inspection: "..tostring(recoverError),entry) end
	entry.Busy=true; local saved,message=commit(self,entry,nextData); entry.Busy=false
	if not saved then return fail(message,entry) end
	if not self.Debug and next(pending) then
		retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old)
			old=old or {}; for id in pairs(pending) do if entry.Profile.LastSavedData.ProcessedMatchIds[id] then old[id]=nil end end; return old
		end) end)
	end
	if cancelled() or not active(entry) then return fail("Profile loading was cancelled",entry) end
	entry.Ready=true; self.Loading[player.UserId]=nil; return true
end
function Data:get(player)
	local entry=self.Profiles[player.UserId]
	return active(entry) and entry.Ready and entry.Player==player and entry.Data or nil
end
function Data:mutate(player,fn,context)
	local entry=self.Profiles[player.UserId]
	if not active(entry) or not entry.Ready or entry.Player~=player then return false,"Data not loaded" end
	while entry.Busy and active(entry) do task.wait() end
	if not active(entry) or not entry.Ready then return false,"Session closed" end
	entry.Busy=true
	local nextData=P.clone(entry.Data); P.refresh(nextData,os.time(),Config)
	local safe,accepted,message,code=xpcall(function() return fn(nextData) end,function(err) return debug.traceback(tostring(err),2) end)
	if not safe then
		entry.Busy=false
		if studio and Config.CosmeticDebugLogging then warn("[PlayerData] Mutation exception action="..tostring(context and context.Action).." category="..tostring(context and context.Category).." id="..tostring(context and context.Id).."\n"..accepted) end
		return false,"Unable to complete this action right now. Please try again.","InternalError"
	end
	if not accepted then entry.Busy=false; return false,message,code end
	local saved,text=commit(self,entry,nextData); entry.Busy=false
	return saved,saved and message or text
end
function Data:settle(player,result)
	if type(result)~="table" or type(result.id)~="string" then return false end
	if not self.Debug then
		local journaled=retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old) old=old or {}; old[result.id]=P.clone(result); return old end) end)
		if not journaled then return false end
	end
	local saved=self:mutate(player,function(d) P.settle(d,result,Config); return true end)
	if saved and not self.Debug then
		local entry=self.Profiles[player.UserId]
		if entry and entry.Profile.LastSavedData.ProcessedMatchIds[result.id] then
			retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old) old=old or {}; old[result.id]=nil; return old end) end)
		end
	end
	return saved
end
function Data:release(player)
	local entry=self.Profiles[player.UserId]; if not entry or entry.Player~=player then return end
	entry.Ready=false; entry.Releasing=true
	while entry.Busy do task.wait() end
	endEntry(self,entry,false)
end
function Data:public(player)
	local d=self:get(player); if not d then return nil end
	local out=P.refresh(P.clone(d),os.time(),Config); out.ProcessedMatchIds=nil; out.MatchReceipts=nil; out.Reservations=nil; out.Pairs=nil; out.SocialRewards.Seen=nil; out._TetrisSaveToken=nil
	out.Debug=self.Debug; out.Energy.Next=P.nextEnergy(out,os.time(),Config)
	out.DebugPrivileges={FreeCosmetics=self.Debug and Config.FreeCosmeticsInDebug,FreePurchases=self.Debug and Config.FreeShopPurchasesInDebug,InfiniteEnergy=self.Debug and Config.InfiniteEnergyInDebug}
	out.Economy={EnergyCap=Config.EnergyCap,BonusCap=Config.BonusEnergyCap,EnergyInterval=Config.EnergyInterval,RankedCost=Config.RankedCost,SocialEnergy=Config.SocialEnergy,SocialLimit=Config.SocialDailyLimit,SocialMinSeconds=Config.SocialMinSeconds,LoginCash=Config.LoginCash,LoginEnergy=Config.LoginEnergy,SeasonDays=Config.SeasonDays,WinCash=Config.WinCash}
	return out
end
game:BindToClose(function() Data.Closing=true end)
print("[PlayerData] ProfileStore / "..(Data.Debug and "Studio mock" or studio and "isolated persistence test" or "live persistence").." / "..namespace)
return Data

end)()
modules.PlayerDataService=StudioPersistentData; Data=StudioPersistentData; assert(not Data.Debug)
local StudioPersistentS=(function()
local Catalog=nil
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local Shared=RS:WaitForChild("Shared")
local E=require(Shared:WaitForChild("TetrisEngine"))
local R=require(Shared:WaitForChild("Config"):WaitForChild("Rules"))
local P=require(Shared:WaitForChild("Progression"))
local Catalog=require(Shared:WaitForChild("Catalog"))
local Data=require(script.Parent:WaitForChild("PlayerDataService"))
local Leaders=require(script.Parent:WaitForChild("LeaderboardService"))
local C=Data.Config
local Network=Instance.new("RemoteEvent"); Network.Name="Network"; Network.Parent=Shared
local S={Sessions={},Rooms={},Queue={},Results={},Invites={},Loading={},Busy={},Buckets={},Closing=false}
local function send(player,kind,payload)
	if player.Parent==Players then Network:FireClient(player,kind,payload) end
end
local function message(player,text) send(player,"Message",text) end
local function profile(player) send(player,"Profile",Data:public(player)) end
local function cosmeticReply(player,kind,category,id,ok,code,text)
	if RunService:IsStudio() and C.CosmeticDebugLogging then
		print(string.format("[Cosmetic] result action=%s category=%s id=%s success=%s code=%s",kind,tostring(category),tostring(id),tostring(ok),tostring(code)))
	end
	send(player,"CosmeticResult",{Action=kind,Category=category,Id=id,Success=ok,Code=code,Message=text})
	message(player,text)
end
local function cosmetic(player,kind,payload)
	local category=type(payload)=="table" and payload.Category or nil
	local id=type(payload)=="table" and payload.Id or nil
	local valid=type(category)=="string" and #category<=32 and type(id)=="string" and #id<=64
	local slot=valid and Catalog.Slots[category] or nil
	local item=slot and Catalog.Items[category..":"..id] or nil
	local d=Data:get(player); local entry=Data.Profiles[player.UserId]
	local isActive=entry and entry.Active and (not entry.Profile or entry.Profile:IsActive()) or false
	local owned=d and slot and d.Inventory[category] and d.Inventory[category][id]==true or false
	local free=Data.Debug and (kind=="Buy" and C.FreeShopPurchasesInDebug or kind=="Equip" and C.FreeCosmeticsInDebug) or false
	if RunService:IsStudio() and C.CosmeticDebugLogging then
		print(string.format("[Cosmetic] request action=%s category=%s id=%s loaded=%s active=%s configured=%s owned=%s debugFree=%s slot=%s fieldExists=%s",kind,valid and category or "invalid",valid and id or "invalid",tostring(d~=nil),tostring(isActive),tostring(item~=nil),tostring(owned),tostring(free),tostring(slot),tostring(d and slot and d.Equipped[slot]~=nil or false)))
	end
	if not d then cosmeticReply(player,kind,valid and category or nil,valid and id or nil,false,"DataNotLoaded","Your player data is still loading."); return end
	if not item then cosmeticReply(player,kind,nil,nil,false,"Unavailable","This cosmetic is unavailable."); return end
	local ok,text,code=Data:mutate(player,function(nextData)
		if kind=="Buy" then return P.purchase(nextData,category,id,Catalog,free) end
		return P.equip(nextData,category,id,Catalog,free)
	end,{Action=kind,Category=category,Id=id})
	profile(player)
	if not ok then
		if RunService:IsStudio() and C.CosmeticDebugLogging then warn("[Cosmetic] rejected internalCode="..tostring(code).." reason="..tostring(text)) end
		code=code or (text=="Data not loaded" and "DataNotLoaded" or "SaveFailed")
		text=code=="NotOwned" and "You don't own this cosmetic yet." or code=="Unavailable" and "This cosmetic is unavailable." or code=="DataNotLoaded" and "Your player data is still loading." or kind=="Equip" and "Unable to equip right now. Please try again." or code=="InternalError" and "Unable to purchase right now. Please try again." or text or "Unable to purchase right now. Please try again."
	end
	cosmeticReply(player,kind,category,id,ok,ok and "OK" or code,text or "Saved")
	if ok then send(player,"Action",{Sound=kind=="Buy" and "Purchase" or "Equip"}) end
end
local function unqueue(player)
	for i=#S.Queue,1,-1 do if S.Queue[i]==player then table.remove(S.Queue,i) end end
end
local function persist(player,result)
	-- Retry the durable inbox. Once written, recovery is idempotent on reconnect.
	for _=1,6 do if Data:settle(player,result) then profile(player); return true end; task.wait(2) end
	warn("[Tetris] Result remains pending or journal unavailable: "..result.id); return false
end
local function playerProfile(player)
	local d=Data:get(player)
	return {UserId=player.UserId,Name=player.Name,DisplayName=player.DisplayName,Rank=d and P.Ranks[d.Rank.Tier] or "Rookie",Tier=d and d.Rank.Tier or 1,Stars=d and d.Rank.Stars or 0,Rating=d and d.Rank.Rating or 1000,Equipped=d and P.clone(d.Equipped) or {}}
end
local function battleEvent(room,kind,values)
	room.EventId=(room.EventId or 0)+1; values.Kind=kind; values.Id=room.EventId; values.MatchId=room.Id
	for _,p in ipairs(room.Players) do send(p,"BattleEvent",values) end
end
local function deliver(room,player,attack)
	if attack<=0 or room.Ended then return end
	local other=room.Players[1]==player and room.Players[2] or room.Players[1]; local target=S.Sessions[other]
	if not target then return end
	E.addGarbage(target.Engine,attack)
	battleEvent(room,"Attack",{From=player.UserId,To=other.UserId,Lines=attack})
end
local function recoverKO(room,player,now)
	local session=S.Sessions[player]; if session.RespawnAt then return end
	local other=room.Players[1]==player and room.Players[2] or room.Players[1]
	S.Sessions[other].Engine.stats.KOs+=1; session.RespawnAt=now+R.KORecovery; E.release(session.Engine)
	battleEvent(room,"KO",{Player=player.UserId,Winner=other.UserId,RecoverAt=session.RespawnAt})
end
local function respawn(session)
	local old=session.Engine; local fresh=E.new(old.bagSeed, R)
	-- Carry cumulative verified statistics and event sequence; reset board/hold/combo/pending.
	fresh.score=old.score; fresh.lines=old.lines; fresh.level=old.level; fresh.elapsed=old.elapsed; fresh.stats=old.stats
	fresh.sequence=old.sequence; fresh.events=old.events; fresh.queue=table.clone(old.queue); fresh.bagSeed=old.bagSeed; fresh.garbageSeed=old.garbageSeed
	E.spawn(fresh); session.Engine=fresh; session.RespawnAt=nil
end
local function refund(room)
	for player,charged in pairs(room.Charged) do if charged then room.Charged[player]=false; persist(player,{id=room.Id..":refund",kind="Refund",roomId=room.Id}) end end
end
local function resultFor(room,player,winner,reason)
	local session=S.Sessions[player]; local start=room.Profiles[player]; local other=room.Players[1]==player and room.Players[2] or room.Players[1]
	local d=Data:get(player); local st=session.Engine.stats
	local outcome=winner==nil and "Draw" or winner==player and "Win" or "Lose"
	local eligible=room.Ranked and (Data.Debug or room.Played>=C.MinRewardSeconds)
	if eligible and not Data.Debug and d then
		local key=tostring(other.UserId); local pair=d.Pairs[key]; local day=math.floor(os.time()/86400)
		if pair and pair.Day==day and (pair.Count>=C.PairRewardsPerDay or os.time()-pair.Last<C.OpponentRewardCooldown) then eligible=false end
	end
	return {id=room.Id,outcome=outcome,score=session.Engine.score,lines=session.Engine.lines,spins=st.TSpins,tetrises=st.Tetrises,perfect=st.PerfectClears,sent=st.Sent,kos=st.KOs,startTier=start.Tier,startRating=start.Rating,opponentRating=room.Profiles[other].Rating,rewardEligible=eligible,opponentId=other.UserId,day=math.floor(os.time()/86400),timestamp=os.time()}
end
local function finish(room,winner,reason)
	if room.Ended then return end
	room.Ended=true; S.Rooms[room.Id]=nil
	if not room.Started then
		refund(room)
		for _,player in ipairs(room.Players) do S.Sessions[player]=nil; send(player,"Lobby",{}); message(player,"Match cancelled before gameplay; energy refunded.") end
		return
	end
	local summaries={}
	if winner and reason=="KO" then S.Sessions[winner].Engine.stats.KOs+=1 end
	for _,player in ipairs(room.Players) do summaries[player]=resultFor(room,player,winner,reason) end
	for _,player in ipairs(room.Players) do
		message(player,"Match finished. Saving results...")
		local session=S.Sessions[player]; local summary=summaries[player]
		local before=Data:get(player) and P.clone(Data:get(player))
		local settled=true
		if room.Ranked then settled=persist(player,summary); if settled then Leaders:update(player) end end
		local after=Data:get(player)
		local other=room.Players[1]==player and room.Players[2] or room.Players[1]
		local payload={Outcome=summary.outcome,Reason=reason,Own=E.pack(session.Engine),Opponent=E.pack(S.Sessions[other].Engine),Profiles=room.PublicProfiles,Ranked=room.Ranked,Rewards=summary.rewardEligible and settled,SettlementPending=not settled,
			Cash=settled and room.Ranked and summary.rewardEligible and summary.outcome=="Win" and C.WinCash[summary.startTier] or 0,BeforeRank=before and before.Rank,AfterRank=after and P.clone(after.Rank),Id=room.Id}
		S.Results[player]={Other=other,Ready=false,Ranked=room.Ranked}; send(player,"Result",payload)
	end
	for _,player in ipairs(room.Players) do S.Sessions[player]=nil end
end
local function startPair(a,b,ranked)
	if S.Sessions[a] or S.Sessions[b] or not Data:get(a) or not Data:get(b) then return end
	local count=0; for _ in pairs(S.Rooms) do count+=1 end
	if count>=C.MaxMatches then
		for _,player in ipairs({a,b}) do send(player,"Lobby",{}); message(player,"All arenas are busy; please search again.") end
		return
	end
	unqueue(a); unqueue(b); S.Results[a]=nil; S.Results[b]=nil
	local room={Id=Http:GenerateGUID(false),Players={a,b},Ranked=ranked,Profiles={},PublicProfiles={playerProfile(a),playerProfile(b)},Charged={},Played=0,Countdown=R.Countdown,Ended=false,Started=false,Preparing=true}
	S.Rooms[room.Id]=room
	local seed=math.random(1,2147483646)
	for _,player in ipairs(room.Players) do
		room.Profiles[player]=P.clone(Data:get(player).Rank)
		S.Sessions[player]={Room=room,Engine=E.new(seed,R),Mode=ranked and "Ranked" or "Challenge"}
		send(player,"Found",{Profiles=room.PublicProfiles,Ranked=ranked,MatchId=room.Id})
	end
	for _,player in ipairs(room.Players) do
		if ranked and not (Data.Debug and C.InfiniteEnergyInDebug) then
			local ok=Data:mutate(player,function(d)
				if d.Energy.Current<C.RankedCost then return false,"Not enough Energy" end
				d.Energy.Current-=C.RankedCost; d.Reservations[room.Id]={At=os.time()}; return true
			end)
			if not ok then finish(room,nil,"Energy unavailable"); return end
			room.Charged[player]=true; profile(player)
		end
		if room.Cancelled or player.Parent~=Players then finish(room,nil,"Cancelled"); return end
	end
	room.Preparing=false; room.StartAt=workspace:GetServerTimeNow()+R.Countdown
end
local function leave(player)
	unqueue(player)
	local session=S.Sessions[player]
	if session then
		if session.Room then
			local room=session.Room; local other=room.Players[1]==player and room.Players[2] or room.Players[1]
			if room.Preparing then room.Cancelled=true else finish(room,other,"Opponent left") end
		else
			persist(player,{id=session.Id,kind="Solo",score=session.Engine.score,lines=session.Engine.lines,spins=session.Engine.stats.TSpins,tetrises=session.Engine.stats.Tetrises,perfect=session.Engine.stats.PerfectClears})
			S.Sessions[player]=nil
		end
	end
end
local function solo(player)
	leave(player); S.Results[player]=nil
	if S.Sessions[player] then return end
	S.Sessions[player]={Id=Http:GenerateGUID(false),Engine=E.new(math.random(1,2147483646),R),Mode="Solo",StartAt=workspace:GetServerTimeNow()+R.Countdown}
end
local function queue(player)
	if S.Sessions[player] then return end
	if Data.Debug and not C.TestRankedMatches then message(player,"Test ranked matches disabled"); return end
	local d=P.refresh(P.clone(Data:get(player)),os.time(),C)
	if not (Data.Debug and C.InfiniteEnergyInDebug) and d.Energy.Current<C.RankedCost then message(player,"No Energy. Regeneration, quests and free Solo are available."); profile(player); return end
	S.Results[player]=nil
	unqueue(player); table.insert(S.Queue,player); send(player,"Searching",{Profile=playerProfile(player),StartedAt=workspace:GetServerTimeNow()})
end
local validInputs={Left=true,Right=true,SoftDrop=true,CW=true,CCW=true,Hold=true,HardDrop=true}
local function command(player,kind,payload)
	if kind=="Buy" or kind=="Equip" then cosmetic(player,kind,payload); return end
	if not Data:get(player) then message(player,"Profile is still loading"); return end
	if kind=="Refresh" then profile(player)
	elseif kind=="Hello" then profile(player); if not S.Sessions[player] then send(player,"Lobby",{}) end
	elseif kind=="Solo" then solo(player)
	elseif kind=="Queue" then queue(player)
	elseif kind=="Cancel" or kind=="Exit" then leave(player); S.Results[player]=nil; send(player,"Lobby",{})
	elseif kind=="Pause" then local s=S.Sessions[player]; if s and s.Mode=="Solo" then s.Engine.paused=payload==true; E.release(s.Engine) end
	elseif kind=="Restart" then local s=S.Sessions[player]; if s and s.Mode=="Solo" then solo(player) end
	elseif kind=="Rematch" then
		local result=S.Results[player]; if not result or result.Other.Parent~=Players then message(player,"Opponent unavailable; use Find Match"); return end
		local other=S.Results[result.Other]
		if not other or other.Other~=player then message(player,"Opponent returned to lobby; use Find Match"); return end
		result.Ready=true; message(player,"Rematch requested. Waiting for opponent.")
		if other and other.Other==player and other.Ready then startPair(player,result.Other,result.Ranked) end
	elseif kind=="ClaimQuest" then
		if type(payload)~="table" or not ({Daily=true,Weekly=true})[payload.Group] or type(payload.Id)~="string" then return end
		local ok,text=Data:mutate(player,function(d) return P.claimQuest(d,payload.Group,payload.Id,C) end); profile(player); message(player,text); if ok then send(player,"Action",{Sound="QuestClaim"}) end
	elseif kind=="Login" then local ok,text=Data:mutate(player,function(d) return P.login(d,os.time(),C) end); profile(player); message(player,text); if ok then send(player,"Action",{Sound="CashEarned"}) end
	elseif kind=="Leaderboard" then
		-- Legacy string requests remain supported. Echo the bounded request identity for race filtering.
		local category=type(payload)=="table" and payload.Kind or payload
		local requestId=type(payload)=="table" and payload.RequestId or nil
		if type(category)~="string" or not ({GlobalRating=true,GlobalWins=true,SeasonRating=true,SeasonWins=true})[category] then return end
		if requestId~=nil and (type(requestId)~="number" or requestId<1 or requestId>2147483647 or requestId%1~=0) then return end
		local rows,text=Leaders:read(player,category); send(player,"Leaderboard",{Rows=rows or {},Kind=category,RequestId=requestId,Notice=text,Unavailable=not rows})
	elseif kind=="Challenge" then
		if type(payload)~="number" or S.Sessions[player] then return end
		local other=Players:GetPlayerByUserId(payload); if not other or other==player or S.Sessions[other] then return end
		local ok,isFriend=pcall(function() return player:IsFriendsWithAsync(other.UserId) end)
		if not ok or not isFriend then message(player,"Choose a friend in this server"); return end
		S.Invites[other]={From=player,Expires=os.clock()+30}; send(other,"Challenge",playerProfile(player)); message(player,"Friend challenge sent")
	elseif kind=="AcceptChallenge" then
		local invitation=S.Invites[player]; S.Invites[player]=nil
		if invitation and invitation.Expires>os.clock() and invitation.From.Parent==Players then startPair(player,invitation.From,false) end
	elseif kind=="Settings" then
		if type(payload)~="table" then return end
		Data:mutate(player,function(d) if type(payload.Sound)=="boolean" then d.Settings.Sound=payload.Sound end; if type(payload.ReducedMotion)=="boolean" then d.Settings.ReducedMotion=payload.ReducedMotion end; for _,field in ipairs({"ClassicHUD","SwapRotation"}) do if type(payload[field])=="boolean" then d.Settings[field]=payload[field] end end; for _,field in ipairs({"Master","MusicVolume","SFXVolume","UIScale"}) do local value=payload[field]; if type(value)=="number" and value==value and math.abs(value)<=1000 then d.Settings[field]=math.clamp(value,field=="UIScale" and 0.9 or 0,1) end end; return true end); profile(player)
	elseif kind=="Emote" then
		local session=S.Sessions[player]; if not session or not session.Room or session.Room.Ended or type(payload)~="number" or payload%1~=0 or not R.Emotes[payload] then return end
		local now=workspace:GetServerTimeNow(); if now<(session.EmoteAt or 0) then return end; session.EmoteAt=now+R.EmoteCooldown
		battleEvent(session.Room,"Emote",{From=player.UserId,Text=R.Emotes[payload]})
	end
end
Network.OnServerEvent:Connect(function(player,kind,payload)
	if S.Closing or type(kind)~="string" or #kind>30 then return end
	local now=os.clock(); local b=S.Buckets[player] or {Time=now,Input=80,Command=8}; S.Buckets[player]=b
	local dt=now-b.Time; b.Time=now; b.Input=math.min(80,b.Input+dt*60); b.Command=math.min(8,b.Command+dt*2)
	if kind=="Input" then
		if type(payload)~="table" or not validInputs[payload.Action] or type(payload.Down)~="boolean" then return end
		local session=S.Sessions[player]
		if not session or (session.Room and (session.Room.Ended or not session.Room.Started or workspace:GetServerTimeNow()>=session.Room.EndAt)) or session.StartAt and workspace:GetServerTimeNow()<session.StartAt or session.RespawnAt then return end
		-- A rate-limited press must never prevent releasing an already held key.
		if not session.Engine or b.Input<1 and (payload.Down or not session.Engine.controls[payload.Action]) then return end
		b.Input=math.max(0,b.Input-1)
		if payload.Action=="HardDrop" and payload.Down then if now-(session.LastDrop or 0)<0.08 then return end; session.LastDrop=now end
		local beforeEvent=session.Engine.sequence
  local equipped=Data:get(player) and Data:get(player).Equipped
  local dropTheme=equipped and equipped.DropEffect
  local attack=E.input(session.Engine,payload.Action,payload.Down)
  if payload.Action=="HardDrop" and payload.Down then
   for _,event in ipairs(session.Engine.events) do if event.id>beforeEvent and event.name=="HardDrop" then event.data.DropEffect=dropTheme end end
  end
		if attack>0 and session.Room then deliver(session.Room,player,attack) end
		return
	end
	if b.Command<1 or S.Busy[player] then
  if kind=="Leaderboard" and type(payload)=="table" and type(payload.Kind)=="string" and type(payload.RequestId)=="number" then
   send(player,"Leaderboard",{Kind=payload.Kind,RequestId=payload.RequestId,Rows={},Unavailable=true,Notice="Server busy. Please retry in a moment.",RetryAfter=0.6})
  end
  return
 end; b.Command-=1; S.Busy[player]=true
	local ok,err=pcall(command,player,kind,payload); S.Busy[player]=nil
	if not ok then warn("[Tetris server] "..tostring(err)); message(player,"Operation failed; please retry") end
end)
local accumulator=0; local snapshotTime=0; local queueTime=0
RunService.Heartbeat:Connect(function(dt)
	accumulator=math.min(0.5,accumulator+dt); snapshotTime+=dt; queueTime+=dt
	local now=workspace:GetServerTimeNow()
	for _,room in pairs(S.Rooms) do if not room.Preparing and not room.Started and now>=room.StartAt then room.Started=true; room.EndAt=room.StartAt+R.MatchDuration end end
	while accumulator>=1/60 do
		accumulator-=1/60
		for player,session in pairs(S.Sessions) do
			local room=session.Room
			if session.Engine and not session.RespawnAt and (not session.StartAt or now>=session.StartAt) and (not room or room.Started and not room.Ended and now<room.EndAt) then
				local attack=E.step(session.Engine,1/60)
				if room and attack>0 then deliver(room,player,attack) end
			end
		end
	end
	for _,room in pairs(S.Rooms) do
		if room.Started and not room.Ended then
			room.Played=math.max(0,now-room.StartAt)
			local a,b=room.Players[1],room.Players[2]; local sa,sb=S.Sessions[a],S.Sessions[b]
			if sa and sb then
				if (not room.Ranked or not R.TimedKO) and (not sa.Engine.alive or not sb.Engine.alive) then
					local winner=sa.Engine.alive and a or sb.Engine.alive and b or nil
					task.spawn(finish,room,winner,"KO")
				elseif now>=room.EndAt then
					-- Deterministic policy: sent garbage, then cleared lines, then score.
					local winner
					for _,values in ipairs({{sa.Engine.stats.KOs,sb.Engine.stats.KOs},{sa.Engine.stats.Sent,sb.Engine.stats.Sent},{sa.Engine.lines,sb.Engine.lines},{sa.Engine.score,sb.Engine.score}}) do if values[1]~=values[2] then winner=values[1]>values[2] and a or b; break end end
					task.spawn(finish,room,winner,"Time expired")
				elseif room.Ranked and R.TimedKO then
					for _,p in ipairs(room.Players) do local session=S.Sessions[p]
						if not session.Engine.alive and not session.RespawnAt then recoverKO(room,p,now) end
						if session.RespawnAt and now>=session.RespawnAt then respawn(session) end
					end
				end
			end
		end
	end
	if snapshotTime>=1/R.SnapshotHz then
		snapshotTime=0
		for player,session in pairs(S.Sessions) do
			local room=session.Room
			if session.Engine and (not room or not room.Ended) then
				local other=room and (room.Players[1]==player and room.Players[2] or room.Players[1]); local osession=other and S.Sessions[other]
				local start=room and room.StartAt or session.StartAt
				send(player,"State",{Mode=session.Mode,MatchId=room and room.Id or session.Id,StartAt=start,EndAt=room and room.EndAt,ServerNow=now,Own=E.pack(session.Engine),Opponent=osession and E.pack(osession.Engine),Profiles=room and room.PublicProfiles,Countdown=start and math.max(0,math.ceil(start-now)) or room and not room.Started and R.Countdown or 0,Remaining=room and (room.Started and math.max(0,room.EndAt-now) or R.MatchDuration) or nil,RespawnAt=session.RespawnAt,Round=1})
			end
		end
	end
	if queueTime>=0.5 then
		queueTime=0
		for i=#S.Queue,1,-1 do local p=S.Queue[i]; if p.Parent~=Players or not Data:get(p) or S.Sessions[p] then table.remove(S.Queue,i) end end
		while #S.Queue>=2 do
			local a=table.remove(S.Queue,1); local b=table.remove(S.Queue,1)
			-- Reserve before a yielding data transaction can let another queue request race.
			S.Sessions[a]={Reserved=true}; S.Sessions[b]={Reserved=true}
			task.spawn(function() S.Sessions[a]=nil; S.Sessions[b]=nil; startPair(a,b,true) end)
		end
	end
end)
local function joined(player)
	if S.Loading[player] or Data:get(player) then return end
	S.Loading[player]=true
	local ok,text=Data:load(player); S.Loading[player]=nil
	if not ok then player:Kick(text); return end
	if player.Parent~=Players then Data:release(player); return end
	profile(player); send(player,"Lobby",{})
	-- Alternative to invite attribution: a verified first-time friend session.
	task.delay(C.SocialMinSeconds,function()
		local newcomer=Data:get(player)
		if player.Parent~=Players or not newcomer or os.time()-newcomer.CreatedAt>600 or player.AccountAge<C.SocialMinAccountAge then return end
		for _,host in ipairs(Players:GetPlayers()) do
			if host~=player and Data:get(host) then
				local success,friend=pcall(function() return host:IsFriendsWithAsync(player.UserId) end)
				local hostData=P.refresh(P.clone(Data:get(host)),os.time(),C)
				if success and friend and not newcomer.SocialRewardHost and hostData.SocialRewards.Count<C.SocialDailyLimit and not hostData.SocialRewards.Seen[tostring(player.UserId)] then
					local reserved=Data:mutate(player,function(d)
						if d.SocialRewardHost then return false end
						d.SocialRewardHost=host.UserId; return true
					end)
					if not reserved then return end
					persist(host,{id="social:"..player.UserId,kind="Social",friendId=player.UserId})
					return
				end
			end
		end
	end)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player) leave(player); Data:release(player); S.Results[player]=nil; S.Invites[player]=nil; S.Buckets[player]=nil; S.Busy[player]=nil end)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(joined,player) end
game:BindToClose(function()
	S.Closing=true
	for _,room in pairs(S.Rooms) do if not room.Started then room.Cancelled=true; if not room.Preparing then finish(room,nil,"Server closing") end end end
	local pending=0
	for _,player in ipairs(Players:GetPlayers()) do pending+=1; task.spawn(function() leave(player); Data:release(player); pending-=1 end) end
	local deadline=os.clock()+25; while pending>0 and os.clock()<deadline do task.wait(0.1) end
end)
S.Matchmaking={Enqueue=queue,Cancel=unqueue,StartPair=startPair}
return S

end)()
S=StudioPersistentS
local shopper=player(11001); shopper.AccountAge=365
Players.PlayerAdded:fire(shopper); tick(0.1); assert(Data:get(shopper))
local function request(category,id)
	S.Buckets={}; sent[shopper].CosmeticResult=nil
	send(shopper,"Equip",{Category=category,Id=id}); tick(0.1)
	return assert(sent[shopper].CosmeticResult,"No structured cosmetic response")
end
local balance=Data:get(shopper).Cash
for category,slot in pairs(Catalog.Slots) do
	local reply=request(category,"Default")
	assert(reply.Success and reply.Code=="OK" and Data:get(shopper).Equipped[slot]=="Default")
	assert(Data:get(shopper).Cash==balance)
end
print("PASS all four default cosmetics equip through the real remote without spending Cash")
local chosen={}; assert(Data:mutate(shopper,function(d)
	d.Cash=125000
	for category in pairs(Catalog.Slots) do local item=Catalog.list(category)[2]; chosen[category]=item.Id; d.Inventory[category][item.Id]=true end
	return true
end))
for category,slot in pairs(Catalog.Slots) do
	for _,id in ipairs({chosen[category],"Default",chosen[category]}) do
		local reply=request(category,id); assert(reply.Success and reply.Category==category and reply.Id==id)
		assert(Data:get(shopper).Equipped[slot]==id and Data:get(shopper).Cash==125000)
	end
end
print("PASS repeated owned skin/drop/ghost/sound equips preserve Cash and return accurate success payloads")
local missing=Catalog.list("BrickSkins")[3].Id; local reply=request("BrickSkins",missing)
assert(not reply.Success and reply.Code=="NotOwned" and reply.Message=="You don't own this cosmetic yet.")
assert(Data:get(shopper).Equipped.BrickSkin==chosen.BrickSkins and Data:get(shopper).Cash==125000)
for _,pair in ipairs({{"BrickSkins","Missing"},{"Unknown","Default"},{"HardDropEffects","Default"}}) do
	reply=request(pair[1],pair[2]); assert(not reply.Success and reply.Code=="Unavailable")
end
S.Buckets={}; send(shopper,"Equip",{Category={},Id=5}); assert(sent[shopper].CosmeticResult.Code=="Unavailable")
print("PASS unowned, mismatched and malformed cosmetic requests reject without changing equipped state")
-- Exercise the import on Buy as well; then equip an actually purchased item.
S.Buckets={}; send(shopper,"Buy",{Category="BrickSkins",Id=missing}); tick(0.1)
assert(sent[shopper].CosmeticResult.Success and Data:get(shopper).Inventory.BrickSkins[missing])
balance=125000-Catalog.Items["BrickSkins:"..missing].Price
reply=request("BrickSkins",missing); assert(reply.Success and Data:get(shopper).Cash==balance); chosen.BrickSkins=missing
Data:release(shopper); tick(0.1)
local reloaded; task.spawn(function() reloaded=Data:load(shopper) end); tick(0.3); assert(reloaded)
for category,slot in pairs(Catalog.Slots) do assert(Data:get(shopper).Equipped[slot]==chosen[category]) end
assert(Data:get(shopper).Cash==balance)
print("PASS remote purchase then equip and rejoin preserve ownership, all equipped slots and exact Cash")
local success,text,code=Data:mutate(shopper,function() error("equip-test-private-stack-marker") end,{Action="Equip",Category="BrickSkins",Id="Default"})
assert(not success and code=="InternalError" and not text:find("private%-stack") and Data:get(shopper).Cash==balance)
if RunService:IsStudio() then assert(warnings[#warnings]:find("equip-test-private-stack-marker",1,true) and warnings[#warnings]:find("action=Equip",1,true)) end
print("PASS mutation exceptions return an internal code without exposing server traces or changing data")
Data:release(shopper); reply=request("BrickSkins","Default")
assert(not reply.Success and reply.Code=="DataNotLoaded" and reply.Message=="Your player data is still loading.")
print("PASS unloaded profiles cannot equip or receive false success")
