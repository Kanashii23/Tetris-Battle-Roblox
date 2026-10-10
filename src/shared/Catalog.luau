local Definition=if game then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CosmeticConfig")) else require("./Config/CosmeticConfig")
local Catalog={Items={},Categories={"BrickSkins","DropEffects","GhostEffects","SoundPacks"},Slots={BrickSkins="BrickSkin",DropEffects="DropEffect",GhostEffects="GhostEffect",SoundPacks="SoundPack"},Prices=Definition.Prices}
local hues={{0.15,0.9,1},{0.7,0.4,1},{0.1,0.7,1},{0.8,0.5,1},{1,0.8,0.2},{1,0.3,0.1},{0.7,0.9,1}}
for category,rows in pairs(Definition.Collections) do
	for index,definition in ipairs(rows) do
		local item=table.clone(definition); item.Category=category; item.Description="Cosmetic only. Shared live-board renderer; no gameplay advantages."
		item.Preview={Kind="T",Color=hues[(index-1)%#hues+1]}; item.Visual={Blend=0,Transparency=0,Effect=index}; item.Audio={Pack=item.Id}; Catalog.Items[category..":"..item.Id]=item
	end
end
function Catalog.list(category)
	local out={}; for _,item in pairs(Catalog.Items) do if item.Category==category then table.insert(out,item) end end
	table.sort(out,function(a,b) if a.Price==b.Price then return a.Name<b.Name end; return a.Price<b.Price end); return out
end
return Catalog
