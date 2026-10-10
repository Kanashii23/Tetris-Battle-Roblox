local Diagnostics=require(script.Parent:WaitForChild("TextureDiagnostics"))
local Layers=require(script.Parent:WaitForChild("RenderLayers"))
local Styles=require(script.Parent:WaitForChild("BrickStyles"))
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local E=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("TetrisEngine"))
local Assets=require(script.Parent:WaitForChild("CosmeticsAssets"))
local Renderer={Styles=Styles}
function Renderer.tile(parent,name,UI)
	local root=UI.new("Frame",name,parent,{BorderSizePixel=0,BackgroundColor3=Theme.Colors.empty,ZIndex=(parent.ZIndex or 1)+1})
	local face=UI.new("Frame","Face",root,{Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-2),BorderSizePixel=0,ZIndex=root.ZIndex+1})
	local edge=UI.stroke(face,Theme.Colors.line,0,1)
	local shine=UI.new("Frame","Highlight",face,{Size=UDim2.new(1,0,0,1),BorderSizePixel=0,BackgroundTransparency=0.35,ZIndex=face.ZIndex+1})
	local detail=UI.new("Frame","Detail",face,{Size=UDim2.fromScale(0.24,0.24),BorderSizePixel=0,Visible=false,ZIndex=face.ZIndex+1})
	local facets={}; for i=1,2 do facets[i]=UI.new("Frame","Facet"..i,face,{BorderSizePixel=0,Visible=false,ZIndex=face.ZIndex+1}) end
	local image=UI.new("ImageLabel","CosmeticTexture",root,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image="",ImageColor3=Color3.fromRGB(255,255,255),ImageTransparency=0,ScaleType=Enum.ScaleType.Fit,Visible=false,ZIndex=root.ZIndex+4})
 local tile={Frame=root,Face=face,Edge=edge,Shine=shine,Detail=detail,Facets=facets,Image=image}
 local function refresh()
  if not tile.PaintArgs or tile.Painting or not image.Parent then return end
  tile.Key=nil; Renderer.paint(tile,table.unpack(tile.PaintArgs,1,8))
 end
 image:GetPropertyChangedSignal("IsLoaded"):Connect(refresh)
 Assets.observe(image,refresh)
 return tile
