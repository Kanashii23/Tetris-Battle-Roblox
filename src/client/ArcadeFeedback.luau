-- One presentation controller, driven exclusively by replicated state/events.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared:WaitForChild("Config"):WaitForChild("BattleEffectsConfig"))
local SoundConfig=require(Shared:WaitForChild("Config"):WaitForChild("SoundConfig"))
local Assets=require(script.Parent:WaitForChild("UIAssets"))
local Feedback={}; Feedback.__index=Feedback
local labels={Single="SINGLE",Double="DOUBLE",Triple="TRIPLE",Tetris="TETRIS!",TSpin="T-SPIN!",TSpinMini="T-SPIN MINI!",TSpinSingle="T-SPIN SINGLE!",TSpinDouble="T-SPIN DOUBLE!",TSpinTriple="T-SPIN TRIPLE!",BackToBack="BACK-TO-BACK!",PerfectClear="PERFECT CLEAR!",KO="K.O.!"}
function Feedback.new(parent,UI,audio,own,opponent)
	local self=setmetatable({UI=UI,Audio=audio,Own=own,Opponent=opponent,Queues={{},{}},Current={},Particles={},Clock=0,Seen={},CountdownValue=false},Feedback)
	self.Layer=UI.new("Frame","ArcadeFeedback",parent,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=12})
	self.Labels={}; self.Emotes={}
	for i=1,2 do
		local label=UI.text("ArcadeAnnouncement"..i,self.Layer,"",24,UI.colors.yellow,UI.theme.Fonts.Display); label.ZIndex=14; label.TextXAlignment=Enum.TextXAlignment.Center; label.TextStrokeColor3=UI.colors.background; label.TextStrokeTransparency=0; label.Visible=false
		local sticker=UI.image(label,"AnnouncementArtwork",""); sticker.Size=UDim2.fromScale(1,1); self.Labels[i]=label; self.Emotes[i]=UI.text("BattleEmote"..i,self.Layer,"",15,UI.colors.text,UI.theme.Fonts.Strong); self.Emotes[i].ZIndex=16; self.Emotes[i].Visible=false
	end
	self.Countdown=UI.text("ArcadeCountdown",self.Layer,"",48,UI.colors.yellow,UI.theme.Fonts.Display); self.Countdown.ZIndex=18; self.Countdown.TextXAlignment=Enum.TextXAlignment.Center; self.Countdown.TextStrokeColor3=UI.colors.background; self.Countdown.TextStrokeTransparency=0; self.Countdown.Visible=false
	self.CountdownAsset=UI.image(self.Countdown,"CountdownArtwork",""); self.CountdownAsset.Size=UDim2.fromScale(1,1)
 self.Arrow=UI.image(self.Layer,"AttackArrow",Assets.uri("Images.battle.attack_arrow")); self.Arrow.Visible=false
 for i=1,Config.Attack.MaxActive do local p=UI.new("Frame","AttackBlock"..i,self.Layer,{Size=UDim2.fromOffset(8,8),BorderSizePixel=0,BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),Visible=false,ZIndex=13}); local edge=UI.stroke(p,UI.colors.cyan,0.05,2); local glow=UI.new("Frame","Glow",p,{Position=UDim2.fromOffset(-3,-3),Size=UDim2.new(1,6,1,6),BackgroundTransparency=1,ZIndex=12}); UI.stroke(glow,UI.colors.cyan,0.75,3); local texture=UI.image(p,"BlockTexture",Assets.uri("Images.battle.garbage_projectile")); texture.Size=UDim2.fromScale(1,1); if texture.Visible then edge.Transparency=0.6 end; self.Particles[i]={Frame=p,Edge=edge,Glow=glow} end
	self.Rays={}; for i=1,8 do local ray=UI.new("Frame","ClearRay"..i,self.Layer,{BackgroundColor3=UI.colors.green,BackgroundTransparency=0.8,BorderSizePixel=0,Rotation=i*45,Visible=false,ZIndex=12}); self.Rays[i]=ray end
	self.Impacts={}; for i=1,2 do local frame=UI.new("Frame","AttackImpact"..i,self.Layer,{BackgroundTransparency=1,Visible=false,ZIndex=13}); local edge=UI.stroke(frame,UI.colors.orange,0,2); self.Impacts[i]={Frame=frame,Edge=edge} end
	return self
end
function Feedback:layout(layout) self.Layout=layout end
function Feedback:reset(id)
	self.MatchId=id; self.Seen={}; self.OpponentSequence=0; self.ArrowUntil=0; self.Arrow.Visible=false; self.Queues={{},{}}; self.Current={}; self.StartAt=nil; self.CountdownValue=false; self.GoUntil=nil
	for _,p in ipairs(self.Particles) do p.Frame.Visible=false; p.Age=nil end
	for _,label in ipairs(self.Labels) do label.Visible=false end; for _,e in ipairs(self.Emotes) do e.Visible=false end; self.Countdown.Visible=false
	for _,impact in ipairs(self.Impacts) do impact.Age=nil; impact.Frame.Visible=false end; for _,ray in ipairs(self.Rays) do ray.Visible=false end
	self.Audio:warning(0,self.Clock)
