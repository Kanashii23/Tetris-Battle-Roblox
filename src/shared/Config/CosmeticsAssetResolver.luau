-- Checked canonical mapping shared by gameplay, HOLD/NEXT and previews.
local Resolver={}
local metadata=require(script.Parent:WaitForChild("CosmeticsAssetMetadata"))
local ids=require(script.Parent:WaitForChild("CosmeticsAssetIds"))
local prefixes={DefaultClassic="Default",Default="Default",OceanWave="OceanWave",RetroPixel="RetroPixel",NeonClub="NeonClub",CrystalGlass="CrystalGlass",CyberCore="CyberCore",Glitch="Glitch",Lava="Lava",Galaxy="Galaxy",GoldElite="GoldElite",Holographic="Holographic",RoyalPrism="RoyalPrism"}
local pieces={I=true,O=true,T=true,S=true,Z=true,J=true,L=true}
function Resolver.uri(value)
 if type(value)~="string" then return "" end
 if value:match("^%d+$") then return "rbxassetid://"..value end
 if value:match("^rbxassetid://%d+$") then return value end
 return ""
end
function Resolver.theme(category,id)
 return metadata.Aliases[category] and metadata.Aliases[category][id] or id or "DefaultClassic"
end
function Resolver.key(category,theme,piece,component)
 local prefix=prefixes[theme]
 if not prefix or not pieces[piece] then return nil end
 if category=="Bricks" and not component then return prefix,"Brick "..prefix.." "..piece end
 if category=="GhostFX" and not component then return prefix,"GhostFx "..prefix.." GhostFX "..piece end
 if category=="DropFX" and (component=="Ripple" or component=="WhiteBase" or component=="Droplet") then return prefix,"Drop "..prefix.." "..piece.." "..component end
 return nil
end
function Resolver.resolve(category,id,piece,component)
 local theme=Resolver.theme(category,id)
 local prefix,key=Resolver.key(category,theme,piece,component)
 return Resolver.uri(prefix and ids[prefix] and ids[prefix][key]),theme
end
return Resolver
