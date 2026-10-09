-- Compatibility name; all styling comes from RetroTheme.
local TweenService=game:GetService("TweenService")
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
	UI.round(panel); UI.stroke(panel,accent or UI.colors.line,accent and 0.2 or 0); return panel
end
function UI.text(name,parent,value,size,color,font)
	return UI.new("TextLabel",name,parent,{BackgroundTransparency=1,Text=tostring(value),TextColor3=color or UI.colors.text,
		FontFace=Font.fromEnum(font or Theme.Fonts.Body),TextSize=size or Theme.Type.Body,TextWrapped=true,
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
		Text=text,TextSize=15,TextColor3=UI.colors.text,FontFace=Font.fromEnum(Theme.Fonts.Strong),Selectable=true})
	UI.round(button); local outline=UI.stroke(button,accent,0.15)
	local function focus(active)
		if button:GetAttribute("Disabled") then return end
		UI.tween(button,{BackgroundColor3=active and UI.colors.raised or UI.colors.panel}); UI.tween(outline,{Color=active and UI.colors.yellow or accent})
	end
	button.MouseEnter:Connect(function() focus(true); if UI.onHover then UI.onHover() end end); button.MouseLeave:Connect(function() focus(false) end)
	button.SelectionGained:Connect(function() focus(true) end); button.SelectionLost:Connect(function() focus(false) end)
	button.Activated:Connect(function() if not button:GetAttribute("Disabled") and clicked then clicked() end end)
	return button
end
function UI.divider(parent,name) return UI.new("Frame",name,parent,{BackgroundColor3=UI.colors.line,BorderSizePixel=0,Size=UDim2.new(1,0,0,1)}) end
function UI.focusGroup(object)
	object.SelectionGroup=true
	for _,direction in ipairs({"Up","Down","Left","Right"}) do object["SelectionBehavior"..direction]=Enum.SelectionBehavior.Stop end
end
return UI
