-- Original native-UI artwork; no bitmap or third-party image IDs.
local Assets=require(script.Parent:WaitForChild("UIAssets"))
local Art={}; Art.__index=Art
function Art.new(parent,UI)
	local self=setmetatable({UI=UI,Lines={},Streaks={},Rails={},Elapsed=0,Speed=0.12,Destroyed=false},Art); local C=UI.colors
	self.Frame=UI.new("Frame","SynthwaveArtwork",parent,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,BorderSizePixel=0,ClipsDescendants=true,Active=false,ZIndex=1})
	self.Sun=UI.new("Frame","StripedSun",self.Frame,{BackgroundTransparency=1,Active=false,ZIndex=2})
	for index=0,63 do local y=(index+0.5)/64; local chord=math.sqrt(math.max(0,1-(y*2-1)^2))
		UI.new("Frame","SunBand"..index,self.Sun,{Position=UDim2.fromScale((1-chord)/2,index/64),Size=UDim2.new(chord,0,1/64,1),BorderSizePixel=0,BackgroundColor3=C.yellow:Lerp(C.orange,y),BackgroundTransparency=(index<15 or index%6<4) and 0 or 1,Active=false,ZIndex=2})
	end
	self.City=UI.new("Frame","DistantCity",self.Frame,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=3})
	for index=0,29 do local height=0.10+(index*7%11)*0.012
		UI.new("Frame","Building"..index,self.City,{Position=UDim2.fromScale(index/30,0.70-height),Size=UDim2.fromScale(0.038,height),BackgroundColor3=Color3.fromRGB(18,10,29),BorderSizePixel=0,ZIndex=3})
		if index%5==0 then UI.new("Frame","Antenna"..index,self.City,{Position=UDim2.fromScale((index+0.45)/30,0.687-height),Size=UDim2.new(0,1,0.018,0),BackgroundColor3=C.line,BorderSizePixel=0,ZIndex=3}) end
	end
	for index=0,29 do
  local building=self.City:FindFirstChild("Building"..index)
  for row=1,5 do for col=1,2 do
   UI.new("Frame","Window"..row..col,building,{Position=UDim2.fromScale(col*0.28,row*0.15),Size=UDim2.fromOffset(2,3),BackgroundColor3=index%4==0 and C.cyan or C.pink,BackgroundTransparency=0.2,BorderSizePixel=0,ZIndex=3})
  end end
 end
 for index=1,23 do self.Lines[index]=UI.new("Frame","PerspectiveLine"..index,self.Frame,{BackgroundColor3=C.purple,BackgroundTransparency=0.48,BorderSizePixel=0,AnchorPoint=Vector2.new(0.5,0.5),ZIndex=3}) end
 for i=1,40 do UI.new("Frame","SkyStar"..i,self.Frame,{Position=UDim2.fromScale((i*31%101)/101,(i*17%47)/100),Size=UDim2.fromOffset(i%9==0 and 2 or 1,2),BackgroundColor3=i%4==0 and C.cyan or C.pink,BackgroundTransparency=0.5,BorderSizePixel=0,ZIndex=1}) end
 self.Horizon=UI.new("Frame","NeonHorizon",self.Frame,{BackgroundColor3=C.pink,BackgroundTransparency=0.3,BorderSizePixel=0,ZIndex=3,Size=UDim2.new(1,0,0,2)})
 local haze=UI.new("Frame","SkylineGlow",self.Frame,{Size=UDim2.fromScale(1,0.34),Position=UDim2.fromScale(0,0.25),BackgroundColor3=C.pink,BackgroundTransparency=0.74,BorderSizePixel=0,ZIndex=1})
 UI.new("UIGradient","HazeFade",haze,{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.75,0.2),NumberSequenceKeypoint.new(1,1)})})
	self.Background=UI.image(self.Frame,"UploadedBackdrop",Assets.uri("Images.artwork.background")); self.Background.Size=UDim2.fromScale(1,1); self.Background.ScaleType=Enum.ScaleType.Crop; self.Background.ZIndex=3
 -- The video keeps the striped sun/city still. Only the surface flow is approximated here.
 self.Flow=UI.new("Frame","SurfaceFlow",self.Frame,{BackgroundTransparency=1,ClipsDescendants=true,ZIndex=3})
 for i=1,24 do
  local row=(i-1)%8; local seed=((i*37)%101)/101
  local frame=UI.new("Frame","SurfaceStreak"..i,self.Flow,{Size=UDim2.new(0.05+row*0.006,0,0,1),BackgroundColor3=i%3==0 and C.pink or C.cyan,BackgroundTransparency=0.30+row*0.025,BorderSizePixel=0,Active=false,ZIndex=3})
  self.Streaks[i]={Frame=frame,Seed=seed,Y=0.10+(row/8)^1.4*0.8}
 end
 -- Passing foreground rail supports reflect the reference's leftward roadside motion.
 self.RailLayer=UI.new("Frame","RoadsideFlow",self.Frame,{BackgroundTransparency=1,ClipsDescendants=true,Active=false,ZIndex=3})
 for i=1,5 do
  local post=UI.new("Frame","PassingSupport"..i,self.RailLayer,{Size=UDim2.new(0,3,0.16,0),BackgroundColor3=C.purple,BackgroundTransparency=0.35,BorderSizePixel=0,Active=false,ZIndex=3})
  self.Rails[i]={Frame=post,Seed=(i-1)*0.26}
 end
 self.Dim=UI.new("Frame","ArtworkDim",self.Frame,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4})
	return self
