-- Data-driven lobby screens. All purchases and claims are requested from server.
local Players=game:GetService("Players")
local SocialService=game:GetService("SocialService")
local TextService=game:GetService("TextService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog=require(Shared:WaitForChild("Catalog"))
local P=require(Shared:WaitForChild("Progression"))
local Assets=require(script.Parent:WaitForChild("UIAssets"))
local Products=require(Shared:WaitForChild("Config"):WaitForChild("DeveloperProductConfig"))
local ThemeConfig=require(Shared.Config:WaitForChild("UIThemeConfig"))
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local F=Theme.Fonts
local Preview=require(script.Parent:WaitForChild("BrickPreviewRenderer"))
local Results=require(script.Parent:WaitForChild("ArcadeResults"))
local Portal={}; Portal.__index=Portal
function Portal.new(root,UI,client,closed)
	local self=setmetatable({Root=root,UI=UI,Client=client,Page="Profile",Category="BrickSkins",Inventory=false,Leaderboard="GlobalRating",Closed=closed},Portal)
	local C=UI.colors
	self.Overlay=UI.new("TextButton","LobbyPortal",root,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,Visible=false,ZIndex=30,Active=true,Text="",AutoButtonColor=false,Selectable=false})
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
 local shop=self.Page=="Shop" or self.Page=="Inventory"; self.Sidebar=shop and w>=960; local tabs=w<600 and 96 or 48; self.BodyTop=self.Sidebar and 88 or 76+tabs+12; self.ListX=self.Sidebar and 164 or 20
 self.ListWidth=(self.Page=="Shop" or self.Page=="Inventory") and w>=960 and math.min(440,math.floor((w-220)*0.45)) or w-40
 local U=self.UI; U.rect(self.Header,{20,20,w-156,40}); U.rect(self.Back,{w-116,16,96,44}); U.rect(self.Tabs,{20,76,w-40,tabs})
 self.Header.TextSize=w<640 and 16 or 20
 if self.Sidebar then U.rect(self.Tabs,{20,88,132,h-108}) end
 U.rect(self.Scroll,{self.ListX,self.BodyTop,self.ListWidth,h-self.BodyTop-20})
 if (old~=w or oldHeight~=h) and self.Overlay.Visible then self:render(true) end
end
function Portal:remember()
 self.ScrollPositions=self.ScrollPositions or {}; self.ScrollPositions[self.Page..":"..self.Category]=self.Scroll.CanvasPosition
 self.PageState=self.PageState or {}; self.PageState[self.Page]={Category=self.Category,Selected=self.Selected}
end
function Portal:close(suppressCancel)
 self:remember()
 if not suppressCancel and self.PreviewOpen then self.PreviewOpen=false; self:render(true); return end
 if not suppressCancel and self.Stack and #self.Stack>0 and self.Page~="Searching" and self.Page~="Result" then local prior=table.remove(self.Stack); self.Page=prior.Page; self.Category=prior.Category; self.Selected=prior.Selected; self.PreviewOpen=false; self:render(); self:restoreFocus(); return end
 self.Stack={}
 if self.Page=="Searching" and not suppressCancel then self.Client:send("Cancel") end
 self.PreviewOpen=false; self:clearPreview(); self.Overlay.Visible=false; self.UI.ActiveModal=nil; self.Client:block(false)
 if self.ResultSequence then self.ResultSequence:destroy(); self.ResultSequence=nil end
 self.Client.Audio:music(self.Client.Mode=="Solo" and "SoloMusic" or (self.Client.Mode=="Ranked" or self.Client.Mode=="Challenge") and "BattleMusic" or "MenuMusic")
 if self.Closed then self.Closed() end
end
function Portal:open(page)
 if page=="Assets" then return end
 self.Stack=self.Stack or {}
 if self.Overlay.Visible and self.Page~=page and self.Page~="Searching" and self.Page~="Result" and page~="Searching" and page~="Result" then self:remember(); table.insert(self.Stack,{Page=self.Page,Category=self.Category,Selected=self.Selected}) end
 if page=="Searching" or page=="Result" then self.Stack={} end
 local saved=self.PageState and self.PageState[page]; if saved then self.Category=saved.Category; self.Selected=saved.Selected end
 self.UI.ActiveModal=self.Overlay
 self.Page=page; self.PreviewOpen=false; self.Overlay.Visible=true; self.Client:block(true); self.Client.Audio:play("ButtonClick")
 self.Client.Audio:music((page=="Shop" or page=="Inventory") and "ShopMusic" or "MenuMusic")
 self:layout(self.Width or self.Root.AbsoluteSize.X,self.Height or self.Root.AbsoluteSize.Y); self:render(); self:restoreFocus()
