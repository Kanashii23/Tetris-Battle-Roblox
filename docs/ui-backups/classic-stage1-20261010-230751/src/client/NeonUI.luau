-- Compatibility name; all styling comes from RetroTheme.
local TweenService=game:GetService("TweenService")
local Assets=require(script.Parent:WaitForChild("UIAssets"))
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local UI={reducedMotion=false,theme=Theme,colors=Theme.Colors}
function UI.new(class,name,parent,props)
	local object=Instance.new(class); object.Name=name
	for key,value in pairs(props or {}) do object[key]=value end
	object.Parent=parent; return object
end
function UI.round(object,radius) return UI.new("UICorner","Corner",object,{CornerRadius=UDim.new(0,radius or Theme.Radius)}) end
function UI.stroke(object,color,transparency,thickness)
	return UI.new("UIStroke","Outline",object,{Color=color or UI.colors.line,Transparency=transparency or 0,Thickness=thickness or Theme.Border,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
function UI.panel(name,parent,accent)
	local panel=UI.new("Frame",name,parent,{BackgroundColor3=UI.colors.panel,BorderSizePixel=0})
	UI.round(panel); UI.stroke(panel,accent or UI.colors.line,accent and 0.2 or 0)
 UI.new("Frame","PixelEdge",panel,{Size=UDim2.new(1,-12,0,2),Position=UDim2.fromOffset(6,3),BackgroundColor3=accent or UI.colors.line,BorderSizePixel=0,BackgroundTransparency=0.45})
 return panel
end
function UI.text(name,parent,value,size,color,font)
	return UI.new("TextLabel",name,parent,{BackgroundTransparency=1,Text=tostring(value),TextColor3=color or UI.colors.text,
		FontFace=font==Theme.Fonts.Body and Theme.BodyFace or font==Theme.Fonts.Strong and Theme.StrongFace or Theme.Face,TextSize=size or Theme.Type.Body,TextWrapped=true,
		TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center})
end
function UI.rect(object,rect) object.Position=UDim2.fromOffset(rect[1],rect[2]); object.Size=UDim2.fromOffset(rect[3],rect[4]) end
function UI.tween(object,properties,duration)
	if UI.reducedMotion then for key,value in pairs(properties) do object[key]=value end; return nil end
	local tween=TweenService:Create(object,TweenInfo.new(duration or Theme.Motion.Hover,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties); tween:Play(); return tween
end
function UI.enabled(button,value)
	button:SetAttribute("Disabled",not value); button.Interactable=value; button.Selectable=value
	button.TextColor3=value and UI.colors.text or UI.colors.muted; button.BackgroundTransparency=value and 0 or 0.4
end
function UI.button(name,parent,text,accent,clicked)
	accent=accent or UI.colors.pink
	local button=UI.new("TextButton",name,parent,{BackgroundColor3=UI.colors.panel,BorderSizePixel=0,AutoButtonColor=false,
		Text=text,TextSize=15,TextColor3=UI.colors.text,TextTransparency=0,FontFace=Theme.StrongFace,Selectable=true,TextWrapped=true})
	UI.round(button); local outline=UI.stroke(button,accent,0.15)
	local function focus(active)
		if button:GetAttribute("Disabled") or not UI.canInteract(button) then return end
		UI.tween(button,{BackgroundColor3=active and UI.colors.raised or UI.colors.panel}); UI.tween(outline,{Color=active and UI.colors.yellow or accent})
	end
	button.MouseEnter:Connect(function() if UI.canInteract(button) then focus(true); if UI.onHover then UI.onHover() end end end); button.MouseLeave:Connect(function() focus(false) end)
	button.SelectionGained:Connect(function() focus(true) end); button.SelectionLost:Connect(function() focus(false) end)
	button.Activated:Connect(function()
  if not UI.canInteract(button) then return end
  if not button:GetAttribute("Disabled") and clicked then clicked() end
 end)
 button.InputBegan:Connect(function(input) if UI.canInteract(button) and not button:GetAttribute("Disabled") and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then UI.tween(button,{BackgroundColor3=UI.colors.line},0.08) end end)
 button.InputEnded:Connect(function() focus(false) end)
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
function UI.measure(text,size,width)
 local lines=0; for _,line in ipairs(string.split(tostring(text),"\n")) do lines+=math.max(1,math.ceil(#line*size/math.max(1,width))) end
 return lines*size*1.25
end
return UI
