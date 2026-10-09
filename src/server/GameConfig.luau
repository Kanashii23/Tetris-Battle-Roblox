-- Server-only authority. Debug privileges are effective ONLY in Roblox Studio.
return {
	Debug=true, FreeCosmeticsInDebug=true, InfiniteEnergyInDebug=true,
	CosmeticDebugLogging=true, -- Temporary request diagnostics, Roblox Studio only.
	FreeShopPurchasesInDebug=true, TestRankedMatches=true,
	DataStoreName="TetrisBattle_Player_v1", LockLease=180, Autosave=45,
	-- First verify real persistence in a separate published TEST experience.
	-- Live stays on the existing backend until this rollout switch is enabled.
	ProfileStoreLiveEnabled=false, ProfileStoreStudioPersistence=false,
	ProfileStoreTestDataStoreName="TetrisBattle_ProfileStoreTest_v1",
	ProfileStoreMigrateLegacy=true, ProfileLoadTimeout=90, ProfileSaveTimeout=15,
	MaxPlayers=100, MaxMatches=50, AllowDemotion=true,
	EnergyCap=10, BonusEnergyCap=20, EnergyInterval=600, RankedCost=1,
	WinCash={50,75,100,150,225,350,500}, MasterK=24,
	SeasonStart=1791590400, SeasonDays=42, SeasonResetRating=1000,
	SeasonCashPerWin=10, SeasonCashCap=2000,
	MinRewardSeconds=20, OpponentRewardCooldown=600, PairRewardsPerDay=3,
	SocialDailyLimit=2, SocialEnergy=1, SocialMinSeconds=120, SocialMinAccountAge=7,
	LoginCash={25,50,75,100,125,150,250}, LoginEnergy={0,0,1,0,1,0,2},
}
