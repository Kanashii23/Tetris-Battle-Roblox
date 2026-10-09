local E=require("../src/shared/TetrisEngine")
local R=require("../src/shared/Config/Rules")
local passed=0
local function test(name,fn) fn(); passed+=1; print("PASS "..name) end
local function fresh() return E.new(42,R) end
test("all seven shapes spawn and rotate in open space",function()
	for _,kind in ipairs({"I","O","T","S","Z","J","L"}) do
		local s=fresh(); E.spawn(s,kind); s.piece.y=10; assert(#E.cells(s.piece)==4 and E.fits(s,s.piece))
		if kind~="O" then for _=1,4 do assert(E.rotate(s,1)) end; assert(s.piece.rotation==0) end
	end
end)
test("seven bag distribution over 140 pieces",function()
	local s=fresh(); local pieces={s.piece.kind}; for _=1,139 do E.spawn(s); table.insert(pieces,s.piece.kind) end
	for start=1,140,7 do local seen={}; for i=start,start+6 do assert(not seen[pieces[i]]); seen[pieces[i]]=true end end
end)
test("walls, floor and occupied cells reject collision",function()
	local s=fresh(); s.piece={kind="O",rotation=0,x=0,y=10}; assert(not E.move(s,-1,0))
	s.piece.y=23; assert(not E.move(s,0,1)); s.board[23][3]="G"; assert(not E.move(s,1,0))
end)
test("I piece wall kick and T floor kick",function()
	local s=fresh(); s.piece={kind="I",rotation=1,x=-1,y=10}; assert(E.rotate(s,-1) and E.fits(s,s.piece))
	s.piece={kind="T",rotation=0,x=4,y=23}; assert(E.rotate(s,1) and E.fits(s,s.piece))
end)
test("CW then CCW restores rotation",function() local s=fresh(); s.piece.y=10; E.spawn(s,"J"); s.piece.y=10; assert(E.rotate(s,1) and E.rotate(s,-1)); assert(s.piece.rotation==0) end)
test("hold restriction and swap after lock",function() local s=fresh(); local kind=s.piece.kind; assert(E.hold(s)); assert(not E.hold(s)); E.hardDrop(s); assert(E.hold(s) and s.piece.kind==kind) end)
test("ghost equals hard drop landing",function()
	local s=fresh(); local g=E.snapshot(s).ghost; E.hardDrop(s)
	for _,p in ipairs(E.cells(g)) do assert(s.board[p[2]+R.Hidden][p[1]]==g.kind) end
end)
local function tetris(s)
	for y=21,24 do for x=1,10 do if x~=5 then s.board[y][x]="G" end end end
	s.piece={kind="I",rotation=1,x=3,y=21}
	return E.lock(s)
end
test("Tetris, perfect clear, combo and back-to-back",function()
	local s=fresh(); assert(tetris(s)==10 and s.lines==4 and s.stats.PerfectClears==1)
	assert(tetris(s)==11 and s.combo==1 and s.stats.Tetrises==2)
end)
test("single double and triple",function()
	for n=1,3 do
		local s=fresh(); for y=25-n,24 do for x=1,10 do if x~=5 then s.board[y][x]="G" end end end
		s.piece={kind="I",rotation=1,x=3,y=21}; E.lock(s); assert(s.lines==n)
	end
end)
test("T spin and mini corner detection",function()
	local s=fresh(); s.piece={kind="T",rotation=0,x=4,y=21}; s.spin=true; s.kick=1
	s.board[21][4]="G"; s.board[21][6]="G"; s.board[23][4]="G"; assert(E.spinType(s)=="Spin")
	s.board[21][6]=0; s.board[23][6]="G"; assert(E.spinType(s)=="Mini")
	s.kick=5; assert(E.spinType(s)=="Spin"); s.spin=false; assert(E.spinType(s)==nil)
end)
test("T-spin triple attack and statistics",function()
	local s=fresh(); s.piece={kind="T",rotation=1,x=4,y=21}; s.spin=true; s.kick=1
	for y=21,24 do for x=1,10 do s.board[y][x]="G" end end
	for _,p in ipairs(E.cells(s.piece)) do s.board[p[2]][p[1]]=0 end
	s.board[24][10]=0
	assert(E.lock(s)==6 and s.lines==3 and s.stats.TSpins==1)
end)
test("garbage cancels attacks, delay and hole",function()
	local s=fresh(); E.addGarbage(s,12); assert(tetris(s)==0 and E.pending(s)==2)
	E.hardDrop(s); assert(E.pending(s)==2)
	s.elapsed=2; E.hardDrop(s); assert(E.pending(s)==0)
	for y=23,24 do local holes=0; for _,v in ipairs(s.board[y]) do if v==0 then holes+=1 end end; assert(holes==1) end
end)
test("garbage RNG does not change bag order",function()
	local a,b=fresh(),fresh(); E.applyGarbage(a,1); for _=1,30 do E.spawn(a); E.spawn(b); assert(a.piece.kind==b.piece.kind) end
end)
test("spawn block and full hidden lock top out",function()
	local s=fresh(); for x=1,10 do s.board[4][x]="G" end; E.spawn(s,"O"); assert(not s.alive)
	s=fresh(); s.piece.y=R.Hidden-1; E.lock(s); assert(not s.alive)
end)
test("lock delay, reset cap and pause",function()
	local s=fresh(); s.piece={kind="O",rotation=0,x=4,y=23}; E.step(s,0.49); assert(s.board[24][5]==0)
	for i=1,20 do s.lockTime=0.3; E.move(s,i%2==0 and -1 or 1,0) end; assert(s.lockResets==15 and s.lockTime==0.3)
	s.paused=true; E.step(s,100); assert(s.elapsed==0.49); s.paused=false; E.step(s,0.21); assert(s.board[24][5]=="O")
end)
test("Down soft drops without rotation, hold repeats and release",function()
	local s=fresh(); local rotation=s.piece.rotation; E.input(s,"SoftDrop",true); E.step(s,0.1); assert(s.piece.rotation==rotation and s.score>0)
	E.input(s,"Left",true); local x=s.piece.x; E.step(s,0.15); assert(s.piece.x==x); E.step(s,0.02); assert(s.piece.x<x)
	E.input(s,"Left",false); x=s.piece.x; E.step(s,0.3); assert(s.piece.x==x)
end)
test("T-spin single and double, mini scoring and no-spin movement",function()
	for rows=1,2 do
		local s=fresh(); s.piece={kind="T",rotation=0,x=4,y=22}; s.spin=true; s.kick=1
		for y=24-rows,23 do for x=1,10 do s.board[y][x]="G" end end
		for _,cell in ipairs(E.cells(s.piece)) do s.board[cell[2]][cell[1]]=0 end
		s.board[22][4]="G"; s.board[22][6]="G"; s.board[24][4]="G"
		local before=s.stats.TSpins; E.lock(s); assert(s.lines==rows and s.stats.TSpins==before+1)
	end
	local s=fresh(); s.piece={kind="T",rotation=0,x=4,y=21}; s.spin=true; s.kick=1
	s.board[21][4]="G"; s.board[23][4]="G"; s.board[23][6]="G"
	E.lock(s); assert(s.score==100 and s.stats.TSpins==1)
end)
test("compact network board round-trip",function()
	local s=fresh(); E.hardDrop(s); local packed=E.pack(s); assert(#packed.grid==200 and packed.board==nil)
	local unpacked=E.unpack(packed); local actual=E.snapshot(s)
	for y=1,20 do for x=1,10 do assert(unpacked.board[y][x]==actual.board[y][x]) end end
end)
test("seeded random inputs preserve valid live pieces and board height",function()
	for seed=1,20 do
		local s=E.new(seed,R); local prng=seed
		for _=1,500 do
			prng=(prng*48271)%2147483647; local action=({"Left","Right","CW","CCW","SoftDrop","HardDrop","Hold"})[prng%7+1]
			E.input(s,action,true); E.step(s,1/60); E.input(s,action,false)
			assert(#s.board==24); if s.alive then assert(E.fits(s,s.piece)) else break end
		end
	end
end)
print(passed.." total engine tests passed")
