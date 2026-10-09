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
