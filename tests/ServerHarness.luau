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
		stats={TSpins=0,Tetrises=0,PerfectClears=0,Sent=0,KOs=0},
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
	s.score+=distance*2; emit(s,"HardDrop",{distance=distance}); return E.lock(s)
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
		Season={Id=0,Rating=1000,Wins=0,History={}},ProcessedMatchIds={},MatchReceipts={},Reservations={},Pairs={},Achievements={},Login={LastDay=-1,Index=0},Settings={Sound=true,ReducedMotion=false},CreatedAt=now,
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
local Catalog={Items={},Categories={"BrickSkins","DropEffects","GhostEffects","SoundPacks"},Slots={BrickSkins="BrickSkin",DropEffects="DropEffect",GhostEffects="GhostEffect",SoundPacks="SoundPack"}}
local sets={
	BrickSkins={"Default Classic","Neon Club","Cyber Core","Ocean Wave","Galaxy","Gold Elite","Lava","Crystal Glass","Retro Pixel","Holographic"},
	DropEffects={"Default","Neon Sparks","Lightning Strike","Stardust","Fire Burst","Pixel Explosion","Crystal Shatter","Cyber Glitch"},
	GhostEffects={"Default Outline","Neon Outline","Hologram","Pulse","Glitch","Prism","Electric"},
	SoundPacks={"Default","Retro Arcade","Cyber","Crystal","Neon Club"},
}
local hues={{0.15,0.9,1},{0.7,0.4,1},{0.1,0.7,1},{0.8,0.5,1},{1,0.8,0.2},{1,0.3,0.1},{0.7,0.9,1}}
for category,names in pairs(sets) do
	for index,name in ipairs(names) do
		local id=index==1 and "Default" or name:gsub("%s","")
		local item={Id=id,Name=name,Category=category,Rarity=index<4 and "Common" or (index<7 and "Rare" or "Epic"),Price=index==1 and 0 or (index-1)*175,
			Description="Cosmetic only. Changes appearance or sound; never gameplay.",Preview={Kind="T",Color=hues[(index-1)%#hues+1]},
			Visual={Tint=index==1 and nil or hues[(index-1)%#hues+1],Blend=0.12+(index%3)*0.08,Border=index%2==0,Transparency=category=="GhostEffects" and (0.72+(index%3)*0.05) or 0,Effect=index},
			Audio={Pack=id},
		}
		Catalog.Items[category..":"..id]=item
	end
end
function Catalog.list(category)
	local out={}; for _,item in pairs(Catalog.Items) do if item.Category==category then table.insert(out,item) end end
	table.sort(out,function(a,b) if a.Price==b.Price then return a.Name<b.Name end; return a.Price<b.Price end); return out
end
return Catalog

end)()
local modules={TetrisEngine=E,Progression=P,Rules=R,Catalog=Catalog,GameConfig=C}
local now=0
local delayed={}
local task={}
function task.wait(seconds) return coroutine.yield(seconds or 0.01) end
function task.spawn(fn,...)
	local co=coroutine.create(fn); local ok,delay=coroutine.resume(co,...); assert(ok,delay)
	if coroutine.status(co)~="dead" then table.insert(delayed,{Co=co,At=now+(delay or 0.01)}) end
end
function task.delay(delay,fn) table.insert(delayed,{Co=coroutine.create(fn),At=now+delay}) end
local function event()
	local e={Listeners={}}
	function e:Connect(fn) table.insert(self.Listeners,fn); return {Disconnect=function() end} end
	function e:fire(...) for _,fn in ipairs(self.Listeners) do task.spawn(fn,...) end end
	return e
end
local records={}
local failWrites=false
local rejectAfterInboxRead=false
local DSS={}
function DSS:GetDataStore(name)
	records[name]=records[name] or {}; local rows=records[name]
	return {UpdateAsync=function(_,key,fn)
		if failWrites then error("simulated outage") end
		local value=fn(P.clone(rows[key])); if value~=nil then rows[key]=P.clone(value) end; return P.clone(value)
	end,GetAsync=function(_,key) if rejectAfterInboxRead and name:match("_Results$") then failWrites=true end; return P.clone(rows[key]) end,SetAsync=function(_,key,value) rows[key]=value end}
end
function DSS:GetOrderedDataStore(name)
	local store=self:GetDataStore(name)
	store.GetSortedAsync=function() return {GetCurrentPage=function() return {} end} end
	return store
end
local Players={PlayerAdded=event(),PlayerRemoving=event(),List={}}
function Players:GetPlayers() return self.List end
function Players:GetPlayerByUserId(uid) for _,p in ipairs(self.List) do if p.UserId==uid then return p end end end
function Players:GetNameFromUserIdAsync(uid) return "User"..uid end
local folder={WaitForChild=function(_,key) return key end}
local shared={WaitForChild=function(_,key) return key=="Config" and folder or key end}
local RS={WaitForChild=function() return shared end}
local RunService={Heartbeat=event(),IsStudio=function() return false end}
local guid=0
local Http={GenerateGUID=function() guid+=1; return "test-match-"..guid end}
local game={JobId="mock-server",GetService=function(_,key) return ({Players=Players,ReplicatedStorage=RS,RunService=RunService,HttpService=Http,DataStoreService=DSS})[key] end,BindToClose=function(_,fn) end}
local workspace={GetServerTimeNow=function() return now end}
local sent={}
local remote={OnServerEvent=event(),FireClient=function(_,player,kind,data)
	sent[player]=sent[player] or {}; sent[player][kind]=P.clone(data)
end}
local Instance={new=function() return remote end}
local script={Parent=folder}
local require=function(name) assert(modules[name],"Unknown require "..tostring(name)); return modules[name] end
local warn=function(...) print(...) end
local function player(uid)
	local p={UserId=uid,Name="Player"..uid,DisplayName="Player"..uid,AccountAge=365,Parent=Players,Kick=function(self,text) self.Kicked=text end,IsFriendsWithAsync=function() return true end}
	table.insert(Players.List,p); return p
end
local function tick(seconds)
	local steps=math.ceil(seconds*60)
	for _=1,steps do
		now+=1/60; RunService.Heartbeat:fire(1/60)
		for i=#delayed,1,-1 do local scheduled=delayed[i]; if scheduled.At<=now then
			table.remove(delayed,i); local ok,delay=coroutine.resume(scheduled.Co); assert(ok,delay)
			if coroutine.status(scheduled.Co)~="dead" then table.insert(delayed,{Co=scheduled.Co,At=now+(delay or 0.01)}) end
		end end
	end
end

local Legacy=(function()
local DSS=game:GetService("DataStoreService")
local Http=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local P=require(Shared:WaitForChild("Progression"))
local Catalog=require(Shared:WaitForChild("Catalog"))
local Config=require(script.Parent:WaitForChild("GameConfig"))
local Data={Profiles={},Debug=Config.Debug and RunService:IsStudio(),Config=Config}
local namespace=Config.DataStoreName..(RunService:IsStudio() and "_Studio" or "_Live")
local store=DSS:GetDataStore(namespace)
local inbox=DSS:GetDataStore(namespace.."_Results")
local owner=game.JobId~="" and game.JobId or Http:GenerateGUID(false)
local function retry(fn)
	local problem
	for attempt=1,4 do
		local ok,value=pcall(fn); if ok then return true,value end
		problem=value; if attempt<4 then task.wait(0.5*2^(attempt-1)) end
	end
	return false,tostring(problem)
end
local function acquire(profile)
	while profile.Busy do task.wait() end
	profile.Busy=true
end
function Data:load(player)
	local existing=self.Profiles[player.UserId]
	if existing and existing.Active then return existing.Player==player,"Data is already active in this server" end
	local now=os.time(); local profile={Player=player,Busy=false,Active=true,LastSave=now}
	if self.Debug then profile.Data=P.refresh(P.default(now),now,Config); self.Profiles[player.UserId]=profile; return true end
	local acquired=false
	local ok,value=retry(function()
		return store:UpdateAsync(tostring(player.UserId),function(old)
			old=old or {Data=P.default(now)}
			if old.Lease and old.Lease.Owner~=owner and old.Lease.Expires>now then return nil end
			local data=P.validate(P.clone(old.Data or old),now,Catalog,Config)
			P.refresh(data,now,Config); acquired=true
			return {Data=data,Lease={Owner=owner,Expires=now+Config.LockLease}}
		end)
	end)
	if not ok or not acquired or not value then return false,"Your data is unavailable or active in another server. Please reconnect." end
	profile.Data=value.Data; self.Profiles[player.UserId]=profile
	local readOK,pending=retry(function() return inbox:GetAsync(tostring(player.UserId)) end)
	if not readOK then self:release(player); return false,"Pending results could not be recovered. Please reconnect." end
	for id,result in pairs(pending or {}) do
		local settled=self:mutate(player,function(d) P.settle(d,result,Config); return true end)
		if not settled then self:release(player); return false,"Pending results could not be saved. Please reconnect." end
		retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old) old=old or {}; old[id]=nil; return old end) end)
	end
	-- An abandoned server cannot leave an unresolved energy charge behind.
	local recovered=self:mutate(player,function(d)
		for id in pairs(d.Reservations) do
			P.settle(d,{id=id..":refund",kind="Refund",roomId=id},Config)
		end
		return true
	end)
	if not recovered then self:release(player); return false,"Energy reservations could not be recovered. Please reconnect." end
	return true
end
function Data:get(player)
	local p=self.Profiles[player.UserId]; return p and p.Active and p.Data or nil
end
function Data:mutate(player,fn,context)
	local profile=self.Profiles[player.UserId]; if not profile or not profile.Active then return false,"Data not loaded" end
	acquire(profile)
	if not profile.Active then profile.Busy=false; return false,"Session closed" end
	local nextData=P.clone(profile.Data); P.refresh(nextData,os.time(),Config)
	local safe,accepted,message,code=xpcall(function() return fn(nextData) end,function(err) return debug.traceback(tostring(err),2) end)
	if not safe then
		profile.Busy=false
		if RunService:IsStudio() and Config.CosmeticDebugLogging then warn("[PlayerData] Mutation exception action="..tostring(context and context.Action).." category="..tostring(context and context.Category).." id="..tostring(context and context.Id).."\n"..accepted) end
		return false,"Unable to complete this action right now. Please try again.","InternalError"
	end
	if not accepted then profile.Busy=false; return false,message,code end
	if not self.Debug then
		local own=false
		local ok,written=retry(function()
			own=false
			return store:UpdateAsync(tostring(player.UserId),function(old)
				if not old or not old.Lease or old.Lease.Owner~=owner then return nil end
				own=true; return {Data=nextData,Lease={Owner=owner,Expires=os.time()+Config.LockLease}}
			end)
		end)
		if not ok or not own or not written then
			profile.Busy=false
			if ok and not written then profile.Active=false; player:Kick("Data session ownership was lost. Please reconnect.") end
			return false,"Saving failed; nothing was charged. Please retry."
		end
	end
	profile.Data=nextData; profile.LastSave=os.time(); profile.Busy=false; return true,message
end
function Data:settle(player,result)
	if not self.Debug then
		local ok=retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old)
			old=old or {}; old[result.id]=result; return old
		end) end)
		if not ok then return false end
	end
	local ok=self:mutate(player,function(d) P.settle(d,result,Config); return true end)
	if ok and not self.Debug then
		retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old) old=old or {}; old[result.id]=nil; return old end) end)
	end
	return ok
