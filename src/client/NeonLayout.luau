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
