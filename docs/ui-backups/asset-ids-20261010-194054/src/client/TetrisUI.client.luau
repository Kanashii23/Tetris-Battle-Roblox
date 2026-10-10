-- Responsive presentation; gameplay and progression remain server-authoritative.
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
local ArcadeFeedback=require(script.Parent:WaitForChild("ArcadeFeedback"))
local BattleEffects=require(Shared:WaitForChild("Config"):WaitForChild("BattleEffectsConfig"))
local Assets=require(script.Parent:WaitForChild("UIAssets"))
local RankIcons=require(Shared:WaitForChild("Config"):WaitForChild("RankIconConfig"))
local Rules=require(Shared:WaitForChild("Config"):WaitForChild("Rules"))
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
local client,portal,layout,openSettings,applyLayout,arcade,notify
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
menuObjects.settings=UI.button("MenuSettings",menu,"SET",C.line,function() feedback(); openSettings() end)
menuObjects.kicker=UI.text("Edition",menu,"THE BLOCK ARCADE",13,C.orange,F.Mono)
menuObjects.shadow=UI.text("TitleShadow",menu,"TETRIS\nBATTLE",54,C.pink,F.Display)
menuObjects.title=UI.text("Title",menu,"TETRIS\nBATTLE",54,C.text,F.Display)
menuObjects.title.TextStrokeColor3=C.background; menuObjects.title.TextStrokeTransparency=0.1
menuObjects.solo=UI.button("SoloPractice",menu,"SOLO PRACTICE",C.orange,function() feedback(); if client then client:send("Solo") end end)
menuObjects.battle=UI.button("Battle1v1",menu,"RANKED 1v1 BATTLE",C.pink,function() feedback(); if client then client:send("Queue") end end)
menuObjects.solo.FontFace=UI.theme.Face; menuObjects.solo.TextSize=15
menuObjects.battle.FontFace=UI.theme.Face; menuObjects.battle.TextSize=15
menuObjects.nav=UI.new("Frame","ArcadeNavigation",menu,{BackgroundTransparency=1})
local navButtons={}
local destinations={{"CosmeticShop","SHOP","Shop",nil,"shop"},{"CosmeticInventory","INVENTORY","Inventory",nil,"inventory"},{"DailyQuests","QUESTS","Quests",nil,"quests"},{"GlobalLeaderboard","LEADERBOARDS","Leaderboards","GlobalRating","leaderboards"},{"ArcadeFriends","FRIENDS","Friends",nil,"friends"},{"MoreArcade","MORE","Hub",nil,"more"}}
for index,destination in ipairs(destinations) do
	navButtons[index]=UI.button(destination[1],menuObjects.nav,destination[2],C.line,function()
		if not portal then return end; feedback()
		if destination[4] then portal.Leaderboard=destination[4]; portal.BoardData=nil end
		portal:open(destination[3])
	end)
 local icon=UI.icon(navButtons[index],"Images.menu."..destination[5]); icon.Position=UDim2.new(0.5,-18,0,6); icon.Size=UDim2.fromOffset(36,36); navButtons[index].TextSize=12; if icon.Visible then navButtons[index].TextYAlignment=Enum.TextYAlignment.Bottom; navButtons[index].IconPadding.PaddingLeft=UDim.new(0,4); navButtons[index].IconPadding.PaddingBottom=UDim.new(0,6) end
