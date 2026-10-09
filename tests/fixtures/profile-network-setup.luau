-- Remote equip integration uses the supplied library and actual player data service.
Players.List={}; Players.PlayerAdded=event(); Players.PlayerRemoving=event()
function Players:GetPlayerByUserId(uid) for _,p in ipairs(self.List) do if p.UserId==uid then return p end end end
local workspace={GetServerTimeNow=function() return now end}
local sent={}
local remote={OnServerEvent=event(),FireClient=function(_,p,kind,value) sent[p]=sent[p] or {}; sent[p][kind]=P.clone(value) end}
local originalNew=Instance.new
Instance.new=function(class) if class=="RemoteEvent" then return remote end; return originalNew(class) end
modules.LeaderboardService={update=function() end,read=function() return {} end}
local originalFire=RunService.Heartbeat.fire
function RunService.Heartbeat:fire() originalFire(self,0.01) end
