local modules={TetrisEngine=E,Progression=P,Rules=R,Catalog=Catalog,GameConfig=C}
local now=0
local delayed={}
local task={}
function task.wait(seconds) return coroutine.yield(seconds or 0.01) end
function task.spawn(fn,...)
	local co=coroutine.create(fn); local ok,delay=coroutine.resume(co,...); assert(ok,delay)
	if coroutine.status(co)~="dead" then table.insert(delayed,{Co=co,At=now+(delay or 0.01)}) end
end
function task.delay(delay,fn) table.insert(delayed,{Co=coroutine.create(fn),At=now+delay}) end
local function event()
	local e={Listeners={}}
	function e:Connect(fn) table.insert(self.Listeners,fn); return {Disconnect=function() end} end
	function e:fire(...) for _,fn in ipairs(self.Listeners) do task.spawn(fn,...) end end
	return e
end
local records={}
local failWrites=false
local rejectAfterInboxRead=false
local DSS={}
function DSS:GetDataStore(name)
	records[name]=records[name] or {}; local rows=records[name]
	return {UpdateAsync=function(_,key,fn)
		if failWrites then error("simulated outage") end
		local value=fn(P.clone(rows[key])); if value~=nil then rows[key]=P.clone(value) end; return P.clone(value)
	end,GetAsync=function(_,key) if rejectAfterInboxRead and name:match("_Results$") then failWrites=true end; return P.clone(rows[key]) end,SetAsync=function(_,key,value) rows[key]=value end}
end
function DSS:GetOrderedDataStore(name)
	local store=self:GetDataStore(name)
	store.GetSortedAsync=function() return {GetCurrentPage=function() return {} end} end
	return store
end
local Players={PlayerAdded=event(),PlayerRemoving=event(),List={}}
function Players:GetPlayers() return self.List end
function Players:GetPlayerByUserId(uid) for _,p in ipairs(self.List) do if p.UserId==uid then return p end end end
function Players:GetNameFromUserIdAsync(uid) return "User"..uid end
local folder={WaitForChild=function(_,key) return key end}
local shared={WaitForChild=function(_,key) return key=="Config" and folder or key end}
local RS={WaitForChild=function() return shared end}
local RunService={Heartbeat=event(),IsStudio=function() return false end}
local guid=0
local Http={GenerateGUID=function() guid+=1; return "test-match-"..guid end}
local game={JobId="mock-server",GetService=function(_,key) return ({Players=Players,ReplicatedStorage=RS,RunService=RunService,HttpService=Http,DataStoreService=DSS})[key] end,BindToClose=function(_,fn) end}
local workspace={GetServerTimeNow=function() return now end}
local sent={}
local remote={OnServerEvent=event(),FireClient=function(_,player,kind,data)
	sent[player]=sent[player] or {}; sent[player][kind]=P.clone(data)
end}
local Instance={new=function() return remote end}
local script={Parent=folder}
local require=function(name) assert(modules[name],"Unknown require "..tostring(name)); return modules[name] end
local warn=function(...) print(...) end
local function player(uid)
	local p={UserId=uid,Name="Player"..uid,DisplayName="Player"..uid,AccountAge=365,Parent=Players,Kick=function(self,text) self.Kicked=text end,IsFriendsWithAsync=function() return true end}
	table.insert(Players.List,p); return p
end
local function tick(seconds)
	local steps=math.ceil(seconds*60)
	for _=1,steps do
		now+=1/60; RunService.Heartbeat:fire(1/60)
		for i=#delayed,1,-1 do local scheduled=delayed[i]; if scheduled.At<=now then
			table.remove(delayed,i); local ok,delay=coroutine.resume(scheduled.Co); assert(ok,delay)
			if coroutine.status(scheduled.Co)~="dead" then table.insert(delayed,{Co=scheduled.Co,At=now+(delay or 0.01)}) end
		end end
	end
end
