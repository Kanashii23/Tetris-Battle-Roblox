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
