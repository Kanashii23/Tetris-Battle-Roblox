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
}
return {
	MasterVolume=1,MusicVolume=0.5,SFXVolume=0.8,Sounds=sounds,
	-- Sound pack overrides are configured here, never in gameplay scripts.
	Packs={Default={Pitch=1,Sounds={}},RetroArcade={Pitch=1.2,Sounds={}},Cyber={Pitch=0.85,Sounds={}},Crystal={Pitch=1.4,Sounds={}},NeonClub={Pitch=1.05,Sounds={}}},
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
local Font={fromEnum=function(font) return {Name=font.Name} end}
local Instance={}
local methods={}
function methods:GetChildren() return table.clone(self.Children) end
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
		if ({MouseEnter=true,MouseLeave=true,SelectionGained=true,SelectionLost=true,Activated=true,InputBegan=true,Destroying=true,Loaded=true})[key] then self.Props[key]=signal(); return self.Props[key] end
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
for _,name in ipairs({"Rules","SoundConfig"}) do named("ModuleScript",name,ConfigFolder) end
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
for _,name in ipairs({"RetroTheme","RetroArtwork","BrickStyles","BrickRenderer","BrickPreviewRenderer","NeonUI","NeonLayout","GameClient","PortalUI","AudioController","InputController","CosmeticRenderer"}) do named("ModuleScript",name,clientFolder) end
local script={Parent=clientFolder}
local modules={TetrisEngine=E,Rules=R,Progression=P,SoundConfig=SoundConfig,Catalog=Catalog}
local require=function(obj) return assert(modules[type(obj)=="string" and obj or obj.Name],"Unknown module") end
local warn=print

modules.RetroTheme=(function()
-- One palette/type/spacing source for the complete arcade interface.
local Theme={RGB={
	background={12,7,20},panel={27,15,42},raised={40,22,58},board={10,7,17},empty={24,16,35},
	text={255,244,228},muted={176,158,191},line={75,43,92},pink={255,61,143},purple={219,49,139},
	cyan={83,213,226},orange={255,152,81},yellow={255,218,137},green={127,222,173},
	I={85,215,230},O={255,212,112},T={185,118,242},S={128,221,171},Z={248,97,143},J={111,146,238},L={255,164,98},G={104,87,124},
},Fonts={Display=Enum.Font.Arcade,Body=Enum.Font.BuilderSans,Strong=Enum.Font.BuilderSansBold,Mono=Enum.Font.Code},
Type={Hero=54,Heading=22,Body=16,Label=13,Number=28},Space={Small=8,Medium=16,Large=24,XL=32},Border=1,Radius=2,Touch=44,
Motion={Hover=0.12,Page=0.18,Preview=0.7}}
Theme.Colors={}; for name,rgb in pairs(Theme.RGB) do Theme.Colors[name]=Color3.fromRGB(table.unpack(rgb)) end
return Theme

end)()

modules.NeonUI=(function()
-- Compatibility name; all styling comes from RetroTheme.
local TweenService=game:GetService("TweenService")
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
	UI.round(panel); UI.stroke(panel,accent or UI.colors.line,accent and 0.2 or 0); return panel
end
function UI.text(name,parent,value,size,color,font)
	return UI.new("TextLabel",name,parent,{BackgroundTransparency=1,Text=tostring(value),TextColor3=color or UI.colors.text,
		FontFace=Font.fromEnum(font or Theme.Fonts.Body),TextSize=size or Theme.Type.Body,TextWrapped=true,
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
		Text=text,TextSize=15,TextColor3=UI.colors.text,FontFace=Font.fromEnum(Theme.Fonts.Strong),Selectable=true})
	UI.round(button); local outline=UI.stroke(button,accent,0.15)
	local function focus(active)
		if button:GetAttribute("Disabled") then return end
		UI.tween(button,{BackgroundColor3=active and UI.colors.raised or UI.colors.panel}); UI.tween(outline,{Color=active and UI.colors.yellow or accent})
	end
	button.MouseEnter:Connect(function() focus(true); if UI.onHover then UI.onHover() end end); button.MouseLeave:Connect(function() focus(false) end)
	button.SelectionGained:Connect(function() focus(true) end); button.SelectionLost:Connect(function() focus(false) end)
	button.Activated:Connect(function() if not button:GetAttribute("Disabled") and clicked then clicked() end end)
	return button
end
function UI.divider(parent,name) return UI.new("Frame",name,parent,{BackgroundColor3=UI.colors.line,BorderSizePixel=0,Size=UDim2.new(1,0,0,1)}) end
function UI.focusGroup(object)
	object.SelectionGroup=true
	for _,direction in ipairs({"Up","Down","Left","Right"}) do object["SelectionBehavior"..direction]=Enum.SelectionBehavior.Stop end
end
return UI

end)()

modules.NeonLayout=(function()
-- Physical design pixels: normal device sizes do not shrink readable text.
local Layout={}
function Layout.resolve(width,height,battle)
	local w,h=math.max(320,width),math.max(280,height)
	local compact=h<540 and w>h; local portrait=not compact and w/h<0.9
	local menu={brand={16,12,math.min(250,w-144),44},settings={w-120,12,96,44}}
	if portrait then
		local cw=math.min(520,w-32); local x=(w-cw)/2; local start=math.max(242,math.min(300,h*0.34))
		menu.title={x,82,cw,136}; menu.titleSize=math.min(52,math.floor(cw/6*0.85))
		menu.kicker={x,58,cw,24}; menu.solo={x,start,cw,56}; menu.battle={x,start+72,cw,56}
		menu.nav={x,start+152,cw,152}; menu.navColumns=2; menu.status={x,start+328,cw,64}
		menu.footer={x,math.max(h-36,start+416),cw,24}
	elseif compact or h<660 then
		local bx=math.max(280,w*0.35); local bw=math.min(280,w-bx-24)
		menu.title={24,64,240,104}; menu.titleSize=32; menu.kicker={24,48,240,18}
		menu.solo={bx,64,bw,44}; menu.battle={bx,120,bw,44}; menu.nav={24,h-108,w-48,96}; menu.navColumns=3
		menu.status={24,172,w-48,40}; menu.footer={0,0,0,0}
	else
		local x=w<1100 and 48 or 72; local cw=448; local top=math.max(98,h*0.16)
		menu.title={x,top,cw,136}; menu.titleSize=54; menu.kicker={x,top-32,cw,24}
		menu.solo={x,top+176,cw,56}; menu.battle={x,top+248,cw,56}
		menu.nav={x,top+328,cw,152}; menu.navColumns=2; menu.status={w-644,12,508,44}
		menu.footer={x,h-38,cw,24}
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
		local available=cy-top-16; local maxWidth=battle and (w-32-side-middle-gap*3)/2 or (w-32-side*2-middle-gap*3)
		local cell=math.max(4,math.floor(math.min(available/20,maxWidth/10))); local bw,bh=cell*10,cell*20
		local bodyW=side+gap+bw+gap+middle+(battle and gap+bw or compact and 0 or gap+side); local left=(w-bodyW)/2
		game.hold={left,top,side,compact and 68 or 104}; game.next={battle and left or left+side+gap+bw+gap, battle and top+(compact and 80 or 124) or top,side,battle and bh-(compact and 80 or 124) or bh}
		if compact then game.hold={left+84,top,72,68}; game.next={left,top,72,bh} end
		local x=left+side+gap; local center=(battle or compact) and x+bw+gap or x+bw+gap+side+gap
		game.board={x,top,bw,bh}; game.player={x,top-44,bw,36}
		game.opponent={center+middle+gap,top,bw,bh}; game.opponentPlayer={center+middle+gap,top-44,bw,36}
		if compact and battle then local ew=math.max(4,cell-1)*10; game.opponent={center+middle+gap,top+(bh-ew*2)/2,ew,ew*2}; game.opponentPlayer[3]=ew end
		game.timer={center,top,middle,compact and 42 or 72}
		game.ownStats={center,top+(compact and 42 or 88),middle,compact and math.min(128,cy-top-50) or 176}
		game.enemyStats={center,top+(compact and 156 or 292),middle,compact and 0 or 140}
		game.banner=compact and {center,58,middle,24} or {16,66,w-32,24}; game.controls={(w-math.min(640,w-32))/2,cy,math.min(640,w-32),44}; game.controlColumns=7
	end
	game.footer={16,h-16,w-32,12}
	return {width=w,height=h,scale=math.min(width/w,height/h),portrait=portrait,compact=compact,menu=menu,game=game}
end
return Layout

end)()

modules.RetroArtwork=(function()
-- Original native-UI artwork; no bitmap or third-party image IDs.
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
	self.Dim=UI.new("Frame","ArtworkDim",self.Frame,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4})
	return self
end
function Art:layout(width,height,portrait)
	local size=math.min(width*(portrait and 0.54 or 0.37),height*0.5)
	local cx=width*(portrait and 0.79 or 0.76); local cy=height*(portrait and 0.25 or 0.43)
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
function Art:quiet(value) self.Dim.BackgroundTransparency=value and 0.12 or 1 end
function Art:destroy() self.Frame:Destroy() end
return Art

end)()

