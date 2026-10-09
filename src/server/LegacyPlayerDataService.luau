local DSS=game:GetService("DataStoreService")
local Http=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local P=require(Shared:WaitForChild("Progression"))
local Catalog=require(Shared:WaitForChild("Catalog"))
local Config=require(script.Parent:WaitForChild("GameConfig"))
local Data={Profiles={},Debug=Config.Debug and RunService:IsStudio(),Config=Config}
local namespace=Config.DataStoreName..(RunService:IsStudio() and "_Studio" or "_Live")
local store=DSS:GetDataStore(namespace)
local inbox=DSS:GetDataStore(namespace.."_Results")
local owner=game.JobId~="" and game.JobId or Http:GenerateGUID(false)
local function retry(fn)
	local problem
	for attempt=1,4 do
		local ok,value=pcall(fn); if ok then return true,value end
		problem=value; if attempt<4 then task.wait(0.5*2^(attempt-1)) end
	end
	return false,tostring(problem)
end
local function acquire(profile)
	while profile.Busy do task.wait() end
	profile.Busy=true
end
function Data:load(player)
	local existing=self.Profiles[player.UserId]
	if existing and existing.Active then return existing.Player==player,"Data is already active in this server" end
	local now=os.time(); local profile={Player=player,Busy=false,Active=true,LastSave=now}
	if self.Debug then profile.Data=P.refresh(P.default(now),now,Config); self.Profiles[player.UserId]=profile; return true end
	local acquired=false
	local ok,value=retry(function()
		return store:UpdateAsync(tostring(player.UserId),function(old)
			old=old or {Data=P.default(now)}
			if old.Lease and old.Lease.Owner~=owner and old.Lease.Expires>now then return nil end
			local data=P.validate(P.clone(old.Data or old),now,Catalog,Config)
			P.refresh(data,now,Config); acquired=true
			return {Data=data,Lease={Owner=owner,Expires=now+Config.LockLease}}
		end)
	end)
	if not ok or not acquired or not value then return false,"Your data is unavailable or active in another server. Please reconnect." end
	profile.Data=value.Data; self.Profiles[player.UserId]=profile
	local readOK,pending=retry(function() return inbox:GetAsync(tostring(player.UserId)) end)
	if not readOK then self:release(player); return false,"Pending results could not be recovered. Please reconnect." end
	for id,result in pairs(pending or {}) do
		local settled=self:mutate(player,function(d) P.settle(d,result,Config); return true end)
		if not settled then self:release(player); return false,"Pending results could not be saved. Please reconnect." end
		retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old) old=old or {}; old[id]=nil; return old end) end)
	end
	-- An abandoned server cannot leave an unresolved energy charge behind.
	local recovered=self:mutate(player,function(d)
		for id in pairs(d.Reservations) do
			P.settle(d,{id=id..":refund",kind="Refund",roomId=id},Config)
		end
		return true
	end)
	if not recovered then self:release(player); return false,"Energy reservations could not be recovered. Please reconnect." end
	return true
end
function Data:get(player)
	local p=self.Profiles[player.UserId]; return p and p.Active and p.Data or nil
end
function Data:mutate(player,fn,context)
	local profile=self.Profiles[player.UserId]; if not profile or not profile.Active then return false,"Data not loaded" end
	acquire(profile)
	if not profile.Active then profile.Busy=false; return false,"Session closed" end
	local nextData=P.clone(profile.Data); P.refresh(nextData,os.time(),Config)
	local safe,accepted,message,code=xpcall(function() return fn(nextData) end,function(err) return debug.traceback(tostring(err),2) end)
	if not safe then
		profile.Busy=false
		if RunService:IsStudio() and Config.CosmeticDebugLogging then warn("[PlayerData] Mutation exception action="..tostring(context and context.Action).." category="..tostring(context and context.Category).." id="..tostring(context and context.Id).."\n"..accepted) end
		return false,"Unable to complete this action right now. Please try again.","InternalError"
	end
	if not accepted then profile.Busy=false; return false,message,code end
	if not self.Debug then
		local own=false
		local ok,written=retry(function()
			own=false
			return store:UpdateAsync(tostring(player.UserId),function(old)
				if not old or not old.Lease or old.Lease.Owner~=owner then return nil end
				own=true; return {Data=nextData,Lease={Owner=owner,Expires=os.time()+Config.LockLease}}
			end)
		end)
		if not ok or not own or not written then
			profile.Busy=false
			if ok and not written then profile.Active=false; player:Kick("Data session ownership was lost. Please reconnect.") end
			return false,"Saving failed; nothing was charged. Please retry."
		end
	end
	profile.Data=nextData; profile.LastSave=os.time(); profile.Busy=false; return true,message
end
function Data:settle(player,result)
	if not self.Debug then
		local ok=retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old)
			old=old or {}; old[result.id]=result; return old
		end) end)
		if not ok then return false end
	end
	local ok=self:mutate(player,function(d) P.settle(d,result,Config); return true end)
	if ok and not self.Debug then
		retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old) old=old or {}; old[result.id]=nil; return old end) end)
	end
	return ok
end
function Data:release(player)
	local profile=self.Profiles[player.UserId]; if not profile then return end
	acquire(profile); profile.Active=false
	if not self.Debug then
		local data=P.clone(profile.Data)
		retry(function() return store:UpdateAsync(tostring(player.UserId),function(old)
			if not old or not old.Lease or old.Lease.Owner~=owner then return nil end
			return {Data=data}
		end) end)
	end
	profile.Busy=false; self.Profiles[player.UserId]=nil
end
function Data:public(player)
	local d=self:get(player); if not d then return nil end
	local out=P.refresh(P.clone(d),os.time(),Config); out.ProcessedMatchIds=nil; out.MatchReceipts=nil; out.Reservations=nil; out.Pairs=nil; out.SocialRewards.Seen=nil
	out.Debug=self.Debug; out.Energy.Next=P.nextEnergy(out,os.time(),Config)
	out.DebugPrivileges={FreeCosmetics=self.Debug and Config.FreeCosmeticsInDebug,FreePurchases=self.Debug and Config.FreeShopPurchasesInDebug,InfiniteEnergy=self.Debug and Config.InfiniteEnergyInDebug}
	out.Economy={EnergyCap=Config.EnergyCap,BonusCap=Config.BonusEnergyCap,EnergyInterval=Config.EnergyInterval,RankedCost=Config.RankedCost,SocialEnergy=Config.SocialEnergy,SocialLimit=Config.SocialDailyLimit,SocialMinSeconds=Config.SocialMinSeconds,LoginCash=Config.LoginCash,LoginEnergy=Config.LoginEnergy,SeasonDays=Config.SeasonDays,WinCash=Config.WinCash}
	return out
end
task.spawn(function()
	while true do
		task.wait(5)
		for _,profile in pairs(Data.Profiles) do
			if profile.Active and os.time()-profile.LastSave>=Config.Autosave then
				task.spawn(function() Data:mutate(profile.Player,function() return true end) end)
			end
		end
	end
end)
return Data
