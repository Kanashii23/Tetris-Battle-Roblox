-- Compatibility name; all styling comes from RetroTheme.
local TextService=game:GetService("TextService")
local TweenService=game:GetService("TweenService")
local Assets=require(script.Parent:WaitForChild("UIAssets"))
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local UI={reducedMotion=false,theme=Theme,colors=Theme.Colors}
function UI.new(class,name,parent,props)
	local object=Instance.new(class); object.Name=name
	for key,value in pairs(props or {}) do object[key]=value end
	if parent and (class=="Frame" or class=="ImageLabel" or class=="TextLabel" or class=="TextButton" or class=="ScrollingFrame") and (not props or props.ZIndex==nil) then object.ZIndex=(parent:IsA("GuiObject") and parent.ZIndex or 1)+1 end
 object.Parent=parent; return object
end
function UI.round(object,radius) return UI.new("UICorner","Corner",object,{CornerRadius=UDim.new(0,radius or Theme.Radius)}) end
function UI.stroke(object,color,transparency,thickness)
	return UI.new("UIStroke","Outline",object,{Color=color or UI.colors.line,Transparency=transparency or 0,Thickness=thickness or Theme.Border,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
-- Bounded procedural halo: widening, fading edges plus a short dark cast shadow.
function UI.depth(object,color)
 object.ClipsDescendants=false
 local parts={}
 local shadow=UI.new("Frame","CastShadow",object,{Position=UDim2.fromOffset(0,4),Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(2,1,7),BackgroundTransparency=0.12,BorderSizePixel=0,Active=false})
 UI.round(shadow,4)
 for i,spread in ipairs({3,6,9}) do
  local halo=UI.new("Frame","NeonHalo"..i,object,{Position=UDim2.fromOffset(-spread,-spread),Size=UDim2.new(1,spread*2,1,spread*2),BackgroundTransparency=1,BorderSizePixel=0,Active=false})
  UI.round(halo,4+spread); local stroke=UI.stroke(halo,color,0.9+i*0.02,2); parts[i]=stroke
 end
 local surface=UI.new("Frame","Surface",object,{Size=UDim2.fromScale(1,1),BackgroundColor3=UI.colors.panel,BorderSizePixel=0,Active=false})
 UI.round(surface,4)
 UI.new("UIGradient","SurfaceGradient",surface,{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(150,140,170))})
 local rail=UI.new("Frame","PixelEdge",object,{Size=UDim2.new(1,-16,0,1),Position=UDim2.fromOffset(8,3),BackgroundColor3=color,BackgroundTransparency=0.5,BorderSizePixel=0,Active=false})
 local function layers()
  local z=object.ZIndex
  shadow.ZIndex=math.max(1,z-3)
  for i=1,3 do parts[i].Parent.ZIndex=math.max(1,z-2) end
  surface.ZIndex=math.max(1,z-1); rail.ZIndex=z+1
 end
 object:GetPropertyChangedSignal("ZIndex"):Connect(layers); layers()
 return {Halos=parts,Surface=surface,Rail=rail,Shadow=shadow}
end
function UI.rails(object,color) return UI.depth(object,color) end
function UI.panel(name,parent,accent)
 local panel=UI.new("Frame",name,parent,{BackgroundColor3=UI.colors.panel,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3})
 UI.round(panel,4); UI.stroke(panel,accent or UI.colors.line,0.15,1)
 UI.depth(panel,accent or UI.colors.line)
 return panel
end
function UI.contentCard(name,parent,accent)
 local card=UI.panel(name,parent,accent or UI.colors.line)
 card:SetAttribute("ContentCard",true)
 return card
end
function UI.text(name,parent,value,size,color,font)
	return UI.new("TextLabel",name,parent,{ZIndex=(parent.ZIndex or 1)+1,BackgroundTransparency=1,Text=tostring(value),TextColor3=color or UI.colors.text,
		FontFace=font==Theme.Fonts.Body and Theme.BodyFace or font==Theme.Fonts.Strong and Theme.StrongFace or Theme.Face,TextSize=size or Theme.Type.Body,TextWrapped=true,
		TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center})
end
function UI.rect(object,rect) object.Position=UDim2.fromOffset(rect[1],rect[2]); object.Size=UDim2.fromOffset(rect[3],rect[4]) end
function UI.tween(object,properties,duration)
	if UI.reducedMotion then for key,value in pairs(properties) do object[key]=value end; return nil end
	local tween=TweenService:Create(object,TweenInfo.new(duration or Theme.Motion.Hover,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties); tween:Play(); return tween
end
local states=setmetatable({},{__mode="k"})
local palette={UI.colors.pink,UI.colors.cyan,UI.colors.purple,UI.colors.yellow,UI.colors.green}
function UI.enabled(button,value)
 button:SetAttribute("Disabled",not value); button.Interactable=value; button.Selectable=value
 button.TextColor3=value and UI.colors.text or UI.colors.muted
 local state=states[button]; if state then state.Reset(); state.Depth.Surface.BackgroundTransparency=value and 0 or 0.25 end
end
function UI.restSurface(button,color)
 local state=states[button]; if state then state.RestSurface(color) end
end
function UI.reset(root)
 for button,state in pairs(states) do
  local node=button
  while node and node~=root do node=node.Parent end
  if node==root then state.Reset() end
 end
end
function UI.button(name,parent,text,accent,clicked)
 accent=accent or UI.colors.pink
 local button=UI.new("TextButton",name,parent,{BackgroundColor3=UI.colors.panel,BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,ZIndex=4,
  Text=text,TextSize=15,TextColor3=UI.colors.text,TextTransparency=1,FontFace=Theme.Face,Selectable=true,TextWrapped=true})
 UI.round(button,4); local outline=UI.stroke(button,accent,0.18,1.5); local depth=UI.depth(button,accent)
 -- Separate text and surface prevent UIGradient/UIPadding from tinting or shifting art.
 local caption=UI.text("ButtonCaption",button,text,15,UI.colors.text); caption.Size=UDim2.new(1,-16,1,-8); caption.Position=UDim2.fromOffset(8,4); caption.TextXAlignment=Enum.TextXAlignment.Center
 local function captionSync()
  caption.Text=button.Text; caption.TextColor3=button.TextColor3; caption.TextSize=button.TextSize; caption.FontFace=button.FontFace; caption.TextYAlignment=button.TextYAlignment; caption.ZIndex=button.ZIndex+2
 end
 for _,prop in ipairs({"Text","TextColor3","TextSize","TextYAlignment","FontFace","ZIndex"}) do button:GetPropertyChangedSignal(prop):Connect(captionSync) end
 captionSync()
 local restSurface=UI.colors.panel
 local hovered,pressed=false,false; local generation=0; local tweens={}; local bag={}; local last
 local function cancel() generation+=1; for _,tween in ipairs(tweens) do tween:Cancel() end; table.clear(tweens) end
 local function transition(object,properties,time)
  local tween=UI.tween(object,properties,time); if tween then table.insert(tweens,tween) end
 end
 local function choose()
  if #bag==0 then
   for i=1,#palette do bag[i]=i end
   for i=#bag,2,-1 do local j=math.random(i); bag[i],bag[j]=bag[j],bag[i] end
   if last and bag[#bag]==last then bag[1],bag[#bag]=bag[#bag],bag[1] end
  end
  last=table.remove(bag); return palette[last]
 end
 local selected=accent
 local function paint(instant)
  cancel(); local active=(hovered or pressed) and not button:GetAttribute("Disabled") and UI.canInteract(button)
  local color=active and selected or accent; local duration=instant and 0 or active and 0.14 or 0.18
  local function apply(o,props) if instant or UI.reducedMotion then for k,v in pairs(props) do o[k]=v end else transition(o,props,duration) end end
  apply(outline,{Color=color,Thickness=active and 2 or 1.5,Transparency=active and 0 or 0.18})
  for i,halo in ipairs(depth.Halos) do apply(halo,{Color=color,Transparency=active and (0.48+i*0.12) or (0.9+i*0.02)}) end
  apply(depth.Rail,{BackgroundColor3=color,BackgroundTransparency=active and 0.15 or 0.5})
  apply(depth.Surface,{BackgroundColor3=pressed and UI.colors.line or active and UI.colors.raised or restSurface})
  depth.Shadow.BackgroundColor3=Color3.fromRGB(2,1,7); depth.Shadow.Position=UDim2.fromOffset(0,4)
  button:SetAttribute("HoverActive",active); button:SetAttribute("TransitionGeneration",generation)
 end
 local function reset() hovered=false; pressed=false; paint(true) end
 states[button]={Reset=reset,Depth=depth,RestSurface=function(color) restSurface=color; paint(true) end}
 local function enter()
  if hovered or button:GetAttribute("Disabled") or not UI.canInteract(button) then return end
  hovered=true; selected=choose(); paint(false)
 end
 local function leave() hovered=false; pressed=false; paint(false) end
 button.MouseEnter:Connect(enter); button.MouseLeave:Connect(leave)
 button.SelectionGained:Connect(enter); button.SelectionLost:Connect(leave)
 button.Activated:Connect(function() if UI.canInteract(button) and not button:GetAttribute("Disabled") and clicked then clicked() end end)
 button.InputBegan:Connect(function(input)
  if not UI.canInteract(button) or button:GetAttribute("Disabled") then return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then pressed=true; if not hovered then selected=choose() end; paint(false) end
 end)
 button.InputEnded:Connect(function(input) pressed=false; if input.UserInputType==Enum.UserInputType.Touch then hovered=false end; paint(false) end)
 button:GetPropertyChangedSignal("Visible"):Connect(function() if not button.Visible then reset() end end)
 local visibility={}; local node=button.Parent
 while node do
  if node:IsA("GuiObject") then local ancestor=node; table.insert(visibility,ancestor:GetPropertyChangedSignal("Visible"):Connect(function() if not ancestor.Visible then reset() end end)) end
  node=node.Parent
 end
 button.Destroying:Connect(function() cancel(); for _,connection in ipairs(visibility) do connection:Disconnect() end; states[button]=nil end)
 return button
end
function UI.canInteract(button)
 local node=button; local modal=UI.ActiveModal
 if modal then while node and node~=modal do node=node.Parent end; if node~=modal then return false end end
 return true
end
function UI.divider(parent,name) return UI.new("Frame",name,parent,{BackgroundColor3=UI.colors.line,BorderSizePixel=0,Size=UDim2.new(1,0,0,1)}) end
function UI.focusGroup(object)
	object.SelectionGroup=true
	for _,direction in ipairs({"Up","Down","Left","Right"}) do object["SelectionBehavior"..direction]=Enum.SelectionBehavior.Stop end
end
function UI.icon(parent,key) return Assets.icon(UI,parent,key) end
function UI.image(parent,name,uri) return Assets.image(UI,parent,name,uri) end
-- Dense descriptions use measured readable text; retro headings retain Press Start 2P.
function UI.measure(value,size,width,font)
 local ok,bounds=pcall(function() return TextService:GetTextSize(tostring(value),size,font or Enum.Font.Arcade,Vector2.new(math.max(1,width),10000)) end)
 if ok then
  if font and font~=Enum.Font.Arcade then return math.ceil(bounds.Y)+4 end
  -- Arcade measurement can be narrower than the Press Start 2P face; reserve the pixel glyph width.
  local rows=0; for _,line in ipairs(string.split(tostring(value),"\n")) do rows+=math.max(1,math.ceil(#line*size/math.max(1,width))) end
  return math.max(math.ceil(bounds.Y)+4,rows*size*1.25)
 end
 local lines=0; for _,line in ipairs(string.split(tostring(value),"\n")) do lines+=math.max(1,math.ceil(#line*size/math.max(1,width))) end
 return lines*size*1.25
end
function UI.iconButton(name,parent,key,label,clicked)
 local button=UI.button(name,parent,"",UI.colors.line,clicked)
 button:SetAttribute("AccessibleLabel",label)
 local icon=UI.image(button,"AssetIcon",Assets.uri(key)); icon.AnchorPoint=Vector2.new(0.5,0.5); icon.Position=UDim2.fromScale(0.5,0.5); icon.Size=UDim2.fromOffset(28,28)
 local fallback=UI.new("Frame","SymbolFallback",button,{BackgroundTransparency=1,Position=UDim2.new(0.5,-12,0.5,-12),Size=UDim2.fromOffset(24,24),ZIndex=button.ZIndex+1})
 local function line(name,x,y,w,h,rotation)
  return UI.new("Frame",name,fallback,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),Rotation=rotation or 0,BackgroundColor3=UI.colors.text,BorderSizePixel=0,ZIndex=fallback.ZIndex})
 end
 if label=="Mail" then
  local outline=UI.new("Frame","Envelope",fallback,{Position=UDim2.fromOffset(1,4),Size=UDim2.fromOffset(22,16),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=fallback.ZIndex}); UI.stroke(outline,UI.colors.text,0,2)
  line("FlapLeft",2,7,12,2,32); line("FlapRight",11,7,12,2,-32)
 else
  local hub=UI.new("Frame","GearHub",fallback,{Position=UDim2.fromOffset(6,6),Size=UDim2.fromOffset(12,12),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=fallback.ZIndex}); UI.stroke(hub,UI.colors.text,0,3)
  for i=0,7 do local angle=i*math.pi/4; line("Tooth"..i,10+math.cos(angle)*9,10+math.sin(angle)*9,4,4,i*45) end
 end
 local function refresh() fallback.Visible=icon.Image=="" or not icon.IsLoaded end
 icon:GetPropertyChangedSignal("IsLoaded"):Connect(refresh); icon:GetPropertyChangedSignal("Image"):Connect(refresh); refresh()
 return button
end
return UI
