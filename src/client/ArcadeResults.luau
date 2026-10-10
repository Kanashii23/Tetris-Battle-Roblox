-- Timeline reads one confirmed Result. It cannot grant rewards or mutate profiles.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local P=require(Shared:WaitForChild("Progression")); local Config=Shared:WaitForChild("Config")
local Effects=require(Config:WaitForChild("BattleEffectsConfig")); local RankIcons=require(Config:WaitForChild("RankIconConfig")); local Currency=require(Config:WaitForChild("CurrencyIconConfig"))
local Assets=require(script.Parent:WaitForChild("UIAssets"))
local Results={}; Results.__index=Results
local function ordinal(rank) local n=rank.Stars; for i=1,rank.Tier-1 do n+=P.Stars[i] end; return n end
function Results.new(parent,U,client,result,width)
	local self=setmetatable({UI=U,Client=client,Data=result,Elapsed=client.ResultElapsed or 0},Results)
	self.Frame=U.panel("ArcadeResults",parent); self.Frame.Size=UDim2.new(1,-8,0,530); self.Frame.ZIndex=32
	local C=U.colors; local text=result.Outcome=="Win" and "YOU WIN!" or result.Outcome=="Lose" and "YOU LOSE!" or "DRAW!"
	self.BaseTitleSize=math.min(32,width/12); self.Title=U.text("Outcome",self.Frame,text,self.BaseTitleSize,result.Outcome=="Win" and C.yellow or result.Outcome=="Lose" and C.pink or C.cyan,U.theme.Fonts.Display); U.rect(self.Title,{16,16,width-40,64}); self.Title.ZIndex=33; self.Title.TextStrokeColor3=C.background; self.Title.TextStrokeTransparency=0
	self.KO=U.text("FinalKO",self.Frame,"FINAL K.O.  "..result.Own.stats.KOs.." : "..result.Opponent.stats.KOs,22,C.text,U.theme.Fonts.Mono); U.rect(self.KO,{16,94,width-40,36}); self.KO.ZIndex=33
	local stats=result.Own.stats
	local detail=U.text("FinalStats",self.Frame,string.format("SENT %d   CLEARED %d   BEST COMBO %d",stats.Sent,result.Own.lines,stats.BestCombo or 0),14,C.muted,U.theme.Fonts.Mono); U.rect(detail,{16,134,width-40,40}); detail.ZIndex=33
	self.Coin=U.text("CashIcon",self.Frame,Currency.CashFallback,26,C.yellow,U.theme.Fonts.Display); U.rect(self.Coin,{16,184,32,42}); self.Coin.ZIndex=33
	local cashAsset=Assets.currency("Cash"); if cashAsset~="" then self.Coin.Text=""; local image=U.image(self.Coin,"CashAsset",cashAsset); image.Size=UDim2.fromScale(1,1) end
	self.Cash=U.text("ConfirmedCash",self.Frame,"+"..result.Cash.." CASH",24,C.yellow,U.theme.Fonts.Mono); U.rect(self.Cash,{60,184,width-100,42}); self.Cash.ZIndex=33
	self.RankLabel=U.text("RankLabel",self.Frame,"",20,C.text,U.theme.Fonts.Display); U.rect(self.RankLabel,{60,250,width-100,44}); self.RankLabel.ZIndex=33
	self.Icon=U.text("RankIcon",self.Frame,"",22,C.orange,U.theme.Fonts.Display); U.rect(self.Icon,{16,246,36,48}); self.Icon.ZIndex=33; U.stroke(self.Icon,C.orange,0,1)
	self.Bar=U.new("Frame","StarProgress",self.Frame,{Position=UDim2.fromOffset(16,310),Size=UDim2.new(1,-32,0,12),BackgroundColor3=C.line,BorderSizePixel=0,ZIndex=33})
	self.Fill=U.new("Frame","Fill",self.Bar,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.orange,BorderSizePixel=0,ZIndex=34})
	self.Stars=U.text("StarChange",self.Frame,"",16,C.orange,U.theme.Fonts.Mono); U.rect(self.Stars,{16,336,width-40,52}); self.Stars.ZIndex=33
	local pending=result.SettlementPending and "REWARDS PENDING / RECONNECT TO CHECK" or result.Rewards and "SERVER-CONFIRMED REWARDS" or "NO STANDARD RANKED REWARD"
	local note=U.text("RewardNotice",self.Frame,pending,13,C.muted,U.theme.Fonts.Mono); U.rect(note,{16,396,width-40,40}); note.ZIndex=33
	local rematch=U.button("ResultRematch",self.Frame,"REMATCH",C.pink,function() client:send("Rematch") end); rematch.ZIndex=33; U.rect(rematch,{16,452,(width-48)/2,56})
	local exit=U.button("ResultLobby",self.Frame,"LOBBY",C.cyan,function() client:send("Exit") end); exit.ZIndex=33; U.rect(exit,{24+(width-48)/2,452,(width-48)/2,56})
	client.ResultPhases=client.ResultPhases or {}; self.Phases=client.ResultPhases
	self:tick(0); return self