end
function Portal:clear(parent)
	for _,child in ipairs(parent:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
end
function Portal:tab(text,index,fn)
 local b=self.UI.button("Tab"..index,self.Tabs,text,self.UI.colors.line,fn); b.ZIndex=32
 if self.Sidebar then self.UI.rect(b,{0,(index-1)*56,132,48}); b.TextSize=10; return b end
 local columns=self.Width<600 and 2 or 4; local width=(self.Width-40-(columns-1)*8)/columns
 self.UI.rect(b,{((index-1)%columns)*(width+8),math.floor((index-1)/columns)*52,width,44})
end
function Portal:row(title,body,action,fn,accent,height)
 local U,C=self.UI,self.UI.colors; local narrow=self.Width<640
 local reserved=action and not narrow and 196 or 28
 local textWidth=math.max(80,self.ListWidth-8-reserved)
 local titleHeight=math.max(28,U.measure(title,14,textWidth)+4)
 local bodyHeight=math.max(44,U.measure(body,12,textWidth)+4)
 local row=U.new("Frame","Row",self.Scroll,{BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=32}); row.Size=UDim2.new(1,-8,0,math.max(height or (action and 112 or 96),8+titleHeight+4+bodyHeight+12+(action and narrow and 54 or 0)))
 U.stroke(row,accent or C.line,0.15,1); local divider=U.divider(row,"RowBorder"); divider.ZIndex=33
 local t=U.text("Title",row,title,14,C.text,F.Strong); t.ZIndex=33; t.Position=UDim2.fromOffset(14,8); t.Size=UDim2.new(1,-reserved,0,titleHeight); t.TextYAlignment=Enum.TextYAlignment.Top
 local d=U.text("Body",row,body,12,C.muted,F.Body); d.ZIndex=33; d.Position=UDim2.fromOffset(14,12+titleHeight); d.Size=UDim2.new(1,-reserved,0,bodyHeight); d.TextYAlignment=Enum.TextYAlignment.Top
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
	if preserveScroll and self.Page=="Result" and self.ResultSequence and self.ResultSequence.Data.Id==self.ResultData.Id and self.ResultWidth==self.Width then return end
	if preserveScroll and shop and d and view and view.Page==self.Page and view.Category==self.Category and view.Width==self.Width and view.Height==self.Height then
		-- Server profile updates and preview actions never remove the list or its cards.
		self:shop(d,true); self:restoreFocus(focusName); return
	end
	local scroll=preserveScroll and self.Scroll.CanvasPosition or shop and self.ScrollPositions and self.ScrollPositions[self.Page..":"..self.Category] or Vector2.new(0,0)
	if self.ResultSequence then self.ResultSequence:destroy(); self.ResultSequence=nil end
	self.RowIndex=0; self.ClaimButtons={}; self.QuestReset=nil; self.EnergyRow=nil; self:clearPreview()
	self:layout(self.Width or 1120,self.Height or 760)
	self.ShopView=nil
	self:clear(self.Tabs); self:clear(self.Scroll); self.Scroll.CanvasPosition=scroll
	self.Header.Text=self.Page=="ChallengeInvite" and "DUEL INVITE" or self.Page:upper()
 if self.HeaderIcon then self.HeaderIcon:Destroy() end
 local headerKeys={Shop="shop",Inventory="inventory",Quests="quests",Profile="profile",Leaderboards="leaderboards",Login="login_rewards",Friends="friends",Audio="audio",Hub="more",Help="help",Redeem="redeem_code",Emotes="emoji",Controls="settings"}
 local headerUri=self.Page=="Energy" and Assets.currency("Energy") or self.Page=="Cash" and Assets.currency("Cash") or Assets.uri("Images.menu."..(headerKeys[self.Page] or "more"))
 self.HeaderIcon=self.UI.image(self.Overlay,"HeaderAsset",headerUri); self.HeaderIcon.Position=UDim2.fromOffset(20,24); self.HeaderIcon.Size=UDim2.fromOffset(32,32); self.HeaderIcon.ZIndex=32; self.Header.Position=UDim2.fromOffset(headerUri~="" and 62 or 20,20); self.Header.Size=UDim2.fromOffset(self.Width-(headerUri~="" and 198 or 156),40)
	if not d then self:row("Loading profile","Please wait for your server data."); return end
	if self.Page=="Hub" then
  self.Header.Text="MORE"
  local links={{"Profile","profile"},{"Leaderboards","leaderboards"},{"Login","login_rewards"},{"Friends","friends"},{"Energy","currency.energy"},{"Help","help"},{"Audio","audio"},{"Redeem","redeem_code"}}
  self:menuGrid(links)
 elseif self.Page=="Shop" or self.Page=="Inventory" then
  self:shop(d)
	elseif self.Page=="Quests" then
		self:tab("DAILY",1,function() self.QuestGroup="Daily"; self:render() end); self:tab("WEEKLY",2,function() self.QuestGroup="Weekly"; self:render() end)
		local group=self.QuestGroup or "Daily"; self.Header.Text=group:upper().." QUESTS"
  self.QuestReset=self.UI.text("QuestReset",self.Tabs,"",11,self.UI.colors.muted); self.QuestReset.ZIndex=33; self.UI.rect(self.QuestReset,self.Width<600 and {0,56,self.Width-40,24} or {(self.Width-40)/2,8,(self.Width-40)/2,28})
  self.QuestResetAt=group=="Daily" and (d.Quests[group].Window+1)*86400 or ((d.Quests[group].Window+1)*7-3)*86400
		for _,q in ipairs(P[group]) do
			local state=d.Quests[group]; local n=state.Progress[q.Id] or 0
			local row=self:row(q.Label,string.format("%d / %d  |  %s%s\nReset: %s UTC",n,q.Target,q.Cash and q.Cash.." Cash" or "",q.Energy and q.Energy.." Energy" or "",group=="Daily" and "daily at 00:00" or "Monday 00:00"),state.Claimed[q.Id] and "CLAIMED" or "CLAIM",function() self.Client:send("ClaimQuest",{Group=group,Id=q.Id}) end)
   local button=row:FindFirstChildOfClass("TextButton"); local ready=n>=q.Target and not state.Claimed[q.Id]; button.Text=state.Claimed[q.Id] and "CLAIMED" or ready and "CLAIM" or "INCOMPLETE"; self.UI.enabled(button,ready); if ready then table.insert(self.ClaimButtons,button); button.BackgroundColor3=self.UI.colors.orange; button.TextColor3=self.UI.colors.background end
   local key=q.Id:lower():find("spin") and "t_spins" or q.Id:lower():find("send") and "send_lines" or q.Id:lower():find("win") and "ranked_wins" or q.Id:lower():find("minute") and "play_time" or "practice"
   local icon=self.UI.icon(row,"Images.quests."..key); if icon.Visible then row.Title.Position=UDim2.fromOffset(48,8); row.Title.Size=UDim2.new(1,-(self.Width<640 and 62 or 244),0,row.Title.Size.Y.Offset) end
   local bar=self.UI.new("Frame","QuestProgress",row,{Position=UDim2.new(0,14,1,self.Width<640 and -64 or -12),Size=UDim2.new(1,-(self.Width<640 and 28 or 206),0,6),BackgroundColor3=self.UI.colors.line,BorderSizePixel=0,ZIndex=33}); self.UI.new("Frame","Fill",bar,{Size=UDim2.fromScale(math.clamp(n/q.Target,0,1),1),BackgroundColor3=self.UI.colors.cyan,BorderSizePixel=0,ZIndex=34})
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
		self:row("Audio volumes","Adjust master, music and effects volume separately. Settings are saved with your profile.")
		for _,field in ipairs({"Master","MusicVolume","SFXVolume"}) do
			self:row(field,math.floor(self.Client.Audio[field]*100).."%","CYCLE +20%",function()
				local a=self.Client.Audio; a[field]=(math.floor(a[field]*5+0.5)+1)%6/5
				a:settings(a.Master,a.MusicVolume,a.SFXVolume,a.Muted); self.Client:send("Settings",{[field]=a[field]}); self:render()
			end)
		end
	elseif self.Page=="Emotes" then
		local rules=require(Shared:WaitForChild("Config"):WaitForChild("Rules"))
		for i,text in ipairs(rules.Emotes) do self:row(text,"Battle only / server cooldown "..rules.EmoteCooldown.."s","SEND",function() self.Client:send("Emote",i); self:close() end) end
		self:row("Roblox chat","Use the native filtered chat. Availability follows Roblox account permissions.","OPEN CHAT",function() local ok=pcall(function() local bar=game:GetService("TextChatService").ChatInputBarConfiguration; assert(bar.Enabled and bar.TextBox); bar.TextBox:CaptureFocus() end); if not ok then self.Client.Hooks.Message("Native chat is unavailable; use preset emotes.") end end)
	elseif self.Page=="Controls" then
		for _,field in ipairs({"SwapRotation","ClassicHUD"}) do self:row(field,d.Settings[field] and "ON" or "OFF","TOGGLE",function() self.Client:send("Settings",{[field]=not d.Settings[field]}) end) end
		self:row("UI scale",tostring(d.Settings.UIScale or 1).." / desktop only; touch targets stay full size","CYCLE",function() self.Client:send("Settings",{UIScale=d.Settings.UIScale==0.9 and 1 or 0.9}) end)
		self:row("Keyboard / controller","Arrows or WASD: move. X/Up: clockwise. Z: counterclockwise. C/Shift: hold. Space: hard drop. Swap Rotation exchanges the rotation actions. Gamepad bindings remain in Rules.")
	elseif self.Page=="Friends" then
		self:row("Invite friends","A verified first-time friend who stays "..d.Economy.SocialMinSeconds.."s earns you "..d.Economy.SocialEnergy.." Energy. Limit "..d.Economy.SocialLimit.." daily. Clicking Invite gives no reward.","INVITE FRIENDS",function()
			task.spawn(function() local ok,allowed=pcall(function() return SocialService:CanSendGameInviteAsync(Players.LocalPlayer) end); if ok and allowed then pcall(function() SocialService:PromptGameInvite(Players.LocalPlayer) end) else self.Client.Hooks.Message("Invitations are unavailable on this device or in Studio") end end)
		end)
		for _,other in ipairs(Players:GetPlayers()) do
			if other~=Players.LocalPlayer then self:row(other.DisplayName,"Free unranked challenge; server verifies friendship.","CHALLENGE",function() self.Client:send("Challenge",other.UserId) end) end
		end
	elseif self.Page=="Featured" then
  self:row("COSMETICS","Equip your owned styles or preview before spending Cash.","OPEN COSMETICS",function() self:open("Shop") end)
  self:packCards("Cash",d); self:packCards("Energy",d)
 elseif self.Page=="Cash" then
  self:packCards("Cash",d)
 elseif self.Page=="Energy" then
		self.EnergyRow=self:row("Energy "..d.Energy.Current.." / "..d.Economy.EnergyCap,d.DebugPrivileges and d.DebugPrivileges.InfiniteEnergy and "Unlimited Studio test energy. Test rewards never write to live data." or ("Next regeneration: "..d.Energy.Next.."s. +1 every "..d.Economy.EnergyInterval.."s, including offline. Bonus cap "..d.Economy.BonusCap..". Ranked costs "..d.Economy.RankedCost.."; Solo is free."),"OPEN QUESTS",function() self:open("Quests") end)
	  local energy=self.UI.panel("EnergySegments",self.Scroll,self.UI.colors.cyan); energy.Size=UDim2.new(1,-8,0,72); energy.ZIndex=32
  for i=1,d.Economy.EnergyCap do self.UI.new("Frame","Energy"..i,energy,{Position=UDim2.new((i-1)/d.Economy.EnergyCap,4,0,20),Size=UDim2.new(1/d.Economy.EnergyCap,-8,0,28),BackgroundColor3=i<=d.Energy.Current and self.UI.colors.cyan or self.UI.colors.line,BorderSizePixel=0,ZIndex=33}) end
  self:packCards("Energy",d)
 elseif self.Page=="Help" then self:row("ARCADE CONTROLS","Arrows / WASD move. X/Up rotates, Z reverses, C/Shift holds, Space drops. Ranked uses a server-timed 120 second battle. Settings include touch/gamepad controls and Reduced Motion.","CONTROLS",function() self:open("Controls") end)
 elseif self.Page=="Redeem" then self:row("REDEEM CODE","Code redemption is not available yet.")
 elseif self.Page=="Assets" then return
 elseif self.Page=="Searching" then
		self:row("FINDING OPPONENT","Searching for a real player in this server.","CANCEL SEARCH",function() self:close() end)
		self.SearchLabel=self.UI.text("Elapsed",self.Scroll,"",18,self.UI.colors.cyan); self.SearchLabel.Size=UDim2.new(1,-8,0,48); self.SearchLabel.ZIndex=32
		local row=self:row(Players.LocalPlayer.DisplayName,"@"..Players.LocalPlayer.Name.." / "..P.Ranks[d.Rank.Tier].." / "..d.Rank.Stars.." stars / "..d.Rank.Rating.." rating")
		self.UI.new("ImageLabel","Avatar",row,{Position=UDim2.new(1,-58,0,8),Size=UDim2.fromOffset(44,44),BackgroundTransparency=1,Image="rbxthumb://type=AvatarHeadShot&id="..Players.LocalPlayer.UserId.."&w=150&h=150",ZIndex=33})
	elseif self.Page=="Result" then
		if self.ResultData then self.ResultSequence=Results.new(self.Scroll,self.UI,self.Client,self.ResultData,self.ListWidth); self.ResultWidth=self.Width end
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
	if preserveScroll or shop then task.defer(function() if self.Overlay.Parent and self.Overlay.Visible and self.RenderRevision==revision then self.Scroll.CanvasPosition=scroll end end) end
	self:restoreFocus(focusName)
end
function Portal:clearPreview()
	if self.UI.ActiveModal==self.PreviewPanel then self.UI.ActiveModal=self.Overlay.Visible and self.Overlay or nil end
	self.Client.Audio:stopPreview()
	if self.Sample then self.Sample:destroy(); self.Sample=nil end
	if self.PreviewPanel then self.PreviewPanel:Destroy(); self.PreviewPanel=nil end
	if self.PreviewShade then self.PreviewShade:Destroy(); self.PreviewShade=nil end
	self.DetailId=nil; self.DetailCategory=nil
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
  for index,category in ipairs(Catalog.Categories) do self:tab(captions[index],index,function() self.ScrollPositions=self.ScrollPositions or {}; self.ScrollPositions[self.Page..":"..self.Category]=self.Scroll.CanvasPosition; self.Category=category; self.Selected=nil; self.PreviewOpen=false; self:render() end) end
		if self.Sidebar and self.Page=="Shop" then for i,page in ipairs({"Featured","Cash","Energy"}) do self:tab(page:upper(),i+4,function() self:open(page) end) end end
  self.ShopView={Page=self.Page,Category=self.Category,Width=self.Width,Height=self.Height,Cards={}}
		self.ShopView.Balance=self:row("CASH "..d.Cash,"Visuals only. Your purchases and loadout are saved.",nil,nil,nil,88)
	end
	local view=self.ShopView; local seen={}
 if self.Page=="Inventory" and not view.Grid then view.Grid=U.new("Frame","InventoryGrid",self.Scroll,{BackgroundTransparency=1,Size=UDim2.new(1,-8,0,0),ZIndex=32,LayoutOrder=1}); U.new("UIGridLayout","Grid",view.Grid,{CellSize=UDim2.fromOffset((self.ListWidth-20)/2,200),CellPadding=UDim2.fromOffset(10,10),SortOrder=Enum.SortOrder.LayoutOrder,FillDirectionMaxCells=2}) end
 local gridCount=0
	view.Balance:FindFirstChild("Title").Text="CASH "..d.Cash
 if not view.Balance:FindFirstChild("AssetIcon") then U.icon(view.Balance,"Images.currency.cash") end
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
			local row=U.panel("Cosmetic_"..item.Id,view.Grid or self.Scroll); row.Size=UDim2.new(1,-8,0,156); row.ZIndex=32; row.LayoutOrder=order
			card={Row=row,Buttons={},Rarity=item.Rarity}; row.Outline.Color=Color3.fromRGB(table.unpack(ThemeConfig.RarityColors[item.Rarity] or ThemeConfig.RarityColors.Common)); view.Cards[item.Id]=card
			local label=U.text("Name",row,item.Name,13,C.text,F.Strong); label.ZIndex=33; U.rect(label,{112,10,width-144,40})
			local rarity=U.text("Rarity",row,item.Rarity:upper(),10,C.orange,F.Mono); rarity.ZIndex=33; U.rect(rarity,{112,50,width-144,20})
			local price=d.DebugPrivileges and d.DebugPrivileges.FreePurchases and 0 or item.Price
			local status=equipped and "EQUIPPED" or owned and "OWNED" or "LOCKED"
			local meta=U.text("Ownership",row,status.." / "..price.." CASH",10,owned and C.green or C.muted,F.Mono); meta.ZIndex=33; U.rect(meta,{112,72,width-144,26})
			if item.Category=="SoundPacks" then
				local text=U.text("SoundPack",row,"SFX",22,C.cyan,F.Mono); text.ZIndex=33; U.rect(text,{16,22,80,54})
			else
				card.Mini=Preview.thumbnail(row,U,item,d.Equipped); U.rect(card.Mini.Frame,{16,28,80,40})
			end
			local art=U.image(row,"CosmeticArtwork",Assets.cosmetic(item)); U.rect(art,{16,6,80,72}); if art.Visible and card.Mini then U.rect(card.Mini.Frame,{28,74,56,28}) end
   if item.Category=="SoundPacks" and art.Visible then row.SoundPack.Visible=false end
   local actions={{"Preview_","PREVIEW",function() self.Selected=item.Id; self.PreviewOpen=self.Width<960; self:render(true) end},
				{"Buy_",owned and "OWNED" or "BUY",function() self:cosmeticRequest("Buy",item) end},
				{"Equip_",equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP",function() local current=self.Client.Profile; local isEquipped=current and current.Equipped[Catalog.Slots[item.Category]]==item.Id; self:cosmeticRequest("Equip",item,isEquipped and "Default" or item.Id) end}}
			local bw=(width-48)/3
			for index,action in ipairs(actions) do local button=U.button(action[1]..item.Id,row,action[2],index==1 and C.cyan or C.line,action[3]); button.ZIndex=33
				card.Buttons[index]=button
				U.rect(button,{16+(index-1)*(bw+8),102,bw,44}); if index==2 then U.enabled(button,not owned) elseif index==3 then U.enabled(button,owned and not (equipped and item.Id=="Default")) end
			end
			end
			local price=d.DebugPrivileges and d.DebugPrivileges.FreePurchases and 0 or item.Price
			local status=equipped and "EQUIPPED" or owned and "OWNED" or "LOCKED"
			if view.Grid then
    gridCount+=1; local row=card.Row; local cw=(self.ListWidth-20)/2; row.Size=UDim2.fromOffset(cw,200)
    U.rect(row:FindFirstChild("Name"),{10,76,cw-20,32}); row:FindFirstChild("Name").TextSize=11; row:FindFirstChild("Name").TextXAlignment=Enum.TextXAlignment.Center
    U.rect(row.Rarity,{10,112,cw-20,18}); U.rect(row.Ownership,{10,132,cw-20,18}); row.Ownership.TextSize=10
    if card.Mini then U.rect(card.Mini.Frame,{(cw-80)/2,16,80,40}) end; local art=row:FindFirstChild("CosmeticArtwork"); if art then U.rect(art,{(cw-68)/2,4,68,68}); if art.Visible and card.Mini then U.rect(card.Mini.Frame,{8,42,44,22}) end end
    card.Buttons[2].Visible=false; U.rect(card.Buttons[1],{8,154,(cw-24)/2,44}); U.rect(card.Buttons[3],{16+(cw-24)/2,154,(cw-24)/2,44}); card.Buttons[1].TextSize=10; card.Buttons[3].TextSize=10
   end
   card.Row.Outline.Color=self.Selected==item.Id and C.yellow or Color3.fromRGB(table.unpack(ThemeConfig.RarityColors[item.Rarity] or ThemeConfig.RarityColors.Common))
			local meta=card.Row:FindFirstChild("Ownership"); meta.Text=view.Grid and status or status.." / "..price.." CASH"; meta.TextColor3=owned and C.green or C.muted
			card.Buttons[2].Text=owned and "OWNED" or "BUY"; U.enabled(card.Buttons[2],not owned)
			card.Buttons[3].Text=equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP"; U.enabled(card.Buttons[3],owned and not (equipped and item.Id=="Default"))
			local pending=self.Client.PendingCosmetic; if pending then for i=2,3 do U.enabled(card.Buttons[i],false); if pending.Category==item.Category and (pending.Id==item.Id or pending.Id=="Default" and equipped) then card.Buttons[i].Text="WAIT..." end end end
   if card.Mini then local Bricks=require(script.Parent:WaitForChild("BrickRenderer")); Bricks.piece(card.Mini,"T",{BrickSkin=item.Category=="BrickSkins" and item.Id or d.Equipped.BrickSkin,GhostEffect="Default"},U.reducedMotion) end
		end
	end
	if view.Grid then view.Grid.Size=UDim2.new(1,-8,0,math.ceil(gridCount/2)*210) end
 for id,card in pairs(view.Cards) do if not seen[id] then card.Row:Destroy(); view.Cards[id]=nil end end
	if self.Width>=960 or self.PreviewOpen then
		if self.Sample and self.DetailId==selected.Id and self.DetailCategory==selected.Category then
			for category,slot in pairs(Catalog.Slots) do if category~=selected.Category and slot~="SoundPack" then self.Sample.Loadout[slot]=d.Equipped[slot] end end
			self:updateDetail(selected,d)
		else self:clearPreview(); self:detail(selected,d) end
	else self:clearPreview() end
end
function Portal:detail(item,d)
	local U,C=self.UI,self.UI.colors; local mobile=self.Width<960; local landscape=mobile and self.Height<420 and self.Width>self.Height
	local width,height,x,y
	if mobile then
		width=math.min(landscape and 680 or 480,self.Width-32); height=math.min(520,self.Height-32); x=(self.Width-width)/2; y=(self.Height-height)/2
		self.PreviewShade=U.new("TextButton","PreviewBackdrop",self.Overlay,{Size=UDim2.fromScale(1,1),Text="",AutoButtonColor=false,Selectable=false,BackgroundColor3=C.background,BackgroundTransparency=0.06,ZIndex=38})
	else width=self.Width-20-self.ListX-self.ListWidth-24; height=self.Height-self.BodyTop-20; x=self.ListX+self.ListWidth+24; y=self.BodyTop end
	local panel=U.panel("CosmeticDetail",self.Overlay,C.line); panel.ZIndex=39; U.rect(panel,{x,y,width,height}); self.PreviewPanel=panel
	if mobile then U.focusGroup(panel); U.ActiveModal=panel end
	local title=U.text("PreviewName",panel,item.Name,14,C.orange,F.Display); title.ZIndex=40; U.rect(title,{20,14,width-100,42})
	local close=U.button("ClosePreview",panel,mobile and "BACK" or "SAMPLE",C.line,function() self.PreviewOpen=false; self:render(true) end); close.ZIndex=40; U.rect(close,{width-76,14,56,44}); U.enabled(close,mobile)
	local desc=U.text("PreviewDescription",panel,item.Rarity:upper().." / "..item.Price.." CASH / "..(item.Category=="SoundPacks" and "MANUAL AUDIO SAMPLE" or "LIVE PREVIEW"),11,C.muted); desc.ZIndex=40; U.rect(desc,{20,62,width-40,34})
	local contentWidth=landscape and math.floor(width*0.5) or width
	if landscape then U.rect(title,{20,14,contentWidth-40,42}); U.rect(desc,{20,62,contentWidth-40,40}); U.rect(close,{width-76,4,56,44}) end
	self.DetailId=item.Id; self.DetailCategory=item.Category
	local sample=Preview.new(panel,U); self.Sample=sample
	local bh=landscape and math.min(height-68,(width-contentWidth-48)*2) or math.min(400,height-308,(width-48)*2); local bw=bh/2
	U.rect(sample.Frame,landscape and {contentWidth+(width-contentWidth-bw)/2,28,bw,bh} or {(width-bw)/2,104,bw,bh}); sample:set(item,d.Equipped)
		local caption=U.text("PreviewCaption",panel,U.reducedMotion and "REDUCED MOTION / STILL FRAME" or "LIVE ENGINE DEMO / NO REWARDS",12,C.muted,F.Mono); caption.ZIndex=40; caption.TextXAlignment=Enum.TextXAlignment.Center; U.rect(caption,landscape and {contentWidth+12,32+bh,width-contentWidth-24,20} or {20,108+bh,width-40,20})
	local controls={{"Pause","PAUSE"},{"Replay","REPLAY"},{"Rotate","ROTATE"},{"Next","PIECE"},{"Speed","1x"},{"Audio","SFX"}}
 local cols=3; local cw=(contentWidth-48)/cols; local start=height-164
 for i,spec in ipairs(controls) do local b=U.button("Preview"..spec[1],panel,spec[2],C.cyan,function() if spec[1]=="Audio" then if item.Category=="SoundPacks" then self:sampleAudio(item) end else sample:control(spec[1]); if spec[1]=="Pause" then panel.PreviewPause.Text=sample.Paused and "PLAY" or "PAUSE" elseif spec[1]=="Speed" then panel.PreviewSpeed.Text=tostring(sample.Speed or 1).."x" end end end); b.ZIndex=40; b.TextSize=10; U.rect(b,{20+(i-1)%cols*(cw+4),start+math.floor((i-1)/cols)*52,cw-4,44}); if spec[1]=="Audio" then U.enabled(b,item.Category=="SoundPacks") end end
 local owned=d.Inventory[item.Category][item.Id] or d.DebugPrivileges and d.DebugPrivileges.FreeCosmetics; local equipped=d.Equipped[Catalog.Slots[item.Category]]==item.Id
 local buy=U.button("DetailBuy",panel,owned and "OWNED" or "PURCHASE",C.orange,function() self:cosmeticRequest("Buy",item) end); buy.ZIndex=40
	local equip=U.button("DetailEquip",panel,equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP",C.line,function() local current=self.Client.Profile; local active=current and current.Equipped[Catalog.Slots[item.Category]]==item.Id; self:cosmeticRequest("Equip",item,active and "Default" or item.Id) end); equip.ZIndex=40
	local bw=(contentWidth-48)/2; local by=height-60; U.rect(buy,{20,by,bw,44}); U.rect(equip,{28+bw,by,bw,44}); U.enabled(buy,not owned); U.enabled(equip,owned and not (equipped and item.Id=="Default"))
end
function Portal:updateDetail(item,d)
	local owned=d.Inventory[item.Category][item.Id] or d.DebugPrivileges and d.DebugPrivileges.FreeCosmetics; local equipped=d.Equipped[Catalog.Slots[item.Category]]==item.Id
	local buy=self.PreviewPanel:FindFirstChild("DetailBuy"); local equip=self.PreviewPanel:FindFirstChild("DetailEquip")
	buy.Text=owned and "OWNED" or "PURCHASE"; self.UI.enabled(buy,not owned); equip.Text=equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP"; self.UI.enabled(equip,owned and not (equipped and item.Id=="Default")); if self.Client.PendingCosmetic then self.UI.enabled(buy,false); self.UI.enabled(equip,false); equip.Text="WAIT..." end
end
function Portal:destroy()
	self:clearPreview(); if self.ResultSequence then self.ResultSequence:destroy(); self.ResultSequence=nil end; game:GetService("ContextActionService"):UnbindAction("RetroPortalBack"); self.Overlay:Destroy()
end

function Portal:cosmeticRequest(kind,item,id)
 if self.Client.PendingCosmetic then return end
 self.Client.PendingCosmetic={Kind=kind,Category=item.Category,Id=id or item.Id,At=os.clock()}
 self.Client:send(kind,{Category=item.Category,Id=id or item.Id}); self:render(true)
end
function Portal:packCards(kind,d)
 local U,C=self.UI,self.UI.colors
 for i,size in ipairs({"small","medium","large"}) do
  local product=Products[kind][i]; local row=self:row(kind:upper().." / "..size:upper(),product and product.Quantity and tostring(product.Quantity).." "..kind or "Not available","UNAVAILABLE",function() self.Client.Hooks.Message("No verified Developer Product integration is configured.") end,nil,140)
  local art=U.image(row,"PackArtwork",Assets.uri("Images.shop."..kind:lower().."_"..size)); U.rect(art,{14,28,70,80}); row.Title.Position=UDim2.fromOffset(96,8); row.Title.Size=UDim2.new(1,-(self.Width<640 and 110 or 292),0,36); row.Body.Position=UDim2.fromOffset(96,48); row.Body.Size=UDim2.new(1,-(self.Width<640 and 110 or 292),0,52); U.enabled(row:FindFirstChildOfClass("TextButton"),false)
 end
end
function Portal:menuGrid(links)
 local U=self.UI; local cols=self.Width>=500 and 2 or 1; local cw=(self.ListWidth-8-(cols-1)*10)/cols
 local grid=U.new("Frame","MoreGrid",self.Scroll,{BackgroundTransparency=1,Size=UDim2.new(1,-8,0,math.ceil(#links/cols)*100),ZIndex=32})
 U.new("UIGridLayout","Tiles",grid,{CellSize=UDim2.fromOffset(cw,90),CellPadding=UDim2.fromOffset(10,10),SortOrder=Enum.SortOrder.LayoutOrder,FillDirectionMaxCells=cols})
 for i,link in ipairs(links) do local captions={Login="Login Rewards",Audio="Audio Settings",Help="Help / Info",Redeem="Redeem Code"}; local button=U.button("More"..link[1],grid,captions[link[1]] or link[1],U.colors.line,function() self:open(link[1]) end); button.ZIndex=33; button.LayoutOrder=i; U.icon(button,link[2]:find("%.") and "Images."..link[2] or "Images.menu."..link[2]) end
end
function Portal:assetGallery()
 local U=self.UI
 local row=self:row("ARTWORK REFERENCE","Original filenames and upload locations are in ASSET_ID_CHECKLIST.md. These images never replace live boards or alter ownership.")
 for _,key in ipairs({"brick_demon_wave"}) do local r=self:row(key,"Unmatched cosmetic artwork / no catalog item"); local image=U.image(r,"Reference",Assets.uri("Images.cosmetics."..key)); U.rect(image,{self.ListWidth-80,8,64,64}) end
 for _,key in ipairs({"rookie","amateur","pro","expert","master","immortal"}) do local r=self:row("REFERENCE "..key:upper(),"Optional badge / actual rank progression preserved"); local image=U.image(r,"Reference",Assets.uri("OptionalReferenceRanks.Images."..key)); U.rect(image,{self.ListWidth-80,8,64,64}) end
 local r=self:row("PACK CONTACT SHEET","Optional reference only"); local image=U.image(r,"Reference",Assets.uri("Images.artwork.preview")); U.rect(image,{self.ListWidth-80,8,64,64})
end
function Portal:tick(dt)
 local now=workspace:GetServerTimeNow()
 if self.QuestReset and self.QuestReset.Parent then local left=math.max(0,math.floor(self.QuestResetAt-now)); self.QuestReset.Text=string.format("RESET %02d:%02d:%02d",math.floor(left/3600),math.floor(left%3600/60),left%60) end
 if self.EnergyRow and self.EnergyRow.Parent then local d=self.Client.Profile; local left=d.Energy.Current>=d.Economy.EnergyCap and 0 or math.max(0,math.ceil(d.Economy.EnergyInterval-(now-d.Energy.LastRegenTimestamp))); self.EnergyRow.Body.Text=(d.DebugPrivileges and d.DebugPrivileges.InfiniteEnergy and "Studio test energy" or left==0 and "Energy full" or string.format("+1 ENERGY IN %02d:%02d",math.floor(left/60),left%60)).." / SOLO IS FREE" end
 for _,button in ipairs(self.ClaimButtons or {}) do if button.Parent then button.BackgroundColor3=self.UI.reducedMotion and self.UI.colors.orange or self.UI.colors.orange:Lerp(self.UI.colors.yellow,(math.sin(now*3)+1)*0.15) end end
 local pending=self.Client.PendingCosmetic
 if pending and os.clock()-pending.At>12 then self.Client.PendingCosmetic=nil; self.Client.Hooks.Message("Request timed out. Refresh your profile before trying again."); self:render(true) end
 if self.ShopView then for _,card in pairs(self.ShopView.Cards) do local outline=card.Row:FindFirstChild("Outline"); local alpha=ThemeConfig.RarityMotion[card.Rarity] or 0; if outline then outline.Transparency=self.UI.reducedMotion and 0.15 or 0.15+math.sin(os.clock()*2)*alpha end end end
end

return Portal
