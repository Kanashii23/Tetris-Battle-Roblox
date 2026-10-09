local Styles=require(script.Parent:WaitForChild("BrickStyles"))
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local E=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("TetrisEngine"))
local Renderer={Styles=Styles}
function Renderer.tile(parent,name,UI)
	local root=UI.new("Frame",name,parent,{BorderSizePixel=0,BackgroundColor3=Theme.Colors.empty,ZIndex=(parent.ZIndex or 1)+1})
	local face=UI.new("Frame","Face",root,{Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-2),BorderSizePixel=0,ZIndex=root.ZIndex+1})
	local edge=UI.stroke(face,Theme.Colors.line,0,1)
	local shine=UI.new("Frame","Highlight",face,{Size=UDim2.new(1,0,0,1),BorderSizePixel=0,BackgroundTransparency=0.35,ZIndex=face.ZIndex+1})
	local detail=UI.new("Frame","Detail",face,{Size=UDim2.fromScale(0.24,0.24),BorderSizePixel=0,Visible=false,ZIndex=face.ZIndex+1})
	return {Frame=root,Face=face,Edge=edge,Shine=shine,Detail=detail}
end
function Renderer.paint(tile,kind,skin,ghostId,isGhost,reduced,clock,variation)
	local phase=isGhost and not reduced and math.floor((clock or 0)*12) or 0
	local key=tostring(kind)..":"..(skin or "Default")..":"..(ghostId or "Default")..":"..tostring(isGhost)..":"..phase..":"..tostring(reduced)
	if tile.Key==key then return end; tile.Key=key
	tile.Frame:SetAttribute("SkinId",skin or "Default"); tile.Frame:SetAttribute("PieceKind",tostring(kind)); tile.Frame:SetAttribute("Ghost",isGhost or false)
	if kind==0 then tile.Face.Visible=false; tile.Frame.BackgroundColor3=Theme.Colors.empty; tile.Frame.BackgroundTransparency=0; return end
	local spec=Styles.describe(kind,skin,ghostId,isGhost,reduced,clock)
	tile.Face.Visible=true; tile.Frame.BackgroundColor3=spec.Color:Lerp(Theme.Colors.board,0.55); tile.Frame.BackgroundTransparency=isGhost and 1 or 0
	tile.Face.Position=UDim2.fromOffset(spec.Inset,spec.Inset); tile.Face.Size=UDim2.new(1,-2*spec.Inset,1,-2*spec.Inset)
	tile.Face.BackgroundColor3=spec.Color; tile.Face.BackgroundTransparency=spec.Transparency; tile.Edge.Color=spec.Edge; tile.Edge.Transparency=isGhost and 0.38 or 0.12
	tile.Shine.Visible=not isGhost; tile.Shine.BackgroundColor3=spec.Color:Lerp(Theme.Colors.text,0.5)
	local mark=tile.Detail; mark.Visible=not isGhost and spec.Texture~="Bevel" and spec.Texture~="Neon"
	mark.Rotation=0; mark.BackgroundTransparency=0.25; mark.BackgroundColor3=spec.Edge; mark.Position=UDim2.fromScale(0.15,0.2); mark.Size=UDim2.fromScale(0.25,0.25)
	if spec.Texture=="Circuit" then mark.Size=UDim2.new(0.6,0,0,2); mark.Position=UDim2.fromScale(0.2,0.72); mark.BackgroundColor3=Theme.Colors.cyan
	elseif spec.Texture=="Wave" then mark.Size=UDim2.new(0.8,0,0,2); mark.Position=UDim2.fromScale(0.1,0.5)
	elseif spec.Texture=="Star" then mark.Size=UDim2.fromOffset(2,2); mark.Position=UDim2.fromScale(0.2+(variation or 0)%3*0.2,0.25); mark.BackgroundColor3=Theme.Colors.text
	elseif spec.Texture=="Gold" then mark.Size=UDim2.new(0,1,0.6,0); mark.Position=UDim2.fromScale(0.8,0.2); mark.BackgroundColor3=Theme.Colors.yellow
	elseif spec.Texture=="Lava" then mark.Size=UDim2.new(0.7,0,0,2); mark.Position=UDim2.fromScale(0.1,0.65); mark.BackgroundColor3=Theme.Colors.orange
	elseif spec.Texture=="Crystal" then mark.Rotation=45; mark.BackgroundTransparency=0.4
	elseif spec.Texture=="Pixel" then mark.Size=UDim2.fromScale(0.32,0.32); mark.Position=UDim2.fromScale(0.5,0.5); mark.BackgroundTransparency=0.45
	elseif spec.Texture=="Scan" then mark.Size=UDim2.new(0.8,0,0,1); mark.Position=UDim2.fromScale(0.1,0.65); mark.BackgroundColor3=Theme.Colors.cyan end
end
function Renderer.board(parent,name,columns,rows,UI)
	local frame=UI.new("Frame",name,parent,{BackgroundColor3=Theme.Colors.board,BorderSizePixel=0,ClipsDescendants=true,ZIndex=(parent.ZIndex or 1)+1}); UI.stroke(frame,Theme.Colors.line)
	local view={Frame=frame,Tiles={},Columns=columns,Rows=rows,UI=UI}
	for y=1,rows do view.Tiles[y]={}; for x=1,columns do local tile=Renderer.tile(frame,"Brick_"..x.."_"..y,UI)
		tile.Frame.Position=UDim2.fromScale((x-1)/columns,(y-1)/rows); tile.Frame.Size=UDim2.new(1/columns,-1,1/rows,-1); view.Tiles[y][x]=tile
	end end; return view
end
function Renderer.draw(view,state,loadout,reduced,clock)
	loadout=loadout or {}; local cells={}
	for y=1,view.Rows do cells[y]={}; for x=1,view.Columns do cells[y][x]={kind=state and state.board[y] and state.board[y][x] or 0,ghost=false} end end
	if state and state.alive then for _,field in ipairs({"ghost","piece"}) do if state[field] then for _,point in ipairs(E.cells(state[field])) do
		if cells[point[2]] and cells[point[2]][point[1]] then cells[point[2]][point[1]]={kind=state[field].kind,ghost=field=="ghost"} end
	end end end end
	for y,row in ipairs(view.Tiles) do for x,tile in ipairs(row) do local cell=cells[y][x]; Renderer.paint(tile,cell.kind,loadout.BrickSkin,loadout.GhostEffect,cell.ghost,reduced,clock,y*view.Columns+x) end end; view.State=state
end
function Renderer.piece(view,kind,loadout,reduced)
	Renderer.draw(view,{board={},alive=type(kind)=="string",piece=type(kind)=="string" and {kind=kind,x=1,y=1,rotation=0} or nil},loadout,reduced,0)
end
return Renderer
