-- Physical design pixels: normal device sizes do not shrink readable text.
local Layout={}
function Layout.resolve(width,height,battle)
	local w,h=math.max(320,width),math.max(280,height)
	local compact=h<540 and w>h; local portrait=not compact and w/h<0.9
 local menu={brand={16,12,1,1},status={16,12,1,1}}
 if portrait or compact and w<720 then
  local cw=w-32; menu.header={16,12,cw-100,56}; menu.settings={w-60,12,44,44}; menu.mail={w-112,12,44,44}; menu.cash={16,78,(cw-8)/2,44}; menu.energy={24+(cw-8)/2,78,(cw-8)/2,44}
  menu.kicker={16,142,cw,24}; menu.title={16,176,cw,120}; menu.titleSize=math.min(40,math.floor(cw/8)); menu.solo={16,318,cw,52}; menu.battle={16,382,cw,52}; menu.nav={16,454,cw,280}; menu.navColumns=2; menu.footer={16,750,cw,20}
 elseif compact or h<660 then
  menu.header={16,8,220,56}; menu.settings={w-60,12,44,44}; menu.mail={w-112,12,44,44}; menu.cash={w-420,12,140,44}; menu.energy={w-272,12,152,44}
  menu.kicker={24,76,260,20}; menu.title={24,100,math.max(240,w*0.36),104}; menu.titleSize=30; menu.solo={w*0.47,88,w*0.53-24,48}; menu.battle={w*0.47,148,w*0.53-24,48}; menu.nav={24,h-92,w-48,72}; menu.navColumns=6; menu.footer={0,0,0,0}
 else
  menu.header={24,16,280,64}; menu.settings={w-72,20,48,48}; menu.mail={w-128,20,48,48}; menu.cash={w-492,20,172,48}; menu.energy={w-312,20,176,48}
  local margin=math.max(28,w*0.045); local cw=w-margin*2
  local top=math.max(112,h*0.16); menu.kicker={margin,top-24,cw,20}; menu.title={margin,top,math.min(520,cw*0.55),150}; menu.titleSize=math.clamp(w*0.045,38,60)
  local by=math.min(h-190,math.max(top+170,h*0.48)); menu.solo={margin,by,(cw-16)/2,56}; menu.battle={margin+(cw+16)/2,by,(cw-16)/2,56}; menu.nav={margin,by+76,cw,88}; menu.navColumns=6; menu.footer={margin,h-30,cw,20}
 end
 -- One shared top-bar calculation: centered contents, reserved utility footprints.
 local margin=w<960 and 16 or 24; local gap=8; local icon=44; local y=16
 if portrait or w<720 then
  menu.header={margin,y,w-2*margin-2*icon-2*gap,56}
  menu.mail={w-margin-2*icon-gap,y+6,icon,icon}; menu.settings={w-margin-icon,y+6,icon,icon}
  local cw=(w-2*margin-gap)/2; menu.cash={margin,y+64,cw,44}; menu.energy={margin+cw+gap,y+64,cw,44}
 else
  local header=math.clamp(w*0.23,180,280); local cw=math.min(176,(w-2*margin-header-2*icon-5*gap)/2)
  menu.header={margin,y,header,56}; menu.settings={w-margin-icon,y+6,icon,icon}; menu.mail={w-margin-2*icon-gap,y+6,icon,icon}
  menu.energy={menu.mail[1]-gap-cw,y+6,cw,44}; menu.cash={menu.energy[1]-gap-cw,y+6,cw,44}
 end
	local game={back={16,12,96,44},heading={128,12,w-256,44},settings={w-60,12,44,44}}
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