end
menuObjects.status=UI.text("PlayerBalance",menu,"Loading player profile...",15,C.text,F.Mono)
menuObjects.status.Active=true
menuObjects.header=UI.panel("LobbyHeader",menu,C.line)
menuObjects.avatar=UI.new("ImageLabel","PlayerAvatar",menuObjects.header,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(40,40),BackgroundTransparency=1,Image="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=150&h=150"})
menuObjects.username=UI.text("LobbyUsername",menuObjects.header,player.DisplayName,12,C.text,F.Strong); menuObjects.username.Position=UDim2.fromOffset(58,8); menuObjects.username.Size=UDim2.new(1,-62,0,22); menuObjects.username.TextTruncate=Enum.TextTruncate.AtEnd
menuObjects.rank=UI.text("LobbyRank",menuObjects.header,"LOADING",10,C.orange,F.Mono); menuObjects.rank.Position=UDim2.fromOffset(58,32); menuObjects.rank.Size=UDim2.new(1,-96,0,20)
menuObjects.rankAsset=UI.image(menuObjects.header,"LobbyRankBadge",""); menuObjects.rankAsset.Position=UDim2.new(1,-38,0,28); menuObjects.rankAsset.Size=UDim2.fromOffset(28,28)
menuObjects.cash=UI.button("LobbyCash",menu,"CASH / +",C.yellow,function() if portal then portal:open("Cash") end end); UI.icon(menuObjects.cash,"Images.currency.cash")
menuObjects.energy=UI.button("LobbyEnergy",menu,"ENERGY / +",C.cyan,function() if portal then portal:open("Energy") end end); UI.icon(menuObjects.energy,"Images.currency.energy")
menuObjects.mail=UI.button("LobbyMail",menu,"MAIL",C.line,function() if portal then portal:open("Quests") end end); UI.icon(menuObjects.mail,"Images.menu.mail"); menuObjects.mail.Text=""; local mailFallback=UI.text("IconFallback",menuObjects.mail,"MAIL",10,C.text,F.Strong); mailFallback.Size=UDim2.fromScale(1,1); mailFallback.TextXAlignment=Enum.TextXAlignment.Center; mailFallback.ZIndex=menuObjects.mail.ZIndex+1; menuObjects.mail.AssetIcon:GetPropertyChangedSignal("IsLoaded"):Connect(function() mailFallback.Visible=not menuObjects.mail.AssetIcon.IsLoaded end); mailFallback.Visible=not menuObjects.mail.AssetIcon.IsLoaded
UI.icon(menuObjects.settings,"Images.menu.settings"); menuObjects.settings.Text=""; local settingsFallback=UI.text("IconFallback",menuObjects.settings,"SET",10,C.text,F.Strong); settingsFallback.Size=UDim2.fromScale(1,1); settingsFallback.TextXAlignment=Enum.TextXAlignment.Center; settingsFallback.ZIndex=menuObjects.settings.ZIndex+1; menuObjects.settings.AssetIcon:GetPropertyChangedSignal("IsLoaded"):Connect(function() settingsFallback.Visible=not menuObjects.settings.AssetIcon.IsLoaded end); settingsFallback.Visible=not menuObjects.settings.AssetIcon.IsLoaded
menuObjects.footer=UI.text("Footer",menu,"FREE PRACTICE. REAL RIVALS.",13,C.muted,F.Mono)
menuObjects.brand.Visible=false; menuObjects.status.Visible=false
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
local boardArt={UI.image(gamePage,"PinkBoardFrame",Assets.uri("Images.artwork.board_frame_pink")),UI.image(gamePage,"CyanBoardFrame",Assets.uri("Images.artwork.board_frame_cyan"))}; for _,image in ipairs(boardArt) do image.ZIndex=11 end
local function profileWidget(name)
	local frame=UI.new("Frame",name,gamePage,{BackgroundColor3=C.panel,BackgroundTransparency=0.12,BorderSizePixel=0}); UI.stroke(frame,name=="LocalProfile" and C.pink or C.cyan,0.15,2)
	local avatar=UI.new("ImageLabel","Avatar",frame,{Position=UDim2.fromOffset(0,3),Size=UDim2.fromOffset(28,28),BackgroundTransparency=1})
	local label=UI.text("Username",frame,"",14,C.text,F.Strong); label.Position=UDim2.fromOffset(36,0); label.Size=UDim2.new(1,-36,0,18); label.TextWrapped=false; label.TextTruncate=Enum.TextTruncate.AtEnd
	local rank=UI.text("RankStars",frame,"",13,C.orange,F.Mono); rank.Position=UDim2.fromOffset(36,18); rank.Size=UDim2.new(1,-36,0,18); rank.TextWrapped=false
	local badge=UI.text("RankBadge",frame,"",15,C.orange,F.Display); badge.Position=UDim2.new(1,-28,0,0); badge.Size=UDim2.fromOffset(28,32)
	local icon=UI.new("ImageLabel","RankIcon",badge,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false})
	local bar=UI.new("Frame","RankStarsBar",frame,{Position=UDim2.new(0,36,1,0),Size=UDim2.new(1,-36,0,3),BackgroundColor3=C.line,BorderSizePixel=0}); local fill=UI.new("Frame","Fill",bar,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.orange,BorderSizePixel=0})
	return {Frame=frame,Avatar=avatar,Name=label,Rank=rank,Badge=badge,Icon=icon,Fill=fill}