end
function Data:release(player)
	local profile=self.Profiles[player.UserId]; if not profile then return end
	acquire(profile); profile.Active=false
	if not self.Debug then
		local data=P.clone(profile.Data)
		retry(function() return store:UpdateAsync(tostring(player.UserId),function(old)
			if not old or not old.Lease or old.Lease.Owner~=owner then return nil end
			return {Data=data}
		end) end)
	end
	profile.Busy=false; self.Profiles[player.UserId]=nil
end
function Data:public(player)
	local d=self:get(player); if not d then return nil end
	local out=P.refresh(P.clone(d),os.time(),Config); out.ProcessedMatchIds=nil; out.MatchReceipts=nil; out.Reservations=nil; out.Pairs=nil; out.SocialRewards.Seen=nil
	out.Debug=self.Debug; out.Energy.Next=P.nextEnergy(out,os.time(),Config)
	out.DebugPrivileges={FreeCosmetics=self.Debug and Config.FreeCosmeticsInDebug,FreePurchases=self.Debug and Config.FreeShopPurchasesInDebug,InfiniteEnergy=self.Debug and Config.InfiniteEnergyInDebug}
	out.Economy={EnergyCap=Config.EnergyCap,BonusCap=Config.BonusEnergyCap,EnergyInterval=Config.EnergyInterval,RankedCost=Config.RankedCost,SocialEnergy=Config.SocialEnergy,SocialLimit=Config.SocialDailyLimit,SocialMinSeconds=Config.SocialMinSeconds,LoginCash=Config.LoginCash,LoginEnergy=Config.LoginEnergy,SeasonDays=Config.SeasonDays,WinCash=Config.WinCash}
	return out
