-- Cosmetic-only sample. Uses exactly the same tile painter as live game boards.
local Bricks=require(script.Parent:WaitForChild("BrickRenderer"))
local Effects=require(script.Parent:WaitForChild("CosmeticRenderer"))
local Preview={}; Preview.__index=Preview
function Preview.new(parent,UI)
	local self=setmetatable({UI=UI,Elapsed=0,LastStep=-1},Preview)
	self.View=Bricks.board(parent,"CosmeticSampleBoard",10,12,UI)
	self.Frame=self.View.Frame; self.Frame:SetAttribute("CosmeticSample",true)
	return self
end
function Preview.thumbnail(parent,UI,item,loadout)
	local view=Bricks.board(parent,"TetrominoPreview",4,2,UI)
	local outfit={BrickSkin=item.Category=="BrickSkins" and item.Id or loadout and loadout.BrickSkin or "Default",GhostEffect="Default"}
	Bricks.piece(view,"T",outfit,UI.reducedMotion)
	return view
end
function Preview:set(item,equipped)
	self.Item=item; self.Elapsed=0; self.Landed=false; self.LastStep=-1
	self.Loadout={BrickSkin=equipped and equipped.BrickSkin or "Default",GhostEffect=equipped and equipped.GhostEffect or "Default"}
	if item.Category=="BrickSkins" then self.Loadout.BrickSkin=item.Id end
	if item.Category=="GhostEffects" then self.Loadout.GhostEffect=item.Id end
	self:tick(0,true)
end
function Preview:tick(dt,force)
	if not self.Item then return end
	self.Elapsed+=dt; local step=math.floor(self.Elapsed*20)
	if not force and step==self.LastStep then return end; self.LastStep=step
	local board={}; for y=1,12 do board[y]=table.create(10,0) end
	for x=1,10 do board[12][x]=({"J","J","J","I","I","I","I","L","L","L"})[x] end
	board[11][1]="O"; board[11][2]="O"; board[11][9]="S"; board[11][10]="S"
	local drop=self.Item.Category=="DropEffects"; local progress=self.Elapsed%2.4
	local y=drop and (self.UI.reducedMotion and 10 or math.min(10,2+math.floor(progress/0.75*8))) or 3
	local state={board=board,alive=true,piece={kind="T",x=4,y=y,rotation=0},ghost={kind="T",x=4,y=10,rotation=0}}
	Bricks.draw(self.View,state,self.Loadout,self.UI.reducedMotion,self.Elapsed)
	if drop and not self.UI.reducedMotion then
		if progress>=0.75 and not self.Landed then self.Landed=true; Effects.drop(self.Frame,self.Item.Id,false,{X=0.5,Y=0.87}) end
		if progress<0.75 then self.Landed=false end
	end
end
function Preview:destroy() self.Item=nil; self.Frame:Destroy() end
return Preview