end
local ownProfile,opponentProfile=profileWidget("LocalProfile"),profileWidget("OpponentProfile")
for _,widget in ipairs({ownProfile,opponentProfile}) do
 widget.Strip=UI.panel("RankStarStrip",gamePage,C.line); widget.Star=UI.image(widget.Strip,"RankStar",Assets.uri("Images.battle.star_empty")); widget.Star.Position=UDim2.fromOffset(4,2); widget.Star.Size=UDim2.fromOffset(24,24)
 widget.StarText=UI.text("StarCount",widget.Strip,"",10,C.yellow,F.Mono); widget.StarText.Position=UDim2.fromOffset(32,2); widget.StarText.Size=UDim2.new(1,-36,0,24)
end
gameObjects.player=ownProfile.Frame; gameObjects.opponentPlayer=opponentProfile.Frame
local function setProfile(widget,data)
	if not data then return end
	widget.Avatar.Image="rbxthumb://type=AvatarHeadShot&id="..data.UserId.."&w=150&h=150"; widget.Name.Text=data.DisplayName or data.Name
	local tier=data.Tier or 1; if not data.Tier then for i,name in ipairs(P.Ranks) do if name==data.Rank then tier=i end end end
	widget.Badge.Text=RankIcons.Fallback[P.Ranks[tier]]; widget.Fill.Size=UDim2.fromScale(P.Stars[tier]>0 and (data.Stars or 0)/P.Stars[tier] or 1,1)
	local asset=Assets.rank(P.Ranks[tier]); widget.Icon.Image=asset; widget.Icon.Visible=asset~=""; if asset~="" then widget.Badge.Text="" end
	widget.Badge.Visible=widget.Frame.AbsoluteSize.X>=180; local reserve=widget.Badge.Visible and 68 or 36; widget.Name.Size=UDim2.new(1,-reserve,0,18); widget.Rank.Size=UDim2.new(1,-reserve,0,18)
	widget.Star.Image=Assets.uri("Images.battle."..((data.Stars or 0)>0 and "star_filled" or "star_empty")); widget.Star.Visible=widget.Star.Image~=""; widget.StarText.Text=(data.Stars or 0).." / "..P.Stars[tier].." STARS"
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
local enemyHoldPanel=UI.panel("OpponentHoldPanel",gamePage,C.cyan); gameObjects.enemyHold=enemyHoldPanel
local enemyHoldLabel=UI.text("Title",enemyHoldPanel,"HOLD",13,C.cyan,F.Mono); UI.rect(enemyHoldLabel,{8,4,80,22}); local enemyHoldPiece=Bricks.board(enemyHoldPanel,"OpponentHoldPiece",4,2,UI)
local enemyNextPanel=UI.panel("OpponentNextPanel",gamePage,C.cyan); gameObjects.enemyNext=enemyNextPanel
local enemyNextLabel=UI.text("Title",enemyNextPanel,"NEXT",13,C.cyan,F.Mono); UI.rect(enemyNextLabel,{8,4,80,22}); local enemyNextPieces={}; for i=1,5 do enemyNextPieces[i]=Bricks.board(enemyNextPanel,"OpponentNext"..i,4,2,UI) end
ownBoard.Frame:FindFirstChildOfClass("UIStroke").Color=C.pink; ownBoard.Frame:FindFirstChildOfClass("UIStroke").Thickness=3
enemyBoard.Frame:FindFirstChildOfClass("UIStroke").Color=C.cyan; enemyBoard.Frame:FindFirstChildOfClass("UIStroke").Thickness=3
local ownMeter=UI.new("Frame","LocalGarbageMeter",gamePage,{BackgroundColor3=C.pink,BorderSizePixel=0})
local enemyMeter=UI.new("Frame","OpponentGarbageMeter",gamePage,{BackgroundColor3=C.pink,BorderSizePixel=0})
local emoteButton=UI.button("Emotes",gamePage,"EMOTE",C.line,function() if portal then portal:open("Emotes") end end)
local chatButton=UI.button("NativeChat",gamePage,"CHAT",C.line,function()
	local ok=pcall(function() local bar=game:GetService("TextChatService").ChatInputBarConfiguration; assert(bar.Enabled and bar.TextBox); bar.TextBox:CaptureFocus() end)
	if not ok then notify("Use Roblox's native chat button. Chat availability follows your account permissions.") end
end)
local controls=UI.new("Frame","ControlTray",gamePage,{BackgroundTransparency=1}); gameObjects.controls=controls
local controlSpecs={{"Left","LEFT"},{"Right","RIGHT"},{"SoftDrop","DOWN"},{"CW","CW"},{"CCW","CCW"},{"Hold","HOLD"},{"HardDrop","DROP"}}
local controlButtons={}
for _,spec in ipairs(controlSpecs) do controlButtons[spec[1]]=UI.button(spec[1],controls,spec[2],spec[1]=="HardDrop" and C.orange or C.line) end
local toast=UI.text("Notification",root,"",16,C.yellow,F.Strong); toast.ZIndex=50; toast.BackgroundColor3=C.panel; toast.BackgroundTransparency=0
toast.AnchorPoint=Vector2.new(0.5,0); toast.Position=UDim2.new(0.5,0,0,58); toast.Size=UDim2.new(1,-32,0,38); toast.Visible=false; toast.TextXAlignment=Enum.TextXAlignment.Center
notify=function(text) toast.Text=tostring(text); toast.Visible=true; notifyUntil=os.clock()+3 end
local overlay=UI.new("TextButton","SettingsOverlay",root,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,BackgroundTransparency=0.1,Text="",Visible=false,ZIndex=20,Selectable=false,AutoButtonColor=false})
local modal=UI.panel("SettingsModal",overlay,C.line); modal.ZIndex=21
UI.focusGroup(modal)
local title=UI.text("SettingsTitle",modal,"SETTINGS",20,C.orange,F.Display); title.ZIndex=22; UI.rect(title,{20,16,260,36})
local note=UI.text("PauseNote",modal,"Solo pauses here. Online battles keep running.",15,C.muted); note.ZIndex=22
local function closeSettings()
	settingsOpen=false; overlay.Visible=false; UI.ActiveModal=portal and portal.Overlay.Visible and portal.Overlay or nil; gui:SetAttribute("SettingsOpen",false)
	if client then if client.Mode=="Solo" then client:send("Pause",false) end; client:block(false) end
	if UIS.GamepadEnabled then GuiService.SelectedObject=currentPage=="Menu" and menuObjects.solo or nil end
