local SoundService=game:GetService("SoundService")
local Config=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SoundConfig"))
local Effects=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("BattleEffectsConfig"))
local PreviewConfig=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ShopPreviewConfig"))
local Audio={}; Audio.__index=Audio
function Audio.normalize(value)
	if type(value)~="string" then return "" end
	local id=value:match("^%s*(%d+)%s*$") or value:match("^rbxassetid://(%d+)$")
	return id and "rbxassetid://"..id or ""
end
function Audio.new()
	local self=setmetatable({Pool={},Muted=false,Pack="Default",Master=Config.MasterVolume,MusicVolume=Config.MusicVolume,SFXVolume=Config.SFXVolume,Failed={}},Audio)
	self.Folder=Instance.new("Folder"); self.Folder.Name="TetrisAudio"; self.Folder.Parent=SoundService
	self.Music=Instance.new("Sound"); self.Music.Name="Music"; self.Music.Looped=true; self.Music.Parent=self.Folder
	self.Warning=Instance.new("Sound"); self.Warning.Name="GarbageWarning"; self.Warning.Parent=self.Folder; self.WarningNext=0; self.WarningGeneration=0
	return self
end
function Audio:resolve(key,packId)
	local pack=Config.Packs[packId or self.Pack] or Config.Packs.Default
	return Audio.normalize(pack.Sounds[key] or Config.Sounds[key]),pack.Pitch or 1
end
function Audio:preview(packId)
	if self.Muted then return false,"Sound is muted." end
	for _,key in ipairs({"HardDrop","Rotate","Tetris","Move"}) do
		local id,pitch=self:resolve(key,packId)
		if id~="" and not self.Failed[id] then
			if self.Preview then self.Preview:Destroy() end
			local sample=Instance.new("Sound"); self.Preview=sample; sample.Name="PackPreview"; sample.SoundId=id
			sample.PlaybackSpeed=pitch; sample.Volume=self.Master*self.SFXVolume; sample.Parent=self.Folder
			local started=false; local loaded
			local function finish()
				if loaded then loaded:Disconnect(); loaded=nil end
				if sample.Parent then sample:Stop(); sample:Destroy() end
				if self.Preview==sample then self.Preview=nil end
			end
			local function start()
				if started or self.Preview~=sample or not sample.Parent then return end
				started=true; sample:Play(); task.delay(PreviewConfig.SoundSampleSeconds,finish)
			end
			loaded=sample.Loaded:Connect(start); if sample.IsLoaded then start() end
			task.delay(8,function() if not started then if self.Preview==sample then self.Failed[id]=true; warn("[Tetris Audio] Could not load pack sample: "..id) end; finish() end end)
			return true
		end
	end
	return false,"No audio sample is available yet."
end
function Audio:stopPreview() if self.Preview then self.Preview:Stop(); self.Preview:Destroy(); self.Preview=nil end end
function Audio:play(key,asset)
	if self.Muted then return end
	local id,pitch=self:resolve(key); if asset and asset~="" then id=Audio.normalize(asset) end; if id=="" or self.Failed[id] then return end
	local sound
	for _,s in ipairs(self.Pool) do if not s.IsPlaying then sound=s; break end end
	if not sound then
		if #self.Pool>=16 then return end
		sound=Instance.new("Sound"); sound.Parent=self.Folder; table.insert(self.Pool,sound)
	end
	sound.SoundId=id; sound.PlaybackSpeed=pitch; sound.Volume=self.Master*self.SFXVolume
	sound:Play()
	task.delay(8,function()
		if sound.Parent and sound.SoundId==id and not sound.IsLoaded then self.Failed[id]=true; sound:Stop(); warn("[Tetris Audio] Could not load permitted audio: "..id) end
	end)
end
function Audio:warning(lines,clock)
	local level=0; for i,threshold in ipairs(Effects.Garbage.Thresholds) do if lines>=threshold then level=i end end
	if level==0 or self.Muted or self.SFXVolume==0 then self.Warning:Stop(); self.WarningNext=0; return false end
	if (clock<self.WarningNext and level<=(self.WarningLevel or 0)) or clock<(self.WarningStarted or -1e9)+Config.GarbageWarning.MinimumInterval or self.Warning.IsPlaying then return false end
	local key=({"GarbageWarningLow","GarbageWarningMedium","GarbageWarningHigh","GarbageWarningCritical"})[level]
	local id,pitch=self:resolve(key); if id=="" or self.Failed[id] then return false end
	self.WarningGeneration+=1; local generation=self.WarningGeneration
	self.WarningLevel=level; self.WarningStarted=clock
	self.WarningLevelVolume=Config.GarbageWarning.Volumes[level]
	self.Warning.SoundId=id; self.Warning.Volume=self.Master*self.SFXVolume*self.WarningLevelVolume; self.Warning.PlaybackSpeed=pitch; self.Warning:Play()
	self.WarningNext=clock+Config.GarbageWarning.Cooldowns[level]
	task.delay(Config.GarbageWarning.MaxSampleSeconds,function() if self.WarningGeneration==generation and self.Warning.Parent then self.Warning:Stop() end end)
	return true
end
function Audio:music(key)
	local id=self:resolve(key)
	if self.Failed[id] then id="" end
	if self.Music.SoundId==id then return end
	self.Music:Stop(); self.Music.SoundId=id; self.Music.Volume=self.Muted and 0 or self.Master*self.MusicVolume
	if id~="" then
		self.Music:Play()
		task.delay(8,function()
			if self.Music.Parent and self.Music.SoundId==id and not self.Music.IsLoaded then self.Failed[id]=true; self.Music:Stop(); warn("[Tetris Audio] Could not load permitted music: "..id) end
		end)
	end
end
function Audio:settings(master,music,sfx,muted)
	self.Master=math.clamp(master,0,1); self.MusicVolume=math.clamp(music,0,1); self.SFXVolume=math.clamp(sfx,0,1); self.Muted=muted
	self.Music.Volume=muted and 0 or self.Master*self.MusicVolume
	for _,sound in ipairs(self.Pool) do sound.Volume=muted and 0 or self.Master*self.SFXVolume end
	if self.Preview then self.Preview.Volume=muted and 0 or self.Master*self.SFXVolume end
	self.Warning.Volume=muted and 0 or self.Master*self.SFXVolume*(self.WarningLevelVolume or 0); if muted then self.Warning:Stop() end
end
function Audio:destroy() self.Folder:Destroy() end
return Audio