end
function Renderer.paint(tile,kind,skin,ghostId,isGhost,reduced,clock,variation)
	tile.PaintArgs=tile.PaintArgs or {}
 local args=tile.PaintArgs; args[1]=kind; args[2]=skin; args[3]=ghostId; args[4]=isGhost; args[5]=reduced; args[6]=clock; args[7]=variation
 tile.Painting=true
 local animate=isGhost or skin=="CyberCore" or skin=="Lava" or skin=="Glitch" or skin=="RoyalPrism"
	local phase=animate and not reduced and math.floor((clock or 0)*6) or 0
	local uri=""
 if type(kind)=="string" and kind~="G" then uri=Assets.request(isGhost and "GhostFX" or "Bricks",isGhost and ghostId or skin,kind) end
 tile.Image.Image=uri
 -- The actual ImageLabel wins over a failed preload cache or a successful preload for another instance.
 local ready=uri~="" and tile.Image.IsLoaded
 Layers.cell(tile,isGhost,kind==0)
 tile.Image.Size=UDim2.fromScale(1,1); tile.Image.Position=UDim2.fromScale(0,0)
 tile.Image.BackgroundTransparency=1; tile.Image.ImageColor3=Color3.fromRGB(255,255,255); tile.Image.ImageTransparency=0
 tile.Image.Visible=uri~="" and kind~=0
 tile.Face.Visible=not ready and kind~=0
 if ready then
  tile.Frame.BackgroundTransparency=1; tile.Shine.Visible=false; tile.Detail.Visible=false
  for _,facet in ipairs(tile.Facets) do facet.Visible=false end
 end
 local key=tostring(ready)..":"..uri..":"..tostring(kind)..":"..(skin or "Default")..":"..(ghostId or "Default")..":"..tostring(isGhost)..":"..phase..":"..tostring(reduced)
	if tile.Key==key then tile.Painting=false; return end; tile.Key=key
	tile.Frame:SetAttribute("SkinId",skin or "Default"); tile.Frame:SetAttribute("PieceKind",tostring(kind)); tile.Frame:SetAttribute("Ghost",isGhost or false)
	if kind==0 then tile.Image.Visible=false; tile.Face.Visible=false; tile.Frame.BackgroundColor3=Theme.Colors.empty; tile.Frame.BackgroundTransparency=0; tile.Painting=false; return end
	tile.Image.Image=uri; tile.Image.Visible=uri~=""; tile.Image.ImageColor3=Color3.fromRGB(255,255,255); tile.Image.ImageTransparency=0
 if ready then tile.Face.Visible=false; tile.Shine.Visible=false; tile.Detail.Visible=false; for _,facet in ipairs(tile.Facets) do facet.Visible=false end; tile.Frame.BackgroundTransparency=1; tile.Painting=false; return end
 local spec=Styles.describe(kind,skin,ghostId,isGhost,reduced,clock)
	tile.Frame:SetAttribute("Texture",spec.Texture)
	tile.Face.Visible=true; tile.Frame.BackgroundColor3=spec.Color:Lerp(Theme.Colors.board,0.55); tile.Frame.BackgroundTransparency=isGhost and 1 or 0
	tile.Face.Position=UDim2.fromOffset(spec.Inset,spec.Inset); tile.Face.Size=UDim2.new(1,-2*spec.Inset,1,-2*spec.Inset)
	tile.Face.BackgroundColor3=spec.Color; tile.Face.BackgroundTransparency=spec.Transparency; tile.Edge.Color=spec.Edge; tile.Edge.Transparency=isGhost and 0.38 or 0.12
	tile.Shine.Visible=not isGhost; tile.Shine.BackgroundColor3=spec.Color:Lerp(Theme.Colors.text,0.5)
	local mark=tile.Detail; mark.Visible=spec.Texture~="Bevel" and spec.Texture~="Default"
	mark.Rotation=0; mark.BackgroundTransparency=0.25; mark.BackgroundColor3=spec.Edge; mark.Position=UDim2.fromScale(0.15,0.2); mark.Size=UDim2.fromScale(0.25,0.25)
	if spec.Texture=="Circuit" then mark.Size=UDim2.new(0.6,0,0,2); mark.Position=UDim2.fromScale(0.2,0.72); mark.BackgroundColor3=Theme.Colors.cyan
	elseif spec.Texture=="Wave" then mark.Size=UDim2.new(0.8,0,0,2); mark.Position=UDim2.fromScale(0.1,0.5)
	elseif spec.Texture=="Star" then mark.Size=UDim2.fromOffset(2,2); mark.Position=UDim2.fromScale(0.2+(variation or 0)%3*0.2,0.25); mark.BackgroundColor3=Theme.Colors.text
	elseif spec.Texture=="Gold" then mark.Size=UDim2.new(0,1,0.6,0); mark.Position=UDim2.fromScale(0.8,0.2); mark.BackgroundColor3=Theme.Colors.yellow
	elseif spec.Texture=="Lava" then mark.Size=UDim2.new(0.7,0,0,2); mark.Position=UDim2.fromScale(0.1,0.65); mark.BackgroundColor3=Theme.Colors.orange
	elseif spec.Texture=="Crystal" then mark.Rotation=45; mark.BackgroundTransparency=0.4
	elseif spec.Texture=="Pixel" then mark.Size=UDim2.fromScale(0.32,0.32); mark.Position=UDim2.fromScale(0.5,0.5); mark.BackgroundTransparency=0.45
	elseif spec.Texture=="Scan" then mark.Size=UDim2.new(0.8,0,0,1); mark.Position=UDim2.fromScale(0.1,0.65); mark.BackgroundColor3=Theme.Colors.cyan end
	local a,b=tile.Facets[1],tile.Facets[2]
	for _,facet in ipairs(tile.Facets) do facet.Visible=kind~=0 and not isGhost; facet.BackgroundColor3=spec.Edge; facet.BackgroundTransparency=0.5; facet.Rotation=0 end
	a.Position=UDim2.fromScale(0.06,0.05); a.Size=UDim2.fromScale(0.08,0.86); b.Position=UDim2.fromScale(0.05,0.85); b.Size=UDim2.fromScale(0.88,0.09); b.BackgroundColor3=spec.Color:Lerp(Theme.Colors.background,0.5)
	if spec.Texture=="Crystal" or spec.Texture=="Prism" then
		a.Position=UDim2.fromScale(0.25,0.08); a.Size=UDim2.fromScale(0.15,0.65); a.Rotation=-35; b.Position=UDim2.fromScale(0.62,0.25); b.Size=UDim2.fromScale(0.12,0.65); b.Rotation=35
		if spec.Texture=="Prism" then a.BackgroundColor3=Color3.fromHSV((phase%24)/24,0.55,1); b.BackgroundColor3=Color3.fromHSV(((variation or 0)%7)/7,0.55,1) end
	elseif spec.Texture=="Circuit" then a.Size=UDim2.new(0,2,0.7,0); a.Position=UDim2.fromScale(0.6,0.15); b.Size=UDim2.fromScale(0.16,0.16); b.Position=UDim2.fromScale(0.48,0.38); a.BackgroundColor3=Theme.Colors.cyan; b.BackgroundColor3=Theme.Colors.cyan; b.BackgroundTransparency=reduced and 0.2 or phase%2*0.35
	elseif spec.Texture=="Star" then a.Size=UDim2.fromOffset(2,2); b.Size=UDim2.fromOffset(1,1); a.Position=UDim2.fromScale(0.65,0.64); b.Position=UDim2.fromScale(0.8,0.2); a.BackgroundColor3=Theme.Colors.text; b.BackgroundColor3=Theme.Colors.text
	elseif spec.Texture=="Gold" then a.Size=UDim2.fromScale(0.13,0.8); a.Rotation=25; b.Size=UDim2.new(0.8,0,0,2); b.Position=UDim2.fromScale(0.1,0.15); b.BackgroundColor3=Theme.Colors.yellow
	elseif spec.Texture=="Lava" then a.Position=UDim2.fromScale(0.2,0.3); a.Size=UDim2.fromScale(0.15,0.6); a.Rotation=35; b.Position=UDim2.fromScale(0.5,0.4); b.Size=UDim2.fromScale(0.12,0.55); b.Rotation=-30; a.BackgroundColor3=Theme.Colors.orange; b.BackgroundColor3=Theme.Colors.yellow; mark.BackgroundTransparency=reduced and 0.2 or 0.2+phase%3*0.1
	elseif spec.Texture=="Wave" or spec.Texture=="Scan" then a.Size=UDim2.new(0.85,0,0,1); b.Size=a.Size; a.Position=UDim2.fromScale(0.08,0.28); b.Position=UDim2.fromScale(0.08,0.75)
	elseif spec.Texture=="Glitch" then a.Size=UDim2.new(0.5,0,0,2); a.Position=UDim2.fromScale(0.1+(phase%2)*0.15,0.35); b.Size=UDim2.new(0.5,0,0,2); b.Position=UDim2.fromScale(0.3,0.7); a.BackgroundColor3=Theme.Colors.pink; b.BackgroundColor3=Theme.Colors.cyan
	elseif spec.Texture=="Neon" then a.Size=UDim2.new(0.85,0,0,1); a.Position=UDim2.fromScale(0.08,0.13); b.Size=UDim2.new(0,1,0.75,0); b.Position=UDim2.fromScale(0.86,0.13); a.BackgroundTransparency=0.1; b.BackgroundTransparency=0.1
	elseif spec.Texture=="Metal" then a.Position=UDim2.fromScale(0.15,0.2); a.Size=UDim2.fromOffset(2,2); b.Position=UDim2.fromScale(0.7,0.65); b.Size=UDim2.fromOffset(2,2) end
	if isGhost then
		mark.Visible=ghostId~="Default"; mark.BackgroundTransparency=0.6; mark.BackgroundColor3=spec.Edge
		if ghostId=="PixelDotted" then mark.Position=UDim2.fromScale(0.03,0.03); mark.Size=UDim2.fromScale(0.16,0.16)
		elseif ghostId=="CyberScanline" or ghostId=="Hologram" then mark.Size=UDim2.new(0.9,0,0,1); mark.Position=UDim2.fromScale(0.05,0.35)
		elseif ghostId=="Glitch" then mark.Size=UDim2.new(0.3,0,0,1); mark.Position=UDim2.fromScale(phase%2*0.4+0.1,0.1)
		elseif ghostId=="CrystalOutline" or ghostId=="RoyalPrism" then mark.Rotation=45; mark.Size=UDim2.fromScale(0.15,0.4) end
	end
 tile.Painting=false