end
function Feedback:announce(side,text,priority,color)
	local q=self.Queues[side]; table.insert(q,{Text=text,Priority=priority or 30,Color=color or self.UI.colors.yellow})
	table.sort(q,function(a,b) return a.Priority>b.Priority end); while #q>Config.Announcements.QueueLimit do table.remove(q) end
end
function Feedback:event(event,side)
 side=side or 1
	local name=event.name; local color=name=="PerfectClear" and self.UI.colors.green or name=="KO" and self.UI.colors.pink or (name=="Tetris" or name:find("TSpin")) and self.UI.colors.cyan or self.UI.colors.orange
	if name=="Tetris" then color=self.UI.colors.cyan end
	if labels[name] then self:announce(side,labels[name],name=="PerfectClear" and 90 or name=="KO" and 100 or 50,color)
	elseif name=="Combo" then self:announce(side,"COMBO "..event.data.combo,55,self.UI.colors.orange) end
end
function Feedback:battle(event,localId)
	if event.MatchId~=self.MatchId or self.Seen[event.Id] then return end; self.Seen[event.Id]=true
	-- IDs are monotonic and match-local; keep dedup state bounded.
	if event.Id>64 then self.Seen[event.Id-64]=nil end
	if event.Kind=="Attack" and type(event.Lines)=="number" and event.Lines>0 then
		local side=event.From==localId and 1 or 2; local strength=event.Lines>=Config.Attack.Powerful and 3 or event.Lines>=Config.Attack.Medium and 2 or 1
		self.ArrowUntil=self.Clock+Config.Attack.Duration+0.35; self.ArrowSide=side
  self:announce(side,"+"..event.Lines..(event.Lines==1 and " LINE" or " LINES"),60,self.UI.colors[side==1 and "pink" or "cyan"])
		if self.UI.reducedMotion then self.Impacts[side==1 and 2 or 1].Age=0 end
		if not self.UI.reducedMotion then
			local count=math.min(Config.Attack.MaxProjectiles,math.max(2,event.Lines+1)); local added=0
			for _,p in ipairs(self.Particles) do if not p.Age then
				p.Side=side; p.Frame:SetAttribute("ServerEventId",event.Id); p.Age=-added*0.055; p.Strength=strength; local r=self.Layout and self.Layout.game.board; local size=math.clamp((r and r[3] or 240)/18,7,16)*(0.9+strength*0.06); p.Frame.Size=UDim2.fromOffset(size,size); p.Edge.Color=self.UI.colors[side==1 and "pink" or "cyan"]; p.Glow.Outline.Color=p.Edge.Color; p.Frame.BackgroundColor3=p.Edge.Color; added+=1
				if added>=count then break end
			end end
		end
	elseif event.Kind=="KO" then self:announce(event.Player==localId and 1 or 2,"K.O.!",100,self.UI.colors.pink); self.Audio:play("KO")
	elseif event.Kind=="Emote" then local side=event.From==localId and 1 or 2; self.Emotes[side].Text=event.Text; self.Emotes[side].Visible=true; self.Emotes[side]:SetAttribute("Until",self.Clock+2.5) end
end
function Feedback:state(data)
	if data.MatchId and data.MatchId~=self.MatchId then self:reset(data.MatchId) end
	self.State=data; self.StartAt=data.StartAt
 if data.Opponent then for _,event in ipairs(data.Opponent.events or {}) do if event.id>(self.OpponentSequence or 0) then self.OpponentSequence=event.id; if event.name~="KO" then self:event(event,2) end end end end
