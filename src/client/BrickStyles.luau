local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local Config=game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
local Styles={Skins=require(Config:WaitForChild("BrickSkinConfig")),Ghosts=require(Config:WaitForChild("GhostEffectConfig"))}
function Styles.describe(kind,skinId,ghostId,ghost,reduced,clock)
	local C=Theme.Colors; local skin=Styles.Skins[skinId] or Styles.Skins.Default; local base=C[kind] or C.G
	if kind=="G" then skin={Texture="Metal",Inset=1}; base=Color3.fromRGB(99,104,130) end
	if skin.Tint then base=base:Lerp(Color3.fromRGB(table.unpack(skin.Tint)),skin.Blend) end
	local border=base:Lerp(C.text,skin.Texture=="Neon" and 0.65 or 0.3); local fill=0; local time=reduced and 0 or clock or 0
	if ghost then
		local effect=Styles.Ghosts[ghostId] or Styles.Ghosts.Default; fill=effect.Alpha
		if ghostId=="Pulse" then fill+=math.sin(time*4)*0.02 elseif ghostId=="Glitch" then fill+=math.floor(time*6)%2*0.02
		elseif ghostId=="Prism" or ghostId=="RoyalPrism" then border=border:Lerp(Color3.fromHSV(time%6/6,0.6,1),0.35)
		elseif ghostId=="GoldenTrace" then border=Color3.fromRGB(255,207,88) elseif ghostId=="GalaxyShadow" then border=Color3.fromRGB(179,133,245) elseif ghostId=="Electric" then fill+=math.sin(time*12)*0.015 end
	end
	return {Color=base,Edge=border,Transparency=math.clamp(fill,0,1),Texture=ghost and ghostId or skin.Texture,Inset=skin.Inset,Ghost=ghost}
end
return Styles
