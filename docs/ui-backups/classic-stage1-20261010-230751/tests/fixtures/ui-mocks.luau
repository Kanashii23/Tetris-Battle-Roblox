local deferred={}; local delayed={}
local function signal()
	local e={Handlers={}}
	function e:Connect(fn) table.insert(self.Handlers,fn); return {Disconnect=function() for i,handler in ipairs(self.Handlers) do if handler==fn then table.remove(self.Handlers,i); break end end end} end
	function e:Once(fn) return self:Connect(fn) end
	function e:fire(...) for _,fn in ipairs(self.Handlers) do fn(...) end end
	return e
end
local task={defer=function(fn) table.insert(deferred,fn) end,delay=function(seconds,fn) table.insert(delayed,{Seconds=seconds,Run=fn}) end,wait=function() coroutine.yield() end,spawn=function(fn) local co=coroutine.create(fn); local ok,err=coroutine.resume(co); assert(ok,err) end}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local UDim={new=function(s,o) return {Scale=s,Offset=o} end}
local UDim2={}
function UDim2.new(xs,xo,ys,yo) return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo)} end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
local Color3={}
function Color3.new(r,g,b) return setmetatable({R=r,G=g,B=b},{__index={Lerp=function(self,other,a) return Color3.new(self.R+(other.R-self.R)*a,self.G+(other.G-self.G)*a,self.B+(other.B-self.B)*a) end}}) end
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
function Color3.fromHSV() return Color3.new(1,0,1) end
local ColorSequence={new=function(v) return v end}
local ColorSequenceKeypoint={new=function(...) return {...} end}
local TweenInfo={new=function(...) return {...} end}
local Enum=setmetatable({},{__index=function(t,key)
	local group=setmetatable({},{__index=function(g,k) local value={Name=k}; rawset(g,k,value); return value end}); rawset(t,key,group); return group
end})
local Font={new=function(family) return {Family=family} end,fromEnum=function(font) return {Name=font.Name} end}
local Instance={}
local methods={}
function methods:GetChildren() return table.clone(self.Children) end
function methods:FindFirstChildOfClass(class) for _,child in ipairs(self.Children) do if child.ClassName==class then return child end end end
function methods:FindFirstChild(name,recursive) for _,c in ipairs(self.Children) do if c.Name==name then return c end; if recursive then local found=c:FindFirstChild(name,true); if found then return found end end end end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),"Missing child "..name.." in "..self.Name) end
function methods:IsA(class) return self.ClassName==class or class=="GuiObject" and ({Frame=true,TextLabel=true,TextButton=true,ImageLabel=true,CanvasGroup=true,ScrollingFrame=true})[self.ClassName] or false end
function methods:SetAttribute(k,v) self.Attributes[k]=v end
function methods:GetAttribute(k) return self.Attributes[k] end
function methods:GetPropertyChangedSignal() return signal() end
function methods:Destroy()
	if self.Destroying then self.Destroying:fire() end
	local parent=self.Parent
	if self.Parent then for i,c in ipairs(self.Parent.Children) do if c==self then table.remove(self.Parent.Children,i); break end end end
	self.Props.Parent=nil
	if parent and parent.ClassName=="ScrollingFrame" then local hasRows=false; for _,child in ipairs(parent.Children) do if child:IsA("GuiObject") then hasRows=true end end; if not hasRows then parent.CanvasPosition=Vector2.new(0,0) end end
end
function methods:Play() self.IsPlaying=true end
function methods:Stop() self.IsPlaying=false end
function Instance.new(class)
	local obj={Props={ClassName=class,Name=class,Visible=true,AbsoluteSize=Vector2.new(1366,768),IsLoaded=true,IsPlaying=false,ZIndex=1},Children={},Attributes={}}
	setmetatable(obj,{__index=function(self,key)
		if methods[key] then return methods[key] end
		if self.Props[key]~=nil then return self.Props[key] end
		if ({MouseEnter=true,MouseLeave=true,SelectionGained=true,SelectionLost=true,Activated=true,InputBegan=true,InputEnded=true,Destroying=true,Loaded=true})[key] then self.Props[key]=signal(); return self.Props[key] end
		return methods.FindFirstChild(self,key)
	end,__newindex=function(self,key,value)
		if key=="CanvasPosition" and self.ClassName=="ScrollingFrame" then local hasRows=false; for _,child in ipairs(self.Children) do if child:IsA("GuiObject") then hasRows=true end end; if not hasRows then value=Vector2.new(0,0) end end
		if key=="Parent" and value~=self.Props.Parent then
 if self.Props.Parent then for i,c in ipairs(self.Props.Parent.Children) do if c==self then table.remove(self.Props.Parent.Children,i); break end end end
 if value then table.insert(value.Children,self) end
end
		self.Props[key]=value
	end})
	return obj