end
openSettings=function()
	settingsOpen=true; overlay.Visible=true; UI.ActiveModal=overlay; gui:SetAttribute("SettingsOpen",true)
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
local preferencesButton=UI.button("ControlPreferences",modal,"CONTROLS / CLASSIC HUD",C.line,function() if portal then portal:open("Controls") end end)
local socialButton=UI.button("BattleSocial",modal,"EMOTES / NATIVE CHAT",C.line,function() if portal then portal:open("Emotes") end end)
local modalButtons={soundButton,motionButton,audioButton,resumeButton,restartButton,exitButton,preferencesButton,socialButton}
for _,button in ipairs(modalButtons) do button.ZIndex=22 end
local settingsScroll=UI.new("ScrollingFrame","SettingsOptions",modal,{BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=22,CanvasSize=UDim2.fromOffset(0,0)})
for _,button in ipairs(modalButtons) do button.Parent=settingsScroll end
game:GetService("ContextActionService"):BindActionAtPriority("RetroSettingsClose",function(_,state)
	if settingsOpen and state==Enum.UserInputState.Begin then closeSettings(); return Enum.ContextActionResult.Sink end
	return Enum.ContextActionResult.Pass
end,false,3100,Enum.KeyCode.Escape,Enum.KeyCode.ButtonStart,Enum.KeyCode.ButtonB)
local function meter(node,rectangle,pending)
	local fraction=math.clamp((pending or 0)/BattleEffects.Garbage.MeterMax,0,1); node.Visible=fraction>0
	local danger=1; for i,threshold in ipairs(BattleEffects.Garbage.Thresholds) do if (pending or 0)>=threshold then danger=i end end
	node:SetAttribute("PendingLines",pending or 0); node:SetAttribute("Danger",danger); node.BackgroundColor3=Color3.fromRGB(table.unpack(BattleEffects.Garbage.Colors[danger]))
	node.BackgroundTransparency=danger==4 and not UI.reducedMotion and (math.sin(os.clock()*math.pi*2*BattleEffects.Garbage.FlashHz)+1)*0.22 or 0
	UI.rect(node,{rectangle[1]-8,rectangle[2]+rectangle[4]*(1-fraction),BattleEffects.Garbage.Width,rectangle[4]*fraction})
