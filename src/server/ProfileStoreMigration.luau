-- Converts only recognized legacy envelopes after making an immutable backup.
-- ProfileStore itself is installed unchanged. No cloud calls run from this module on require.
local P=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Progression"))
local Migration={}
local function payloadValid(data)
	if type(data)~="table" then return false,"Profile data is not a table" end
	if data.SchemaVersion~=nil and (type(data.SchemaVersion)~="number" or data.SchemaVersion>1) then return false,"Unsupported profile schema" end
	if data.Cash~=nil and (type(data.Cash)~="number" or data.Cash~=data.Cash or data.Cash<0 or data.Cash==math.huge) then return false,"Invalid Cash data" end
	for _,key in ipairs({"Energy","Rank","Stats","Inventory","Equipped","Season","Quests","Login","Achievements","Settings","ProcessedMatchIds","MatchReceipts","Reservations","Pairs","SocialRewards"}) do
		if data[key]~=nil and type(data[key])~="table" then return false,"Invalid "..key.." data" end
	end
	local function shape(actual,template,path)
		for key,expected in pairs(template) do local value=actual[key]
			if value~=nil then
				if type(value)~=type(expected) then return false,"Invalid "..path..key.." data" end
				if type(value)=="number" and (value~=value or math.abs(value)==math.huge) then return false,"Invalid "..path..key.." number" end
				if type(expected)=="table" then local ok,text=shape(value,expected,path..key.."."); if not ok then return false,text end end
			end
		end
		return true
	end
	local compatible,message=shape(data,P.default(0),""); if not compatible then return false,message end
	return true
end
Migration.payloadValid=payloadValid
function Migration.isProfileStore(record)
	return type(record)=="table" and type(record.Data)=="table" and type(record.MetaData)=="table"
		and type(record.MetaData.SessionLoadCount)=="number" and type(record.GlobalUpdates)=="table"
		and type(record.GlobalUpdates[1])=="number" and type(record.GlobalUpdates[2])=="table"
end
function Migration.prepare(store,backup,key,userId,allowConversion,retry,cancelled)
	local readOK,record,info=retry(function() return store:GetAsync(key) end)
	if not readOK then return false,"Existing save could not be read; no default profile was created." end
	if cancelled() then return false,"Profile loading was cancelled" end
	if record==nil then return true end
	if Migration.isProfileStore(record) then return payloadValid(record.Data) end
	if type(record)~="table" then return false,"Unrecognized save format; existing data was left untouched." end
	if record.MetaData~=nil or record.GlobalUpdates~=nil then return false,"Malformed ProfileStore envelope; restore or inspect it manually. Migration did not replace it." end
	local data=record.Data~=nil and record.Data or record
	local valid,problem=payloadValid(data); if not valid then return false,problem end
	if data.SchemaVersion==nil and data.Cash==nil and data.Rank==nil and data.Energy==nil then return false,"Unrecognized legacy profile; migration refused." end
	if record.Lease~=nil then
		if type(record.Lease)~="table" or type(record.Lease.Expires)~="number" then return false,"Invalid legacy lease; migration refused." end
		if record.Lease.Expires>os.time() then return false,"A legacy server still owns this profile. Reconnect after it closes." end
	end
	if not allowConversion then return false,"Legacy conversion is disabled; existing data was left untouched." end
	local version=info and info.Version
	if type(version)~="string" then return false,"Existing save version could not be verified; migration refused." end
	local backupOK,snapshot=retry(function()
		return backup:UpdateAsync(key,function(old)
			if old~=nil then return old.SourceVersion==version and old or nil end
			return {Original=P.clone(record),SourceVersion=version,BackedUpAt=os.time(),UserId=userId}
		end)
	end)
	if not backupOK or not snapshot or snapshot.SourceVersion~=version then return false,"Legacy backup could not be verified; conversion was not performed." end
	if cancelled() then return false,"Profile loading was cancelled" end
	local migrated=false
	local writeOK,written=retry(function()
		return store:UpdateAsync(key,function(latest,keyInfo)
			migrated=false
			if Migration.isProfileStore(latest) then migrated=true; return latest end
			if not keyInfo or keyInfo.Version~=version or cancelled() then return nil end
			if latest.Lease and latest.Lease.Expires>os.time() then return nil end
			migrated=true
			return {Data=P.clone(data),MetaData={ProfileCreateTime=data.CreatedAt or os.time(),SessionLoadCount=0,LastUpdate=os.time(),MetaTags={}},
				RobloxMetaData={TetrisLegacySourceVersion=version},UserIds={userId},GlobalUpdates={0,{}}}
		end)
	end)
	if not writeOK or not migrated or not written then return false,"Existing save changed during migration; no player data was replaced." end
	return payloadValid(written.Data)
end
return Migration
