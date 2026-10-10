-- Removable Studio-only evidence; max three states per surface/piece presentation.
local D={Enabled=true}
function D.record(view,tile)
 if not D.Enabled then return end
 local ok,studio=pcall(function() return game:GetService("RunService"):IsStudio() end)
 if not ok or not studio or tile.Frame:GetAttribute("PieceKind")=="0" then return end
 local image=tile.Image
 local state=image.Image=="" and "Unmapped" or image.IsLoaded and "Loaded" or "PendingOrFailed"
 local key=(tile.Frame:GetAttribute("Ghost") and "Ghost/" or "Solid/")..state
 view.Evidence=view.Evidence or {}; if view.Evidence[key] then return end; view.Evidence[key]=true
 local visible=true; local opacity=1; local node=image
 while node do
  if node:IsA("GuiObject") then visible=visible and node.Visible end
  if node:IsA("CanvasGroup") then opacity*=1-(node.GroupTransparency or 0) end
  node=node.Parent
 end
 print(string.format("[Tetris PNG evidence] surface=%s parent=%s kind=%s ghost=%s uri=%s IsLoaded=%s Visible=%s alpha=%.2f tint=%.2f,%.2f,%.2f Z=%d nativeZ=%d cellZ=%d size=%.1fx%.1f ancestorsVisible=%s groupOpacity=%.2f state=%s",
  view.Frame.Name,view.Frame.Parent and view.Frame.Parent.Name or "Detached",tostring(tile.Frame:GetAttribute("PieceKind")),tostring(tile.Frame:GetAttribute("Ghost")),image.Image,tostring(image.IsLoaded),tostring(image.Visible),image.ImageTransparency,image.ImageColor3.R,image.ImageColor3.G,image.ImageColor3.B,image.ZIndex,tile.Face.ZIndex,tile.Frame.ZIndex,image.AbsoluteSize.X,image.AbsoluteSize.Y,tostring(visible),opacity,state))
end
return D
