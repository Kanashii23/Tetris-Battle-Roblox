-- Readiness and animation metadata; editable IDs are in CosmeticsAssetIds.
local Assets={Readiness={

 DefaultClassic={Supplied=true,Uploaded=false,Status="IDsConfigured_AccessUnverified"},

 OceanWave={Supplied=false,Uploaded=false,Status="NotSupplied"},

 RetroPixel={Supplied=false,Uploaded=false,Status="NotSupplied"},

 NeonClub={Supplied=false,Uploaded=false,Status="NotSupplied"},

 CrystalGlass={Supplied=false,Uploaded=false,Status="NotSupplied"},

 CyberCore={Supplied=false,Uploaded=false,Status="NotSupplied"},

 Glitch={Supplied=false,Uploaded=false,Status="NotSupplied"},

 Lava={Supplied=false,Uploaded=false,Status="NotSupplied"},

 Galaxy={Supplied=false,Uploaded=false,Status="NotSupplied"},

 GoldElite={Supplied=false,Uploaded=false,Status="NotSupplied"},

 Holographic={Supplied=false,Uploaded=false,Status="NotSupplied"},

 RoyalPrism={Supplied=false,Uploaded=false,Status="NotSupplied"},

},Aliases={

 Bricks={Default="DefaultClassic"},

 GhostFX={Default="DefaultClassic",NeonOutline="NeonClub",Hologram="Holographic",Pulse="NeonClub",Prism="RoyalPrism",Electric="CyberCore",PixelDotted="RetroPixel",CyberScanline="CyberCore",CrystalOutline="CrystalGlass",GoldenTrace="GoldElite",GalaxyShadow="Galaxy"},

 DropFX={Default="DefaultClassic",NeonSparks="NeonClub",LightningStrike="CyberCore",Stardust="Galaxy",FireBurst="Lava",PixelExplosion="RetroPixel",CrystalShatter="CrystalGlass",CyberGlitch="Glitch",GoldenImpact="GoldElite"}

},Animation={DefaultClassic={Droplets=6,WhiteBase=0.16,Ripple=0.26,Droplet=0.32,Delay=0.02,RippleFrom=0.5,RippleTo=1.45,WhiteBaseRotation=90}}}
return Assets