end
function Results:once(phase,key)
	local id=tostring(self.Data.Id)..":"..phase; if self.Phases[id] then return end; self.Phases[id]=true; if key then self.Client.Audio:play(key) end
end
function Results:tick(dt)
	self.Elapsed+=dt; self.Client.ResultElapsed=self.Elapsed; local U=self.UI; local c=Effects.Results; local t=U.reducedMotion and 100 or self.Elapsed; local d=self.Data
	self.Title.TextSize=self.BaseTitleSize*(U.reducedMotion and 1 or 1+math.sin(math.min(t/c.OutcomeDuration,1)*math.pi)*0.12*c.Intensity)
	self:once("Outcome",d.Outcome=="Win" and "Victory" or d.Outcome=="Lose" and "Defeat" or "Draw")
	self.KO.Visible=t>=c.KOAfter; self.Coin.Visible=t>=c.CashAfter; self.Cash.Visible=self.Coin.Visible
	self.RankLabel.Visible=t>=c.RankAfter; self.Icon.Visible=self.RankLabel.Visible; self.Bar.Visible=self.RankLabel.Visible; self.Stars.Visible=self.RankLabel.Visible
	if self.Cash.Visible and d.Cash>0 then self:once("Cash","CashEarned") end
	if t>=c.CashAfter and d.Outcome=="Win" then self:once("Fanfare","VictoryFanfare") end
	self.Coin.Rotation=U.reducedMotion and 0 or math.sin(math.min(1,math.max(0,t-c.CashAfter)/0.6)*math.pi)*12*c.Intensity
	local before,after=d.BeforeRank,d.AfterRank
	if after then
		local delta=before and ordinal(after)-ordinal(before) or 0; local promoted=before and after.Tier>before.Tier; local demoted=before and after.Tier<before.Tier
		self.RankLabel.Text=(promoted and "RANK UP! / " or demoted and "RANK DOWN / " or "")..P.Ranks[after.Tier]:upper()
		self.Icon.Text=self.IconAsset and "" or RankIcons.Fallback[P.Ranks[after.Tier]] or "*"
		local asset=Assets.rank(P.Ranks[after.Tier])
		if asset and asset~="" and not self.IconAsset then self.Icon.Text=""; self.IconAsset=U.new("ImageLabel","UploadedRankIcon",self.Icon,{Size=UDim2.fromScale(1,1),Image=asset,BackgroundTransparency=1,ZIndex=34}) end
		local required=P.Stars[after.Tier]; local target=required>0 and after.Stars/required or 1
		local start=before and P.Stars[before.Tier]>0 and before.Stars/P.Stars[before.Tier] or 0; local progress=math.clamp((t-c.RankAfter)/c.RankDuration,0,1)
		local fraction=start+(target-start)*progress
		if promoted then fraction=progress<0.5 and start+(1-start)*progress*2 or target*(progress-0.5)*2 elseif demoted then fraction=progress<0.5 and start*(1-progress*2) or target*(progress-0.5)*2 end
		self.Fill.Size=UDim2.fromScale(fraction,1); self.Fill.BackgroundColor3=delta<0 and U.colors.pink or U.colors.orange
		self.Stars.TextColor3=delta<0 and U.colors.pink or U.colors.yellow; self.Icon.Rotation=U.reducedMotion and 0 or (promoted and math.sin(math.clamp((t-c.RankAfter-c.RankDuration)/c.HighlightDuration,0,1)*math.pi)*8*c.Intensity or 0)
		self.Stars.Text=after.Tier==7 and ("RATING "..after.Rating) or (delta>0 and "+"..delta.." STAR"..(delta==1 and "" or "S") or delta<0 and tostring(delta).." STAR"..(delta==-1 and "" or "S") or "STARS UNCHANGED").." / "..after.Stars.." OF "..required
		if self.RankLabel.Visible and delta~=0 then self:once("Progress","RankProgress"); self:once("Star",delta>0 and "StarEarned" or "StarLost") end
		if progress>=1 then if promoted then self:once("Tier","RankUp") elseif demoted then self:once("Tier","RankDown") end end
	else self.RankLabel.Text="RANK UPDATE PENDING"; self.Stars.Text="Reconnect to check saved progression."; self.Bar.Visible=false
	end
end
function Results:destroy() self.Frame:Destroy() end
return Results
