-- An isolated deterministic engine; never calls remotes or progression functions.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local E=require(Shared:WaitForChild("TetrisEngine")); local Rules=require(Shared:WaitForChild("Config"):WaitForChild("Rules"))
local Config=require(Shared:WaitForChild("Config"):WaitForChild("ShopPreviewConfig"))
local Bricks=require(script.Parent:WaitForChild("BrickRenderer")); local Effects=require(script.Parent:WaitForChild("CosmeticRenderer"))
local Preview={}; Preview.__index=Preview
function Preview.new(parent,UI)
	local self=setmetatable({UI=UI,Elapsed=0,LastStep=-1,Round=0},Preview)
	self.View=Bricks.board(parent,"CosmeticSampleBoard",10,20,UI); self.Frame=self.View.Frame; self.Frame:SetAttribute("CosmeticSample",true)
	self.ClearLabel=UI.text("DemoClear",self.Frame,"",14,UI.colors.green,UI.theme.Fonts.Display); self.ClearLabel.Size=UDim2.new(1,0,0,40); self.ClearLabel.Position=UDim2.fromScale(0,0.4); self.ClearLabel.TextXAlignment=Enum.TextXAlignment.Center; self.ClearLabel.ZIndex=self.Frame.ZIndex+10; self.ClearLabel.Visible=false
	return self
end
function Preview.paintThumbnail(view,UI,item,loadout)
 local equipped=loadout or {}; local kind="T"
 local appearance={BrickSkin=item.Category=="BrickSkins" and item.Id or equipped.BrickSkin or "Default",GhostEffect=item.Category=="GhostEffects" and item.Id or equipped.GhostEffect or "Default"}
 if item.Category=="GhostEffects" then
  Bricks.draw(view,{board={},alive=true,ghost={kind=kind,x=1,y=1,rotation=0}},appearance,UI.reducedMotion,0)
 else Bricks.piece(view,kind,appearance,UI.reducedMotion) end
end
function Preview.thumbnail(parent,UI,item,loadout)
 local view=Bricks.board(parent,"TetrominoPreview",4,2,UI)
 Preview.paintThumbnail(view,UI,item,loadout); return view
end
function Preview:begin()
 Effects.clear(self.Frame)
	self.Round+=1; self.Cycle=0; self.Landed=false; self.Moved=false; self.Frozen=false; self.ClearLabel.Visible=false
	local rules=table.clone(Rules); rules.Gravity=Config.FallInterval; self.Engine=E.new(Config.Seed+self.Round,rules)
	if self.Round%Config.ClearEvery==0 then
		for y=21,24 do for x=1,10 do self.Engine.board[y][x]=x==5 and 0 or ({"J","L","S","Z","O","T","I"})[(x+y)%7+1] end end
		E.spawn(self.Engine,"I"); self.Engine.piece.rotation=1; self.Engine.piece.x=3
	else
		for x=1,10 do if x<3 or x>8 then self.Engine.board[24][x]="J" end end
		E.spawn(self.Engine,({"I","O","T","S","Z","J","L"})[(self.Round-1)%7+1])
	end
	self.Engine.piece.y=Rules.Hidden+1
end
function Preview:set(item,equipped)
	self.Item=item; self.Elapsed=0; self.Round=0; self.LastStep=-1
	self.Loadout={BrickSkin=equipped and equipped.BrickSkin or "Default",GhostEffect=equipped and equipped.GhostEffect or "Default",DropEffect=equipped and equipped.DropEffect or "Default"}
	if item.Category=="BrickSkins" then self.Loadout.BrickSkin=item.Id elseif item.Category=="GhostEffects" then self.Loadout.GhostEffect=item.Id elseif item.Category=="DropEffects" then self.Loadout.DropEffect=item.Id end
	self:begin(); self:tick(0,true)
end
function Preview:hardDrop()
 local sequence=self.Engine.sequence
 E.hardDrop(self.Engine); self.Landed=true
 for _,event in ipairs(self.Engine.events) do if event.id>sequence and event.name=="HardDrop" then Effects.dropEvent(self.Frame,self.Loadout.DropEffect,self.UI.reducedMotion,event) end end
end
function Preview:tick(dt,force)
 if not self.Item or not self.Frame.Visible then Effects.clear(self.Frame); return end
 Effects.tick(dt*(self.Speed or 1),self.Frame,self.UI.reducedMotion)
	if self.Paused and not force then return end
	dt=dt*(self.Speed or 1)
	if self.UI.reducedMotion then if not self.Frozen or force then Bricks.draw(self.View,E.snapshot(self.Engine),self.Loadout,true,0); self.Frozen=true end; return end
	self.Frozen=false
	self.Elapsed+=math.min(dt,0.1); self.Cycle+=math.min(dt,0.1)
	if not self.Landed then
		if self.Cycle>0.55 and not self.Moved and self.Round%Config.ClearEvery~=0 then self.Moved=true; E.move(self.Engine,self.Round%2==0 and -1 or 1,0); E.rotate(self.Engine,1) end
		if self.Cycle>=Config.HardDropAfter then self:hardDrop(); if self.Engine.lines>0 then self.ClearLabel.Text=self.Engine.stats.PerfectClears>0 and "PERFECT CLEAR!" or self.Engine.lines==4 and "TETRIS!" or "LINE CLEAR!"; self.ClearLabel.Visible=true end else E.step(self.Engine,math.min(dt,0.1)) end
	end
	local step=math.floor(self.Elapsed*Config.FPS); if force or step~=self.LastStep then self.LastStep=step; Bricks.draw(self.View,E.snapshot(self.Engine),self.Loadout,false,self.Elapsed) end
	if self.Cycle>=Config.NextAfter then self:begin() end
end
function Preview:control(action)
 if action=="Pause" then self.Paused=not self.Paused
 elseif action=="Replay" then
  self.Round=math.max(0,self.Round-1); self:begin()
  if self.Item.Category=="DropEffects" then self:hardDrop() end
 elseif action=="Rotate" and not self.Landed then E.rotate(self.Engine,1)
 elseif action=="Next" then self:begin()
 elseif action=="Speed" then self.Speed=(self.Speed or 1)==1 and 0.5 or 1 end
 self:tick(0,true)
end
function Preview:destroy() Effects.clear(self.Frame,true); self.Item=nil; self.Frame:Destroy() end
return Preview
