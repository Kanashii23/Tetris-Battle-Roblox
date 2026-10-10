local Config={Default={Alpha=1},NeonOutline={Alpha=0.95},Hologram={Alpha=0.9},Pulse={Alpha=0.97},Glitch={Alpha=0.97},Prism={Alpha=0.98},Electric={Alpha=0.98},PixelDotted={Alpha=1},CyberScanline={Alpha=0.96},CrystalOutline={Alpha=1},GoldenTrace={Alpha=1},GalaxyShadow={Alpha=0.93},RoyalPrism={Alpha=0.97}}
function Config.ResolveAsset(id,piece,component)
 local ids=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CosmeticsAssetResolver"))
 return ids.resolve("GhostFX",id,piece,component)
end
return Config
