-- Central profile authority. Live rollout stays on the original backend until verified.
local DSS=game:GetService("DataStoreService")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local Config=require(script.Parent:WaitForChild("GameConfig"))
local studio=RunService:IsStudio()
if not studio and not Config.ProfileStoreLiveEnabled then
	return require(script.Parent:WaitForChild("LegacyPlayerDataService"))
end
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local P=require(Shared:WaitForChild("Progression"))
local Catalog=require(Shared:WaitForChild("Catalog"))
local ProfileStore=require(script.Parent:WaitForChild("ProfileStore"))
local Migration=require(script.Parent:WaitForChild("ProfileStoreMigration"))
local namespace=studio and Config.ProfileStoreTestDataStoreName or Config.DataStoreName.."_Live"
assert(type(namespace)=="string" and #namespace<=43,"ProfileStore namespace is missing or too long")
local Data={Profiles={},Loading={},Debug=studio and Config.Debug and not Config.ProfileStoreStudioPersistence,Config=Config,Namespace=namespace,Closing=false}
local playerStore=ProfileStore.New(namespace,P.default(0))
local store=DSS:GetDataStore(namespace)
local backup=DSS:GetDataStore(namespace.."_Backup")
local inbox=DSS:GetDataStore(namespace.."_Results")
local function retry(fn)
	local problem
	for attempt=1,4 do
		local values=table.pack(pcall(fn))
		if values[1] then return true,table.unpack(values,2,values.n) end
		problem=values[2]; if attempt<4 then task.wait(0.5*2^(attempt-1)) end
	end
	return false,tostring(problem)
end
local function active(entry) return entry and entry.Active and not entry.Releasing and entry.Profile:IsActive() end
local function endEntry(self,entry,unexpected)
	entry.Ready=false; entry.Active=false; entry.Releasing=true
	if entry.Profile:IsActive() then entry.Profile:EndSession() end
	if self.Profiles[entry.Player.UserId]==entry then self.Profiles[entry.Player.UserId]=nil end
	if unexpected and entry.Player.Parent==Players and not self.Closing and not ProfileStore.IsClosing then entry.Player:Kick("Your data session ended. Please reconnect; your existing save was not reset.") end
end
local function commit(self,entry,nextData)
	if not active(entry) then return false,"Data session closed" end
	local token=Http:GenerateGUID(false); nextData._TetrisSaveToken=token
	entry.Profile.Data=nextData; entry.Data=nextData
	if self.Debug then return true end -- Explicit Studio-only ProfileStore.Mock session.
	local deadline=os.clock()+Config.ProfileSaveTimeout; local nextAttempt=0
	while active(entry) and os.clock()<deadline do
		if entry.Profile.LastSavedData._TetrisSaveToken==token then return true end
		if os.clock()>=nextAttempt then entry.Profile:Save(); nextAttempt=os.clock()+2 end
		if entry.Profile.LastSavedData._TetrisSaveToken==token and active(entry) then return true end
		task.wait(0.05)
	end
	-- The write may already have reached Roblox. Preserve the atomic Cash/item pair,
	-- close access and let ProfileStore finish its final save instead of pretending to roll it back.
	endEntry(self,entry,not entry.Releasing)
	return false,"Save confirmation was interrupted. Reconnect to check the completed operation."
end
function Data:load(player)
	local existing=self.Profiles[player.UserId]
	if active(existing) then return existing.Player==player and existing.Ready,"Data is already active in this server" end
	if self.Loading[player.UserId] then return false,"A profile load is already in progress" end
	self.Loading[player.UserId]=player
	local deadline=os.clock()+Config.ProfileLoadTimeout
	local function cancelled() return self.Closing or ProfileStore.IsClosing or player.Parent~=Players or os.clock()>=deadline end
	local function fail(text,entry)
		if entry then endEntry(self,entry,false) end
		if self.Loading[player.UserId]==player then self.Loading[player.UserId]=nil end
		return false,text
	end
	if cancelled() then return fail("Profile loading was cancelled") end
	if not self.Debug then
		while ProfileStore.DataStoreState=="NotReady" and not cancelled() do task.wait(0.05) end
		if cancelled() or ProfileStore.DataStoreState~="Access" then return fail("Persistent data is unavailable. Enable API access in the separate test experience; no mock production profile was created.") end
		local prepared,text=Migration.prepare(store,backup,tostring(player.UserId),player.UserId,Config.ProfileStoreMigrateLegacy,retry,cancelled)
		if not prepared then return fail(text) end
	end
	local target=self.Debug and playerStore.Mock or playerStore
	local started,profile=pcall(function() return target:StartSessionAsync(tostring(player.UserId),{Cancel=cancelled}) end)
	if not started or not profile then return fail("Your profile could not be loaded. No purchases or rewards were enabled; please reconnect.") end
	local entry={Player=player,Profile=profile,Data=profile.Data,Active=true,Ready=false,Busy=false,Releasing=false}
	self.Profiles[player.UserId]=entry
	profile.OnSessionEnd:Connect(function()
		local unexpected=not entry.Releasing
		entry.Active=false; entry.Ready=false
		if self.Profiles[player.UserId]==entry then self.Profiles[player.UserId]=nil end
		if unexpected and player.Parent==Players and not self.Closing and not ProfileStore.IsClosing then player:Kick("Your data session ended. Please reconnect.") end
	end)
	if cancelled() or not profile:IsActive() then return fail("Profile loading was cancelled",entry) end
	local checked,text=Migration.payloadValid(profile.Data); if not checked then return fail(text,entry) end
	local initialized,problem=pcall(function()
		profile:AddUserId(player.UserId); profile:Reconcile()
		if profile.Data.CreatedAt==0 then profile.Data.CreatedAt=profile.FirstSessionTime end
		entry.Data=P.validate(P.clone(profile.Data),os.time(),Catalog,Config); profile.Data=entry.Data
	end)
	if not initialized then return fail("Your existing profile needs manual inspection; it was not reset. "..tostring(problem),entry) end
	local pending={}
	if not self.Debug then
		local readOK,value=retry(function() return inbox:GetAsync(tostring(player.UserId)) end)
		if not readOK or value~=nil and type(value)~="table" then return fail("Pending results could not be recovered. Please reconnect.",entry) end
		pending=value or {}
	end
	local nextData=P.clone(entry.Data); P.refresh(nextData,os.time(),Config)
	local recovered,recoverError=pcall(function()
		for _,result in pairs(pending) do P.settle(nextData,result,Config) end
		for id in pairs(nextData.Reservations) do P.settle(nextData,{id=id..":refund",kind="Refund",roomId=id},Config) end
	end)
	if not recovered then return fail("Pending results need manual inspection: "..tostring(recoverError),entry) end
	entry.Busy=true; local saved,message=commit(self,entry,nextData); entry.Busy=false
	if not saved then return fail(message,entry) end
	if not self.Debug and next(pending) then
		retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old)
			old=old or {}; for id in pairs(pending) do if entry.Profile.LastSavedData.ProcessedMatchIds[id] then old[id]=nil end end; return old
		end) end)
	end
	if cancelled() or not active(entry) then return fail("Profile loading was cancelled",entry) end
	entry.Ready=true; self.Loading[player.UserId]=nil; return true
