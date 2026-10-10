local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared:WaitForChild("Config"):WaitForChild("UIAssetConfig"))
local Ranks=require(Shared.Config:WaitForChild("RankIconConfig"))
local Currency=require(Shared.Config:WaitForChild("CurrencyIconConfig"))
local Assets={Config=Config}
function Assets.uri(key)
 local value=Config
 for part in key:gmatch("[^%.]+") do value=type(value)=="table" and value[part] or nil end
 return Config.ImageUri(value)
end
function Assets.rank(name)
 local current=Config.ImageUri(Ranks.Icons[name]); if current~="" then return current end
 local optional=Config.OptionalReferenceRanks
 return optional.Enabled and optional.Mapping[name] and Config.ImageUri(optional.Images[optional.Mapping[name]]) or ""
end
function Assets.currency(name)
 return Assets.uri("Images.currency."..name:lower())~="" and Assets.uri("Images.currency."..name:lower()) or Config.ImageUri(Currency[name])
end
function Assets.cosmetic(item)
 local key=Config.CosmeticArtwork[item.Category] and Config.CosmeticArtwork[item.Category][item.Id]
 if item.Category=="SoundPacks" then key="sound_pack" end
 return key and Assets.uri("Images.cosmetics."..key) or ""
end
function Assets.image(UI,parent,name,uri)
 return UI.new("ImageLabel",name,parent,{BackgroundTransparency=1,Image=uri,Visible=uri~="",ScaleType=Enum.ScaleType.Fit,ResampleMode=Enum.ResamplerMode.Pixelated,ZIndex=parent.ZIndex+1})
end
function Assets.icon(UI,parent,key)
 local icon=Assets.image(UI,parent,"AssetIcon",Assets.uri(key)); icon.Size=UDim2.fromOffset(28,28); icon.Position=UDim2.new(0,10,0.5,-14)
 if icon.Visible and parent:IsA("TextButton") then local pad=UI.new("UIPadding","IconPadding",parent,{PaddingLeft=UDim.new(0,38),PaddingRight=UDim.new(0,6)}); parent.TextSize=math.min(parent.TextSize,13) end
 return icon
end
return Assets
