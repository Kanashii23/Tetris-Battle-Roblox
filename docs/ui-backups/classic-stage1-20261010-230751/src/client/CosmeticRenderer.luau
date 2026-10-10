-- Bounded temporary layers, all cosmetic. No collision/scoring/attack changes.
local TweenService=game:GetService("TweenService")
local Config=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("DropEffectConfig"))
local Renderer={Active=0,Limit=Config.MaxActive}
function Renderer.drop(board,id,reduced,origin)
	local spec=Config.Styles[id] or Config.Styles.Default; local count=reduced and 1 or spec.Count
	for i=1,count do
		if Renderer.Active>=Renderer.Limit then break end; Renderer.Active+=1
		local p=Instance.new("Frame"); p.Name="CosmeticParticle"; p.BorderSizePixel=0; p.ZIndex=(board.ZIndex or 1)+8; p.AnchorPoint=Vector2.new(0.5,0.5)
		p.BackgroundColor3=Color3.fromRGB(table.unpack(spec.Color)); p.Size=UDim2.fromOffset(6,6)
		local x,y=origin and origin.X or 0.5,origin and origin.Y or 0.9; p.Position=UDim2.fromScale(x,y)
		local target=UDim2.fromScale(math.clamp(x+(i-(count+1)/2)*0.035,0.03,0.97),math.clamp(y-0.1-(i%3)*0.035,0.05,0.97))
		if spec.Style=="Wave" or spec.Style=="Pulse" or reduced then p.Size=UDim2.new(0.65,0,0,2); target=p.Position
		elseif spec.Style=="Bolt" then p.Size=UDim2.new(0,2,0.12,0); p.Position=UDim2.fromScale(x+(i%2)*0.05,y-i*0.08); target=p.Position
		elseif spec.Style=="Shard" then p.Size=UDim2.fromOffset(4,10); p.Rotation=45
		elseif spec.Style=="Flame" then p.Size=UDim2.fromOffset(6,12); target=UDim2.fromScale(x+(i-(count+1)/2)*0.025,math.max(0,y-0.2-(i%3)*0.07))
		elseif spec.Style=="Glitch" then p.Size=UDim2.new(0.25,0,0,2); target=UDim2.fromScale(x+(i%2==0 and 0.1 or -0.1),y-i*0.045)
		elseif spec.Style=="Orbit" then target=UDim2.fromScale(x+math.cos(i/count*math.pi*2)*0.18,y+math.sin(i/count*math.pi*2)*0.1)
		elseif spec.Style=="Prism" then p.Rotation=45; p.BackgroundColor3=Color3.fromHSV(i/count,0.6,1) end
		p.Parent=board; local done=false; local function release() if done then return end; done=true; p:Destroy(); Renderer.Active=math.max(0,Renderer.Active-1) end
		local tween=TweenService:Create(p,TweenInfo.new(reduced and 0.2 or Config.Duration),{Position=target,BackgroundTransparency=1}); tween.Completed:Once(release); tween:Play(); task.delay(1,release)
	end
end
return Renderer
