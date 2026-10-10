local ProfileStore=modules.ProfileStore; local ns=Data.Namespace
local a,b=player(101),player(202)
assert(Data:load(a) and Data:load(b)); local pa,pb=Data.Profiles[a.UserId].Profile,Data.Profiles[b.UserId].Profile
assert(pa:IsActive() and pb:IsActive() and pa~=pb and pa.Key=="101" and pb.Key=="202")
assert(table.find(pa.UserIds,101)); assert(records[ns]["101"].Data.Cash==0)
assert(next(ProfileStore.Test().MockStore)==nil and next(ProfileStore.Test().UserMockStore)==nil)
print("PASS supplied ProfileStore creates distinct active sessions with user IDs and real-backend API calls")
assert(Data:mutate(a,function(d)
	d.Cash=125000; d.Rank={Tier=3,Stars=2,Rating=1345}; d.Stats.Wins=9; d.Stats.Losses=4; d.Stats.CurrentWinStreak=3; d.Stats.BestWinStreak=6
	d.Season.Rating=1500; d.Season.Wins=5; d.Quests.Daily.Progress.lines=24; d.Quests.Weekly.Progress.wins=8
	d.Login.Index=4; d.Login.LastDay=math.floor(os.time()/86400); d.Achievements.Test=true; d.Inventory.Badges.Test=true; d.Settings.ReducedMotion=true; d.Settings.Sound=false
	d.Energy.Current=3; d.Energy.LastRegenTimestamp=os.time(); return true
end))
for _,category in ipairs(Catalog.Categories) do local item=Catalog.list(category)[2]
	assert(Data:mutate(a,function(d) return P.purchase(d,category,item.Id,Catalog,false) end))
	assert(Data:mutate(a,function(d) return P.equip(d,category,item.Id,Catalog,false) end))
