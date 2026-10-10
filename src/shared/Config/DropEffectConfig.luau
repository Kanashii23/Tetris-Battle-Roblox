local Config={
	MaxActive=36,Duration=0.45,
	Styles={Default={Style="Pulse",Count=1,Color={210,183,255}},NeonSparks={Style="Wave",Count=5,Color={66,222,255}},LightningStrike={Style="Bolt",Count=6,Color={135,206,255}},Stardust={Style="Orbit",Count=10,Color={184,115,255}},FireBurst={Style="Flame",Count=10,Color={255,116,38}},PixelExplosion={Style="Pixel",Count=8,Color={244,132,211}},CrystalShatter={Style="Shard",Count=8,Color={128,231,249}},CyberGlitch={Style="Glitch",Count=5,Color={71,241,184}},GoldenImpact={Style="Spark",Count=10,Color={255,209,74}},RoyalPrism={Style="Prism",Count=10,Color={216,137,255}}},
}
function Config.ResolveAsset(id,piece,component)
 local ids=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CosmeticsAssetResolver"))
 return ids.resolve("DropFX",id,piece,component)
end
return Config
