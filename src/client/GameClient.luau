local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Shared=RS:WaitForChild("Shared")
local Engine=require(Shared:WaitForChild("TetrisEngine"))
local Catalog=require(Shared:WaitForChild("Catalog"))
local Audio=require(script.Parent:WaitForChild("AudioController"))
local Input=require(script.Parent:WaitForChild("InputController"))
local Client={}; Client.__index=Client
function Client.new(hooks)
	local self=setmetatable({Hooks=hooks,Mode="Lobby",Profile=nil,LastEvent=0,State=nil,Blocked=false,Audio=Audio.new()},Client)
	self.Network=Shared:WaitForChild("Network")
	self.Input=Input.new(function(action,down)
		self:send("Input",{Action=action,Down=down})
	end,function(force) if self.Mode=="Solo" or self.Mode=="Ranked" or self.Mode=="Challenge" then hooks.Pause(force) end end)
	self.Connection=self.Network.OnClientEvent:Connect(function(kind,data)
		if kind=="Profile" then
			local previous=self.Profile; self.Profile=data
   local pending=self.PendingCosmetic; if pending and data then local slot=Catalog.Slots[pending.Category]; if pending.Kind=="Buy" and data.Inventory[pending.Category][pending.Id] or pending.Kind=="Equip" and data.Equipped[slot]==pending.Id then self.PendingCosmetic=nil end end
			if data then
				self.Audio.Pack=data.Equipped.SoundPack
				if previous then
					if previous.Season.Id~=data.Season.Id and #data.Season.History>#previous.Season.History then self.Audio:play("SeasonReward") end
					if data.Energy.Current>previous.Energy.Current then self.Audio:play("EnergyRestored") end
					for group,quests in pairs(data.Quests) do
						local old=previous.Quests[group]
						if old and old.Window==quests.Window then
							local P=require(Shared:WaitForChild("Progression"))
							for _,q in ipairs(P[group]) do if (quests.Progress[q.Id] or 0)>=q.Target and (old.Progress[q.Id] or 0)<q.Target then self.Audio:play("QuestComplete"); hooks.Message("Quest complete: "..q.Label) end end
						end
					end
				end
				hooks.Profile(data)
			end
		elseif kind=="Lobby" then self.Mode="Lobby"; self.State=nil; self.LastEvent=0; self.Input:enable(false); self.Audio:music("MenuMusic"); hooks.Lobby()
		elseif kind=="Searching" then self.Mode="Searching"; self.Input:enable(false); self.Audio:play("Matchmaking"); hooks.Searching(data)
		elseif kind=="Found" then self.Mode=data.Ranked and "Ranked" or "Challenge"; self.MatchId=data.MatchId; self.LastEvent=0; self.LastBattleEvent=0; self.Audio:play("OpponentFound"); hooks.Found(data)
		elseif kind=="State" then
			Engine.unpack(data.Own); Engine.unpack(data.Opponent)
			local changed=self.Mode~=data.Mode; self.Mode=data.Mode; self.State=data
			if data.MatchId and self.MatchId~=data.MatchId then self.LastEvent=0; self.LastBattleEvent=0; self.MatchId=data.MatchId end
			if changed then self.LastEvent=0 end
			self.Input:enable(data.Own.alive and not data.Own.paused and data.Countdown==0 and not self.Blocked)
			self.Audio:music(data.Mode=="Solo" and "SoloMusic" or "BattleMusic")
			for _,event in ipairs(data.Own.events) do if event.id>self.LastEvent then self.LastEvent=event.id; if event.name~="KO" or data.Mode=="Solo" then self.Audio:play(event.name); if hooks.Event then hooks.Event(event) end end end end
			hooks.State(data)
		elseif kind=="BattleEvent" then
			if data.MatchId==self.MatchId and data.Id>(self.LastBattleEvent or 0) then self.LastBattleEvent=data.Id; if hooks.BattleEvent then hooks.BattleEvent(data) end end
		elseif kind=="Result" then
			if data.Id and self.MatchId and data.Id~=self.MatchId then return end
			if self.LastResultId==data.Id and data.Id then return end; self.LastResultId=data.Id; self.ResultElapsed=0; self.ResultPhases={}
			Engine.unpack(data.Own); Engine.unpack(data.Opponent)
			self.Mode="Result"; self.Input:enable(false); self.Audio:music("MenuMusic"); self.Audio:warning(0,0)
			hooks.Result(data)
		elseif kind=="Leaderboard" then hooks.Leaderboard(data)
		elseif kind=="Challenge" then hooks.Challenge(data)
		elseif kind=="CosmeticResult" then
			self.PendingCosmetic=nil; self.LastCosmeticResult=data -- Profile remains the authority for equipped state.
			if hooks.CosmeticResult then hooks.CosmeticResult(data) end
		elseif kind=="Action" then self.Audio:play(data.Sound)
		elseif kind=="Message" then hooks.Message(data) end
	end)
	self.Alive=true
	task.spawn(function() while self.Alive do task.wait(15); if self.Alive then self:send("Refresh") end end end)
	self:send("Hello")
	return self
end
function Client:send(kind,payload)
	if kind=="Solo" or kind=="Restart" then self.LastEvent=0; if self.Hooks.ResetCosmetics then self.Hooks.ResetCosmetics() end end
	self.Network:FireServer(kind,payload)
end
function Client:block(value)
	self.Blocked=value
	local playing=self.Mode=="Solo" or self.Mode=="Ranked" or self.Mode=="Challenge"
	self.Input:enable(playing and not value and self.State and self.State.Own.alive and not self.State.Own.paused and self.State.Countdown==0 or false)
end
function Client:destroy() self.Alive=false; self.Connection:Disconnect(); self.Input:destroy(); self.Audio:destroy() end
function Client:colors(kind,ghost)
	local data=self.Profile
	local item=data and Catalog.Items[(ghost and "GhostEffects:" or "BrickSkins:")..data.Equipped[ghost and "GhostEffect" or "BrickSkin"]]
	return item and item.Visual
end
Client.Engine=Engine
return Client
