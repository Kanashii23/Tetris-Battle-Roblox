local DSS=game:GetService("DataStoreService")
local Players=game:GetService("Players")
local Data=require(script.Parent:WaitForChild("PlayerDataService"))
local P=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Progression"))
local L={Cache={},Names={}}
local function stores(season)
	local prefix=Data.Namespace or Data.Config.DataStoreName..(game:GetService("RunService"):IsStudio() and "_Studio" or "_Live")
	return {
		GlobalRating=DSS:GetOrderedDataStore(prefix.."_Rating"),GlobalWins=DSS:GetOrderedDataStore(prefix.."_Wins"),
		SeasonRating=DSS:GetOrderedDataStore(prefix.."_S"..season.."_Rating"),SeasonWins=DSS:GetOrderedDataStore(prefix.."_S"..season.."_Wins"),
	}
end
function L:update(player)
	if Data.Debug then self.Cache={}; return end
	local d=Data:get(player); if not d then return end
	local metrics={GlobalRating=d.Rank.Rating,GlobalWins=d.Stats.QualifiedWins,SeasonRating=d.Season.Rating,SeasonWins=d.Season.Wins}
	for key,store in pairs(stores(d.Season.Id)) do
		local ok=pcall(function() store:SetAsync(tostring(player.UserId),math.floor(metrics[key])*10+d.Rank.Tier) end)
		if not ok then warn("[Leaderboard] Update delayed: "..key) end
	end
	self.Cache={}
end
function L:read(player,kind)
	local d=Data:get(player); if not d then return nil,"Profile unavailable" end
	if not ({GlobalRating=true,GlobalWins=true,SeasonRating=true,SeasonWins=true})[kind] then return nil,"Unknown leaderboard" end
	if Data.Debug then
		local rows={}
		for uid,profile in pairs(Data.Profiles) do local v=profile.Data; table.insert(rows,{UserId=uid,Name=profile.Player.Name,Value=kind=="GlobalRating" and v.Rank.Rating or kind=="GlobalWins" and v.Stats.QualifiedWins or kind=="SeasonRating" and v.Season.Rating or v.Season.Wins,Rank=P.Ranks[v.Rank.Tier]}) end
		table.sort(rows,function(a,b) return a.Value==b.Value and a.UserId<b.UserId or a.Value>b.Value end)
		return rows,"STUDIO TEST STANDINGS (this server only)"
	end
	local cacheKey=kind..d.Season.Id; local cached=self.Cache[cacheKey]
	if cached and cached.Time>os.clock()-60 then return cached.Rows end
	local ok,pages=pcall(function() return stores(d.Season.Id)[kind]:GetSortedAsync(false,100) end)
	if not ok then return nil,"Leaderboard temporarily unavailable" end
	local rows={}
	for position,entry in ipairs(pages:GetCurrentPage()) do
		local uid=tonumber(entry.key); local name=self.Names[uid]
		if not name then local success,value=pcall(function() return Players:GetNameFromUserIdAsync(uid) end); name=success and value or ("User "..uid); self.Names[uid]=name end
		table.insert(rows,{Position=position,UserId=uid,Name=name,Value=math.floor(entry.value/10),Rank=P.Ranks[entry.value%10]})
	end
	self.Cache[cacheKey]={Time=os.clock(),Rows=rows}; return rows
end
return L
