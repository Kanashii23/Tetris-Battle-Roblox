-- Data-driven lobby screens. All purchases and claims are requested from server.
local Players=game:GetService("Players")
local SocialService=game:GetService("SocialService")
local TextService=game:GetService("TextService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog=require(Shared:WaitForChild("Catalog"))
local P=require(Shared:WaitForChild("Progression"))
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local F=Theme.Fonts
local Preview=require(script.Parent:WaitForChild("BrickPreviewRenderer"))
local Portal={}; Portal.__index=Portal
function Portal.new(root,UI,client,closed)
	local self=setmetatable({Root=root,UI=UI,Client=client,Page="Profile",Category="BrickSkins",Inventory=false,Leaderboard="GlobalRating",Closed=closed},Portal)
	local C=UI.colors
	self.Overlay=UI.new("Frame","LobbyPortal",root,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,Visible=false,ZIndex=30,Active=true})
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
 local tabs=w<600 and 96 or 48; self.BodyTop=76+tabs+12
 self.ListWidth=(self.Page=="Shop" or self.Page=="Inventory") and w>=960 and math.min(500,math.floor(w*0.43)) or w-40
 local U=self.UI; U.rect(self.Header,{20,20,w-156,40}); U.rect(self.Back,{w-116,16,96,44}); U.rect(self.Tabs,{20,76,w-40,tabs})
 self.Header.TextSize=w<640 and 16 or 20
 U.rect(self.Scroll,{20,self.BodyTop,self.ListWidth,h-self.BodyTop-20})
 if (old~=w or oldHeight~=h) and self.Overlay.Visible then self:render(true) end
end
function Portal:close(suppressCancel)
 if self.Page=="Searching" and not suppressCancel then self.Client:send("Cancel") end
 self.PreviewOpen=false; self:clearPreview(); self.Overlay.Visible=false; self.Client:block(false)
 self.Client.Audio:music(self.Client.Mode=="Solo" and "SoloMusic" or (self.Client.Mode=="Ranked" or self.Client.Mode=="Challenge") and "BattleMusic" or "MenuMusic")
 if self.Closed then self.Closed() end
end
function Portal:open(page)
 self.Page=page; self.PreviewOpen=false; self.Overlay.Visible=true; self.Client:block(true); self.Client.Audio:play("ButtonClick")
 self.Client.Audio:music((page=="Shop" or page=="Inventory") and "ShopMusic" or "MenuMusic")
 self:layout(self.Width or self.Root.AbsoluteSize.X,self.Height or self.Root.AbsoluteSize.Y); self:render(); self:restoreFocus()
