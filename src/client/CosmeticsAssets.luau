-- One resolver/cache for gameplay cells, HOLD/NEXT and isolated previews.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ids=require(Shared:WaitForChild("Config"):WaitForChild("CosmeticsAssetResolver"))
local Provider=game:GetService("ContentProvider")
local Assets={Ids=require(Shared.Config:WaitForChild("CosmeticsAssetMetadata")),Resolver=Ids,Status={},Warned={}}
local watchers=setmetatable({},{__mode="k"})
function Assets.observe(image,fn)
 watchers[image]=fn
 image.Destroying:Connect(function() watchers[image]=nil end)
end
local function notify(uri)
 for image,fn in pairs(watchers) do if image.Parent and image.Image==uri then fn() end end
end
local function once(key,message)
 if Assets.Warned[key] then return end; Assets.Warned[key]=true; warn("[Tetris cosmetics] "..message)
end
function Assets.get(category,id,piece,component)
 local uri,theme=Ids.resolve(category,id,piece,component)
 local context=theme.."/"..tostring(piece).."/"..category..(component and "/"..component or "")
 if uri=="" then
  once(context,"Native fallback: "..context.." has no valid uploaded image ID.")
  return "",theme
 end
 if not Assets.Status[uri] then
  Assets.Status[uri]="Loading"
  task.spawn(function()
   local ok=pcall(function() Provider:PreloadAsync({uri},function(_,status)
    Assets.Status[uri]=status==Enum.AssetFetchStatus.Success and "Ready" or "Failed"
   end) end)
   if not ok or Assets.Status[uri]~="Ready" then Assets.Status[uri]="Failed"; once(uri,"Native fallback: "..context.." failed to load "..uri.."; check image ID, processing and experience permissions.") end
     notify(uri)
  end)
 end
 return Assets.Status[uri]=="Ready" and uri or "",theme
end
-- Retain the configured URI while loading or failed, independently of fallback presentation.
function Assets.request(category,id,piece,component)
 local uri,theme=Ids.resolve(category,id,piece,component)
 Assets.get(category,id,piece,component)
 return uri,theme,Assets.Status[uri]
end
function Assets.preloadDefault()
 for _,piece in ipairs({"I","O","T","S","Z","J","L"}) do
  Assets.get("Bricks","Default",piece); Assets.get("GhostFX","Default",piece)
  for _,component in ipairs({"Ripple","WhiteBase","Droplet"}) do Assets.get("DropFX","Default",piece,component) end
 end
end
function Assets.presentation(category,id)
 local key=({BrickSkins="Bricks",GhostEffects="GhostFX",DropEffects="DropFX"})[category]
 if not key then return "LIVE PREVIEW" end
 local ready,total=0,0
 for _,piece in ipairs({"I","O","T","S","Z","J","L"}) do
  for _,component in ipairs(key=="DropFX" and {"WhiteBase","Droplet","Ripple"} or {false}) do
   total+=1; local uri=Ids.resolve(key,id,piece,component or nil)
   if uri~="" and Assets.Status[uri]=="Ready" then ready+=1 end
  end
 end
 return ready==0 and "NATIVE PREVIEW" or ready==total and "IMAGE PREVIEW" or "MIXED PREVIEW"
end
return Assets
