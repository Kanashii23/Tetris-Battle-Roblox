-- Pooled 2D cosmetics only. Gameplay outcomes are untouched.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local E=require(Shared:WaitForChild("TetrisEngine"))
local Assets=require(script.Parent:WaitForChild("CosmeticsAssets"))
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local Renderer={Active=0,Limit=36,Pools={},MaxBursts=3,LastEvent={}}
local function node(board,name)
 local frame=Instance.new("Frame"); frame.Name=name; frame.BorderSizePixel=0; frame.AnchorPoint=Vector2.new(0.5,0.5); frame.ZIndex=(board.ZIndex or 1)+8; frame.Visible=false; frame.Parent=board
 local image=Instance.new("ImageLabel"); image.Name="ComponentImage"; image.BackgroundTransparency=1; image.Size=UDim2.fromScale(1,1); image.ScaleType=Enum.ScaleType.Fit; image.ImageColor3=Color3.fromRGB(255,255,255); image.ZIndex=frame.ZIndex+1; image.Parent=frame
 return {Frame=frame,Image=image}
end
local function release(burst)
 if not burst.Active then return end
 burst.Active=false; Renderer.Active=math.max(0,Renderer.Active-burst.Count)
 for _,part in ipairs(burst.Parts) do part.Frame.Visible=false end
end
function Renderer.clear(board,destroy,keepEvents)
 for _,burst in ipairs(Renderer.Pools[board] or {}) do
  release(burst)
  if destroy then for _,part in ipairs(burst.Parts) do part.Frame:Destroy() end end
 end
 if not keepEvents then Renderer.LastEvent[board]=nil end
 if destroy then Renderer.Pools[board]=nil end
end
function Renderer.origin(data)
 if not data or not data.kind or not data.x or not data.y then return nil end
 local cells=E.cells({kind=data.kind,x=data.x,y=data.y,rotation=data.rotation or 0})
 local lo,hi,bottom=math.huge,-math.huge,-math.huge
 for _,cell in ipairs(cells) do lo=math.min(lo,cell[1]); hi=math.max(hi,cell[1]); bottom=math.max(bottom,cell[2]) end
 return {X=math.clamp((lo+hi-1)/20,0,1),Y=math.clamp(bottom/20,0,1)}
end
function Renderer.dropEvent(board,id,reduced,event)
 if not event or event.name~="HardDrop" then return false end
 if event.id and (Renderer.LastEvent[board] or 0)>=event.id then return false end
 if event.id then Renderer.LastEvent[board]=event.id end
 local origin=Renderer.origin(event.data); if not origin then return false end
 return Renderer.drop(board,event.data.DropEffect or id,reduced,origin,event.data.kind,event.id)
end
function Renderer.drop(board,id,reduced,origin,kind,seed)
 if reduced then Renderer.clear(board,false,true); return false end
 kind=kind or "T"; origin=origin or {X=0.5,Y=0.9}
 local _,theme=Assets.get("DropFX",id,kind,"WhiteBase")
 local spec=Assets.Ids.Animation[theme] or Assets.Ids.Animation.DefaultClassic
 local pool=Renderer.Pools[board]; if not pool then pool={}; Renderer.Pools[board]=pool end
 local burst
 for _,candidate in ipairs(pool) do if not candidate.Active then burst=candidate; break end end
 if not burst and #pool<Renderer.MaxBursts then
  burst={Parts={node(board,"WhiteBase"),node(board,"Ripple")}}
  for i=1,spec.Droplets do table.insert(burst.Parts,node(board,"Droplet"..i)) end
  table.insert(pool,burst)
 end
 local count=2+spec.Droplets
 if not burst or Renderer.Active+count>Renderer.Limit then return false end
 burst.Active=true; burst.Age=0; burst.Count=count; burst.Origin={X=origin.X,Y=origin.Y}; burst.Spec=spec; burst.Kind=kind; burst.Theme=theme; burst.AssetId=id; Renderer.Active+=count
 local color=Theme.Colors[kind] or Theme.Colors.T
 for i,part in ipairs(burst.Parts) do
  local component=i==1 and "WhiteBase" or i==2 and "Ripple" or "Droplet"
  local uri=Assets.get("DropFX",id,kind,component)
  part.Image.Image=uri; part.Image.Visible=uri~=""; part.Image.ImageColor3=Color3.fromRGB(255,255,255); part.Image.ImageTransparency=0; part.Image.Rotation=i==1 and spec.WhiteBaseRotation or 0
  part.Frame.BackgroundTransparency=uri~="" and 1 or 0; part.Frame.BackgroundColor3=color; part.Frame.Rotation=0; part.Frame.Visible=true; part.Frame.Position=UDim2.fromScale(origin.X,origin.Y)
  part.Delay=i>2 and (i-3)*spec.Delay or 0
  -- Distinct deterministic trajectories: left/right fans, height, size, speed and rotation.
  local n=((seed or 1)*17+i*31)%97
  part.DX=(i%2==0 and -1 or 1)*(0.025+n/1900); part.Lift=0.018+(n%7)*0.004; part.Spin=(n-48)*2; part.Scale=0.17+(n%5)*0.02
 end
 Renderer.tick(0,board,false)
 return true
end
function Renderer.tick(dt,board,reduced)
 if reduced or not board.Parent or not board.Visible then Renderer.clear(board,false,true); return end
 for _,burst in ipairs(Renderer.Pools[board] or {}) do if burst.Active then
  burst.Age+=math.max(0,dt)
  local w,h=board.AbsoluteSize.X,board.AbsoluteSize.Y; local cell=math.min(w/10,h/20); local spec=burst.Spec; local origin=burst.Origin
  for i,part in ipairs(burst.Parts) do
   -- Nonblocking loads may complete after the burst began; use the real texture when ready.
   local component=i==1 and "WhiteBase" or i==2 and "Ripple" or "Droplet"
   local uri=Assets.get("DropFX",burst.AssetId,burst.Kind,component)
   if part.Image.Image~=uri then part.Image.Image=uri; part.Image.Visible=uri~="" end
   local age=burst.Age-part.Delay; local duration=i==1 and spec.WhiteBase or i==2 and spec.Ripple or spec.Droplet
   local t=math.clamp(age/duration,0,1); part.Frame.Visible=age>=0 and t<1
   local x,y=origin.X,origin.Y; local width,height
   if i==1 then
    -- Supplied canvas is square; rotate its horizontal flash vertically.
    local size=cell*(1.25+0.12*(1-t)); width=part.Image.Visible and size or math.max(2,cell*0.10); height=size
    y-=size/h*0.36
   elseif i==2 then
    width=cell*2.5*(spec.RippleFrom+(spec.RippleTo-spec.RippleFrom)*t); height=part.Image.Visible and width/4 or math.max(1,cell*0.06)
   else
    width=cell*part.Scale; height=width; x+=part.DX*t; y+=-part.Lift*4*t*(1-t)+0.012*t*t; part.Frame.Rotation=part.Spin*t
   end
   part.Frame.Position=UDim2.fromScale(x,y); part.Frame.Size=UDim2.fromOffset(width,height)
   part.Image.ImageTransparency=t; part.Frame.BackgroundTransparency=part.Image.Visible and 1 or t
  end
  if burst.Age>=spec.Droplet+(spec.Droplets-1)*spec.Delay then release(burst) end
 end end
end
return Renderer
