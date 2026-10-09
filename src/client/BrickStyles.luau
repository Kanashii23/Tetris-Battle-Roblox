-- Shared definitions for match boards, hold/next and cosmetic samples.
local Theme=require(script.Parent:WaitForChild("RetroTheme"))
local Styles={Skins={
	Default={Texture="Bevel",Blend=0,Inset=1},NeonClub={Texture="Neon",Blend=0.12,Tint={255,61,143},Inset=1},
	CyberCore={Texture="Circuit",Blend=0.34,Tint={40,60,94},Inset=1},OceanWave={Texture="Wave",Blend=0.36,Tint={24,158,202},Inset=1},
	Galaxy={Texture="Star",Blend=0.30,Tint={113,50,158},Inset=1},GoldElite={Texture="Gold",Blend=0.78,Tint={238,181,63},Inset=1},
	Lava={Texture="Lava",Blend=0.55,Tint={221,63,33},Inset=1},CrystalGlass={Texture="Crystal",Blend=0.30,Tint={178,223,237},Inset=2},
	RetroPixel={Texture="Pixel",Blend=0,Inset=2},Holographic={Texture="Scan",Blend=0.22,Tint={92,225,218},Inset=1},
},Ghosts={Default={Alpha=0.9},NeonOutline={Alpha=0.83},Hologram={Alpha=0.82},Pulse={Alpha=0.87},Glitch={Alpha=0.87},Prism={Alpha=0.84},Electric={Alpha=0.87}}}
function Styles.describe(kind,skinId,ghostId,ghost,reduced,clock)
	local C=Theme.Colors; local skin=Styles.Skins[skinId] or Styles.Skins.Default; local base=C[kind] or C.G
	if skin.Tint then base=base:Lerp(Color3.fromRGB(table.unpack(skin.Tint)),skin.Blend) end
	local fill=0; local border=base:Lerp(C.text,skin.Texture=="Neon" and 0.6 or 0.22)
	if ghost then local effect=Styles.Ghosts[ghostId] or Styles.Ghosts.Default; local time=reduced and 0 or clock or 0
		fill=effect.Alpha
		if ghostId=="Pulse" then fill+=math.sin(time*4)*0.045
		elseif ghostId=="Glitch" then fill+=math.floor(time*6)%2*0.035
		elseif ghostId=="Prism" then border=border:Lerp(Color3.fromHSV(time%6/6,0.6,1),0.3)
		elseif ghostId=="Electric" then fill+=math.sin(time*12)*0.025 end
	end
	return {Color=base,Edge=border,Transparency=fill,Texture=ghost and "Ghost" or skin.Texture,Inset=skin.Inset,Ghost=ghost}
end
return Styles
