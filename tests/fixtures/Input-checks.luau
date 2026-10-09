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
