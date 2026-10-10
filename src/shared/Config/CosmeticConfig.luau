-- Stable IDs are save keys. Never rename or remove an existing owned cosmetic.
local Config={Prices={Common=2500,Rare=7500,Epic=20000,Legendary=50000,Mythic=125000},Collections={}}
local sets={
	BrickSkins={{"Default","Default Classic","Common"},{"NeonClub","Neon Club","Rare"},{"CyberCore","Cyber Core","Epic"},{"OceanWave","Ocean Wave","Common"},{"Galaxy","Galaxy","Legendary"},{"GoldElite","Gold Elite","Legendary"},{"Lava","Lava","Epic"},{"CrystalGlass","Crystal Glass","Epic"},{"RetroPixel","Retro Pixel","Common"},{"Holographic","Holographic","Legendary"},{"Glitch","Glitch","Epic"},{"RoyalPrism","Royal Prism","Mythic"}},
	DropEffects={{"Default","Default","Common"},{"NeonSparks","Neon Shockwave","Rare"},{"LightningStrike","Lightning Strike","Epic"},{"Stardust","Galaxy Collapse","Legendary"},{"FireBurst","Inferno Slam","Epic"},{"PixelExplosion","Pixel Impact","Common"},{"CrystalShatter","Crystal Shatter","Epic"},{"CyberGlitch","Cyber Glitch","Rare"},{"GoldenImpact","Golden Impact","Legendary"},{"RoyalPrism","Royal Prism","Mythic"}},
	GhostEffects={{"Default","Classic Outline","Common"},{"NeonOutline","Neon Outline","Rare"},{"Hologram","Hologram","Rare"},{"Pulse","Neon Pulse","Epic"},{"Glitch","Glitch Phantom","Epic"},{"Prism","Prism","Legendary"},{"Electric","Electric","Epic"},{"PixelDotted","Pixel Dotted","Common"},{"CyberScanline","Cyber Scanline","Rare"},{"CrystalOutline","Crystal Outline","Epic"},{"GoldenTrace","Golden Trace","Legendary"},{"GalaxyShadow","Galaxy Shadow","Legendary"},{"RoyalPrism","Royal Prism Ghost","Mythic"}},
	SoundPacks={{"Default","Default 8-Bit","Common"},{"RetroArcade","Retro Arcade","Common"},{"Cyber","Cyber","Rare"},{"Crystal","Crystal","Epic"},{"NeonClub","Neon Club","Rare"},{"GoldenElite","Golden Elite","Legendary"},{"Galaxy","Galaxy","Legendary"}},
}
for category,rows in pairs(sets) do
	Config.Collections[category]={}
	for _,row in ipairs(rows) do table.insert(Config.Collections[category],{Id=row[1],Name=row[2],Rarity=row[3],Price=row[1]=="Default" and 0 or Config.Prices[row[3]],DefaultOwned=row[1]=="Default"}) end
end
-- Display/render alias only: existing catalog/save IDs and prices remain unchanged.
function Config.AssetTheme(category,id)
 local ids=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CosmeticsAssetResolver"))
 local keys={BrickSkins="Bricks",GhostEffects="GhostFX",DropEffects="DropFX"}
 return ids.theme(keys[category],id)
end
return Config