end
function Renderer.board(parent,name,columns,rows,UI)
	local frame=UI.new("Frame",name,parent,{BackgroundColor3=Theme.Colors.board,BorderSizePixel=0,ClipsDescendants=true,ZIndex=(parent.ZIndex or 1)+Layers.Grid}); UI.stroke(frame,Theme.Colors.line)
	local view={Frame=frame,Tiles={},Columns=columns,Rows=rows,UI=UI}
	for y=1,rows do view.Tiles[y]={}; for x=1,columns do local tile=Renderer.tile(frame,"Brick_"..x.."_"..y,UI)
		tile.Frame.Position=UDim2.fromScale((x-1)/columns,(y-1)/rows); tile.Frame.Size=UDim2.new(1/columns,-1,1/rows,-1); view.Tiles[y][x]=tile
	end end; return view
end
function Renderer.draw(view,state,loadout,reduced,clock)
	loadout=loadout or {}; local cells={}
	for y=1,view.Rows do cells[y]={}; for x=1,view.Columns do cells[y][x]={kind=state and state.board[y] and state.board[y][x] or 0,ghost=false} end end
	if state and state.alive then for _,field in ipairs({"ghost","piece"}) do if state[field] then for _,point in ipairs(E.cells(state[field])) do
		if cells[point[2]] and cells[point[2]][point[1]] and (field~="ghost" or cells[point[2]][point[1]].kind==0) then cells[point[2]][point[1]]={kind=state[field].kind,ghost=field=="ghost"} end
	end end end end
	local previous=view.State
 for y,row in ipairs(view.Tiles) do for x,tile in ipairs(row) do local cell=cells[y][x]; Renderer.paint(tile,cell.kind,loadout.BrickSkin,loadout.GhostEffect,cell.ghost,reduced,clock,y*view.Columns+x); if cell.kind=="G" and previous and previous.board[y] and previous.board[y][x]~="G" and not reduced then local target=tile.Face.BackgroundColor3; tile.Face.BackgroundColor3=target:Lerp(Theme.Colors.cyan,0.55); view.UI.tween(tile.Face,{BackgroundColor3=target},0.28) end; Diagnostics.record(view,tile) end end; view.State=state
end
function Renderer.piece(view,kind,loadout,reduced)
	Renderer.draw(view,{board={},alive=type(kind)=="string",piece=type(kind)=="string" and {kind=kind,x=1,y=1,rotation=0} or nil},loadout,reduced,0)
end
return Renderer