end
applyLayout=function()
	local size=safe.AbsoluteSize; if size.X<1 or size.Y<1 then return end
	local battle=client and (client.Mode=="Ranked" or client.Mode=="Challenge") or false
	layout=Layout.resolve(size.X,size.Y,battle); root.Size=UDim2.fromOffset(layout.width,layout.height); rootScale.Scale=layout.scale*((not UIS.TouchEnabled and layout.width>=1100 and client and client.Profile and client.Profile.Settings.UIScale) or 1)
	gui:SetAttribute("LayoutMode",layout.portrait and "Portrait" or layout.compact and "Landscape" or "DesktopTablet")
	for name,rectangle in pairs(layout.menu) do if type(rectangle)=="table" and menuObjects[name] then UI.rect(menuObjects[name],rectangle) end end
	local scrollMenu=layout.portrait and layout.height<760 or layout.compact and layout.width<720
	menuScroll.Visible=scrollMenu; UI.rect(menuScroll,{0,130,layout.width,layout.height-130}); menuScroll.CanvasSize=UDim2.fromOffset(0,layout.menu.footer[2]+24-130)
	for _,name in ipairs({"kicker","title","shadow","solo","battle","nav","status","footer"}) do menuObjects[name].Parent=scrollMenu and menuScroll or menu end
	if scrollMenu then for _,name in ipairs({"kicker","title","solo","battle","nav","status","footer"}) do local r=layout.menu[name]; UI.rect(menuObjects[name],{r[1],r[2]-130,r[3],r[4]}) end end
	local t=layout.menu.title; UI.rect(menuObjects.shadow,{t[1]+2,t[2]+3-(scrollMenu and 130 or 0),t[3],t[4]}); menuObjects.title.TextSize=layout.menu.titleSize; menuObjects.shadow.TextSize=layout.menu.titleSize
	local nr=layout.menu.nav; local columns=layout.menu.navColumns; local bw=(nr[3]-(columns-1)*8)/columns
	menuObjects.status.TextXAlignment=layout.portrait and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
	menuObjects.status.BackgroundColor3=C.background; menuObjects.status.BackgroundTransparency=not layout.portrait and layout.height<660 and 0.08 or 1
	for index,button in ipairs(navButtons) do UI.rect(button,{(index-1)%columns*(bw+8),math.floor((index-1)/columns)*80,bw,72}) end
	for name,rectangle in pairs(layout.game) do if type(rectangle)=="table" and gameObjects[name] then UI.rect(gameObjects[name],rectangle) end end
	gameObjects.heading.TextSize=layout.compact and 14 or layout.portrait and 15 or 20
	for _,widget in ipairs({ownProfile,opponentProfile}) do
		local narrow=layout.compact or layout.portrait and widget==opponentProfile
		UI.rect(widget.Avatar,{0,3,narrow and 16 or 28,narrow and 16 or 28})
		widget.Name.Position=UDim2.fromOffset(narrow and 22 or 36,0); widget.Name.Size=UDim2.new(1,narrow and -22 or -36,0,18)
		widget.Rank.Position=UDim2.fromOffset(narrow and 0 or 36,18); widget.Rank.Size=UDim2.new(1,narrow and 0 or -36,0,18)
	end
	for i,image in ipairs(boardArt) do local r=i==1 and layout.game.board or layout.game.opponent; UI.rect(image,{r[1]-6,r[2]-6,r[3]+12,r[4]+12}); image.Visible=image.Image~="" and (i==1 or battle) end
 if arcade then arcade:layout(layout) end
	UI.rect(emoteButton,{layout.width-180,layout.height-112,76,44}); UI.rect(chatButton,{layout.width-96,layout.height-112,76,44}); emoteButton.Visible=battle and not layout.portrait and not layout.compact; chatButton.Visible=emoteButton.Visible
	gameObjects.timer.TextSize=not layout.compact and not layout.portrait and 40 or 22
	local extra=battle and not layout.portrait and (not layout.compact or layout.width>=760); enemyHoldPanel.Visible=extra; enemyNextPanel.Visible=extra
	if extra then local eh=layout.game.enemyHold; UI.rect(enemyHoldPiece.Frame,{10,30,eh[3]-20,(eh[3]-20)/2}); local en=layout.game.enemyNext; local slot=(en[4]-30)/5; for i,v in ipairs(enemyNextPieces) do local pw=math.min(en[3]-20,(slot-4)*2); UI.rect(v.Frame,{(en[3]-pw)/2,28+(i-1)*slot,pw,pw/2}) end end
	for i,widget in ipairs({ownProfile,opponentProfile}) do widget.Badge.Visible=widget.Frame.Size.X.Offset>=180; local r=i==1 and layout.game.board or layout.game.opponent; UI.rect(widget.Strip,{r[1],r[2]+r[4]+8,r[3],28}); widget.Strip.Visible=battle and not layout.portrait and not layout.compact end
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
	UI.rect(settingsScroll,{20,start,mw-40,short and mh-start-12 or 332}); settingsScroll.CanvasSize=UDim2.fromOffset(0,(#modalButtons-1)*spacing+48)
	for index,button in ipairs(modalButtons) do UI.rect(button,{0,(index-1)*spacing,mw-40,44}) end
	note.Visible=not short; UI.rect(note,{20,414,mw-40,46}); UI.enabled(restartButton,client and client.Mode=="Solo" or false)
	if not gameObjects.timer:FindFirstChild("AssetIcon") then UI.icon(gameObjects.timer,"Images.quests.play_time") end
 local state=client and client.State; meter(ownMeter,layout.game.board,state and state.Own.pending); meter(enemyMeter,layout.game.opponent,state and state.Opponent and state.Opponent.pending)
	art.Battle=battle; art.Classic=client and client.Profile and client.Profile.Settings.ClassicHUD; art:quiet(currentPage=="Game" or art.Classic); art:layout(layout.width,layout.height,layout.portrait)
	if portal then portal:layout(layout.width,layout.height) end
end
table.insert(connections,safe:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout))
client=GameClient.new({
	Pause=function(force) if not settingsOpen or not force then openSettings() end end,
	Lobby=function() if arcade then arcade:reset(nil) end; if portal then portal:close(true) end; closeSettings(); page("Menu"); applyLayout() end,
	Message=notify,
	Profile=function(data)
		UI.reducedMotion=data.Settings.ReducedMotion; local a=client.Audio; a:settings(data.Settings.Master or a.Master,data.Settings.MusicVolume or a.MusicVolume,data.Settings.SFXVolume or a.SFXVolume,not data.Settings.Sound); client.Input:preferences(data.Settings); art:quiet(data.Settings.ClassicHUD or currentPage=="Game")
		if client.SettingsScale~=data.Settings.UIScale then client.SettingsScale=data.Settings.UIScale; applyLayout() end
		local stars=data.Rank.Tier==7 and (data.Rank.Rating.." RATING") or (data.Rank.Stars.."/"..P.Stars[data.Rank.Tier].." STARS")
		menuObjects.rank.Text=P.Ranks[data.Rank.Tier].." / "..data.Rank.Stars.."*"; menuObjects.rankAsset.Image=Assets.rank(P.Ranks[data.Rank.Tier]); menuObjects.rankAsset.Visible=menuObjects.rankAsset.Image~=""; menuObjects.cash.Text=tostring(data.Cash).." +"
  local energy=data.DebugPrivileges and data.DebugPrivileges.InfiniteEnergy and "TEST" or data.Energy.Current.."/"..data.Economy.EnergyCap
		menuObjects.energy.Text=energy.." +"
  menuObjects.status.Text=P.Ranks[data.Rank.Tier]:upper().." / "..stars.."\nCASH "..data.Cash.."     ENERGY "..energy
		soundButton.Text="SOUND / "..(a.Muted and "OFF" or "ON"); motionButton.Text="REDUCED MOTION / "..(UI.reducedMotion and "ON" or "OFF")
		setProfile(ownProfile,{UserId=player.UserId,DisplayName=player.DisplayName,Rank=P.Ranks[data.Rank.Tier],Tier=data.Rank.Tier,Stars=data.Rank.Stars})
		if portal then portal:render(true) end
	end,
	Searching=function(data) searchStarted=data.StartedAt; portal:open("Searching") end,
	Found=function(data) if arcade then arcade:reset(data.MatchId) end; client.LastBattleEvent=0; portal:close(true); lastCountdown=-1; notify("OPPONENT FOUND / "..data.Profiles[1].DisplayName.." vs "..data.Profiles[2].DisplayName); applyLayout() end,
	State=function(data)
		arcade:state(data)
		if currentPage~="Game" then page("Game"); applyLayout() end
		gameObjects.heading.Text=data.Mode=="Solo" and "SOLO PRACTICE" or data.Mode=="Ranked" and "RANKED 1v1" or "FRIEND DUEL"
		local ownLoadout=client.Profile and client.Profile.Equipped; local otherLoadout
		if data.Profiles then for _,profile in ipairs(data.Profiles) do if profile.UserId==player.UserId then setProfile(ownProfile,profile) else setProfile(opponentProfile,profile); otherLoadout=profile.Equipped end end end
		Bricks.draw(ownBoard,data.Own,ownLoadout,UI.reducedMotion,os.clock()); Bricks.draw(enemyBoard,data.Opponent,otherLoadout,UI.reducedMotion,os.clock())
		Bricks.piece(holdPiece,data.Own.hold,ownLoadout,UI.reducedMotion); holdPiece.Frame.Visible=type(data.Own.hold)=="string"; holdEmpty.Visible=not holdPiece.Frame.Visible
		for index,view in ipairs(nextPieces) do Bricks.piece(view,data.Own.next[index],ownLoadout,UI.reducedMotion) end
		score.Text=tostring(data.Own.score); ownDetail.Text="LINES "..data.Own.lines.." / LV "..data.Own.level; incoming.Text="SENT "..data.Own.stats.Sent.." / IN "..data.Own.pending.."\nK.O. "..data.Own.stats.KOs
		if layout.compact and layout.game.ownStats[4]<112 then ownDetail.Text="YOU "..data.Own.score.."\nL "..data.Own.lines.." / LV "..data.Own.level.."\nIN "..data.Own.pending.." / KO "..data.Own.stats.KOs end
		for index,value in ipairs({data.Own.score,data.Own.lines,data.Own.level,data.Own.pending.." / "..data.Own.stats.KOs}) do portraitValues[index].Value.Text=tostring(value) end
		if data.Opponent then Bricks.piece(enemyHoldPiece,data.Opponent.hold,otherLoadout,UI.reducedMotion); for i,v in ipairs(enemyNextPieces) do Bricks.piece(v,data.Opponent.next[i],otherLoadout,UI.reducedMotion) end end
		if data.Opponent then enemyScore.Text=tostring(data.Opponent.score); enemyDetail.Text=data.Opponent.lines.." LINES"; enemyIncoming.Text="SENT "..data.Opponent.stats.Sent.." / IN "..data.Opponent.pending.."\nK.O. "..data.Opponent.stats.KOs; compactOpponent.Text="VS "..data.Opponent.score.." / "..data.Opponent.lines.."L\nIN "..data.Opponent.pending.." / KO "..data.Opponent.stats.KOs end
		if data.Opponent and layout.compact and layout.width>=760 then ownDetail.Text="SENT "..data.Own.stats.Sent.."\nK.O. "..data.Own.stats.KOs; ownDetail.TextSize=10; compactOpponent.Visible=false; enemyScore.Text="SENT "..data.Opponent.stats.Sent; enemyScore.TextSize=10; enemyDetail.Text="K.O. "..data.Opponent.stats.KOs; enemyDetail.TextSize=10; enemyIncoming.Visible=false else ownDetail.TextSize=14; enemyDetail.TextSize=14; enemyIncoming.Visible=true end
  if data.Opponent and layout.portrait and layout.game.enemyStats[4]<80 then enemyIncoming.Text="IN"..data.Opponent.pending.." KO"..data.Opponent.stats.KOs end
		if data.Mode~="Solo" and not layout.portrait and not layout.compact then scoreLabel.Text="SENT"; score.Text=tostring(data.Own.stats.Sent); ownDetail.Text="K.O.\n"..data.Own.stats.KOs; ownDetail.TextColor3=C.pink; incoming.Text="INCOMING\n"..data.Own.pending; enemyScore.Text="SENT "..data.Opponent.stats.Sent; enemyDetail.Text="K.O. "..data.Opponent.stats.KOs; enemyDetail.TextColor3=C.pink; enemyIncoming.Text="INCOMING\n"..data.Opponent.pending else scoreLabel.Text="SCORE"; ownDetail.TextColor3=C.muted end
		if data.Mode=="Solo" and not layout.portrait and not layout.compact then ownDetail.Text="LINES "..data.Own.lines.."\nLEVEL "..data.Own.level; ownDetail.TextSize=12; incoming.Visible=false end
		if data.Mode=="Solo" then score.TextSize=math.min(layout.compact and 22 or 28,math.max(10,math.floor((layout.game.ownStats[3]-24)/math.max(1,#score.Text)))) end
		local seconds=data.Remaining or data.Own.elapsed; gameObjects.timer.Text=string.format("%02d:%02d",math.floor(seconds/60),math.floor(seconds%60)); gameObjects.timer.TextColor3=data.Remaining and data.Remaining<=30 and C.pink or C.yellow
		gameObjects.banner.Text=data.Countdown>0 and "READY / "..data.Countdown or not data.Own.alive and (data.RespawnAt and "K.O. / RECOVERING" or "TOP OUT / RESTART OR EXIT") or data.Own.paused and "PAUSED" or data.Remaining and data.Remaining<=10 and "FINAL "..math.ceil(data.Remaining).." SECONDS" or data.Remaining and data.Remaining<=30 and "30 SECOND WARNING" or data.Mode~="Solo" and "ROUND "..(data.Round or 1) or "PRACTICE / NO ENERGY COST"
		lastCountdown=data.Countdown
		meter(ownMeter,layout.game.board,data.Own.pending); meter(enemyMeter,layout.game.opponent,data.Opponent and data.Opponent.pending)
	end,
	Event=function(event)
		if arcade then arcade:event(event) end
		if event.name=="HardDrop" then local loadout=client.Profile and client.Profile.Equipped; Effects.drop(ownBoard.Frame,loadout and loadout.DropEffect or "Default",UI.reducedMotion,{X=math.clamp(((event.data.x or 4)+1)/10,0,1),Y=math.clamp(((event.data.y or 18)+1)/20,0,1)}) end
	end,
	BattleEvent=function(event) arcade:battle(event,player.UserId) end,
	Result=function(data) arcade:reset(nil); closeSettings(); portal.ResultData=data; portal:open("Result") end,
	CosmeticResult=function(data) if portal then portal:render(true) end; if not data.Success then notify(data.Message or "Cosmetic operation failed; try again.") end end,
 Leaderboard=function(data) if portal then portal.BoardData=data; portal:render(true) end end,
	Challenge=function(data) portal.Challenger=data; portal:open("ChallengeInvite") end,
})
portal=PortalUI.new(root,UI,client,function()
	if settingsOpen then UI.ActiveModal=overlay; client:block(true); if UIS.GamepadEnabled then GuiService.SelectedObject=resumeButton end
	elseif UIS.GamepadEnabled then GuiService.SelectedObject=currentPage=="Menu" and menuObjects.solo or nil end
end)
arcade=ArcadeFeedback.new(gamePage,UI,client.Audio,ownBoard,enemyBoard); arcade:layout(layout or Layout.resolve(1366,768,false)); arcade:meters(ownMeter,enemyMeter)
UI.icon(emoteButton,"Images.menu.emoji"); UI.icon(chatButton,"Images.menu.chat"); UI.icon(gameObjects.settings,"Images.menu.settings"); UI.icon(audioButton,"Images.menu.audio")
UI.onHover=function() client.Audio:play("ButtonHover") end
for action,button in pairs(controlButtons) do
	client.Input:button(button,action)
	table.insert(connections,button.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then UI.tween(button,{BackgroundColor3=C.raised},0.08); task.delay(0.15,function() if button.Parent then UI.tween(button,{BackgroundColor3=C.panel},0.12) end end) end
	end))
end
table.insert(connections,RunService.RenderStepped:Connect(function(dt)
	if arcade and currentPage=="Game" and client.Mode~="Result" then
		arcade:tick(dt,workspace:GetServerTimeNow()); local state=client.State
		if state then meter(ownMeter,layout.game.board,state.Own.pending); meter(enemyMeter,layout.game.opponent,state.Opponent and state.Opponent.pending); local now=workspace:GetServerTimeNow(); local remaining=state.EndAt and math.max(0,state.EndAt-math.max(now,state.StartAt or now)); if remaining then gameObjects.timer.Text=string.format("%02d:%02d",math.floor(remaining/60),math.floor(remaining%60)) end end
	end
	if portal.ResultSequence and portal.Overlay.Visible then portal.ResultSequence:tick(dt) end
	if toast.Visible and os.clock()>notifyUntil then toast.Visible=false end
	if portal.Overlay.Visible then
  portal:tick(dt)
		if portal.Sample then portal.Sample:tick(dt) end
		if portal.Page=="Searching" and portal.SearchLabel then portal.SearchLabel.Text="SEARCHING"..string.rep(".",math.floor(os.clock()*2)%4).." / "..math.max(0,math.floor(workspace:GetServerTimeNow()-searchStarted)).."s" end
	end
end))
gui.Destroying:Connect(function()
	alive=false; if pageTween then pageTween:Cancel() end
	for _,connection in ipairs(connections) do connection:Disconnect() end
	arcade:destroy(); portal:destroy(); client:destroy(); art:destroy(); backdrop:Destroy(); UI.onHover=nil; game:GetService("ContextActionService"):UnbindAction("RetroSettingsClose")
end)
applyLayout(); task.defer(function() if alive then page("Menu"); applyLayout() end end)
gui:SetAttribute("UIVersion", "2026-10-10-reference-ui-v2")
print("[Tetris Battle] Scripts are updated with the new version: 2026-10-10-reference-ui-v2 | UI startup complete.")
