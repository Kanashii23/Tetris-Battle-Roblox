local R=(function()
return {
	Width=10, Height=20, Hidden=4, LockDelay=0.5, MaxLockResets=15,
	Gravity=0.8, MinGravity=0.04, SoftDropInterval=0.025, DAS=0.16, ARR=0.045,
	MatchDuration=120, Countdown=3, SnapshotHz=12, GarbageDelay=0.8, MaxPending=40,
	Score={Normal={[0]=0,100,300,500,800},Spin={[0]=400,800,1200,1600},Mini={[0]=100,200,400}},
	Attack={Normal={[0]=0,0,1,2,4},Spin={[0]=0,2,4,6},Mini={[0]=0,0,1}},
	BackToBackScore=1.5, BackToBackAttack=1, PerfectClearScore=2000, PerfectClearAttack=6,
	ComboAttack={0,0,1,1,2,2,3,3,4,4,5},
	Gamepad={Left="DPadLeft",Right="DPadRight",SoftDrop="DPadDown",CW="ButtonA",CCW="ButtonB",HardDrop="ButtonY",Hold="ButtonX",Pause="ButtonStart"},
}

end)()
local signals={}
local function signal() local s={}; function s:Connect(fn) self.Function=fn; return {Disconnect=function() end} end; return s end
local CAS={Bindings={}}
function CAS:BindActionAtPriority(name,fn,_,_,...) self.Bindings[name]={Function=fn,Keys={...}} end
function CAS:UnbindAction(name) self.Bindings[name]=nil end
local UIS={InputEnded=signal(),WindowFocusReleased=signal(),GetFocusedTextBox=function() return nil end}
local keyNames={"A","Left","D","Right","S","Down","X","Up","Z","Space","C","LeftShift","Escape","DPadLeft","DPadRight","DPadDown","ButtonA","ButtonB","ButtonY","ButtonX","ButtonStart"}
local Enum={KeyCode={},UserInputState={Begin="Begin",End="End",Cancel="Cancel"},ContextActionResult={Pass="Pass",Sink="Sink"},UserInputType={Touch="Touch",MouseButton1="Mouse"}}
for _,name in ipairs(keyNames) do Enum.KeyCode[name]={Name=name} end
local folder={WaitForChild=function(self,key) return key=="Rules" and "Rules" or self end}
local game={GetService=function(_,name) return ({ContextActionService=CAS,UserInputService=UIS,ReplicatedStorage=folder})[name] end}
local require=function() return R end

local Input=(function()
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

end)()
local calls={}
local controls=Input.new(function(action,down) table.insert(calls,{action,down}) end,function() end)
controls:enable(true)
local function key(action,name,state) CAS.Bindings["Tetris_"..action].Function(nil,state,{KeyCode=Enum.KeyCode[name]}) end
key("SoftDrop","Down","Begin"); assert(calls[#calls][1]=="SoftDrop")
key("SoftDrop","Down","End"); key("CW","X","Begin"); assert(calls[#calls][1]=="CW")
print("PASS Down and rotation map to separate actions")
key("Left","A","Begin"); key("Left","Left","Begin"); local before=#calls
key("Left","A","End"); assert(#calls==before); key("Left","Left","End"); assert(calls[#calls][1]=="Left" and not calls[#calls][2])
print("PASS overlapping keyboard sources keep movement until all keys release")
local button={InputBegan=signal()}; controls:button(button,"Right")
button.InputBegan.Function({UserInputType="Mouse"}); assert(calls[#calls][1]=="Right" and calls[#calls][2])
UIS.InputEnded.Function({UserInputType="Mouse"}); assert(calls[#calls][1]=="Right" and not calls[#calls][2])
local touch={UserInputType="Touch"}; button.InputBegan.Function(touch); UIS.InputEnded.Function(touch); assert(not calls[#calls][2])
print("PASS mouse and touch press/release, including different mouse release object")
key("Left","A","Begin"); controls:enable(false); assert(not calls[#calls][2])
controls:destroy(); assert(next(CAS.Bindings)==nil)
print("PASS focus/menu release and binding cleanup")
