;(function()
 local art=modules.RetroArtwork.new(app.root,U); art:layout(1366,768,false)
 local positions={}; for i,band in ipairs(art.Bands) do positions[i]=band.Position end
 local period=art.Mask.SolidRows+art.Mask.GapRows
 local snapshot={}; for i,band in ipairs(art.Bands) do snapshot[i]=band.BackgroundTransparency end
 for step=1,period*2 do
  art.Elapsed=step*art.Mask.StepSeconds+0.000001; art:paintSun(false)
  for index=1,63 do
   local band=art.Bands[index+1]
   assert(band.BackgroundTransparency==snapshot[index])
   assert(band.Position==positions[index+1] and band.ZIndex==2)
  end
  for i,band in ipairs(art.Bands) do snapshot[i]=band.BackgroundTransparency end
 end
 art:tick(0,true,true); assert(art.SunStep==0)
 local elapsed=art.Elapsed; art:layout(390,780,true); assert(art.Elapsed==elapsed)
 art:tick(0,false,true); assert(art.SunStep==0)
 art:destroy(); art:tick(1,false,true); assert(#art.Bands==0)
 local portal=app.portal; portal:close(true)
 for _,size in ipairs({{1366,768},{390,780},{844,326}}) do
  portal:layout(size[1],size[2]); portal:open("Leaderboards")
  local tabs=portal.BoardControls
  for _,count in ipairs({0,1,3,100}) do
   local rows={}; for i=1,count do rows[i]={Name="Real payload "..i,Position=i,UserId=1000+i,Value=i} end
   portal.BoardData={Kind=portal.Leaderboard,Rows=rows,Notice="Standings"}; portal:drawLeaderboard()
   local expected=math.min(size[2]-32,portal.BodyTop+math.max(56,portal.ContentHeight)+20)
   assert(portal.Shell.Size.Y.Offset==expected and portal.BoardControls==tabs)
   assert(math.abs(portal.Shell.Position.Y.Offset-(size[2]-expected)/2)<0.001)
   if count==100 then assert(portal.ContentHeight>portal.Scroll.Size.Y.Offset) end
  end
  portal:close(true)
 end
 print("PASS complete downward transparency mask, two loops, static geometry/reduced motion/resize/teardown and content-fit 0/1/3/100 entries across desktop/phone/landscape")
end)()
