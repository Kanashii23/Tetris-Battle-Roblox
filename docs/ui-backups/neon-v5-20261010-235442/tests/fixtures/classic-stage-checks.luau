
local Ids=CosmeticsAssetIds; local A=modules.CosmeticsAssets; local FX=modules.CosmeticRenderer; local U=modules.NeonUI
local themes,slots=0,0
for theme,entries in pairs(Ids.Themes) do
 themes+=1; local colors=0
 for _,kind in ipairs({"I","O","T","S","Z","J","L"}) do
  local e=entries[kind]; assert(e and e.Bricks=="" and e.GhostFX==""); colors+=1; slots+=2
  for _,part in ipairs({"WhiteBase","Droplet","Ripple"}) do assert(e.DropFX[part]==""); slots+=1 end
 end
 assert(colors==7 and Ids.Readiness[theme].Supplied==(theme=="DefaultClassic"))
end
assert(themes==12 and slots==420)
assert(Ids.theme("Bricks","Default")=="DefaultClassic" and Ids.uri("bad-id")=="" and Ids.uri("123")=="rbxassetid://123")
local host=U.new("Frame","PoolTest",app.root); host.Size=UDim2.fromOffset(200,400); host.AbsoluteSize=Vector2.new(200,400)
local floor={id=1,name="HardDrop",data={kind="O",x=4,y=19,rotation=0}}
local origin=FX.origin(floor.data); assert(origin.Y==1 and origin.X==0.5)
assert(FX.dropEvent(host,"Default",false,floor)); assert(not FX.dropEvent(host,"Default",false,floor))
local pool=FX.Pools[host]; assert(#pool==1 and #pool[1].Parts==8 and pool[1].Origin.Y==1)
FX.tick(0.12,host,false); local burst=pool[1]; assert(burst.Parts[3].Frame.Position.X.Scale~=burst.Parts[4].Frame.Position.X.Scale)
assert(burst.Parts[2].Frame.Rotation==0 and burst.Parts[2].Frame.Size.Y.Offset<burst.Parts[2].Frame.Size.X.Offset)
FX.tick(1,host,false); assert(not burst.Active)
local elevated={id=2,name="HardDrop",data={kind="I",x=3,y=8,rotation=1}}
assert(FX.dropEvent(host,"Default",false,elevated)); assert(FX.Pools[host][1].Origin.Y<1)
for n=3,50 do FX.dropEvent(host,"Default",false,{id=n,name="HardDrop",data=elevated.data}) end
assert(#FX.Pools[host]<=FX.MaxBursts and FX.Active<=FX.Limit)
FX.tick(0,host,true); assert(not FX.dropEvent(host,"Default",false,{id=50,name="HardDrop",data=elevated.data}),"Suppressed events must not replay"); for _,b in ipairs(FX.Pools[host]) do assert(not b.Active) end
-- Verify pre-clear coordinates from the real engine without changing its rules.
local rules=table.clone(R); local engine=E.new(18,rules)
for y=21,24 do for x=1,10 do engine.board[y][x]=x==5 and 0 or "J" end end
E.spawn(engine,"I"); engine.piece.rotation=1; engine.piece.x=3; E.hardDrop(engine)
local drop; for _,event in ipairs(engine.events) do if event.name=="HardDrop" then drop=event end end
assert(drop and engine.lines==4 and FX.origin(drop.data).Y==1)
local grounded=E.new(20,rules); grounded.piece={kind="O",x=4,y=23,rotation=0}; E.hardDrop(grounded)
local zero; for _,event in ipairs(grounded.events) do if event.name=="HardDrop" then zero=event end end
assert(zero and zero.data.distance==0 and FX.origin(zero.data).Y==1)
assert(not FX.dropEvent(host,"Default",false,{id=51,name="Move",data=elevated.data}))
-- Exercise all seven unique uploaded mappings using mocked delivery only.
for index,kind in ipairs({"I","O","T","S","Z","J","L"}) do
 Ids.Themes.DefaultClassic[kind].Bricks=tostring(1000+index)
 assert(A.get("Bricks","Default",kind)=="rbxassetid://"..(1000+index))
end
local tile=modules.BrickRenderer.tile(host,"ImageTest",U)
modules.BrickRenderer.paint(tile,"I","Default","Default",false,false,0)
assert(tile.Image.Visible and tile.Image.Image=="rbxassetid://1001" and tile.Image.ImageColor3.R==1 and not tile.Face.Visible)
-- Exercise the supplied three-component schema and Ghost lookup with successful mock delivery.
for index,kind in ipairs({"I","O","T","S","Z","J","L"}) do
 Ids.Themes.DefaultClassic[kind].GhostFX=tostring(2000+index)
 local parts=Ids.Themes.DefaultClassic[kind].DropFX
 parts.WhiteBase=tostring(3000+index); parts.Droplet=tostring(4000+index); parts.Ripple=tostring(5000+index)
 assert(A.get("GhostFX","Default",kind)=="rbxassetid://"..(2000+index))
 FX.clear(host); assert(FX.drop(host,"Default",false,{X=0.5,Y=0.5},kind,index))
 local b=FX.Pools[host][1]; assert(b.Parts[1].Image.Rotation==90 and b.Parts[2].Image.Rotation==0)
 assert(b.Parts[1].Frame.Size.X.Offset==b.Parts[1].Frame.Size.Y.Offset)
 for _,part in ipairs(b.Parts) do assert(part.Image.Visible and part.Image.ImageColor3.R==1 and part.Image.ImageColor3.G==1 and part.Image.ImageColor3.B==1) end
 assert(b.Parts[3].Image.Image==b.Parts[8].Image.Image and #b.Parts==8)
end
modules.BrickRenderer.paint(tile,"I","Default","Default",true,false,0)
assert(tile.Image.Image=="rbxassetid://2001" and tile.Frame:GetAttribute("Ghost"))
FX.clear(host)
local oldPreload=services.ContentProvider.PreloadAsync
services.ContentProvider.PreloadAsync=function(_,uris,fn) fn(uris[1],Enum.AssetFetchStatus.Failure) end
Ids.Themes.DefaultClassic.I.Bricks="9001"; tile.Key=nil
modules.BrickRenderer.paint(tile,"I","Default","Default",false,false,0)
assert(tile.Face.Visible and not tile.Image.Visible and A.Status["rbxassetid://9001"]=="Failed")
services.ContentProvider.PreloadAsync=oldPreload
for _,kind in ipairs({"I","O","T","S","Z","J","L"}) do local e=Ids.Themes.DefaultClassic[kind]; e.Bricks=""; e.GhostFX=""; e.DropFX={WhiteBase="",Droplet="",Ripple=""} end
FX.clear(host,true); assert(not FX.Pools[host]); host:Destroy()
-- Icon-only footprints and quest zones at the required device sizes.
assert(app.menuObjects.mail.Text=="" and app.menuObjects.settings.Text=="")
assert(not app.menuObjects.mail:FindFirstChild("IconPadding") and app.menuObjects.mail:FindFirstChild("SymbolFallback"))
for _,size in ipairs({{390,780},{844,326},{768,1024},{1366,768}}) do
 local l=modules.NeonLayout.resolve(size[1],size[2],true)
 assert(l.game.board[3]*2==l.game.board[4] and l.game.opponent[3]*2==l.game.opponent[4])
 assert(l.menu.cash[2]==l.menu.energy[2] and l.menu.mail[2]==l.menu.settings[2])
 app.portal:layout(size[1],size[2]); app.portal:open("Quests")
 local row=app.portal.Scroll:FindFirstChild("Row"); local icon=row.QuestIcon; local title=row.Title; local body=row.Body
 assert(title.Position.X.Offset>=icon.Position.X.Offset+icon.Size.X.Offset)
 assert(body.Position.Y.Offset>=title.Position.Y.Offset+title.Size.Y.Offset)
 assert(row.QuestProgress.Position.Y.Offset>=body.Position.Y.Offset+body.Size.Y.Offset)
 assert(app.portal.QuestReset.Parent==app.portal.Scroll and app.portal.QuestReset.Size.Y.Offset>=32)
 app.portal:close(true)
end
app.portal:layout(320,568); app.portal:open("Quests")
local quest=P.Daily[1]; local previousLabel=quest.Label; quest.Label=string.rep("Long quest description ",8); app.portal:render()
local longRow=app.portal.Scroll:FindFirstChild("Row"); assert(longRow.Title.Size.Y.Offset>32 and longRow.Body.Position.Y.Offset>=longRow.Title.Position.Y.Offset+longRow.Title.Size.Y.Offset)
local action=longRow:FindFirstChildOfClass("TextButton"); assert(action.Position.Y.Offset+action.Size.Y.Offset<=longRow.Size.Y.Offset)
quest.Label=previousLabel; app.portal:close(true)
print("PASS 12 themes/420 slots, seven image mappings, failed-image fallbacks, real pre-clear origin, once-only drops, six droplets, bounded cleanup, icon-only header and quest zones")
