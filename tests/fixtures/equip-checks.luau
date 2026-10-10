local shopper=player(11001); shopper.AccountAge=365
Players.PlayerAdded:fire(shopper); tick(0.1); assert(Data:get(shopper))
local function request(category,id)
	S.Buckets={}; sent[shopper].CosmeticResult=nil
	send(shopper,"Equip",{Category=category,Id=id}); tick(0.1)
	return assert(sent[shopper].CosmeticResult,"No structured cosmetic response")
end
local balance=Data:get(shopper).Cash
for category,slot in pairs(Catalog.Slots) do
	local reply=request(category,"Default")
	assert(reply.Success and reply.Code=="OK" and Data:get(shopper).Equipped[slot]=="Default")
	assert(Data:get(shopper).Cash==balance)
end
print("PASS all four default cosmetics equip through the real remote without spending Cash")
local chosen={}; assert(Data:mutate(shopper,function(d)
	d.Cash=125000
	for category in pairs(Catalog.Slots) do local item=Catalog.list(category)[2]; chosen[category]=item.Id; d.Inventory[category][item.Id]=true end
	return true
end))
for category,slot in pairs(Catalog.Slots) do
	for _,id in ipairs({chosen[category],"Default",chosen[category]}) do
		local reply=request(category,id); assert(reply.Success and reply.Category==category and reply.Id==id)
		assert(Data:get(shopper).Equipped[slot]==id and Data:get(shopper).Cash==125000)
	end
end
print("PASS repeated owned skin/drop/ghost/sound equips preserve Cash and return accurate success payloads")
local missing=Catalog.list("BrickSkins")[3].Id; local reply=request("BrickSkins",missing)
assert(not reply.Success and reply.Code=="NotOwned" and reply.Message=="You don't own this cosmetic yet.")
assert(Data:get(shopper).Equipped.BrickSkin==chosen.BrickSkins and Data:get(shopper).Cash==125000)
for _,pair in ipairs({{"BrickSkins","Missing"},{"Unknown","Default"},{"HardDropEffects","Default"}}) do
	reply=request(pair[1],pair[2]); assert(not reply.Success and reply.Code=="Unavailable")
end
S.Buckets={}; send(shopper,"Equip",{Category={},Id=5}); assert(sent[shopper].CosmeticResult.Code=="Unavailable")
print("PASS unowned, mismatched and malformed cosmetic requests reject without changing equipped state")
-- Exercise the import on Buy as well; then equip an actually purchased item.
S.Buckets={}; send(shopper,"Buy",{Category="BrickSkins",Id=missing}); tick(0.1)
assert(sent[shopper].CosmeticResult.Success and Data:get(shopper).Inventory.BrickSkins[missing])
balance=125000-Catalog.Items["BrickSkins:"..missing].Price
reply=request("BrickSkins",missing); assert(reply.Success and Data:get(shopper).Cash==balance); chosen.BrickSkins=missing
Data:release(shopper); tick(0.1)
local reloaded; task.spawn(function() reloaded=Data:load(shopper) end); tick(0.3); assert(reloaded)
for category,slot in pairs(Catalog.Slots) do assert(Data:get(shopper).Equipped[slot]==chosen[category]) end
assert(Data:get(shopper).Cash==balance)
print("PASS remote purchase then equip and rejoin preserve ownership, all equipped slots and exact Cash")
local success,text,code=Data:mutate(shopper,function() error("equip-test-private-stack-marker") end,{Action="Equip",Category="BrickSkins",Id="Default"})
assert(not success and code=="InternalError" and not text:find("private%-stack") and Data:get(shopper).Cash==balance)
if RunService:IsStudio() then assert(warnings[#warnings]:find("equip-test-private-stack-marker",1,true) and warnings[#warnings]:find("action=Equip",1,true)) end
print("PASS mutation exceptions return an internal code without exposing server traces or changing data")
Data:release(shopper); reply=request("BrickSkins","Default")
assert(not reply.Success and reply.Code=="DataNotLoaded" and reply.Message=="Your player data is still loading.")
print("PASS unloaded profiles cannot equip or receive false success")
