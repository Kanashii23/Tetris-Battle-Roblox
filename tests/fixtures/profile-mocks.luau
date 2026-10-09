-- Roblox service doubles only: the supplied ProfileStore implementation executes below.
-- No mock ProfileStore/Profile objects are substituted for the library in these checks.
C.ProfileStoreLiveEnabled=true; C.ProfileStoreStudioPersistence=true
C.DataStoreName="TetrisBattle_ProfileHarness"; C.ProfileSaveTimeout=3; C.ProfileLoadTimeout=5
local realOS=os; local now=0; local epoch=1791590400
local os={time=function() return epoch+math.floor(now) end,clock=function() return now end,date=realOS.date}
local scheduled={}; local task={}
local function resume(co,...)
	local ok,value=coroutine.resume(co,...); assert(ok,value)
	if coroutine.status(co)~="dead" and type(value)=="table" and value.Wait then table.insert(scheduled,{Co=co,At=now+value.Wait}) end
end
function task.wait(seconds) return coroutine.yield({Wait=seconds or 0.01}) end
function task.spawn(fn,...)
	local co=type(fn)=="thread" and fn or coroutine.create(fn); resume(co,...); return co
end
function task.defer(fn,...) local args=table.pack(...); task.delay(0,function() fn(table.unpack(args,1,args.n)) end) end
function task.delay(seconds,fn) local co=coroutine.create(fn); table.insert(scheduled,{Co=co,At=now+seconds}); return co end
local function event()
	local e={Handlers={}}
	function e:Connect(fn) table.insert(self.Handlers,fn); return {Disconnect=function() for i,item in ipairs(self.Handlers) do if item==fn then table.remove(self.Handlers,i); break end end end} end
	function e:fire(...) for _,fn in ipairs(table.clone(self.Handlers)) do task.spawn(fn,...) end end
	return e
end
local RunService={Heartbeat=event(),IsStudio=function() return false end}
local records,versions={},{}; local faults={Reads={},Writes={},Latency={},AfterWrite={}}
local function keyInfo(name,key)
	if records[name][key]==nil then return nil end
	return {Version="version-"..(versions[name][key] or 0),CreatedTime=epoch*1000,UpdatedTime=os.time()*1000,GetMetadata=function() return {} end,GetUserIds=function() return {} end}
end
local DSS={}
function DSS:GetDataStore(name)
	records[name]=records[name] or {}; versions[name]=versions[name] or {}
	return {
		GetAsync=function(_,key)
			if faults.Reads[name] then error("simulated read outage") end
			if faults.Latency[name] then task.wait(faults.Latency[name]) end
			return P.clone(records[name][key]),keyInfo(name,key)
		end,
		UpdateAsync=function(_,key,transform)
			if faults.Writes[name] then error("simulated write outage") end
			if faults.Latency[name] then task.wait(faults.Latency[name]) end
			local nextData=transform(P.clone(records[name][key]),keyInfo(name,key))
			if nextData==nil then return nil end
			records[name][key]=P.clone(nextData); versions[name][key]=(versions[name][key] or 0)+1
			if faults.AfterWrite[name] then faults.AfterWrite[name](key) end
			return P.clone(nextData),keyInfo(name,key)
		end,
		SetAsync=function(_,key,value) records[name][key]=P.clone(value); versions[name][key]=(versions[name][key] or 0)+1 end,
	}
end
local Players={List={}}
function Players:GetPlayers() return self.List end
local guid=0; local Http={GenerateGUID=function() guid+=1; return "profile-test-"..guid end}
local Messaging={SubscribeAsync=function() return {Disconnect=function() end} end,PublishAsync=function() end}
local folder={WaitForChild=function(_,key) return key end}
local shared={WaitForChild=function(_,key) return key=="Config" and folder or key end}
local RS={WaitForChild=function() return shared end}
local closeCallbacks={}
local game={PlaceId=100,JobId="profile-test-server",GetService=function(_,key) return ({DataStoreService=DSS,Players=Players,HttpService=Http,MessagingService=Messaging,RunService=RunService,ReplicatedStorage=RS})[key] end,BindToClose=function(_,fn) table.insert(closeCallbacks,fn) end}
local Instance={new=function(class) assert(class=="DataStoreOptions"); return {SetExperimentalFeatures=function() end} end}
local typeof=type; local Enum={SortDirection={}}
local script={Name="ProfileStore",Parent=folder}
local modules={Progression=P,TetrisEngine=E,Rules=R,Catalog=Catalog,GameConfig=C}
local require=function(name) return assert(modules[name],"Unknown module "..tostring(name)) end
local warningCount=0; local warnings={}; local warn=function(value) warningCount+=1; table.insert(warnings,tostring(value)) end
local function player(uid)
	local p={UserId=uid,Parent=Players,Name="Player"..uid,DisplayName="Player"..uid,Kick=function(self,text) self.Kicked=text end}
	table.insert(Players.List,p); return p
end
local function tick(seconds)
	for _=1,math.ceil(seconds*100) do
		now+=0.01; RunService.Heartbeat:fire()
		local ready={}; for i=#scheduled,1,-1 do if scheduled[i].At<=now then table.insert(ready,table.remove(scheduled,i).Co) end end
		for _,co in ipairs(ready) do if coroutine.status(co)=="suspended" then resume(co) end end
	end
end
local function seed(name,key,value) DSS:GetDataStore(name):SetAsync(tostring(key),value) end
local function async(fn,seconds)
	local result; task.spawn(function() result=table.pack(fn()) end); tick(seconds or 10); assert(result,"Async operation did not finish")
	return table.unpack(result,1,result.n)
end