end
local saved=P.clone(Data:get(a)); Data:release(a); assert(not pa:IsActive() and not Data:get(a)); assert(Data:load(a))
local after=Data:get(a)
assert(after.Cash==saved.Cash and after.Rank.Tier==3 and after.Rank.Stars==2 and after.Rank.Rating==1345)
assert(after.Stats.Wins==9 and after.Stats.Losses==4 and after.Stats.CurrentWinStreak==3 and after.Season.Rating==1500)
assert(after.Quests.Daily.Progress.lines==24 and after.Quests.Weekly.Progress.wins==8 and after.Login.Index==4)
assert(after.Achievements.Test and after.Inventory.Badges.Test and after.Settings.ReducedMotion and not after.Settings.Sound)
for _,category in ipairs(Catalog.Categories) do local item=Catalog.list(category)[2]; assert(after.Inventory[category][item.Id] and after.Equipped[Catalog.Slots[category]]==item.Id) end
assert(Data:get(b).Cash==0 and Data:get(b).Rank.Tier==1)
print("PASS Cash, energy, ranks/stars, stats, seasons, four cosmetic slots, quests, login, achievements and settings survive release/rejoin")
Data:release(a); tick(C.EnergyInterval*2+1); assert(Data:load(a)); assert(Data:get(a).Energy.Current==5)
assert(Data:get(a).Energy.LastRegenTimestamp>=saved.Energy.LastRegenTimestamp+C.EnergyInterval*2)
print("PASS offline energy regeneration uses the saved timestamp and preserves partial interval progress")
local legacyPlayer=player(303); local legacy=P.refresh(P.default(os.time()),os.time(),C); legacy.Cash=4321; legacy.Rank={Tier=4,Stars=2,Rating=1600}
legacy.Inventory.BrickSkins.Galaxy=true; legacy.Equipped.BrickSkin="Galaxy"; legacy.CustomUnrecognizedField={Kept=true}
local original={Data=P.clone(legacy),Lease={Owner="old-server",Expires=os.time()-1}}
seed(ns,303,original); assert(Data:load(legacyPlayer)); assert(Data:get(legacyPlayer).Cash==4321 and Data:get(legacyPlayer).Rank.Tier==4 and Data:get(legacyPlayer).Equipped.BrickSkin=="Galaxy")
assert(Data:get(legacyPlayer).CustomUnrecognizedField.Kept and records[ns.."_Backup"]["303"].Original.Data.Cash==4321)
assert(records[ns.."_Backup"]["303"].Original.Lease.Owner=="old-server" and records[ns]["303"].MetaData and not records[ns]["303"].Lease)
Data:release(legacyPlayer); assert(Data:load(legacyPlayer)); assert(Data:get(legacyPlayer).Cash==4321)
print("PASS legacy conversion backs up the full original envelope, keeps names/keys/data and is idempotent")
local rawPlayer=player(304); legacy.Cash=765; seed(ns,304,legacy); assert(Data:load(rawPlayer)); assert(Data:get(rawPlayer).Cash==765)
print("PASS recognized raw v1 saves migrate without losing balances or purchased skins")
local locked=player(404); original.Lease.Expires=os.time()+180; seed(ns,404,original)
assert(not Data:load(locked) and not Data:get(locked)); assert(records[ns]["404"].Lease.Owner=="old-server" and records[ns.."_Backup"]["404"]==nil)
local corrupt=player(405); seed(ns,405,{Data={Cash="bad"},Lease={Expires=0}}); assert(not Data:load(corrupt)); assert(records[ns]["405"].Data.Cash=="bad")
local future=player(406); seed(ns,406,{Data={SchemaVersion=2,Cash=999}}); assert(not Data:load(future)); assert(records[ns]["406"].Data.Cash==999)
local malformed=player(409); seed(ns,409,{Data=legacy,MetaData={SessionLoadCount="bad"},GlobalUpdates={0,{}}}); assert(not Data:load(malformed)); assert(records[ns]["409"].MetaData.SessionLoadCount=="bad" and records[ns.."_Backup"]["409"]==nil)
print("PASS live legacy leases, invalid balances and future schemas fail closed without replacing saves")
local backupFailed=player(407); seed(ns,407,{Data=legacy}); faults.Writes[ns.."_Backup"]=true
assert(not async(function() return Data:load(backupFailed) end,4)); faults.Writes[ns.."_Backup"]=nil
assert(not records[ns]["407"].MetaData and records[ns]["407"].Data.Cash==765)
print("PASS backup failure prevents conversion and leaves the original player record intact")
local changed=player(408); seed(ns,408,{Data=legacy})
faults.AfterWrite[ns.."_Backup"]=function(key) if key=="408" then local newer=P.clone(legacy); newer.Cash=888; seed(ns,408,{Data=newer}) end end
assert(not Data:load(changed)); faults.AfterWrite[ns.."_Backup"]=nil
assert(records[ns]["408"].Data.Cash==888 and not records[ns]["408"].MetaData)
print("PASS version-checked conversion refuses concurrent legacy edits after backup")
local failed=player(505); faults.Reads[ns]=true
assert(not async(function() return Data:load(failed) end,4)); faults.Reads[ns]=nil
assert(not Data:get(failed) and not records[ns]["505"])
assert(not Data:mutate(failed,function(d) d.Cash+=1000; return true end))
print("PASS failed initial reads never create default records or permit purchases/rewards")
local noAccess=player(506); ProfileStore.DataStoreState="NoAccess"
assert(not Data:load(noAccess) and not Data:get(noAccess)); assert(next(ProfileStore.Test().MockStore)==nil)
ProfileStore.DataStoreState="Access"
print("PASS unavailable API access is rejected instead of falling back to a production mock profile")
local unavailable=player(507); faults.Writes[ns]=true
assert(not async(function() return Data:load(unavailable) end,8)); faults.Writes[ns]=nil
assert(not Data:get(unavailable) and not records[ns]["507"])
print("PASS StartSessionAsync write outages respect cancellation deadlines and never unlock the shop")
local r={id="durable-result",outcome="Win",score=0,lines=0,spins=0,tetrises=0,perfect=0,sent=0,kos=0,startTier=1,startRating=1000,opponentRating=1000,rewardEligible=true,opponentId=999,day=math.floor(os.time()/86400),timestamp=os.time()}
local c=player(606); seed(ns.."_Results",606,{[r.id]=r}); assert(Data:load(c)); assert(Data:get(c).Cash==50 and next(records[ns.."_Results"]["606"])==nil)
assert(Data:settle(c,r) and Data:get(c).Cash==50); Data:release(c); assert(Data:load(c)); assert(Data:get(c).Cash==50)
print("PASS durable result inbox recovery and confirmed-save cleanup grant ranked rewards once")
local recovery=player(607); seed(ns.."_Results",607,{[r.id]=r}); faults.Writes[ns]=true
assert(not async(function() return Data:load(recovery) end,8)); faults.Writes[ns]=nil
assert(records[ns.."_Results"]["607"][r.id] and not Data:get(recovery))
assert(Data:load(recovery) and Data:get(recovery).Cash==50)
print("PASS failed recovery keeps the durable result and blocks play until a successful rejoin")
local loss=player(707); assert(Data:load(loss)); local raw=Data.Profiles[707].Profile
records[ns]["707"].MetaData.ActiveSession={200,"another-server","external"}; raw:Save()
assert(not raw:IsActive() and not Data:get(loss) and loss.Kicked)
assert(not Data:mutate(loss,function(d) d.Cash+=999; return true end))
print("PASS external session loss clears access, kicks safely and rejects later mutations")
local leaving=player(808); faults.Latency[ns]=0.1; local outcome
task.spawn(function() outcome=Data:load(leaving) end); leaving.Parent=nil; tick(1); faults.Latency[ns]=nil
assert(outcome==false and not Data:get(leaving)); local opened=ProfileStore.Test().ActiveSessionCheck; for _,profile in pairs(opened) do assert(profile.Key~="808") end
print("PASS players leaving during load cancel acquisition and cannot retain an active profile")
local reservation=player(809); assert(Data:load(reservation)); assert(Data:mutate(reservation,function(d) d.Energy.Current=8; d.Reservations.abandoned={At=os.time()}; return true end))
Data:release(reservation); assert(Data:load(reservation)); assert(Data:get(reservation).Energy.Current==9 and not next(Data:get(reservation).Reservations))
Data:release(reservation); assert(Data:load(reservation)); assert(Data:get(reservation).Energy.Current==9)
print("PASS abandoned energy reservations refund once and remain cleared after rejoin")
local purchase=player(909); assert(Data:load(purchase)); assert(Data:mutate(purchase,function(d) d.Cash=125000; return true end))
faults.Writes[ns]=true; local skin=Catalog.list("BrickSkins")[2]
assert(not async(function() return Data:mutate(purchase,function(d) return P.purchase(d,"BrickSkins",skin.Id,Catalog,false) end) end,4))
assert(not Data:get(purchase) and purchase.Kicked and not Data:mutate(purchase,function(d) d.Cash+=999; return true end))
faults.Writes[ns]=nil; tick(5); assert(Data:load(purchase))
local recoveredPurchase=Data:get(purchase)
assert(recoveredPurchase.Cash==125000-skin.Price and recoveredPurchase.Inventory.BrickSkins[skin.Id])
assert(not Data:mutate(purchase,function(d) return P.purchase(d,"BrickSkins",skin.Id,Catalog,false) end))
print("PASS ambiguous save failure closes access and preserves the atomic Cash/ownership pair without free or duplicate items")
local duplicate=player(909); assert(not Data:load(duplicate)); assert(Data:get(purchase) and not Data:get(duplicate))
print("PASS duplicate player objects cannot reuse another player's loaded session")
for _,p in ipairs(Players.List) do Data:release(p) end
assert(next(ProfileStore.Test().ActiveSessionCheck)==nil)
print("PASS all normal releases call EndSession and clear active library sessions")
print("ProfileStore checks executed the exact supplied library against simulated Roblox services; no cloud data was read or written.")
