local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared:WaitForChild("Config"):WaitForChild("UIAssetConfig"))
local Ranks=require(Shared.Config:WaitForChild("RankIconConfig"))
local Currency=require(Shared.Config:WaitForChild("CurrencyIconConfig"))
local Assets={Config=Config}
local ContentProvider=game:GetService("ContentProvider")
local requested={}
-- Non-blocking, deduplicated requests. A configured ID does not prove delivery.
function Assets.preload(uri)
 if uri=="" or requested[uri] then return end
 requested[uri]=true
 task.spawn(function()
  local ok,err=pcall(function()
   ContentProvider:PreloadAsync({uri},function(content,status)
    if status~=Enum.AssetFetchStatus.Success then
     warn("[Tetris UI image] "..content.." failed: "..status.Name..". Check this image's permission/moderation in Creator Dashboard.")
    end
   end)
  end)
  if not ok then warn("[Tetris UI image] "..uri..": "..tostring(err)) end
 end)
end
function Assets.uri(key)
 local value=Config
 for part in key:gmatch("[^%.]+") do value=type(value)=="table" and value[part] or nil end
 return Config.ImageUri(value)
end
function Assets.rank(name)
 if type(name)~="string" then return "" end
 local current=Config.ImageUri(Ranks.Icons[name]); if current~="" then return current end
 local optional=Config.OptionalReferenceRanks
 local key=optional.Mapping[name] or name:lower()
 return optional.Enabled and Config.ImageUri(optional.Images[key]) or ""
end
-- Bind the same configured lookup everywhere; keep a truthful visible fallback until loaded.
function Assets.bindRank(UI,image,name)
 local fallback=image:FindFirstChild("RankFallback")
 if not fallback then
  fallback=UI.text("RankFallback",image,"",13,UI.colors.orange,UI.theme.Fonts.Strong)
  fallback.Size=UDim2.fromScale(1,1); fallback.TextXAlignment=Enum.TextXAlignment.Center
  image.ScaleType=Enum.ScaleType.Fit; image.ImageColor3=Color3.fromRGB(255,255,255)
  image.BackgroundTransparency=1; image.Active=false
  image:GetPropertyChangedSignal("IsLoaded"):Connect(function()
   fallback.Visible=image.Image=="" or not image.IsLoaded
   image.ImageTransparency=fallback.Visible and 1 or 0
  end)
 end
 image:SetAttribute("RankName",name or "Unknown")
 fallback.Text=Ranks.Fallback[name] or "?"
 image.Image=Assets.rank(name); image.Visible=true
 fallback.Visible=image.Image=="" or not image.IsLoaded
 image.ImageTransparency=fallback.Visible and 1 or 0
 Assets.preload(image.Image)
 return image
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
 Assets.preload(uri)
 return UI.new("ImageLabel",name,parent,{BackgroundTransparency=1,Image=uri,ImageColor3=Color3.fromRGB(255,255,255),ImageTransparency=0,Visible=uri~="",ScaleType=Enum.ScaleType.Fit,ResampleMode=Enum.ResamplerMode.Pixelated,ZIndex=parent.ZIndex+1})
end
function Assets.icon(UI,parent,key)
 local icon=Assets.image(UI,parent,"AssetIcon",Assets.uri(key)); icon.Size=UDim2.fromOffset(28,28); icon.Position=UDim2.new(0,10,0.5,-14)
 if icon.Visible and parent:IsA("TextButton") then
  local caption=parent:FindFirstChild("ButtonCaption")
  if caption then caption.Position=UDim2.fromOffset(46,4); caption.Size=UDim2.new(1,-54,1,-8) end
  parent.TextSize=math.min(parent.TextSize,13)
 end
 return icon
end
return Assets
