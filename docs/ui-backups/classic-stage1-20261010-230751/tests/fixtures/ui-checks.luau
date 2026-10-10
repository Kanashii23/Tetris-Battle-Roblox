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
assert(#Catalog.list("BrickSkins")==12)
print("PASS all twelve tetromino thumbnails match the live brick renderer")
local sample=Preview.new(host,UI); local savedSkin=d.Equipped.BrickSkin; local beforePreview=#requests
sample:set(Catalog.Items["BrickSkins:Galaxy"],d.Equipped)
assert(sample.Loadout.BrickSkin=="Galaxy" and d.Equipped.BrickSkin==savedSkin); assert(#requests==beforePreview)
assert(sample.Frame:GetAttribute("CosmeticSample")); assert(sample.Frame.ZIndex>host.ZIndex)
for _,effect in ipairs(Catalog.list("GhostEffects")) do
	sample:set(effect,d.Equipped); UI.reducedMotion=true; sample:tick(0,true); local point=E.cells(sample.View.State.ghost)[1]; local ghost=sample.View.Tiles[point[2]][point[1]]; local alpha=ghost.Face.BackgroundTransparency; local border=ghost.Edge.Color
	sample:tick(5,true); assert(ghost.Face.BackgroundTransparency==alpha and ghost.Edge.Color.R==border.R and ghost.Edge.Color.G==border.G and ghost.Edge.Color.B==border.B)
end
UI.reducedMotion=false
print("PASS preview leaves inventory/network untouched and every ghost freezes with Reduced Motion")
local fx=modules.CosmeticRenderer; local activeBefore=fx.Active
sample:set(Catalog.Items["DropEffects:PixelExplosion"],d.Equipped); local initialY=sample.View.State.piece.y; for _=1,8 do sample:tick(0.05) end; assert(sample.View.State.piece.y>initialY); for _=1,30 do sample:tick(0.05) end; assert(sample.Landed and fx.Active>activeBefore)
for index=1,12 do fx.drop(sample.Frame,"Stardust",false) end; assert(fx.Active<=fx.Limit)
for _,entry in ipairs(delayed) do if entry.Seconds==1 then entry.Run() end end; assert(fx.Active==0,"Drop particles did not release their budget")
UI.reducedMotion=true; sample:set(Catalog.Items["DropEffects:PixelExplosion"],d.Equipped); local frozenY=sample.View.State.piece.y; sample:tick(10,true); assert(sample.View.State.piece.y==frozenY and fx.Active==0)
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
d.Inventory.BrickSkins.NeonClub=true; Network.OnClientEvent:fire("Profile",d); app.portal.Overlay:FindFirstChild("Equip_NeonClub",true).Activated:fire(); assert(requests[#requests].Kind=="Equip" and requests[#requests].Payload.Id=="NeonClub")
Network.OnClientEvent:fire("CosmeticResult",{Action="Equip",Category="BrickSkins",Id="NeonClub",Success=true})
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