end
function Portal:clear(parent)
	for _,child in ipairs(parent:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
end
function Portal:tab(text,index,fn)
 local b=self.UI.button("Tab"..index,self.Tabs,text,self.UI.colors.line,fn); b.ZIndex=32
 local columns=self.Width<600 and 2 or 4; local width=(self.Width-40-(columns-1)*8)/columns
 self.UI.rect(b,{((index-1)%columns)*(width+8),math.floor((index-1)/columns)*52,width,44})
end
function Portal:row(title,body,action,fn,accent,height)
 local U,C=self.UI,self.UI.colors; local narrow=self.Width<640
 local reserved=action and not narrow and 196 or 28
 local textWidth=math.max(80,self.ListWidth-8-reserved)
 local titleHeight=math.max(28,TextService:GetTextSize(title,18,F.Strong,Vector2.new(textWidth,10000)).Y+4)
 local bodyHeight=math.max(44,TextService:GetTextSize(body,15,F.Body,Vector2.new(textWidth,10000)).Y+4)
 local row=U.new("Frame","Row",self.Scroll,{BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=32}); row.Size=UDim2.new(1,-8,0,math.max(height or (action and 112 or 96),8+titleHeight+4+bodyHeight+12+(action and narrow and 54 or 0)))
 local divider=U.divider(row,"RowBorder"); divider.ZIndex=33
 local t=U.text("Title",row,title,18,C.text,F.Strong); t.ZIndex=33; t.Position=UDim2.fromOffset(14,8); t.Size=UDim2.new(1,-reserved,0,titleHeight); t.TextYAlignment=Enum.TextYAlignment.Top
 local d=U.text("Body",row,body,15,C.muted,F.Body); d.ZIndex=33; d.Position=UDim2.fromOffset(14,12+titleHeight); d.Size=UDim2.new(1,-reserved,0,bodyHeight); d.TextYAlignment=Enum.TextYAlignment.Top
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
	if preserveScroll and shop and d and view and view.Page==self.Page and view.Category==self.Category and view.Width==self.Width and view.Height==self.Height then
		-- Server profile updates and preview actions never remove the list or its cards.
		self:shop(d,true); self:restoreFocus(focusName); return
	end
	local scroll=preserveScroll and self.Scroll.CanvasPosition or Vector2.new(0,0)
	self.RowIndex=0; self:clearPreview()
	self:layout(self.Width or 1120,self.Height or 760)
	self.ShopView=nil
	self:clear(self.Tabs); self:clear(self.Scroll); self.Scroll.CanvasPosition=scroll
	self.Header.Text=self.Page=="ChallengeInvite" and "DUEL INVITE" or self.Page:upper()
	if not d then self:row("Loading profile","Please wait for your server data."); return end
	if self.Page=="Hub" then
  self.Header.Text="YOUR ARCADE"
  for _,page in ipairs({"Profile","Shop","Inventory","Quests","Leaderboards","Login","Energy","Friends","Audio"}) do self:row(page,"", "OPEN",function() self:open(page) end,nil,self.Width<640 and 112 or 88) end
 elseif self.Page=="Shop" or self.Page=="Inventory" then
  self:shop(d)
	elseif self.Page=="Quests" then
		self:tab("DAILY",1,function() self.QuestGroup="Daily"; self:render() end); self:tab("WEEKLY",2,function() self.QuestGroup="Weekly"; self:render() end)
		local group=self.QuestGroup or "Daily"; self.Header.Text=group:upper().." QUESTS"
		for _,q in ipairs(P[group]) do
			local state=d.Quests[group]; local n=state.Progress[q.Id] or 0
			self:row(q.Label,string.format("%d / %d  |  %s%s\nReset: %s UTC",n,q.Target,q.Cash and q.Cash.." Cash" or "",q.Energy and q.Energy.." Energy" or "",group=="Daily" and "daily at 00:00" or "Monday 00:00"),state.Claimed[q.Id] and "CLAIMED" or "CLAIM",function() self.Client:send("ClaimQuest",{Group=group,Id=q.Id}) end)
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
		self:row("Audio volumes","Adjust master, music and effects volume separately. Settings apply to this session.")
		for _,field in ipairs({"Master","MusicVolume","SFXVolume"}) do
			self:row(field,math.floor(self.Client.Audio[field]*100).."%","CYCLE +20%",function()
				local a=self.Client.Audio; a[field]=(math.floor(a[field]*5+0.5)+1)%6/5
				a:settings(a.Master,a.MusicVolume,a.SFXVolume,a.Muted); self:render()
			end)
		end
	elseif self.Page=="Friends" then
		self:row("Invite friends","A verified first-time friend who stays "..d.Economy.SocialMinSeconds.."s earns you "..d.Economy.SocialEnergy.." Energy. Limit "..d.Economy.SocialLimit.." daily. Clicking Invite gives no reward.","INVITE FRIENDS",function()
			task.spawn(function() local ok,allowed=pcall(function() return SocialService:CanSendGameInviteAsync(Players.LocalPlayer) end); if ok and allowed then pcall(function() SocialService:PromptGameInvite(Players.LocalPlayer) end) else self.Client.Hooks.Message("Invitations are unavailable on this device or in Studio") end end)
		end)
		for _,other in ipairs(Players:GetPlayers()) do
			if other~=Players.LocalPlayer then self:row(other.DisplayName,"Free unranked challenge; server verifies friendship.","CHALLENGE",function() self.Client:send("Challenge",other.UserId) end) end
		end
	elseif self.Page=="Energy" then
		self:row("Energy "..d.Energy.Current.." / "..d.Economy.EnergyCap,d.DebugPrivileges and d.DebugPrivileges.InfiniteEnergy and "Unlimited Studio test energy. Test rewards never write to live data." or ("Next regeneration: "..d.Energy.Next.."s. +1 every "..d.Economy.EnergyInterval.."s, including offline. Bonus cap "..d.Economy.BonusCap..". Ranked costs "..d.Economy.RankedCost.."; Solo is free."),"OPEN QUESTS",function() self:open("Quests") end)
	elseif self.Page=="Searching" then
		self:row("FINDING OPPONENT","Searching for a real player in this server.","CANCEL SEARCH",function() self:close() end)
		self.SearchLabel=self.UI.text("Elapsed",self.Scroll,"",18,self.UI.colors.cyan); self.SearchLabel.Size=UDim2.new(1,-8,0,48); self.SearchLabel.ZIndex=32
		local row=self:row(Players.LocalPlayer.DisplayName,"@"..Players.LocalPlayer.Name.." / "..P.Ranks[d.Rank.Tier].." / "..d.Rank.Stars.." stars / "..d.Rank.Rating.." rating")
		self.UI.new("ImageLabel","Avatar",row,{Position=UDim2.new(1,-58,0,8),Size=UDim2.fromOffset(44,44),BackgroundTransparency=1,Image="rbxthumb://type=AvatarHeadShot&id="..Players.LocalPlayer.UserId.."&w=150&h=150",ZIndex=33})
	elseif self.Page=="Result" then
		local result=self.ResultData
		if not result then return end
		self:row(result.Outcome:upper(),result.Reason.." / Cash earned: "..result.Cash.."\n"..(result.SettlementPending and "Saving rewards is delayed. Check your profile after reconnecting." or result.Rewards and "Rank and quest rewards applied once." or "Unranked or anti-farming rules: no standard ranked rewards."),"REMATCH",function() self.Client:send("Rematch") end)
		for i,p in ipairs(result.Profiles) do
			local own=p.UserId==Players.LocalPlayer.UserId; local state=own and result.Own or result.Opponent
			self:row(p.DisplayName,string.format("Score %d | Lines %d | Sent %d | KOs %d",state.score,state.lines,state.stats.Sent,state.stats.KOs))
		end
		if result.BeforeRank and result.AfterRank then
			local row=self:row("RANK PROGRESS",P.Ranks[result.BeforeRank.Tier].." "..result.BeforeRank.Stars.." stars -> "..P.Ranks[result.AfterRank.Tier].." "..result.AfterRank.Stars.." stars / Rating "..result.AfterRank.Rating,"RETURN TO LOBBY",function() self.Client:send("Exit"); self:close() end)
			self:rankProgress(row,result.AfterRank,result.BeforeRank)
		end
		self:row("Quest progress","Daily and weekly totals reflect verified gameplay.","VIEW QUESTS",function() self:open("Quests") end)
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
	if preserveScroll then task.defer(function() if self.Overlay.Parent and self.Overlay.Visible and self.RenderRevision==revision then self.Scroll.CanvasPosition=scroll end end) end
	self:restoreFocus(focusName)
end
function Portal:clearPreview()
	if self.Sample then self.Sample:destroy(); self.Sample=nil end
	if self.PreviewPanel then self.PreviewPanel:Destroy(); self.PreviewPanel=nil end
	if self.PreviewShade then self.PreviewShade:Destroy(); self.PreviewShade=nil end
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
		for index,category in ipairs(Catalog.Categories) do self:tab(captions[index],index,function() self.Category=category; self.Selected=nil; self.PreviewOpen=false; self:render() end) end
		self.ShopView={Page=self.Page,Category=self.Category,Width=self.Width,Height=self.Height,Cards={}}
		self.ShopView.Balance=self:row("CASH "..d.Cash,"Visuals only. Your purchases and loadout are saved.",nil,nil,nil,88)
	end
	local view=self.ShopView; local seen={}
	view.Balance:FindFirstChild("Title").Text="CASH "..d.Cash
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
			local row=U.panel("Cosmetic_"..item.Id,self.Scroll); row.Size=UDim2.new(1,-8,0,156); row.ZIndex=32; row.LayoutOrder=order
			card={Row=row,Buttons={}}; view.Cards[item.Id]=card
			local label=U.text("Name",row,item.Name,self.Width<360 and 16 or 18,C.text,F.Strong); label.ZIndex=33; U.rect(label,{112,10,width-144,28})
			local rarity=U.text("Rarity",row,item.Rarity:upper(),13,C.orange,F.Mono); rarity.ZIndex=33; U.rect(rarity,{112,40,width-144,22})
			local price=d.DebugPrivileges and d.DebugPrivileges.FreePurchases and 0 or item.Price
			local status=equipped and "EQUIPPED" or owned and "OWNED" or "LOCKED"
			local meta=U.text("Ownership",row,status.." / "..price.." CASH",14,owned and C.green or C.muted,F.Mono); meta.ZIndex=33; U.rect(meta,{112,64,width-144,26})
			if item.Category=="SoundPacks" then
				local text=U.text("SoundPack",row,"SFX",22,C.cyan,F.Mono); text.ZIndex=33; U.rect(text,{16,22,80,54})
			else
				card.Mini=Preview.thumbnail(row,U,item,d.Equipped); U.rect(card.Mini.Frame,{16,28,80,40})
			end
			local actions={{"Preview_","PREVIEW",function() self.Selected=item.Id; if item.Category=="SoundPacks" then self:sampleAudio(item) end; self.PreviewOpen=self.Width<960; self:render(true) end},
				{"Buy_",owned and "OWNED" or "BUY",function() self.Client:send("Buy",{Category=item.Category,Id=item.Id}) end},
				{"Equip_",equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP",function() local current=self.Client.Profile; local isEquipped=current and current.Equipped[Catalog.Slots[item.Category]]==item.Id; self.Client:send("Equip",{Category=item.Category,Id=isEquipped and "Default" or item.Id}) end}}
			local bw=(width-48)/3
			for index,action in ipairs(actions) do local button=U.button(action[1]..item.Id,row,action[2],index==1 and C.cyan or C.line,action[3]); button.ZIndex=33
				card.Buttons[index]=button
				U.rect(button,{16+(index-1)*(bw+8),102,bw,44}); if index==2 then U.enabled(button,not owned) elseif index==3 then U.enabled(button,owned and not (equipped and item.Id=="Default")) end
			end
			end
			local price=d.DebugPrivileges and d.DebugPrivileges.FreePurchases and 0 or item.Price
			local status=equipped and "EQUIPPED" or owned and "OWNED" or "LOCKED"
			local meta=card.Row:FindFirstChild("Ownership"); meta.Text=status.." / "..price.." CASH"; meta.TextColor3=owned and C.green or C.muted
			card.Buttons[2].Text=owned and "OWNED" or "BUY"; U.enabled(card.Buttons[2],not owned)
			card.Buttons[3].Text=equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP"; U.enabled(card.Buttons[3],owned and not (equipped and item.Id=="Default"))
			if card.Mini then local Bricks=require(script.Parent:WaitForChild("BrickRenderer")); Bricks.piece(card.Mini,"T",{BrickSkin=item.Category=="BrickSkins" and item.Id or d.Equipped.BrickSkin,GhostEffect="Default"},U.reducedMotion) end
		end
	end
	for id,card in pairs(view.Cards) do if not seen[id] then card.Row:Destroy(); view.Cards[id]=nil end end
	self:clearPreview()
	if self.Width>=960 or self.PreviewOpen then self:detail(selected,d) end
end
function Portal:detail(item,d)
	local U,C=self.UI,self.UI.colors; local mobile=self.Width<960; local landscape=mobile and self.Height<420 and self.Width>self.Height
	local width,height,x,y
	if mobile then
		width=math.min(landscape and 680 or 480,self.Width-32); height=math.min(520,self.Height-32); x=(self.Width-width)/2; y=(self.Height-height)/2
		self.PreviewShade=U.new("TextButton","PreviewBackdrop",self.Overlay,{Size=UDim2.fromScale(1,1),Text="",AutoButtonColor=false,Selectable=false,BackgroundColor3=C.background,BackgroundTransparency=0.06,ZIndex=38})
	else width=self.Width-40-self.ListWidth-24; height=self.Height-self.BodyTop-20; x=20+self.ListWidth+24; y=self.BodyTop end
	local panel=U.panel("CosmeticDetail",self.Overlay,C.line); panel.ZIndex=39; U.rect(panel,{x,y,width,height}); self.PreviewPanel=panel
	if mobile then U.focusGroup(panel) end
	local title=U.text("PreviewName",panel,item.Name,18,C.orange,F.Display); title.ZIndex=40; U.rect(title,{20,14,width-100,42})
	local close=U.button("ClosePreview",panel,mobile and "BACK" or "SAMPLE",C.line,function() self.PreviewOpen=false; self:render(true) end); close.ZIndex=40; U.rect(close,{width-76,14,56,44}); U.enabled(close,mobile)
	local desc=U.text("PreviewDescription",panel,item.Category=="SoundPacks" and "Configured pack audio / 1.6 second sample" or "Actual tetromino rendering. Appearance preview only.",15,C.muted); desc.ZIndex=40; U.rect(desc,{20,62,width-40,34})
	local contentWidth=landscape and math.floor(width*0.5) or width
	if landscape then U.rect(title,{20,14,contentWidth-40,42}); U.rect(desc,{20,62,contentWidth-40,72}); U.rect(close,{20,height-60,contentWidth-40,44}) end
	if item.Category=="SoundPacks" then
		local listen=U.button("PlaySample",panel,"PLAY SOUND SAMPLE",C.cyan,function() self:sampleAudio(item) end); listen.ZIndex=40; U.rect(listen,landscape and {contentWidth+20,72,width-contentWidth-40,56} or {24,132,width-48,56})
	else
		local sample=Preview.new(panel,U); self.Sample=sample
		local bh=landscape and math.min(height-60,(width-contentWidth-48)*1.2) or math.min(360,height-208,(width-48)*1.2); local bw=bh/1.2
		U.rect(sample.Frame,landscape and {contentWidth+(width-contentWidth-bw)/2,20,bw,bh} or {(width-bw)/2,104,bw,bh}); sample:set(item,d.Equipped)
		local caption=U.text("PreviewCaption",panel,U.reducedMotion and "REDUCED MOTION / STILL FRAME" or "COSMETIC SAMPLE",13,C.muted,F.Mono); caption.ZIndex=40; caption.TextXAlignment=Enum.TextXAlignment.Center; U.rect(caption,landscape and {contentWidth+12,28+bh,width-contentWidth-24,24} or {20,112+bh,width-40,24})
	end
	local owned=d.Inventory[item.Category][item.Id] or d.DebugPrivileges and d.DebugPrivileges.FreeCosmetics; local equipped=d.Equipped[Catalog.Slots[item.Category]]==item.Id
	local buy=U.button("DetailBuy",panel,owned and "OWNED" or "PURCHASE",C.orange,function() self.Client:send("Buy",{Category=item.Category,Id=item.Id}) end); buy.ZIndex=40
	local equip=U.button("DetailEquip",panel,equipped and (item.Id=="Default" and "EQUIPPED" or "UNEQUIP") or "EQUIP",C.line,function() self.Client:send("Equip",{Category=item.Category,Id=equipped and "Default" or item.Id}) end); equip.ZIndex=40
	local bw=(contentWidth-48)/2; local by=height-(landscape and 112 or 60); U.rect(buy,{20,by,bw,44}); U.rect(equip,{28+bw,by,bw,44}); U.enabled(buy,not owned); U.enabled(equip,owned and not (equipped and item.Id=="Default"))
end
function Portal:destroy()
	self:clearPreview(); game:GetService("ContextActionService"):UnbindAction("RetroPortalBack"); self.Overlay:Destroy()
end

return Portal