modules.BrickStyles=(function()
-- Shared definitions for match boards, hold/next and cosmetic samples.
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local Styles={Skins={
	Default={Texture="Bevel",Blend=0,Inset=1},NeonClub={Texture="Neon",Blend=0.12,Tint={255,61,143},Inset=1},
	CyberCore={Texture="Circuit",Blend=0.34,Tint={40,60,94},Inset=1},OceanWave={Texture="Wave",Blend=0.36,Tint={24,158,202},Inset=1},
	Galaxy={Texture="Star",Blend=0.30,Tint={113,50,158},Inset=1},GoldElite={Texture="Gold",Blend=0.78,Tint={238,181,63},Inset=1},
	Lava={Texture="Lava",Blend=0.55,Tint={221,63,33},Inset=1},CrystalGlass={Texture="Crystal",Blend=0.30,Tint={178,223,237},Inset=2},
	RetroPixel={Texture="Pixel",Blend=0,Inset=2},Holographic={Texture="Scan",Blend=0.22,Tint={92,225,218},Inset=1},
},Ghosts={Default={Alpha=0.9},NeonOutline={Alpha=0.83},Hologram={Alpha=0.82},Pulse={Alpha=0.87},Glitch={Alpha=0.87},Prism={Alpha=0.84},Electric={Alpha=0.87}}}
function Styles.describe(kind,skinId,ghostId,ghost,reduced,clock)
	local C=Theme.Colors; local skin=Styles.Skins[skinId] or Styles.Skins.Default; local base=C[kind] or C.G
	if skin.Tint then base=base:Lerp(Color3.fromRGB(table.unpack(skin.Tint)),skin.Blend) end
	local fill=0; local border=base:Lerp(C.text,skin.Texture=="Neon" and 0.6 or 0.22)
	if ghost then local effect=Styles.Ghosts[ghostId] or Styles.Ghosts.Default; local time=reduced and 0 or clock or 0
		fill=effect.Alpha
		if ghostId=="Pulse" then fill+=math.sin(time*4)*0.045
		elseif ghostId=="Glitch" then fill+=math.floor(time*6)%2*0.035
		elseif ghostId=="Prism" then border=border:Lerp(Color3.fromHSV(time%6/6,0.6,1),0.3)
		elseif ghostId=="Electric" then fill+=math.sin(time*12)*0.025 end
	end
	return {Color=base,Edge=border,Transparency=fill,Texture=ghost and "Ghost" or skin.Texture,Inset=skin.Inset,Ghost=ghost}
end
return Styles

end)()

modules.AudioController=(function()
local SoundService=game:GetService("SoundService")
local Config=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SoundConfig"))
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
				started=true; sample:Play(); task.delay(1.6,finish)
			end
			loaded=sample.Loaded:Connect(start); if sample.IsLoaded then start() end
			task.delay(8,function() if not started then if self.Preview==sample then self.Failed[id]=true; warn("[Tetris Audio] Could not load pack sample: "..id) end; finish() end end)
			return true
		end
	end
	return false,"No audio sample is available yet."
end
function Audio:play(key)
	if self.Muted then return end
	local id,pitch=self:resolve(key); if id=="" or self.Failed[id] then return end
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
function Input:set(action,source,down)
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
-- Local-only effects. Never changes engine state or sends gameplay commands.
local TweenService=game:GetService("TweenService")
local Catalog=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog"))
local Renderer={Active=0,Limit=48}
function Renderer.color(base,item,ghost)
	if not item then return base end
	local visual=item.Visual
	if visual.Tint then base=base:Lerp(Color3.new(table.unpack(visual.Tint)),visual.Blend) end
	if ghost then
		local alpha=visual.Transparency
		if item.Id=="Pulse" then alpha+=math.sin(os.clock()*4)*0.035
		elseif item.Id=="Glitch" then alpha+=math.floor(os.clock()*8)%2*0.03
		elseif item.Id=="Prism" then base=base:Lerp(Color3.fromHSV(os.clock()%5/5,0.7,1),0.18)
		elseif item.Id=="Electric" then alpha+=math.sin(os.clock()*15)*0.025 end
		base=base:Lerp(Color3.fromRGB(8,10,24),alpha)
	end
	return base
end
function Renderer.drop(board,id,reducedMotion,origin)
	local item=Catalog.Items["DropEffects:"..id]
	if not item or id=="Default" or reducedMotion then return end
	local count=id=="Stardust" and 14 or id=="CyberGlitch" and 5 or 8
	for i=1,count do
		if Renderer.Active>=Renderer.Limit then break end
		Renderer.Active+=1
		local p=Instance.new("Frame"); p.Name="CosmeticParticle"; p.BorderSizePixel=0; p.BackgroundColor3=Color3.new(table.unpack(item.Preview.Color)); p.ZIndex=6
		local ox,oy=origin and origin.X or 0.5,origin and origin.Y or 0.9
		p.ZIndex=(board.ZIndex or 1)+6
		p.AnchorPoint=Vector2.new(0.5,0.5); p.Position=UDim2.fromScale(ox,oy); p.Size=UDim2.fromOffset(4,8)
		local destination=UDim2.fromScale(i/count,0.6+(i%3)*0.1)
		if id=="LightningStrike" then p.Position=UDim2.fromScale(0.5+(i%2)*0.02,(i-1)/count); p.Size=UDim2.new(0,3,1/count,2); destination=p.Position
		elseif id=="FireBurst" then p.Size=UDim2.fromOffset(12,12); p.BackgroundColor3=Color3.fromRGB(255,120+i*8,40); local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(1,0); corner.Parent=p
		elseif id=="PixelExplosion" then p.Size=UDim2.fromOffset(10,10)
		elseif id=="CrystalShatter" then p.Rotation=45; p.Size=UDim2.fromOffset(7,14)
		elseif id=="CyberGlitch" then p.Position=UDim2.fromScale(0.5,i/(count+1)); p.Size=UDim2.new(0.8,0,0,3); destination=UDim2.fromScale(i%2==0 and 0.4 or 0.6,i/(count+1))
		elseif id=="Stardust" then p.Size=UDim2.fromOffset(3,3); destination=UDim2.fromScale(i/count,0.2+(i%5)*0.12) end
		p.Parent=board
		local tween=TweenService:Create(p,TweenInfo.new(0.3+i*0.012),{Position=destination,BackgroundTransparency=1}); tween:Play()
		local finished=false
		local function release() if finished then return end; finished=true; p:Destroy(); Renderer.Active=math.max(0,Renderer.Active-1) end
		tween.Completed:Once(release); task.delay(1,release)
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
	return {Frame=root,Face=face,Edge=edge,Shine=shine,Detail=detail}
end
function Renderer.paint(tile,kind,skin,ghostId,isGhost,reduced,clock,variation)
	local phase=isGhost and not reduced and math.floor((clock or 0)*12) or 0
	local key=tostring(kind)..":"..(skin or "Default")..":"..(ghostId or "Default")..":"..tostring(isGhost)..":"..phase..":"..tostring(reduced)
	if tile.Key==key then return end; tile.Key=key
	tile.Frame:SetAttribute("SkinId",skin or "Default"); tile.Frame:SetAttribute("PieceKind",tostring(kind)); tile.Frame:SetAttribute("Ghost",isGhost or false)
	if kind==0 then tile.Face.Visible=false; tile.Frame.BackgroundColor3=Theme.Colors.empty; tile.Frame.BackgroundTransparency=0; return end
	local spec=Styles.describe(kind,skin,ghostId,isGhost,reduced,clock)
	tile.Face.Visible=true; tile.Frame.BackgroundColor3=spec.Color:Lerp(Theme.Colors.board,0.55); tile.Frame.BackgroundTransparency=isGhost and 1 or 0
	tile.Face.Position=UDim2.fromOffset(spec.Inset,spec.Inset); tile.Face.Size=UDim2.new(1,-2*spec.Inset,1,-2*spec.Inset)
	tile.Face.BackgroundColor3=spec.Color; tile.Face.BackgroundTransparency=spec.Transparency; tile.Edge.Color=spec.Edge; tile.Edge.Transparency=isGhost and 0.38 or 0.12
	tile.Shine.Visible=not isGhost; tile.Shine.BackgroundColor3=spec.Color:Lerp(Theme.Colors.text,0.5)
	local mark=tile.Detail; mark.Visible=not isGhost and spec.Texture~="Bevel" and spec.Texture~="Neon"
	mark.Rotation=0; mark.BackgroundTransparency=0.25; mark.BackgroundColor3=spec.Edge; mark.Position=UDim2.fromScale(0.15,0.2); mark.Size=UDim2.fromScale(0.25,0.25)
	if spec.Texture=="Circuit" then mark.Size=UDim2.new(0.6,0,0,2); mark.Position=UDim2.fromScale(0.2,0.72); mark.BackgroundColor3=Theme.Colors.cyan
	elseif spec.Texture=="Wave" then mark.Size=UDim2.new(0.8,0,0,2); mark.Position=UDim2.fromScale(0.1,0.5)
	elseif spec.Texture=="Star" then mark.Size=UDim2.fromOffset(2,2); mark.Position=UDim2.fromScale(0.2+(variation or 0)%3*0.2,0.25); mark.BackgroundColor3=Theme.Colors.text
	elseif spec.Texture=="Gold" then mark.Size=UDim2.new(0,1,0.6,0); mark.Position=UDim2.fromScale(0.8,0.2); mark.BackgroundColor3=Theme.Colors.yellow
	elseif spec.Texture=="Lava" then mark.Size=UDim2.new(0.7,0,0,2); mark.Position=UDim2.fromScale(0.1,0.65); mark.BackgroundColor3=Theme.Colors.orange
	elseif spec.Texture=="Crystal" then mark.Rotation=45; mark.BackgroundTransparency=0.4
	elseif spec.Texture=="Pixel" then mark.Size=UDim2.fromScale(0.32,0.32); mark.Position=UDim2.fromScale(0.5,0.5); mark.BackgroundTransparency=0.45
	elseif spec.Texture=="Scan" then mark.Size=UDim2.new(0.8,0,0,1); mark.Position=UDim2.fromScale(0.1,0.65); mark.BackgroundColor3=Theme.Colors.cyan end
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
	for y,row in ipairs(view.Tiles) do for x,tile in ipairs(row) do local cell=cells[y][x]; Renderer.paint(tile,cell.kind,loadout.BrickSkin,loadout.GhostEffect,cell.ghost,reduced,clock,y*view.Columns+x) end end; view.State=state
end
function Renderer.piece(view,kind,loadout,reduced)
	Renderer.draw(view,{board={},alive=type(kind)=="string",piece=type(kind)=="string" and {kind=kind,x=1,y=1,rotation=0} or nil},loadout,reduced,0)
end
return Renderer

end)()