end
function Data:get(player)
	local entry=self.Profiles[player.UserId]
	return active(entry) and entry.Ready and entry.Player==player and entry.Data or nil
end
function Data:mutate(player,fn,context)
	local entry=self.Profiles[player.UserId]
	if not active(entry) or not entry.Ready or entry.Player~=player then return false,"Data not loaded" end
	while entry.Busy and active(entry) do task.wait() end
	if not active(entry) or not entry.Ready then return false,"Session closed" end
	entry.Busy=true
	local nextData=P.clone(entry.Data); P.refresh(nextData,os.time(),Config)
	local safe,accepted,message,code=xpcall(function() return fn(nextData) end,function(err) return debug.traceback(tostring(err),2) end)
	if not safe then
		entry.Busy=false
		if studio and Config.CosmeticDebugLogging then warn("[PlayerData] Mutation exception action="..tostring(context and context.Action).." category="..tostring(context and context.Category).." id="..tostring(context and context.Id).."\n"..accepted) end
		return false,"Unable to complete this action right now. Please try again.","InternalError"
	end
	if not accepted then entry.Busy=false; return false,message,code end
	local saved,text=commit(self,entry,nextData); entry.Busy=false
	return saved,saved and message or text
end
function Data:settle(player,result)
	if type(result)~="table" or type(result.id)~="string" then return false end
	if not self.Debug then
		local journaled=retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old) old=old or {}; old[result.id]=P.clone(result); return old end) end)
		if not journaled then return false end
	end
	local saved=self:mutate(player,function(d) P.settle(d,result,Config); return true end)
	if saved and not self.Debug then
		local entry=self.Profiles[player.UserId]
		if entry and entry.Profile.LastSavedData.ProcessedMatchIds[result.id] then
			retry(function() return inbox:UpdateAsync(tostring(player.UserId),function(old) old=old or {}; old[result.id]=nil; return old end) end)
		end
	end
	return saved
end
function Data:release(player)
	local entry=self.Profiles[player.UserId]; if not entry or entry.Player~=player then return end
	entry.Ready=false; entry.Releasing=true
	while entry.Busy do task.wait() end
	endEntry(self,entry,false)
end
function Data:public(player)
	local d=self:get(player); if not d then return nil end
	local out=P.refresh(P.clone(d),os.time(),Config); out.ProcessedMatchIds=nil; out.MatchReceipts=nil; out.Reservations=nil; out.Pairs=nil; out.SocialRewards.Seen=nil; out._TetrisSaveToken=nil
	out.Debug=self.Debug; out.Energy.Next=P.nextEnergy(out,os.time(),Config)
	out.DebugPrivileges={FreeCosmetics=self.Debug and Config.FreeCosmeticsInDebug,FreePurchases=self.Debug and Config.FreeShopPurchasesInDebug,InfiniteEnergy=self.Debug and Config.InfiniteEnergyInDebug}
	out.Economy={EnergyCap=Config.EnergyCap,BonusCap=Config.BonusEnergyCap,EnergyInterval=Config.EnergyInterval,RankedCost=Config.RankedCost,SocialEnergy=Config.SocialEnergy,SocialLimit=Config.SocialDailyLimit,SocialMinSeconds=Config.SocialMinSeconds,LoginCash=Config.LoginCash,LoginEnergy=Config.LoginEnergy,SeasonDays=Config.SeasonDays,WinCash=Config.WinCash}
	return out
end
game:BindToClose(function() Data.Closing=true end)
print("[PlayerData] ProfileStore / "..(Data.Debug and "Studio mock" or studio and "isolated persistence test" or "live persistence").." / "..namespace)
return Data