end
function Art:layout(width,height,portrait)
	local size=math.min(width*(portrait and 0.48 or 0.30),height*0.38)
	local cx=width*(self.Battle and not portrait and 0.5 or portrait and 0.79 or 0.76); local cy=height*(portrait and 0.25 or 0.32)
	if self.Battle and not portrait then size=math.min(width*0.26,height*0.44) end
	for _,band in ipairs(self.Sun:GetChildren()) do local y=(tonumber(band.Name:match("%d+"))+0.5)/64; local warm=y<0.45 and self.UI.colors.yellow:Lerp(self.UI.colors.orange,y/0.45) or self.UI.colors.orange:Lerp(self.UI.colors.pink,(y-0.45)/0.55); band.BackgroundColor3=portrait and warm:Lerp(self.UI.colors.background,0.52) or warm end
	self.Sun.Position=UDim2.fromOffset(cx-size/2,cy-size/2); self.Sun.Size=UDim2.fromOffset(size,size)
	local horizon=height*(portrait and 0.42 or 0.53); local center=width*0.63; self.Horizon.Position=UDim2.fromOffset(0,horizon)
	self.City.Position=UDim2.fromOffset(0,horizon-height*0.70)
 self.Flow.Position=UDim2.fromOffset(0,horizon+2); self.Flow.Size=UDim2.fromOffset(width,height-horizon-2)
 self.RailLayer.Position=UDim2.fromOffset(0,horizon+2); self.RailLayer.Size=self.Flow.Size
 self:paintFlow()
	local function line(index,x1,y1,x2,y2)
		local node=self.Lines[index]; local dx,dy=x2-x1,y2-y1
		node.Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2); node.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),1); node.Rotation=math.deg(math.atan2(dy,dx))
	end
	for index=1,13 do line(index,center+(index-7)*width*0.018,horizon,(index-7)*width*0.16+center,height) end
	for index=1,10 do local y=horizon+(height-horizon)*(index/10)^2; line(index+13,0,y,width,y) end
end
-- Elapsed-time modulo wrap happens entirely outside the clipped viewport.
function Art:paintFlow()
 local phase=(self.Elapsed*self.Speed)%1.3
 for i=1,#self.Streaks do
  local streak=self.Streaks[i]
  streak.Frame.Position=UDim2.fromScale((streak.Seed-phase)%1.3-0.15,streak.Y)
 end
 for _,post in ipairs(self.Rails) do post.Frame.Position=UDim2.fromScale((post.Seed-phase)%1.3-0.15,0.03) end
 self.Frame:SetAttribute("MotionPhase",phase)
end
function Art:tick(dt,reduced,visible)
 if self.Destroyed or not visible or reduced then return end
 self.Elapsed+=math.max(0,dt); self:paintFlow()
end
function Art:quiet(value) self.Dim.BackgroundTransparency=value and (self.Classic and 0.12 or 0.7) or 1 end
function Art:destroy() self.Destroyed=true; self.Frame:Destroy(); table.clear(self.Streaks); table.clear(self.Rails) end
return Art
