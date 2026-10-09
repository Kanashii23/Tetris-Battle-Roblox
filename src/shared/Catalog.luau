local Catalog={Items={},Categories={"BrickSkins","DropEffects","GhostEffects","SoundPacks"},Slots={BrickSkins="BrickSkin",DropEffects="DropEffect",GhostEffects="GhostEffect",SoundPacks="SoundPack"}}
local sets={
	BrickSkins={"Default Classic","Neon Club","Cyber Core","Ocean Wave","Galaxy","Gold Elite","Lava","Crystal Glass","Retro Pixel","Holographic"},
	DropEffects={"Default","Neon Sparks","Lightning Strike","Stardust","Fire Burst","Pixel Explosion","Crystal Shatter","Cyber Glitch"},
	GhostEffects={"Default Outline","Neon Outline","Hologram","Pulse","Glitch","Prism","Electric"},
	SoundPacks={"Default","Retro Arcade","Cyber","Crystal","Neon Club"},
}
local hues={{0.15,0.9,1},{0.7,0.4,1},{0.1,0.7,1},{0.8,0.5,1},{1,0.8,0.2},{1,0.3,0.1},{0.7,0.9,1}}
for category,names in pairs(sets) do
	for index,name in ipairs(names) do
		local id=index==1 and "Default" or name:gsub("%s","")
		local item={Id=id,Name=name,Category=category,Rarity=index<4 and "Common" or (index<7 and "Rare" or "Epic"),Price=index==1 and 0 or (index-1)*175,
			Description="Cosmetic only. Changes appearance or sound; never gameplay.",Preview={Kind="T",Color=hues[(index-1)%#hues+1]},
			Visual={Tint=index==1 and nil or hues[(index-1)%#hues+1],Blend=0.12+(index%3)*0.08,Border=index%2==0,Transparency=category=="GhostEffects" and (0.72+(index%3)*0.05) or 0,Effect=index},
			Audio={Pack=id},
		}
		Catalog.Items[category..":"..id]=item
	end
end
function Catalog.list(category)
	local out={}; for _,item in pairs(Catalog.Items) do if item.Category==category then table.insert(out,item) end end
	table.sort(out,function(a,b) if a.Price==b.Price then return a.Name<b.Name end; return a.Price<b.Price end); return out
end
return Catalog