end
local function named(class,name,parent) local obj=Instance.new(class); obj.Name=name; obj.Parent=parent; return obj end
local ReplicatedStorage=named("Folder","ReplicatedStorage")
local Shared=named("Folder","Shared",ReplicatedStorage)
local ConfigFolder=named("Folder","Config",Shared)
for _,name in ipairs({"TetrisEngine","Progression","Catalog"}) do named("ModuleScript",name,Shared) end
for _,name in ipairs({"UIAssetConfig","UIThemeConfig","DeveloperProductConfig","Rules","SoundConfig","BattleEffectsConfig","ShopPreviewConfig","DropEffectConfig","RankIconConfig","CurrencyIconConfig","BrickSkinConfig","GhostEffectConfig"}) do named("ModuleScript",name,ConfigFolder) end
local Network=named("RemoteEvent","Network",Shared); Network.OnClientEvent=signal()
local requests={}; function Network:FireServer(kind,payload) table.insert(requests,{Kind=kind,Payload=payload}) end
local PlayerGui=named("Folder","PlayerGui")
local player=named("Player","LocalPlayer"); player.UserId=123; player.DisplayName="Test Player"; PlayerGui.Parent=player
local Players={LocalPlayer=player,GetPlayers=function() return {player} end}
local UIS={GamepadEnabled=false,InputEnded=signal(),WindowFocusReleased=signal(),InputBegan=signal(),GetFocusedTextBox=function() return nil end}
local CAS={BindActionAtPriority=function() end,UnbindAction=function() end}
local RunService={RenderStepped=signal()}
local SoundService=named("Folder","SoundService")
local TweenService={Create=function(_,obj,_,properties) return {Play=function() for k,v in pairs(properties) do obj[k]=v end end,Cancel=function() end,Completed=signal()} end}
local TextService={GetTextSize=function(_,value,size,_,bounds)
	local lines=0; for _,line in ipairs(string.split(value,"\n")) do lines+=math.max(1,math.ceil(#line*size*0.55/bounds.X)) end
	return Vector2.new(bounds.X,lines*size*1.2)
end}
local services={Players=Players,ReplicatedStorage=ReplicatedStorage,UserInputService=UIS,GuiService={},RunService=RunService,ContextActionService=CAS,SoundService=SoundService,TweenService=TweenService,TextService=TextService,ContentProvider={PreloadAsync=function(_,uris,callback) for _,uri in ipairs(uris) do callback(uri,Enum.AssetFetchStatus.Success) end end},SocialService={}}
local game=setmetatable({GetService=function(_,name) return assert(services[name],"Unknown service "..name) end},{__index=services})
local workspace={GetServerTimeNow=function() return 1791590400 end}
local clientFolder=named("Folder","Client")
for _,name in ipairs({"UIAssets","RetroTheme","RetroArtwork","BrickStyles","BrickRenderer","BrickPreviewRenderer","NeonUI","NeonLayout","GameClient","ArcadeFeedback","ArcadeResults","PortalUI","AudioController","InputController","CosmeticRenderer"}) do named("ModuleScript",name,clientFolder) end
local script={Parent=clientFolder}
local modules={UIAssetConfig=UIAssetConfig,UIThemeConfig=UIThemeConfig,DeveloperProductConfig=DeveloperProductConfig,TetrisEngine=E,Rules=R,Progression=P,SoundConfig=SoundConfig,Catalog=Catalog,BattleEffectsConfig=BattleEffectsConfig,ShopPreviewConfig=ShopPreviewConfig,DropEffectConfig=DropEffectConfig,RankIconConfig=RankIconConfig,CurrencyIconConfig=CurrencyIconConfig,BrickSkinConfig=BrickSkinConfig,GhostEffectConfig=GhostEffectConfig}
local require=function(obj) return assert(modules[type(obj)=="string" and obj or obj.Name],"Unknown module") end
local warn=print
