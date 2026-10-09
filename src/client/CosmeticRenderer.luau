-- Local-only effects. Never changes engine state or sends gameplay commands.
local TweenService=game:GetService("TweenService")
local Catalog=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog"))
local Renderer={Active=0,Limit=48}
function Renderer.color(base,item,ghost)
	if not item then return base end
	local visual=item.Visual
	if visual.Tint then base=base:Lerp(Color3.new(table.unpack(visual.Tint)),visual.Blend) end
	if ghost then
		local alpha=visual.Transparency
		if item.Id=="Pulse" then alpha+=math.sin(os.clock()*4)*0.035
		elseif item.Id=="Glitch" then alpha+=math.floor(os.clock()*8)%2*0.03
		elseif item.Id=="Prism" then base=base:Lerp(Color3.fromHSV(os.clock()%5/5,0.7,1),0.18)
		elseif item.Id=="Electric" then alpha+=math.sin(os.clock()*15)*0.025 end
		base=base:Lerp(Color3.fromRGB(8,10,24),alpha)
	end
	return base
end
function Renderer.drop(board,id,reducedMotion,origin)
	local item=Catalog.Items["DropEffects:"..id]
	if not item or id=="Default" or reducedMotion then return end
	local count=id=="Stardust" and 14 or id=="CyberGlitch" and 5 or 8
	for i=1,count do
		if Renderer.Active>=Renderer.Limit then break end
		Renderer.Active+=1
		local p=Instance.new("Frame"); p.Name="CosmeticParticle"; p.BorderSizePixel=0; p.BackgroundColor3=Color3.new(table.unpack(item.Preview.Color)); p.ZIndex=6
		local ox,oy=origin and origin.X or 0.5,origin and origin.Y or 0.9
		p.ZIndex=(board.ZIndex or 1)+6
		p.AnchorPoint=Vector2.new(0.5,0.5); p.Position=UDim2.fromScale(ox,oy); p.Size=UDim2.fromOffset(4,8)
		local destination=UDim2.fromScale(i/count,0.6+(i%3)*0.1)
		if id=="LightningStrike" then p.Position=UDim2.fromScale(0.5+(i%2)*0.02,(i-1)/count); p.Size=UDim2.new(0,3,1/count,2); destination=p.Position
		elseif id=="FireBurst" then p.Size=UDim2.fromOffset(12,12); p.BackgroundColor3=Color3.fromRGB(255,120+i*8,40); local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(1,0); corner.Parent=p
		elseif id=="PixelExplosion" then p.Size=UDim2.fromOffset(10,10)
		elseif id=="CrystalShatter" then p.Rotation=45; p.Size=UDim2.fromOffset(7,14)
		elseif id=="CyberGlitch" then p.Position=UDim2.fromScale(0.5,i/(count+1)); p.Size=UDim2.new(0.8,0,0,3); destination=UDim2.fromScale(i%2==0 and 0.4 or 0.6,i/(count+1))
		elseif id=="Stardust" then p.Size=UDim2.fromOffset(3,3); destination=UDim2.fromScale(i/count,0.2+(i%5)*0.12) end
		p.Parent=board
		local tween=TweenService:Create(p,TweenInfo.new(0.3+i*0.012),{Position=destination,BackgroundTransparency=1}); tween:Play()
		local finished=false
		local function release() if finished then return end; finished=true; p:Destroy(); Renderer.Active=math.max(0,Renderer.Active-1) end
		tween.Completed:Once(release); task.delay(1,release)
	end
end
return Renderer