modules.BrickPreviewRenderer=(function()
-- Cosmetic-only sample. Uses exactly the same tile painter as live game boards.
local Bricks=require(script.Parent:WaitForChild("BrickRenderer"))
local Effects=require(script.Parent:WaitForChild("CosmeticRenderer"))
local Preview={}; Preview.__index=Preview
function Preview.new(parent,UI)
	local self=setmetatable({UI=UI,Elapsed=0,LastStep=-1},Preview)
	self.View=Bricks.board(parent,"CosmeticSampleBoard",10,12,UI)
	self.Frame=self.View.Frame; self.Frame:SetAttribute("CosmeticSample",true)
	return self
end
function Preview.thumbnail(parent,UI,item,loadout)
	local view=Bricks.board(parent,"TetrominoPreview",4,2,UI)
	local outfit={BrickSkin=item.Category=="BrickSkins" and item.Id or loadout and loadout.BrickSkin or "Default",GhostEffect="Default"}
	Bricks.piece(view,"T",outfit,UI.reducedMotion)
	return view
end
function Preview:set(item,equipped)
	self.Item=item; self.Elapsed=0; self.Landed=false; self.LastStep=-1
	self.Loadout={BrickSkin=equipped and equipped.BrickSkin or "Default",GhostEffect=equipped and equipped.GhostEffect or "Default"}
	if item.Category=="BrickSkins" then self.Loadout.BrickSkin=item.Id end
	if item.Category=="GhostEffects" then self.Loadout.GhostEffect=item.Id end
	self:tick(0,true)
end
function Preview:tick(dt,force)
	if not self.Item then return end
	self.Elapsed+=dt; local step=math.floor(self.Elapsed*20)
	if not force and step==self.LastStep then return end; self.LastStep=step
	local board={}; for y=1,12 do board[y]=table.create(10,0) end
	for x=1,10 do board[12][x]=({"J","J","J","I","I","I","I","L","L","L"})[x] end
	board[11][1]="O"; board[11][2]="O"; board[11][9]="S"; board[11][10]="S"
	local drop=self.Item.Category=="DropEffects"; local progress=self.Elapsed%2.4
	local y=drop and (self.UI.reducedMotion and 10 or math.min(10,2+math.floor(progress/0.75*8))) or 3
	local state={board=board,alive=true,piece={kind="T",x=4,y=y,rotation=0},ghost={kind="T",x=4,y=10,rotation=0}}
	Bricks.draw(self.View,state,self.Loadout,self.UI.reducedMotion,self.Elapsed)
	if drop and not self.UI.reducedMotion then
		if progress>=0.75 and not self.Landed then self.Landed=true; Effects.drop(self.Frame,self.Item.Id,false,{X=0.5,Y=0.87}) end
		if progress<0.75 then self.Landed=false end
	end
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
		elseif kind=="Found" then self.Mode=data.Ranked and "Ranked" or "Challenge"; self.LastEvent=0; self.Audio:play("OpponentFound"); hooks.Found(data)
		elseif kind=="State" then
			Engine.unpack(data.Own); Engine.unpack(data.Opponent)
			local changed=self.Mode~=data.Mode; self.Mode=data.Mode; self.State=data
			if changed then self.LastEvent=0 end
			self.Input:enable(data.Own.alive and not data.Own.paused and data.Countdown==0 and not self.Blocked)
			self.Audio:music(data.Mode=="Solo" and "SoloMusic" or "BattleMusic")
			for _,event in ipairs(data.Own.events) do if event.id>self.LastEvent then self.LastEvent=event.id; self.Audio:play(event.name); if hooks.Event then hooks.Event(event) end end end
			hooks.State(data)
		elseif kind=="Result" then
			Engine.unpack(data.Own); Engine.unpack(data.Opponent)
			self.Mode="Result"; self.Input:enable(false); self.Audio:music("MenuMusic"); self.Audio:play(data.Outcome=="Win" and "Victory" or data.Outcome=="Lose" and "Defeat" or "Draw")
			if data.BeforeRank and data.AfterRank and data.BeforeRank.Tier~=data.AfterRank.Tier then self.Audio:play(data.AfterRank.Tier>data.BeforeRank.Tier and "RankUp" or "RankDown") end
			if data.Cash>0 then self.Audio:play("CashEarned") end
			hooks.Result(data)
		elseif kind=="Leaderboard" then hooks.Leaderboard(data)
		elseif kind=="Challenge" then hooks.Challenge(data)
		elseif kind=="CosmeticResult" then
			self.LastCosmeticResult=data -- Profile remains the authority for equipped state.
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

modules.PortalUI=(function()
-- Data-driven lobby screens. All purchases and claims are requested from server.
local Players=game:GetService("Players")
local SocialService=game:GetService("SocialService")
local TextService=game:GetService("TextService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog=require(Shared:WaitForChild("Catalog"))
local P=require(Shared:WaitForChild("Progression"))
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local F=Theme.Fonts
local Preview=require(script.Parent:WaitForChild("BrickPreviewRenderer"))
local Portal={}; Portal.__index=Portal
function Portal.new(root,UI,client,closed)
	local self=setmetatable({Root=root,UI=UI,Client=client,Page="Profile",Category="BrickSkins",Inventory=false,Leaderboard="GlobalRating",Closed=closed},Portal)
	local C=UI.colors
	self.Overlay=UI.new("Frame","LobbyPortal",root,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,Visible=false,ZIndex=30,Active=true})
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
 local tabs=w<600 and 96 or 48; self.BodyTop=76+tabs+12
 self.ListWidth=(self.Page=="Shop" or self.Page=="Inventory") and w>=960 and math.min(500,math.floor(w*0.43)) or w-40
 local U=self.UI; U.rect(self.Header,{20,20,w-156,40}); U.rect(self.Back,{w-116,16,96,44}); U.rect(self.Tabs,{20,76,w-40,tabs})
 self.Header.TextSize=w<640 and 16 or 20
 U.rect(self.Scroll,{20,self.BodyTop,self.ListWidth,h-self.BodyTop-20})
 if (old~=w or oldHeight~=h) and self.Overlay.Visible then self:render(true) end
end
function Portal:close(suppressCancel)
 if self.Page=="Searching" and not suppressCancel then self.Client:send("Cancel") end
 self.PreviewOpen=false; self:clearPreview(); self.Overlay.Visible=false; self.Client:block(false)
 self.Client.Audio:music(self.Client.Mode=="Solo" and "SoloMusic" or (self.Client.Mode=="Ranked" or self.Client.Mode=="Challenge") and "BattleMusic" or "MenuMusic")
 if self.Closed then self.Closed() end
end
function Portal:open(page)
 self.Page=page; self.PreviewOpen=false; self.Overlay.Visible=true; self.Client:block(true); self.Client.Audio:play("ButtonClick")
 self.Client.Audio:music((page=="Shop" or page=="Inventory") and "ShopMusic" or "MenuMusic")
 self:layout(self.Width or self.Root.AbsoluteSize.X,self.Height or self.Root.AbsoluteSize.Y); self:render(); self:restoreFocus()
end
function Portal:clear(parent)
	for _,child in ipairs(parent:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
end
function Portal:tab(text,index,fn)
 local b=self.UI.button("Tab"..index,self.Tabs,text,self.UI.colors.line,fn); b.ZIndex=32
 local columns=self.Width<600 and 2 or 4; local width=(self.Width-40-(columns-1)*8)/columns
 self.UI.rect(b,{((index-1)%columns)*(width+8),math.floor((index-1)/columns)*52,width,44})
end
function Portal:row(title,body,action,fn,accent,height)
 local U,C=self.UI,self.UI.colors; local narrow=self.Width<640
 local reserved=action and not narrow and 196 or 28
 local textWidth=math.max(80,self.ListWidth-8-reserved)
 local titleHeight=math.max(28,TextService:GetTextSize(title,18,F.Strong,Vector2.new(textWidth,10000)).Y+4)
 local bodyHeight=math.max(44,TextService:GetTextSize(body,15,F.Body,Vector2.new(textWidth,10000)).Y+4)
 local row=U.new("Frame","Row",self.Scroll,{BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=32}); row.Size=UDim2.new(1,-8,0,math.max(height or (action and 112 or 96),8+titleHeight+4+bodyHeight+12+(action and narrow and 54 or 0)))
 local divider=U.divider(row,"RowBorder"); divider.ZIndex=33
 local t=U.text("Title",row,title,18,C.text,F.Strong); t.ZIndex=33; t.Position=UDim2.fromOffset(14,8); t.Size=UDim2.new(1,-reserved,0,titleHeight); t.TextYAlignment=Enum.TextYAlignment.Top
 local d=U.text("Body",row,body,15,C.muted,F.Body); d.ZIndex=33; d.Position=UDim2.fromOffset(14,12+titleHeight); d.Size=UDim2.new(1,-reserved,0,bodyHeight); d.TextYAlignment=Enum.TextYAlignment.Top
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
	if preserveScroll and shop and d and view and view.Page==self.Page and view.Category==self.Category and view.Width==self.Width and view.Height==self.Height then
		-- Server profile updates and preview actions never remove the list or its cards.
		self:shop(d,true); self:restoreFocus(focusName); return
	end
	local scroll=preserveScroll and self.Scroll.CanvasPosition or Vector2.new(0,0)
	self.RowIndex=0; self:clearPreview()
	self:layout(self.Width or 1120,self.Height or 760)
	self.ShopView=nil
	self:clear(self.Tabs); self:clear(self.Scroll); self.Scroll.CanvasPosition=scroll
	self.Header.Text=self.Page=="ChallengeInvite" and "DUEL INVITE" or self.Page:upper()
	if not d then self:row("Loading profile","Please wait for your server data."); return end
	if self.Page=="Hub" then
  self.Header.Text="YOUR ARCADE"
  for _,page in ipairs({"Profile","Shop","Inventory","Quests","Leaderboards","Login","Energy","Friends","Audio"}) do self:row(page,"", "OPEN",function() self:open(page) end,nil,self.Width<640 and 112 or 88) end
 elseif self.Page=="Shop" or self.Page=="Inventory" then
  self:shop(d)
	elseif self.Page=="Quests" then
		self:tab("DAILY",1,function() self.QuestGroup="Daily"; self:render() end); self:tab("WEEKLY",2,function() self.QuestGroup="Weekly"; self:render() end)
		local group=self.QuestGroup or "Daily"; self.Header.Text=group:upper().." QUESTS"
		for _,q in ipairs(P[group]) do
			local state=d.Quests[group]; local n=state.Progress[q.Id] or 0
			self:row(q.Label,string.format("%d / %d  |  %s%s\nReset: %s UTC",n,q.Target,q.Cash and q.Cash.." Cash" or "",q.Energy and q.Energy.." Energy" or "",group=="Daily" and "daily at 00:00" or "Monday 00:00"),state.Claimed[q.Id] and "CLAIMED" or "CLAIM",function() self.Client:send("ClaimQuest",{Group=group,Id=q.Id}) end)
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
		self:row("Audio volumes","Adjust master, music and effects volume separately. Settings apply to this session.")
		for _,field in ipairs({"Master","MusicVolume","SFXVolume"}) do
			self:row(field,math.floor(self.Client.Audio[field]*100).."%","CYCLE +20%",function()
				local a=self.Client.Audio; a[field]=(math.floor(a[field]*5+0.5)+1)%6/5
				a:settings(a.Master,a.MusicVolume,a.SFXVolume,a.Muted); self:render()
			end)
		end
	elseif self.Page=="Friends" then
		self:row("Invite friends","A verified first-time friend who stays "..d.Economy.SocialMinSeconds.."s earns you "..d.Economy.SocialEnergy.." Energy. Limit "..d.Economy.SocialLimit.." daily. Clicking Invite gives no reward.","INVITE FRIENDS",function()
			task.spawn(function() local ok,allowed=pcall(function() return SocialService:CanSendGameInviteAsync(Players.LocalPlayer) end); if ok and allowed then pcall(function() SocialService:PromptGameInvite(Players.LocalPlayer) end) else self.Client.Hooks.Message("Invitations are unavailable on this device or in Studio") end end)
		end)
		for _,other in ipairs(Players:GetPlayers()) do
			if other~=Players.LocalPlayer then self:row(other.DisplayName,"Free unranked challenge; server verifies friendship.","CHALLENGE",function() self.Client:send("Challenge",other.UserId) end) end
		end
	elseif self.Page=="Energy" then
		self:row("Energy "..d.Energy.Current.." / "..d.Economy.EnergyCap,d.DebugPrivileges and d.DebugPrivileges.InfiniteEnergy and "Unlimited Studio test energy. Test rewards never write to live data." or ("Next regeneration: "..d.Energy.Next.."s. +1 every "..d.Economy.EnergyInterval.."s, including offline. Bonus cap "..d.Economy.BonusCap..". Ranked costs "..d.Economy.RankedCost.."; Solo is free."),"OPEN QUESTS",function() self:open("Quests") end)
	elseif self.Page=="Searching" then
		self:row("FINDING OPPONENT","Searching for a real player in this server.","CANCEL SEARCH",function() self:close() end)
		self.SearchLabel=self.UI.text("Elapsed",self.Scroll,"",18,self.UI.colors.cyan); self.SearchLabel.Size=UDim2.new(1,-8,0,48); self.SearchLabel.ZIndex=32
		local row=self:row(Players.LocalPlayer.DisplayName,"@"..Players.LocalPlayer.Name.." / "..P.Ranks[d.Rank.Tier].." / "..d.Rank.Stars.." stars / "..d.Rank.Rating.." rating")
		self.UI.new("ImageLabel","Avatar",row,{Position=UDim2.new(1,-58,0,8),Size=UDim2.fromOffset(44,44),BackgroundTransparency=1,Image="rbxthumb://type=AvatarHeadShot&id="..Players.LocalPlayer.UserId.."&w=150&h=150",ZIndex=33})
	elseif self.Page=="Result" then
		local result=self.ResultData
		if not result then return end
		self:row(result.Outcome:upper(),result.Reason.." / Cash earned: "..result.Cash.."\n"..(result.SettlementPending and "Saving rewards is delayed. Check your profile after reconnecting." or result.Rewards and "Rank and quest rewards applied once." or "Unranked or anti-farming rules: no standard ranked rewards."),"REMATCH",function() self.Client:send("Rematch") end)
		for i,p in ipairs(result.Profiles) do
			local own=p.UserId==Players.LocalPlayer.UserId; local state=own and result.Own or result.Opponent
			self:row(p.DisplayName,string.format("Score %d | Lines %d | Sent %d | KOs %d",state.score,state.lines,state.stats.Sent,state.stats.KOs))
		end
		if result.BeforeRank and result.AfterRank then
			local row=self:row("RANK PROGRESS",P.Ranks[result.BeforeRank.Tier].." "..result.BeforeRank.Stars.." stars -> "..P.Ranks[result.AfterRank.Tier].." "..result.AfterRank.Stars.." stars / Rating "..result.AfterRank.Rating,"RETURN TO LOBBY",function() self.Client:send("Exit"); self:close() end)
			self:rankProgress(row,result.AfterRank,result.BeforeRank)
		end
		self:row("Quest progress","Daily and weekly totals reflect verified gameplay.","VIEW QUESTS",function() self:open("Quests") end)
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
	if preserveScroll then task.defer(function() if self.Overlay.Parent and self.Overlay.Visible and self.RenderRevision==revision then self.Scroll.CanvasPosition=scroll end end) end
	self:restoreFocus(focusName)
end
function Portal:clearPreview()
	if self.Sample then self.Sample:destroy(); self.Sample=nil end
	if self.PreviewPanel then self.PreviewPanel:Destroy(); self.PreviewPanel=nil end
	if self.PreviewShade then self.PreviewShade:Destroy(); self.PreviewShade=nil end
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
		for index,category in ipairs(Catalog.Categories) do self:tab(captions[index],index,function() self.Category=category; self.Selected=nil; self.PreviewOpen=false; self:render() end) end
		self.ShopView={Page=self.Page,Category=self.Category,Width=self.Width,Height=self.Height,Cards={}}
		self.ShopView.Balance=self:row("CASH "..d.Cash,"Visuals only. Your purchases and loadout are saved.",nil,nil,nil,88)
	end
	local view=self.ShopView; local seen={}
	view.Balance:FindFirstChild("Title").Text="CASH "..d.Cash
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
			local row=U.panel("Cosmetic_"..item.Id,self.Scroll); row.Size=UDim2.new(1,-8,0,156); row.ZIndex=32; row.LayoutOrder=order
			card={Row=row,Buttons={}}; view.Cards[item.Id]=card
			local label=U.text("Name",row,item.Name,self.Width<360 and 16 or 18,C.text,F.Strong); label.ZIndex=33; U.rect(label,{112,10,width-144,28})
			local rarity=U.text("Rarity",row,item.Rarity:upper(),13,C.orange,F.Mono); rarity.ZIndex=33; U.rect(rarity,{112,40,width-144,22})
			local price=d.DebugPrivileges and d.DebugPrivileges.FreePurchases and 0 or item.Price
			local status=equipped and "EQUIPPED" or owned and "OWNED" or "LOCKED"
			local meta=U.text("Ownership",row,status.." / "..price.." CASH",14,owned and C.green or C.muted,F.Mono); meta.ZIndex=33; U.rect(meta,{112,64,width-144,26})
			if item.Category=="SoundPacks" then
				local text=U.text("SoundPack",row,"SFX",22,C.cyan,F.Mono); text.ZIndex=33; U.rect(text,{16,22,80,54})
			else
				card.Mini=Preview.thumbnail(row,U,item,d.Equipped); U.rect(card.Mini.Frame,{16,28,80,40})
			end
			local actions={{"Preview_","PREVIEW",function() self.Selected=item.Id; if item.Category=="SoundPacks" then self:sampleAudio(item) end; self.PreviewOpen=self.Width<960; self:render(true) end},
				{"Buy_",owned and "OWNED" or "BUY",function() self.Client:send("Buy",{Category=item.Category,Id=item.Id}) end},
				{"Equip_",equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP",function() local current=self.Client.Profile; local isEquipped=current and current.Equipped[Catalog.Slots[item.Category]]==item.Id; self.Client:send("Equip",{Category=item.Category,Id=isEquipped and "Default" or item.Id}) end}}
			local bw=(width-48)/3
			for index,action in ipairs(actions) do local button=U.button(action[1]..item.Id,row,action[2],index==1 and C.cyan or C.line,action[3]); button.ZIndex=33
				card.Buttons[index]=button
				U.rect(button,{16+(index-1)*(bw+8),102,bw,44}); if index==2 then U.enabled(button,not owned) elseif index==3 then U.enabled(button,owned and not (equipped and item.Id=="Default")) end
			end
			end
			local price=d.DebugPrivileges and d.DebugPrivileges.FreePurchases and 0 or item.Price
			local status=equipped and "EQUIPPED" or owned and "OWNED" or "LOCKED"
			local meta=card.Row:FindFirstChild("Ownership"); meta.Text=status.." / "..price.." CASH"; meta.TextColor3=owned and C.green or C.muted
			card.Buttons[2].Text=owned and "OWNED" or "BUY"; U.enabled(card.Buttons[2],not owned)
			card.Buttons[3].Text=equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP"; U.enabled(card.Buttons[3],owned and not (equipped and item.Id=="Default"))
			if card.Mini then local Bricks=require(script.Parent:WaitForChild("BrickRenderer")); Bricks.piece(card.Mini,"T",{BrickSkin=item.Category=="BrickSkins" and item.Id or d.Equipped.BrickSkin,GhostEffect="Default"},U.reducedMotion) end
		end
	end
	for id,card in pairs(view.Cards) do if not seen[id] then card.Row:Destroy(); view.Cards[id]=nil end end
	self:clearPreview()
	if self.Width>=960 or self.PreviewOpen then self:detail(selected,d) end
end
function Portal:detail(item,d)
	local U,C=self.UI,self.UI.colors; local mobile=self.Width<960; local landscape=mobile and self.Height<420 and self.Width>self.Height
	local width,height,x,y
	if mobile then
		width=math.min(landscape and 680 or 480,self.Width-32); height=math.min(520,self.Height-32); x=(self.Width-width)/2; y=(self.Height-height)/2
		self.PreviewShade=U.new("TextButton","PreviewBackdrop",self.Overlay,{Size=UDim2.fromScale(1,1),Text="",AutoButtonColor=false,Selectable=false,BackgroundColor3=C.background,BackgroundTransparency=0.06,ZIndex=38})
	else width=self.Width-40-self.ListWidth-24; height=self.Height-self.BodyTop-20; x=20+self.ListWidth+24; y=self.BodyTop end
	local panel=U.panel("CosmeticDetail",self.Overlay,C.line); panel.ZIndex=39; U.rect(panel,{x,y,width,height}); self.PreviewPanel=panel
	if mobile then U.focusGroup(panel) end
	local title=U.text("PreviewName",panel,item.Name,18,C.orange,F.Display); title.ZIndex=40; U.rect(title,{20,14,width-100,42})
	local close=U.button("ClosePreview",panel,mobile and "BACK" or "SAMPLE",C.line,function() self.PreviewOpen=false; self:render(true) end); close.ZIndex=40; U.rect(close,{width-76,14,56,44}); U.enabled(close,mobile)
	local desc=U.text("PreviewDescription",panel,item.Category=="SoundPacks" and "Configured pack audio / 1.6 second sample" or "Actual tetromino rendering. Appearance preview only.",15,C.muted); desc.ZIndex=40; U.rect(desc,{20,62,width-40,34})
	local contentWidth=landscape and math.floor(width*0.5) or width
	if landscape then U.rect(title,{20,14,contentWidth-40,42}); U.rect(desc,{20,62,contentWidth-40,72}); U.rect(close,{20,height-60,contentWidth-40,44}) end
	if item.Category=="SoundPacks" then
		local listen=U.button("PlaySample",panel,"PLAY SOUND SAMPLE",C.cyan,function() self:sampleAudio(item) end); listen.ZIndex=40; U.rect(listen,landscape and {contentWidth+20,72,width-contentWidth-40,56} or {24,132,width-48,56})
	else
		local sample=Preview.new(panel,U); self.Sample=sample
		local bh=landscape and math.min(height-60,(width-contentWidth-48)*1.2) or math.min(360,height-208,(width-48)*1.2); local bw=bh/1.2
		U.rect(sample.Frame,landscape and {contentWidth+(width-contentWidth-bw)/2,20,bw,bh} or {(width-bw)/2,104,bw,bh}); sample:set(item,d.Equipped)
		local caption=U.text("PreviewCaption",panel,U.reducedMotion and "REDUCED MOTION / STILL FRAME" or "COSMETIC SAMPLE",13,C.muted,F.Mono); caption.ZIndex=40; caption.TextXAlignment=Enum.TextXAlignment.Center; U.rect(caption,landscape and {contentWidth+12,28+bh,width-contentWidth-24,24} or {20,112+bh,width-40,24})
	end
	local owned=d.Inventory[item.Category][item.Id] or d.DebugPrivileges and d.DebugPrivileges.FreeCosmetics; local equipped=d.Equipped[Catalog.Slots[item.Category]]==item.Id
	local buy=U.button("DetailBuy",panel,owned and "OWNED" or "PURCHASE",C.orange,function() self.Client:send("Buy",{Category=item.Category,Id=item.Id}) end); buy.ZIndex=40
	local equip=U.button("DetailEquip",panel,equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP",C.line,function() self.Client:send("Equip",{Category=item.Category,Id=equipped and "Default" or item.Id}) end); equip.ZIndex=40
	local bw=(contentWidth-48)/2; local by=height-(landscape and 112 or 60); U.rect(buy,{20,by,bw,44}); U.rect(equip,{28+bw,by,bw,44}); U.enabled(buy,not owned); U.enabled(equip,owned and not (equipped and item.Id=="Default"))
end
function Portal:destroy()
	self:clearPreview(); game:GetService("ContextActionService"):UnbindAction("RetroPortalBack"); self.Overlay:Destroy()
end

return Portal

end)()

local app=(function()
-- Presentation only. GameClient and every server/engine/economy module stay intact.
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
local client,portal,layout,openSettings,applyLayout
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
menuObjects.settings=UI.button("MenuSettings",menu,"SETTINGS",C.line,function() feedback(); openSettings() end)
menuObjects.kicker=UI.text("Edition",menu,"THE BLOCK ARCADE",13,C.orange,F.Mono)
menuObjects.shadow=UI.text("TitleShadow",menu,"TETRIS\nBATTLE",54,C.pink,F.Display)
menuObjects.title=UI.text("Title",menu,"TETRIS\nBATTLE",54,C.text,F.Display)
menuObjects.title.TextStrokeColor3=C.background; menuObjects.title.TextStrokeTransparency=0.1
menuObjects.solo=UI.button("SoloPractice",menu,"SOLO PRACTICE",C.orange,function() feedback(); if client then client:send("Solo") end end)
menuObjects.battle=UI.button("Battle1v1",menu,"RANKED 1v1 BATTLE",C.pink,function() feedback(); if client then client:send("Queue") end end)
menuObjects.solo.FontFace=Font.fromEnum(F.Display); menuObjects.solo.TextSize=15
menuObjects.battle.FontFace=Font.fromEnum(F.Display); menuObjects.battle.TextSize=15
menuObjects.nav=UI.new("Frame","ArcadeNavigation",menu,{BackgroundTransparency=1})
local navButtons={}
local destinations={{"GlobalLeaderboard","GLOBAL TOP 100","Leaderboards","GlobalRating"},{"SeasonalLeaderboard","SEASON TOP 100","Leaderboards","SeasonRating"},{"CosmeticShop","COSMETIC SHOP","Shop"},{"DailyQuests","DAILY QUESTS","Quests"},{"PlayerProfile","PLAYER PROFILE","Profile"},{"MoreArcade","MORE / INVENTORY","Hub"}}
for index,destination in ipairs(destinations) do
	navButtons[index]=UI.button(destination[1],menuObjects.nav,destination[2],C.line,function()
		if not portal then return end; feedback()
		if destination[4] then portal.Leaderboard=destination[4]; portal.BoardData=nil end
		portal:open(destination[3])
	end)
end
menuObjects.status=UI.text("PlayerBalance",menu,"Loading player profile...",15,C.text,F.Mono)
menuObjects.status.Active=true
menuObjects.footer=UI.text("Footer",menu,"FREE PRACTICE. REAL RIVALS.",13,C.muted,F.Mono)
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
local function profileWidget(name)
	local frame=UI.new("Frame",name,gamePage,{BackgroundTransparency=1})
	local avatar=UI.new("ImageLabel","Avatar",frame,{Position=UDim2.fromOffset(0,3),Size=UDim2.fromOffset(28,28),BackgroundTransparency=1})
	local label=UI.text("Username",frame,"",14,C.text,F.Strong); label.Position=UDim2.fromOffset(36,0); label.Size=UDim2.new(1,-36,0,18); label.TextWrapped=false; label.TextTruncate=Enum.TextTruncate.AtEnd
	local rank=UI.text("RankStars",frame,"",13,C.orange,F.Mono); rank.Position=UDim2.fromOffset(36,18); rank.Size=UDim2.new(1,-36,0,18); rank.TextWrapped=false
	return {Frame=frame,Avatar=avatar,Name=label,Rank=rank}
end
local ownProfile,opponentProfile=profileWidget("LocalProfile"),profileWidget("OpponentProfile")
gameObjects.player=ownProfile.Frame; gameObjects.opponentPlayer=opponentProfile.Frame
local function setProfile(widget,data)
	if not data then return end
	widget.Avatar.Image="rbxthumb://type=AvatarHeadShot&id="..data.UserId.."&w=150&h=150"; widget.Name.Text=data.DisplayName or data.Name
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
local ownMeter=UI.new("Frame","LocalGarbageMeter",gamePage,{BackgroundColor3=C.pink,BorderSizePixel=0})
local enemyMeter=UI.new("Frame","OpponentGarbageMeter",gamePage,{BackgroundColor3=C.pink,BorderSizePixel=0})
local controls=UI.new("Frame","ControlTray",gamePage,{BackgroundTransparency=1}); gameObjects.controls=controls
local controlSpecs={{"Left","LEFT"},{"Right","RIGHT"},{"SoftDrop","DOWN"},{"CW","CW"},{"CCW","CCW"},{"Hold","HOLD"},{"HardDrop","DROP"}}
local controlButtons={}
for _,spec in ipairs(controlSpecs) do controlButtons[spec[1]]=UI.button(spec[1],controls,spec[2],spec[1]=="HardDrop" and C.orange or C.line) end
local toast=UI.text("Notification",root,"",16,C.yellow,F.Strong); toast.ZIndex=50; toast.BackgroundColor3=C.panel; toast.BackgroundTransparency=0
toast.AnchorPoint=Vector2.new(0.5,0); toast.Position=UDim2.new(0.5,0,0,58); toast.Size=UDim2.new(1,-32,0,38); toast.Visible=false; toast.TextXAlignment=Enum.TextXAlignment.Center
local function notify(text) toast.Text=tostring(text); toast.Visible=true; notifyUntil=os.clock()+3 end
local overlay=UI.new("TextButton","SettingsOverlay",root,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,BackgroundTransparency=0.1,Text="",Visible=false,ZIndex=20,Selectable=false,AutoButtonColor=false})
local modal=UI.panel("SettingsModal",overlay,C.line); modal.ZIndex=21
UI.focusGroup(modal)
local title=UI.text("SettingsTitle",modal,"SETTINGS",20,C.orange,F.Display); title.ZIndex=22; UI.rect(title,{20,16,260,36})
local note=UI.text("PauseNote",modal,"Solo pauses here. Online battles keep running.",15,C.muted); note.ZIndex=22
local function closeSettings()
	settingsOpen=false; overlay.Visible=false; gui:SetAttribute("SettingsOpen",false)
	if client then if client.Mode=="Solo" then client:send("Pause",false) end; client:block(false) end
	if UIS.GamepadEnabled then GuiService.SelectedObject=currentPage=="Menu" and menuObjects.solo or nil end
end
openSettings=function()
	settingsOpen=true; overlay.Visible=true; gui:SetAttribute("SettingsOpen",true)
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
local modalButtons={soundButton,motionButton,audioButton,resumeButton,restartButton,exitButton}
for _,button in ipairs(modalButtons) do button.ZIndex=22 end
local settingsScroll=UI.new("ScrollingFrame","SettingsOptions",modal,{BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=22,CanvasSize=UDim2.fromOffset(0,0)})
for _,button in ipairs(modalButtons) do button.Parent=settingsScroll end
game:GetService("ContextActionService"):BindActionAtPriority("RetroSettingsClose",function(_,state)
	if settingsOpen and state==Enum.UserInputState.Begin then closeSettings(); return Enum.ContextActionResult.Sink end
	return Enum.ContextActionResult.Pass
end,false,3100,Enum.KeyCode.Escape,Enum.KeyCode.ButtonStart,Enum.KeyCode.ButtonB)
local function meter(node,rectangle,pending)
	local fraction=math.clamp((pending or 0)/20,0,1); node.Visible=fraction>0
	UI.rect(node,{rectangle[1]-6,rectangle[2]+rectangle[4]*(1-fraction),3,rectangle[4]*fraction})
end
applyLayout=function()
	local size=safe.AbsoluteSize; if size.X<1 or size.Y<1 then return end
	local battle=client and (client.Mode=="Ranked" or client.Mode=="Challenge") or false
	layout=Layout.resolve(size.X,size.Y,battle); root.Size=UDim2.fromOffset(layout.width,layout.height); rootScale.Scale=layout.scale
	gui:SetAttribute("LayoutMode",layout.portrait and "Portrait" or layout.compact and "Landscape" or "DesktopTablet")
	for name,rectangle in pairs(layout.menu) do if type(rectangle)=="table" and menuObjects[name] then UI.rect(menuObjects[name],rectangle) end end
	local scrollMenu=layout.portrait and layout.height<700
	menuScroll.Visible=scrollMenu; UI.rect(menuScroll,{0,60,layout.width,layout.height-60}); menuScroll.CanvasSize=UDim2.fromOffset(0,layout.menu.footer[2]+24-60)
	for _,name in ipairs({"kicker","title","shadow","solo","battle","nav","status","footer"}) do menuObjects[name].Parent=scrollMenu and menuScroll or menu end
	if scrollMenu then for _,name in ipairs({"kicker","title","solo","battle","nav","status","footer"}) do local r=layout.menu[name]; UI.rect(menuObjects[name],{r[1],r[2]-60,r[3],r[4]}) end end
	local t=layout.menu.title; UI.rect(menuObjects.shadow,{t[1]+2,t[2]+3-(scrollMenu and 60 or 0),t[3],t[4]}); menuObjects.title.TextSize=layout.menu.titleSize; menuObjects.shadow.TextSize=layout.menu.titleSize
	local nr=layout.menu.nav; local columns=layout.menu.navColumns; local bw=(nr[3]-(columns-1)*8)/columns
	menuObjects.status.TextXAlignment=layout.portrait and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
	menuObjects.status.BackgroundColor3=C.background; menuObjects.status.BackgroundTransparency=not layout.portrait and layout.height<660 and 0.08 or 1
	for index,button in ipairs(navButtons) do UI.rect(button,{(index-1)%columns*(bw+8),math.floor((index-1)/columns)*52,bw,44}) end
	for name,rectangle in pairs(layout.game) do if type(rectangle)=="table" and gameObjects[name] then UI.rect(gameObjects[name],rectangle) end end
	gameObjects.heading.TextSize=layout.compact and 14 or layout.portrait and 15 or 20
	for _,widget in ipairs({ownProfile,opponentProfile}) do
		local narrow=layout.compact or layout.portrait and widget==opponentProfile
		UI.rect(widget.Avatar,{0,3,narrow and 16 or 28,narrow and 16 or 28})
		widget.Name.Position=UDim2.fromOffset(narrow and 22 or 36,0); widget.Name.Size=UDim2.new(1,narrow and -22 or -36,0,18)
		widget.Rank.Position=UDim2.fromOffset(narrow and 0 or 36,18); widget.Rank.Size=UDim2.new(1,narrow and 0 or -36,0,18)
	end
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
	UI.rect(settingsScroll,{20,start,mw-40,short and mh-start-12 or 332}); settingsScroll.CanvasSize=UDim2.fromOffset(0,5*spacing+48)
	for index,button in ipairs(modalButtons) do UI.rect(button,{0,(index-1)*spacing,mw-40,44}) end
	note.Visible=not short; UI.rect(note,{20,414,mw-40,46}); UI.enabled(restartButton,client and client.Mode=="Solo" or false)
	local state=client and client.State; meter(ownMeter,layout.game.board,state and state.Own.pending); meter(enemyMeter,layout.game.opponent,state and state.Opponent and state.Opponent.pending)
	art:layout(layout.width,layout.height,layout.portrait)
	if portal then portal:layout(layout.width,layout.height) end
end
table.insert(connections,safe:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout))
client=GameClient.new({
	Pause=function(force) if not settingsOpen or not force then openSettings() end end,
	Lobby=function() if portal then portal:close(true) end; closeSettings(); page("Menu"); applyLayout() end,
	Message=notify,
	Profile=function(data)
		UI.reducedMotion=data.Settings.ReducedMotion; local a=client.Audio; a:settings(a.Master,a.MusicVolume,a.SFXVolume,not data.Settings.Sound)
		local stars=data.Rank.Tier==7 and (data.Rank.Rating.." RATING") or (data.Rank.Stars.."/"..P.Stars[data.Rank.Tier].." STARS")
		local energy=data.DebugPrivileges and data.DebugPrivileges.InfiniteEnergy and "TEST" or data.Energy.Current.."/"..data.Economy.EnergyCap
		menuObjects.status.Text=P.Ranks[data.Rank.Tier]:upper().." / "..stars.."\nCASH "..data.Cash.."     ENERGY "..energy
		soundButton.Text="SOUND / "..(a.Muted and "OFF" or "ON"); motionButton.Text="REDUCED MOTION / "..(UI.reducedMotion and "ON" or "OFF")
		setProfile(ownProfile,{UserId=player.UserId,DisplayName=player.DisplayName,Rank=P.Ranks[data.Rank.Tier],Stars=data.Rank.Stars})
		if portal then portal:render(true) end
	end,
	Searching=function(data) searchStarted=data.StartedAt; portal:open("Searching") end,
	Found=function(data) portal:close(true); lastCountdown=-1; notify("OPPONENT FOUND / "..data.Profiles[1].DisplayName.." vs "..data.Profiles[2].DisplayName); applyLayout() end,
	State=function(data)
		if currentPage~="Game" then page("Game"); applyLayout() end
		gameObjects.heading.Text=data.Mode=="Solo" and "SOLO PRACTICE" or data.Mode=="Ranked" and "RANKED 1v1" or "FRIEND DUEL"
		local ownLoadout=client.Profile and client.Profile.Equipped; local otherLoadout
		if data.Profiles then for _,profile in ipairs(data.Profiles) do if profile.UserId==player.UserId then setProfile(ownProfile,profile) else setProfile(opponentProfile,profile); otherLoadout=profile.Equipped end end end
		Bricks.draw(ownBoard,data.Own,ownLoadout,UI.reducedMotion,os.clock()); Bricks.draw(enemyBoard,data.Opponent,otherLoadout,UI.reducedMotion,os.clock())
		Bricks.piece(holdPiece,data.Own.hold,ownLoadout,UI.reducedMotion); holdPiece.Frame.Visible=type(data.Own.hold)=="string"; holdEmpty.Visible=not holdPiece.Frame.Visible
		for index,view in ipairs(nextPieces) do Bricks.piece(view,data.Own.next[index],ownLoadout,UI.reducedMotion) end
		score.Text=tostring(data.Own.score); ownDetail.Text="LINES "..data.Own.lines.." / LV "..data.Own.level; incoming.Text="IN "..data.Own.pending.." / KO "..data.Own.stats.KOs
		if layout.compact and layout.game.ownStats[4]<112 then ownDetail.Text="YOU "..data.Own.score.."\nL "..data.Own.lines.." / LV "..data.Own.level.."\nIN "..data.Own.pending.." / KO "..data.Own.stats.KOs end
		for index,value in ipairs({data.Own.score,data.Own.lines,data.Own.level,data.Own.pending.." / "..data.Own.stats.KOs}) do portraitValues[index].Value.Text=tostring(value) end
		if data.Opponent then enemyScore.Text=tostring(data.Opponent.score); enemyDetail.Text=data.Opponent.lines.." LINES"; enemyIncoming.Text="IN "..data.Opponent.pending.."\nKO "..data.Opponent.stats.KOs; compactOpponent.Text="VS "..data.Opponent.score.." / "..data.Opponent.lines.."L\nIN "..data.Opponent.pending.." / KO "..data.Opponent.stats.KOs end
		if data.Opponent and layout.portrait and layout.game.enemyStats[4]<80 then enemyIncoming.Text="IN"..data.Opponent.pending.." KO"..data.Opponent.stats.KOs end
		local seconds=data.Remaining or data.Own.elapsed; gameObjects.timer.Text=string.format("%02d:%02d",math.floor(seconds/60),math.floor(seconds%60)); gameObjects.timer.TextColor3=data.Remaining and data.Remaining<=30 and C.pink or C.yellow
		gameObjects.banner.Text=data.Countdown>0 and "READY / "..data.Countdown or not data.Own.alive and "TOP OUT / RESTART OR EXIT" or data.Own.paused and "PAUSED" or data.Remaining and data.Remaining<=10 and "FINAL "..math.ceil(data.Remaining).." SECONDS" or data.Remaining and data.Remaining<=30 and "30 SECOND WARNING" or data.Mode~="Solo" and "ROUND "..(data.Round or 1) or "PRACTICE / NO ENERGY COST"
		if lastCountdown~=data.Countdown then lastCountdown=data.Countdown; client.Audio:play(data.Countdown>0 and "Countdown" or "MatchStart") end
		meter(ownMeter,layout.game.board,data.Own.pending); meter(enemyMeter,layout.game.opponent,data.Opponent and data.Opponent.pending)
	end,
	Event=function(event)
		if event.name=="HardDrop" then
			local loadout=client.Profile and client.Profile.Equipped; local ghost=ownBoard.State and ownBoard.State.ghost
			Effects.drop(ownBoard.Frame,loadout and loadout.DropEffect or "Default",UI.reducedMotion,ghost and {X=(ghost.x+1)/10,Y=math.clamp((ghost.y+1)/20,0,1)})
		elseif event.name=="Combo" then notify("COMBO x"..event.data.combo)
		elseif event.name=="GarbageSend" then notify("ATTACK +"..event.data.lines)
		elseif event.name=="KO" then notify("TOP OUT")
		elseif event.name=="PerfectClear" or event.name=="BackToBack" or event.name:find("TSpin") then notify(event.name) end
	end,
	Result=function(data) closeSettings(); portal.ResultData=data; portal:open("Result") end,
	Leaderboard=function(data) if portal then portal.BoardData=data; portal:render(true) end end,
	Challenge=function(data) portal.Challenger=data; portal:open("ChallengeInvite") end,
})
portal=PortalUI.new(root,UI,client,function()
	if settingsOpen then client:block(true); if UIS.GamepadEnabled then GuiService.SelectedObject=resumeButton end
	elseif UIS.GamepadEnabled then GuiService.SelectedObject=currentPage=="Menu" and menuObjects.solo or nil end
end)
UI.onHover=function() client.Audio:play("ButtonHover") end
for action,button in pairs(controlButtons) do
	client.Input:button(button,action)
	table.insert(connections,button.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then UI.tween(button,{BackgroundColor3=C.raised},0.08); task.delay(0.15,function() if button.Parent then UI.tween(button,{BackgroundColor3=C.panel},0.12) end end) end
	end))
end
table.insert(connections,RunService.RenderStepped:Connect(function(dt)
	if toast.Visible and os.clock()>notifyUntil then toast.Visible=false end
	if portal.Overlay.Visible then
		if portal.Sample then portal.Sample:tick(dt) end
		if portal.Page=="Searching" and portal.SearchLabel then portal.SearchLabel.Text="SEARCHING"..string.rep(".",math.floor(os.clock()*2)%4).." / "..math.max(0,math.floor(workspace:GetServerTimeNow()-searchStarted)).."s" end
	end
end))
gui.Destroying:Connect(function()
	alive=false; if pageTween then pageTween:Cancel() end
	for _,connection in ipairs(connections) do connection:Disconnect() end
	portal:destroy(); client:destroy(); art:destroy(); backdrop:Destroy(); UI.onHover=nil; game:GetService("ContextActionService"):UnbindAction("RetroSettingsClose")
end)
applyLayout(); task.defer(function() if alive then page("Menu"); applyLayout() end end)
print("[Tetris Battle] Retro synthwave client ready.")

return {gui=gui,menu=menu,portal=portal,root=root,scale=rootScale,safe=safe,layout=applyLayout,own=ownBoard,enemy=enemyBoard,menuObjects=menuObjects,nav=navButtons}
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
assert(#Catalog.list("BrickSkins")==10)
print("PASS all ten tetromino thumbnails match the live brick renderer")
local sample=Preview.new(host,UI); local savedSkin=d.Equipped.BrickSkin; local beforePreview=#requests
sample:set(Catalog.Items["BrickSkins:Galaxy"],d.Equipped)
assert(sample.Loadout.BrickSkin=="Galaxy" and d.Equipped.BrickSkin==savedSkin); assert(#requests==beforePreview)
assert(sample.Frame:GetAttribute("CosmeticSample")); assert(sample.Frame.ZIndex>host.ZIndex)
for _,effect in ipairs(Catalog.list("GhostEffects")) do
	sample:set(effect,d.Equipped); UI.reducedMotion=true; sample:tick(0,true); local ghost=sample.View.Tiles[10][5]; local alpha=ghost.Face.BackgroundTransparency; local border=ghost.Edge.Color
	sample:tick(5,true); assert(ghost.Face.BackgroundTransparency==alpha and ghost.Edge.Color.R==border.R and ghost.Edge.Color.G==border.G and ghost.Edge.Color.B==border.B)
end
UI.reducedMotion=false
print("PASS preview leaves inventory/network untouched and every ghost freezes with Reduced Motion")
local fx=modules.CosmeticRenderer; local activeBefore=fx.Active
sample:set(Catalog.Items["DropEffects:PixelExplosion"],d.Equipped); local initialY=sample.View.State.piece.y; sample:tick(0.4); assert(sample.View.State.piece.y>initialY); sample:tick(0.4); assert(sample.View.State.piece.y==10 and fx.Active>activeBefore)
for index=1,12 do fx.drop(sample.Frame,"Stardust",false) end; assert(fx.Active<=fx.Limit)
for _,entry in ipairs(delayed) do if entry.Seconds==1 then entry.Run() end end; assert(fx.Active==0,"Drop particles did not release their budget")
UI.reducedMotion=true; sample:set(Catalog.Items["DropEffects:PixelExplosion"],d.Equipped); sample:tick(10,true); assert(sample.View.State.piece.y==10 and fx.Active==0)
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
d.Inventory.BrickSkins.NeonClub=true; app.portal:render(true); app.portal.Overlay:FindFirstChild("Equip_NeonClub",true).Activated:fire(); assert(requests[#requests].Kind=="Equip" and requests[#requests].Payload.Id=="NeonClub")
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