end
task.spawn(function()
	while true do
		task.wait(5)
		for _,profile in pairs(Data.Profiles) do
			if profile.Active and os.time()-profile.LastSave>=Config.Autosave then
				task.spawn(function() Data:mutate(profile.Player,function() return true end) end)
			end
		end
	end
end)
return Data

end)()
modules.LegacyPlayerDataService=Legacy

local Data=(function()
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
modules.PlayerDataService=Data

local Leaders=(function()
local DSS=game:GetService("DataStoreService")
local Players=game:GetService("Players")
local Data=require(script.Parent:WaitForChild("PlayerDataService"))
local P=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Progression"))
local L={Cache={},Names={}}
local function stores(season)
	local prefix=Data.Namespace or Data.Config.DataStoreName..(game:GetService("RunService"):IsStudio() and "_Studio" or "_Live")
	return {
		GlobalRating=DSS:GetOrderedDataStore(prefix.."_Rating"),GlobalWins=DSS:GetOrderedDataStore(prefix.."_Wins"),
		SeasonRating=DSS:GetOrderedDataStore(prefix.."_S"..season.."_Rating"),SeasonWins=DSS:GetOrderedDataStore(prefix.."_S"..season.."_Wins"),
	}
end
function L:update(player)
	if Data.Debug then self.Cache={}; return end
	local d=Data:get(player); if not d then return end
	local metrics={GlobalRating=d.Rank.Rating,GlobalWins=d.Stats.QualifiedWins,SeasonRating=d.Season.Rating,SeasonWins=d.Season.Wins}
	for key,store in pairs(stores(d.Season.Id)) do
		local ok=pcall(function() store:SetAsync(tostring(player.UserId),math.floor(metrics[key])*10+d.Rank.Tier) end)
		if not ok then warn("[Leaderboard] Update delayed: "..key) end
	end
	self.Cache={}
end
function L:read(player,kind)
	local d=Data:get(player); if not d then return nil,"Profile unavailable" end
	if not ({GlobalRating=true,GlobalWins=true,SeasonRating=true,SeasonWins=true})[kind] then return nil,"Unknown leaderboard" end
	if Data.Debug then
		local rows={}
		for uid,profile in pairs(Data.Profiles) do local v=profile.Data; table.insert(rows,{UserId=uid,Name=profile.Player.Name,Value=kind=="GlobalRating" and v.Rank.Rating or kind=="GlobalWins" and v.Stats.QualifiedWins or kind=="SeasonRating" and v.Season.Rating or v.Season.Wins,Rank=P.Ranks[v.Rank.Tier]}) end
		table.sort(rows,function(a,b) return a.Value==b.Value and a.UserId<b.UserId or a.Value>b.Value end)
		return rows,"STUDIO TEST STANDINGS (this server only)"
	end
	local cacheKey=kind..d.Season.Id; local cached=self.Cache[cacheKey]
	if cached and cached.Time>os.clock()-60 then return cached.Rows end
	local ok,pages=pcall(function() return stores(d.Season.Id)[kind]:GetSortedAsync(false,100) end)
	if not ok then return nil,"Leaderboard temporarily unavailable" end
	local rows={}
	for position,entry in ipairs(pages:GetCurrentPage()) do
		local uid=tonumber(entry.key); local name=self.Names[uid]
		if not name then local success,value=pcall(function() return Players:GetNameFromUserIdAsync(uid) end); name=success and value or ("User "..uid); self.Names[uid]=name end
		table.insert(rows,{Position=position,UserId=uid,Name=name,Value=math.floor(entry.value/10),Rank=P.Ranks[entry.value%10]})
	end
	self.Cache[cacheKey]={Time=os.clock(),Rows=rows}; return rows
end
return L

end)()
modules.LeaderboardService=Leaders

local S=(function()
local Catalog=nil -- Do not inherit Catalog from the harness scope.
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
	return {UserId=player.UserId,Name=player.Name,DisplayName=player.DisplayName,Rank=d and P.Ranks[d.Rank.Tier] or "Rookie",Stars=d and d.Rank.Stars or 0,Rating=d and d.Rank.Rating or 1000,Equipped=d and P.clone(d.Equipped) or {}}
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
	return {id=room.Id,outcome=outcome,score=session.Engine.score,lines=session.Engine.lines,spins=st.TSpins,tetrises=st.Tetrises,perfect=st.PerfectClears,sent=st.Sent,kos=winner==player and reason=="KO" and 1 or 0,startTier=start.Tier,startRating=start.Rating,opponentRating=room.Profiles[other].Rating,rewardEligible=eligible,opponentId=other.UserId,day=math.floor(os.time()/86400),timestamp=os.time()}
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
			Cash=before and after and after.Cash-before.Cash or 0,BeforeRank=before and before.Rank,AfterRank=after and P.clone(after.Rank),Id=room.Id}
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
		send(player,"Found",{Profiles=room.PublicProfiles,Ranked=ranked})
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
	S.Sessions[player]={Id=Http:GenerateGUID(false),Engine=E.new(math.random(1,2147483646),R),Mode="Solo"}
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
		if type(payload)~="string" then return end
		local rows,text=Leaders:read(player,payload); send(player,"Leaderboard",{Rows=rows or {},Kind=payload,Notice=text,Unavailable=not rows})
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
		Data:mutate(player,function(d) if type(payload.Sound)=="boolean" then d.Settings.Sound=payload.Sound end; if type(payload.ReducedMotion)=="boolean" then d.Settings.ReducedMotion=payload.ReducedMotion end; return true end); profile(player)
	end
end
Network.OnServerEvent:Connect(function(player,kind,payload)
	if S.Closing or type(kind)~="string" or #kind>30 then return end
	local now=os.clock(); local b=S.Buckets[player] or {Time=now,Input=80,Command=8}; S.Buckets[player]=b
	local dt=now-b.Time; b.Time=now; b.Input=math.min(80,b.Input+dt*60); b.Command=math.min(8,b.Command+dt*2)
	if kind=="Input" then
		if type(payload)~="table" or not validInputs[payload.Action] or type(payload.Down)~="boolean" then return end
		local session=S.Sessions[player]
		if not session or (session.Room and (session.Room.Ended or not session.Room.Started)) then return end
		-- A rate-limited press must never prevent releasing an already held key.
		if not session.Engine or b.Input<1 and (payload.Down or not session.Engine.controls[payload.Action]) then return end
		b.Input=math.max(0,b.Input-1)
		if payload.Action=="HardDrop" and payload.Down then if now-(session.LastDrop or 0)<0.08 then return end; session.LastDrop=now end
		local attack=E.input(session.Engine,payload.Action,payload.Down)
		if attack>0 and session.Room then local other=session.Room.Players[1]==player and session.Room.Players[2] or session.Room.Players[1]; if S.Sessions[other] then E.addGarbage(S.Sessions[other].Engine,attack) end end
		return
	end
	if b.Command<1 or S.Busy[player] then return end; b.Command-=1; S.Busy[player]=true
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
			if session.Engine and (not room or room.Started and not room.Ended) then
				local attack=E.step(session.Engine,1/60)
				if room and attack>0 then local other=room.Players[1]==player and room.Players[2] or room.Players[1]; if S.Sessions[other] then E.addGarbage(S.Sessions[other].Engine,attack) end end
			end
		end
	end
	for _,room in pairs(S.Rooms) do
		if room.Started and not room.Ended then
			room.Played=math.max(0,now-room.StartAt)
			local a,b=room.Players[1],room.Players[2]; local sa,sb=S.Sessions[a],S.Sessions[b]
			if sa and sb then
				if not sa.Engine.alive or not sb.Engine.alive then
					local winner=sa.Engine.alive and a or sb.Engine.alive and b or nil
					task.spawn(finish,room,winner,"KO")
				elseif now>=room.EndAt then
					-- Deterministic policy: sent garbage, then cleared lines, then score.
					local winner
					for _,values in ipairs({{sa.Engine.stats.Sent,sb.Engine.stats.Sent},{sa.Engine.lines,sb.Engine.lines},{sa.Engine.score,sb.Engine.score}}) do if values[1]~=values[2] then winner=values[1]>values[2] and a or b; break end end
					task.spawn(finish,room,winner,"Time expired")
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
				send(player,"State",{Mode=session.Mode,Own=E.pack(session.Engine),Opponent=osession and E.pack(osession.Engine),Profiles=room and room.PublicProfiles,Countdown=room and not room.Started and math.max(0,math.ceil((room.StartAt or now+3)-now)) or 0,Remaining=room and room.Started and math.max(0,room.EndAt-now) or nil,Round=1})
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
local a,b,c=player(1),player(2),player(3)
Players.PlayerAdded:fire(a); Players.PlayerAdded:fire(b); Players.PlayerAdded:fire(c)
local function send(p,kind,data) remote.OnServerEvent:fire(p,kind,data) end
send(a,"Solo"); tick(0.2); assert(sent[a].State.Mode=="Solo" and #sent[a].State.Own.grid==200)
local y=S.Sessions[a].Engine.piece.y
send(a,"Input",{Action="SoftDrop",Down=true}); tick(0.1); assert(S.Sessions[a].Engine.piece.y>y and S.Sessions[a].Engine.piece.rotation==0)
send(a,"Input",{Action="SoftDrop",Down=false}); send(a,"Pause",true); y=S.Sessions[a].Engine.piece.y; tick(1); assert(S.Sessions[a].Engine.piece.y==y)
send(a,"Pause",false); send(a,"Input",{Action="Left",Down=true}); S.Buckets[a].Input=0
send(a,"Input",{Action="Left",Down=false}); assert(not S.Sessions[a].Engine.controls.Left)
send(a,"Pause",false); send(a,"Exit"); assert(not S.Sessions[a]); assert(Data:get(a).Energy.Current==10)
print("PASS Solo controls, real state, pause, rate-limited release, exit and free energy")
-- Command tokens refill in wall-clock time in production. Reset fixture buckets between phases.
S.Buckets={}
send(a,"Queue"); send(a,"Queue"); assert(#S.Queue==1)
send(b,"Queue"); tick(0.6)
local room=S.Sessions[a].Room; assert(room==S.Sessions[b].Room and not room.Started)
assert(Data:get(a).Energy.Current==9 and Data:get(b).Energy.Current==9)
send(a,"Cancel"); assert(not S.Sessions[a] and Data:get(a).Energy.Current==10 and Data:get(b).Energy.Current==10)
print("PASS duplicate queue guard, paired reservation and countdown refund")
S.Buckets={}; send(a,"Queue"); send(b,"Queue"); tick(3.8)
room=S.Sessions[a].Room; assert(room.Started)
assert(S.Sessions[a].Engine.piece.kind==S.Sessions[b].Engine.piece.kind)
local state=S.Sessions[a].Engine
for y=21,24 do for x=1,10 do if x~=5 then state.board[y][x]="G" end end end
state.board[20][1]="G"; state.piece={kind="I",rotation=1,x=3,y=21}
send(a,"Input",{Action="HardDrop",Down=true}); tick(0.2)
assert(S.Sessions[b].Engine.pending[1].lines==4)
local opponent=E.unpack(sent[b].State.Opponent); assert(opponent.lines==4 and opponent.board[20][1]=="G")
send(a,"Input",{Action="invented",Down=true}); send(a,"Input",{Action="CW",Down="invalid"})
assert(not sent[c].State or sent[c].State.Mode=="Solo")
print("PASS authoritative garbage, actual opponent board and isolated replication")
room.StartAt=now-25; room.Played=25; S.Sessions[b].Engine.alive=false; tick(0.1)
assert(sent[a].Result.Outcome=="Win" and sent[b].Result.Outcome=="Lose")
assert(sent[a].Result.Own.stats.KOs==1 and sent[b].Result.Opponent.stats.KOs==1)
assert(Data:get(a).Cash==50 and Data:get(a).Rank.Stars==1 and Data:get(a).Stats.QualifiedWins==1)
local cash=Data:get(a).Cash; assert(Data:settle(a,{id=room.Id})); assert(Data:get(a).Cash==cash)
print("PASS KO result, rank, Cash, competitive win and settlement idempotence")
S.Buckets={}; send(a,"Queue"); send(b,"Queue"); tick(3.8)
room=S.Sessions[a].Room; room.EndAt=now+0.05; tick(0.1)
assert(sent[a].Result.Outcome=="Draw" and sent[b].Result.Outcome=="Draw")
print("PASS server-clock expiration and deterministic draw")
S.Buckets={}; send(a,"Rematch"); assert(not S.Sessions[a]); send(b,"Rematch"); assert(S.Sessions[a].Room==S.Sessions[b].Room)
tick(3.2); room=S.Sessions[a].Room; room.EndAt=now+0.05; tick(0.1)
S.Buckets={}; send(a,"Rematch"); send(a,"Exit"); send(b,"Rematch"); assert(not S.Sessions[a] and not S.Sessions[b] and not S.Results[a])
print("PASS mutual rematch consent and lobby exit revokes stale consent")
-- Durable data survives release/reacquisition; a second session cannot overwrite a live lease.
local cash=Data:get(a).Cash; Data:release(a); assert(Data:load(a)); assert(Data:get(a).Cash==cash)
local namespace=C.DataStoreName.."_Live"
local old=records[namespace][tostring(a.UserId)]; old.Lease.Owner="other-server"; old.Lease.Expires=os.time()+180
assert(not Data:load(player(1)))
old.Lease.Owner="mock-server"
print("PASS persistence round-trip and active-session locking")
-- Recover pending awards before allowing another game; a failed recovery blocks loading.
Data:release(c)
records[namespace.."_Results"][tostring(c.UserId)]={recover={id="recover",outcome="Win",score=0,lines=0,spins=0,tetrises=0,perfect=0,sent=0,kos=0,startTier=1,startRating=1000,opponentRating=1000,rewardEligible=true,opponentId=99,day=math.floor(os.time()/86400),timestamp=os.time()}}
rejectAfterInboxRead=true
local loaded
task.spawn(function() loaded=Data:load(c) end); tick(10)
assert(loaded==false and not Data:get(c)); rejectAfterInboxRead=false; failWrites=false
assert(Data:load(c)); assert(Data:get(c).Cash==50); assert(Data:load(c) and Data:get(c).Cash==50)
print("PASS durable pending result recovery blocks on failure and credits once on reconnect")
-- Save rejection must not mutate cached balance or grant the item.
local item=Catalog.list("BrickSkins")[2]
Data:mutate(a,function(d) d.Cash=1000; return true end)
local before=Data:get(a).Cash; failWrites=true
task.spawn(function() Data:mutate(a,function(d) return P.purchase(d,item.Category,item.Id,Catalog,false) end) end)
tick(5); failWrites=false
assert(Data:get(a).Cash==before and not Data:get(a).Inventory.BrickSkins[item.Id] and not a.Kicked)
print("PASS transient save failure does not spend Cash or grant unsaved ownership")
print("Server integration checks passed with mocked Roblox services, not Studio clients.")

S.Buckets={}; send(a,"Equip",{Category="BrickSkins",Id="Default"})
assert(sent[a].Message=="Equipped Default", "Default equip remote failed: "..tostring(sent[a].Message))
print("PASS default equip remote imports its own Catalog")
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
	d.Cash=1200
	for category in pairs(Catalog.Slots) do local item=Catalog.list(category)[2]; chosen[category]=item.Id; d.Inventory[category][item.Id]=true end
	return true
end))
for category,slot in pairs(Catalog.Slots) do
	for _,id in ipairs({chosen[category],"Default",chosen[category]}) do
		local reply=request(category,id); assert(reply.Success and reply.Category==category and reply.Id==id)
		assert(Data:get(shopper).Equipped[slot]==id and Data:get(shopper).Cash==1200)
	end
end
print("PASS repeated owned skin/drop/ghost/sound equips preserve Cash and return accurate success payloads")
local missing=Catalog.list("BrickSkins")[3].Id; local reply=request("BrickSkins",missing)
assert(not reply.Success and reply.Code=="NotOwned" and reply.Message=="You don't own this cosmetic yet.")
assert(Data:get(shopper).Equipped.BrickSkin==chosen.BrickSkins and Data:get(shopper).Cash==1200)
for _,pair in ipairs({{"BrickSkins","Missing"},{"Unknown","Default"},{"HardDropEffects","Default"}}) do
	reply=request(pair[1],pair[2]); assert(not reply.Success and reply.Code=="Unavailable")
end
S.Buckets={}; send(shopper,"Equip",{Category={},Id=5}); assert(sent[shopper].CosmeticResult.Code=="Unavailable")
print("PASS unowned, mismatched and malformed cosmetic requests reject without changing equipped state")
-- Exercise the import on Buy as well; then equip an actually purchased item.
S.Buckets={}; send(shopper,"Buy",{Category="BrickSkins",Id=missing}); tick(0.1)
assert(sent[shopper].CosmeticResult.Success and Data:get(shopper).Inventory.BrickSkins[missing])
balance=1200-Catalog.Items["BrickSkins:"..missing].Price
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