end
function Feedback:tick(dt,serverNow)
	self.Clock+=dt; local U=self.UI; if not self.Layout then return end
	local rects={self.Layout.game.board,self.Layout.game.opponent}
	for side,label in ipairs(self.Labels) do
		local r=rects[side]; local event=self.Current[side]
		if not event and #self.Queues[side]>0 then event=table.remove(self.Queues[side],1); event.Age=0; self.Current[side]=event end
		if event then
			event.Age+=dt; label.Visible=true; label.Text=event.Text; label.TextColor3=event.Color
			local pop=U.reducedMotion and 1 or 1+math.sin(math.min(1,event.Age/0.2)*math.pi)*0.12*Config.Announcements.Intensity
			local sticker=label.AnnouncementArtwork; local uri=event.Text=="K.O.!" and Assets.uri("Images.battle.ko") or event.Text:find("^COMBO ") and Assets.uri("Images.battle.combo") or event.Text=="PERFECT CLEAR!" and Assets.uri("Images.artwork.perfect_clear") or ""
   sticker.Image=uri; sticker.Visible=uri~=""; if sticker.Visible then label.Text=event.Text:find("^COMBO ") and event.Text:match("%d+") or "" end
   if event.Text:find("^COMBO ") then sticker.Size=UDim2.fromScale(0.72,1); label.TextXAlignment=Enum.TextXAlignment.Right else sticker.Size=UDim2.fromScale(1,1); label.TextXAlignment=Enum.TextXAlignment.Center end
   label.TextSize=math.clamp((r[3]+16)/math.max(5,#event.Text),14,event.Text=="K.O.!" and 52 or 36)*pop; U.rect(label,{r[1]-8,r[2]+r[4]*0.38,r[3]+16,64})
			label.TextTransparency=U.reducedMotion and 0 or math.clamp((event.Age-0.55)/0.3,0,1); label.TextStrokeTransparency=label.TextTransparency
			if event.Age>=Config.Announcements.Duration then self.Current[side]=nil; label.Visible=false end
		else label.Visible=false end
		local emote=self.Emotes[side]; U.rect(emote,{r[1],r[2]+r[4]+2,r[3],28}); if emote.Visible and self.Clock>(emote:GetAttribute("Until") or 0) then emote.Visible=false end
		local board=side==1 and self.Own or self.Opponent; local shake=event and event.Text=="K.O.!" and not U.reducedMotion and event.Age<0.25 and math.sin(event.Age*60)*Config.Announcements.ShakePixels or 0
		U.rect(board.Frame,{r[1]+shake,r[2],r[3],r[4]})
	end
	local perfectSide=self.Current[1] and self.Current[1].Text=="PERFECT CLEAR!" and 1 or self.Current[2] and self.Current[2].Text=="PERFECT CLEAR!" and 2; local perfect=perfectSide~=nil; local r=rects[perfectSide or 1]
	for i,ray in ipairs(self.Rays) do ray.Visible=perfect and not U.reducedMotion or false; U.rect(ray,{r[1]-r[3]*0.1,r[2]+r[4]*0.48,r[3]*1.2,math.max(4,r[3]*0.08)}) end
	for _,p in ipairs(self.Particles) do if p.Age then
		p.Age+=dt; local t=math.clamp(p.Age/Config.Attack.Duration,0,1); p.Frame.Visible=p.Age>=0 and not U.reducedMotion
		local a,b=rects[p.Side],rects[p.Side==1 and 2 or 1]; local ax,ay=a[1]+a[3]*0.5,a[2]+a[4]*0.4; local bx,by=b[1]+b[3]*0.5,b[2]+b[4]*0.65
		p.Frame.Position=UDim2.fromOffset(ax+(bx-ax)*t,ay+(by-ay)*t-math.sin(t*math.pi)*math.min(Config.Attack.Arc,math.abs(bx-ax)*0.3)*(0.8+p.Strength*0.15))
		if t>=1 or U.reducedMotion then if t>=1 then self.Impacts[p.Side==1 and 2 or 1].Age=0 end; p.Age=nil; p.Frame.Visible=false end
	end end
	for i,impact in ipairs(self.Impacts) do if impact.Age then impact.Age+=dt; U.rect(impact.Frame,rects[i]); impact.Frame.Visible=impact.Age<0.25; impact.Edge.Transparency=math.clamp(impact.Age/0.25,0,1); if self.Meters and self.Meters[i] then local edge=self.Meters[i]:FindFirstChild("ArrivalOutline"); if not edge then edge=U.stroke(self.Meters[i],U.colors.text,0,2); edge.Name="ArrivalOutline" end; edge.Transparency=math.clamp(impact.Age/0.25,0,1) end; if impact.Age>=0.25 then impact.Age=nil end end end
	local arrowR=rects[1]; self.Arrow.Visible=self.Clock<(self.ArrowUntil or 0) and self.Arrow.Image~=""; self.Arrow.Rotation=self.ArrowSide==2 and 180 or 0; U.rect(self.Arrow,{(rects[1][1]+rects[1][3]+rects[2][1])/2-24,arrowR[2]+arrowR[4]*0.38,48,48})
 if self.StartAt then
		local n=math.max(0,math.ceil(self.StartAt-serverNow))
		if n~=self.CountdownValue then
			local first=self.CountdownValue==false; self.CountdownValue=n
			if n>0 then self.Audio:play("Countdown",SoundConfig.CountdownVariants[n]) elseif serverNow-self.StartAt<Config.Countdown.GoDuration then self.GoUntil=self.Clock+Config.Countdown.GoDuration; self.Audio:play("MatchStart") elseif not first then self.GoUntil=nil end
		end
		self.Countdown.Visible=n>0 or self.GoUntil and self.Clock<self.GoUntil or false; self.Countdown.Text=n>0 and tostring(n) or "GO!"
		local countdownKey=n>0 and "countdown_"..n or "go"; self.CountdownAsset.Image=Assets.uri("Images.battle."..countdownKey); self.CountdownAsset.Visible=self.CountdownAsset.Image~=""; if self.CountdownAsset.Visible then self.Countdown.Text="" end
  self.Countdown.TextSize=math.clamp(r[3]*0.2,28,58); U.rect(self.Countdown,{r[1]-8,r[2]+r[4]*0.3,r[3]+16,100})
	end
	if self.State then self.Audio:warning(self.State.Mode~="Solo" and self.State.Own.alive and self.State.Own.pending or 0,self.Clock) end
end
function Feedback:meters(own,other) self.Meters={own,other} end
function Feedback:destroy() self.Audio:warning(0,self.Clock); self.Layer:Destroy() end
return Feedback
