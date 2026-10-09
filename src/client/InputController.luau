local CAS=game:GetService("ContextActionService")
local UIS=game:GetService("UserInputService")
local Rules=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Rules"))
local Input={}; Input.__index=Input
function Input.new(callback,pause)
	local self=setmetatable({Callback=callback,Enabled=false,Sources={},Touches={},Connections={},Actions={}},Input)
	local keyboard={Left={Enum.KeyCode.A,Enum.KeyCode.Left},Right={Enum.KeyCode.D,Enum.KeyCode.Right},SoftDrop={Enum.KeyCode.S,Enum.KeyCode.Down},CW={Enum.KeyCode.X,Enum.KeyCode.Up},CCW={Enum.KeyCode.Z},HardDrop={Enum.KeyCode.Space},Hold={Enum.KeyCode.C,Enum.KeyCode.LeftShift}}
	for action,keys in pairs(keyboard) do
		table.insert(keys,Enum.KeyCode[Rules.Gamepad[action]])
		local name="Tetris_"..action; table.insert(self.Actions,name)
		CAS:BindActionAtPriority(name,function(_,state,obj)
			if not self.Enabled or UIS:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
			if state==Enum.UserInputState.Begin then self:set(action,obj.KeyCode.Name,true)
			elseif state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then self:set(action,obj.KeyCode.Name,false) end
			return Enum.ContextActionResult.Sink
		end,false,3000,table.unpack(keys))
	end
	CAS:BindActionAtPriority("Tetris_Pause",function(_,state)
		if self.Enabled and state==Enum.UserInputState.Begin then self:release(); pause(); return Enum.ContextActionResult.Sink end
		return Enum.ContextActionResult.Pass
	end,false,3000,Enum.KeyCode.Escape,Enum.KeyCode[Rules.Gamepad.Pause])
	table.insert(self.Actions,"Tetris_Pause")
	table.insert(self.Connections,UIS.InputEnded:Connect(function(obj)
		if obj.UserInputType==Enum.UserInputType.MouseButton1 then
			-- Mouse release may provide a different InputObject from GuiObject.InputBegan.
			for captured,action in pairs(self.Touches) do if captured.UserInputType==Enum.UserInputType.MouseButton1 then self:set(action,captured,false); self.Touches[captured]=nil end end
		else local action=self.Touches[obj]; if action then self:set(action,obj,false); self.Touches[obj]=nil end end
	end))
	table.insert(self.Connections,UIS.WindowFocusReleased:Connect(function() self:release(); if self.Enabled then pause(true) end end))
	return self
end
function Input:set(action,source,down)
	local set=self.Sources[action] or {}; self.Sources[action]=set
	local old=next(set)~=nil; if down then set[source]=true else set[source]=nil end
	local new=next(set)~=nil; if old~=new then self.Callback(action,new) end
end
function Input:button(button,action)
	table.insert(self.Connections,button.InputBegan:Connect(function(obj)
		if self.Enabled and (obj.UserInputType==Enum.UserInputType.Touch or obj.UserInputType==Enum.UserInputType.MouseButton1) then self.Touches[obj]=action; self:set(action,obj,true) end
	end))
end
function Input:release()
	for action,sources in pairs(self.Sources) do if next(sources) then self.Callback(action,false) end end
	self.Sources={}; self.Touches={}
end
function Input:enable(value) if not value then self:release() end; self.Enabled=value end
function Input:destroy()
	self:release(); for _,name in ipairs(self.Actions) do CAS:UnbindAction(name) end
	for _,connection in ipairs(self.Connections) do connection:Disconnect() end
end
return Input
