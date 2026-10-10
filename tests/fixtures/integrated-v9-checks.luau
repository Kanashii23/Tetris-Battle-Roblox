; (function()
 local expected={
  ["Brick Default I"]="111655630931989",
  ["Drop Default I Ripple"]="93084817213736",
  ["Drop Default I WhiteBase"]="130189305254529",
  ["Drop Default I Droplet"]="70429896875963",
  ["GhostFx Default GhostFX I"]="108589394144230",
  ["Brick Default O"]="124182951151535",
  ["Drop Default O Ripple"]="83879968656680",
  ["Drop Default O WhiteBase"]="100164564832700",
  ["Drop Default O Droplet"]="123289670328684",
  ["GhostFx Default GhostFX O"]="77401834407538",
  ["Brick Default T"]="71480123597881",
  ["Drop Default T Ripple"]="70981732924597",
  ["Drop Default T WhiteBase"]="107891102818029",
  ["Drop Default T Droplet"]="96927553904848",
  ["GhostFx Default GhostFX T"]="70394363176296",
  ["Brick Default S"]="107895517526585",
  ["Drop Default S Ripple"]="102865343116311",
  ["Drop Default S WhiteBase"]="83202982625055",
  ["Drop Default S Droplet"]="78568698140085",
  ["GhostFx Default GhostFX S"]="95848619853045",
  ["Brick Default Z"]="136066952632782",
  ["Drop Default Z Ripple"]="98199758693521",
  ["Drop Default Z WhiteBase"]="71893445675591",
  ["Drop Default Z Droplet"]="93537861166043",
  ["GhostFx Default GhostFX Z"]="123677630149848",
  ["Brick Default J"]="72068799898867",
  ["Drop Default J Ripple"]="82070174455022",
  ["Drop Default J WhiteBase"]="74083763976940",
  ["Drop Default J Droplet"]="73748581794808",
  ["GhostFx Default GhostFX J"]="113777646122671",
  ["Brick Default L"]="131902230089198",
  ["Drop Default L Ripple"]="132541352013060",
  ["Drop Default L WhiteBase"]="102150407088729",
  ["Drop Default L Droplet"]="82393635192697",
  ["GhostFx Default GhostFX L"]="102678558648579",
 }

 for key,value in pairs(expected) do assert(configuredDefault[key]==value); CosmeticsAssetIds.Default[key]=value end
 local resolver=CosmeticsAssetResolver; local A=modules.CosmeticsAssets
 for _,piece in ipairs({"I","O","T","S","Z","J","L"}) do
  for _,category in ipairs({"Bricks","GhostFX","DropFX"}) do
   for _,component in ipairs(category=="DropFX" and {"WhiteBase","Ripple","Droplet"} or {false}) do
    local _,key=resolver.key(category,"DefaultClassic",piece,component or nil)
    assert(resolver.resolve(category,"Default",piece,component or nil)=="rbxassetid://"..expected[key])
    A.Status["rbxassetid://"..expected[key]]="Ready"
   end
  end
 end
 local host=U.new("Frame","ConfiguredIntegration",app.root); host.AbsoluteSize=Vector2.new(200,400)
 local tile=modules.BrickRenderer.tile(host,"Test",U)
 for _,piece in ipairs({"I","O","T","S","Z","J","L"}) do
  modules.BrickRenderer.paint(tile,piece,"Default","Default",false,false,0)
  assert(tile.Image.Image=="rbxassetid://"..expected["Brick Default "..piece] and tile.Image.Visible and not tile.Face.Visible)
  assert(tile.Image.ImageColor3.R==1 and not tile.Detail.Visible and not tile.Facets[1].Visible)
  modules.BrickRenderer.paint(tile,piece,"Default","Default",true,false,0)
  assert(tile.Image.Image=="rbxassetid://"..expected["GhostFx Default GhostFX "..piece])
  modules.CosmeticRenderer.clear(host)
  assert(modules.CosmeticRenderer.dropEvent(host,"NeonSparks",false,{id=1,name="HardDrop",data={kind=piece,x=4,y=10,rotation=0,DropEffect="Default"}}))
  local burst=modules.CosmeticRenderer.Pools[host][1]
  assert(#burst.Parts==8 and burst.Parts[1].Image.Image=="rbxassetid://"..expected["Drop Default "..piece.." WhiteBase"])
  assert(burst.Parts[2].Image.Image=="rbxassetid://"..expected["Drop Default "..piece.." Ripple"])
  for i=3,8 do assert(burst.Parts[i].Image.Image=="rbxassetid://"..expected["Drop Default "..piece.." Droplet"]) end
 end
 modules.CosmeticRenderer.clear(host,true); host:Destroy()
 local badges={rookie="99619762052996",amateur="73216878404801",expert="88982625989642",master="93070497943983",pro="131295782237157",immortal="117806290369674"}
 UIAssetConfig.OptionalReferenceRanks.Enabled=true
 for key,id in pairs(badges) do assert(modules.UIAssets.rank(key)=="rbxassetid://"..id) end
 assert(modules.UIAssets.rank("Bronze")=="" and modules.UIAssets.rank("Unknown")=="")
 local badge=U.image(app.root,"BadgeTest",""); modules.UIAssets.bindRank(U,badge,"Rookie")
 assert(badge.Image=="rbxassetid://99619762052996" and badge:GetAttribute("RankName")=="Rookie")
 badge.IsLoaded=false; assert(badge.RankFallback.Visible)
 badge.IsLoaded=true; assert(not badge.RankFallback.Visible); badge:Destroy()
 app.portal:close(true)
 for _,mode in ipairs({"Solo","Ranked","Solo"}) do
  Network.OnClientEvent:fire("State",{Mode=mode,Own=E.pack(E.new(42,R)),Opponent=mode=="Ranked" and E.pack(E.new(43,R)) or nil,Countdown=0})
  local elapsed=app.art.Elapsed; local sun=app.art.Sun
  RunService.RenderStepped:fire(0.16)
  assert(app.art.Elapsed>elapsed and app.art.Sun==sun and #sun:GetChildren()==64)
  Network.OnClientEvent:fire("Lobby",{})
  assert(app.art.Elapsed>elapsed)
 end
 app.portal:open("Leaderboards"); local pending=app.portal.BoardPending
 Network.OnClientEvent:fire("Leaderboard",{Kind=pending.Kind,RequestId=pending.RequestId,Rows={},Unavailable=true,RetryAfter=0.6})
 assert(app.portal.BoardPending==pending and pending.Retries==1)
 app.portal.BoardControls.GlobalWins.Activated:fire(); local latest=app.portal.BoardPending
 Network.OnClientEvent:fire("Leaderboard",{Kind=pending.Kind,RequestId=pending.RequestId,Rows={}})
 assert(app.portal.BoardPending==latest and not app.portal.BoardData)
 Network.OnClientEvent:fire("Leaderboard",{Kind=latest.Kind,RequestId=latest.RequestId,Rows={}})
 assert(app.portal.BoardData.Kind=="GlobalWins")
 local cabinetHeight=app.portal.Shell.Size.Y.Offset
 app.portal.BoardControls.GlobalRating.Activated:fire()
 assert(app.portal.Shell.Size.Y.Offset==cabinetHeight)
 local fitRequest=app.portal.BoardPending
 Network.OnClientEvent:fire("Leaderboard",{Kind=fitRequest.Kind,RequestId=fitRequest.RequestId,Rows={}})
 assert(app.portal.Shell.Size.Y.Offset==math.min(app.portal.Height-32,app.portal.BodyTop+math.max(56,app.portal.ContentHeight)+20))
 app.portal:close(true)
 print("PASS all 35 exact IDs, seven neutral brick/ghost variants and eight-part per-color FX; six rank keys/fallbacks; live RenderStepped across Solo/Ranked/lobby; network busy/stale routing")
end)()
