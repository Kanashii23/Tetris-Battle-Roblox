-- Pure economy and progression. Only the server may persist these mutations.
local P={Ranks={"Rookie","Bronze","Silver","Gold","Platinum","Diamond","Master"},Stars={3,4,5,5,6,7,0}}
P.Daily={{Id="play",Label="Play 3 ranked matches",Stat="Matches",Target=3,Cash=100},{Id="lines",Label="Clear 30 lines",Stat="Lines",Target=30,Cash=75},{Id="spin",Label="Perform 2 T-Spins",Stat="TSpins",Target=2,Energy=1},{Id="wins",Label="Win 2 battles",Stat="Wins",Target=2,Cash=150},{Id="send",Label="Send 20 garbage lines",Stat="Sent",Target=20,Cash=100}}
P.Weekly={{Id="wins",Label="Win 15 battles",Stat="Wins",Target=15,Cash=1000},{Id="lines",Label="Clear 500 lines",Stat="Lines",Target=500,Cash=750},{Id="spins",Label="Perform 25 T-Spins",Stat="TSpins",Target=25,Energy=5},{Id="tetrises",Label="Clear 10 Tetrises",Stat="Tetrises",Target=10,Cash=500},{Id="daily",Label="Complete 20 daily quests",Stat="DailyClaims",Target=20,Cash=1000}}
local function clone(t) if type(t)~="table" then return t end; local out={}; for k,v in pairs(t) do out[k]=clone(v) end; return out end
P.clone=clone
local function int(value,default,max) if type(value)~="number" or value~=value then return default end; return math.clamp(math.floor(value),0,max or 1e9) end
function P.default(now)
	return {SchemaVersion=1,Cash=0,Energy={Current=10,LastRegenTimestamp=now},Rank={Tier=1,Stars=0,Rating=1000},
		Stats={Wins=0,QualifiedWins=0,Losses=0,Draws=0,Matches=0,KOs=0,Lines=0,TSpins=0,Tetrises=0,PerfectClears=0,Sent=0,BestWinStreak=0,CurrentWinStreak=0},
		Inventory={BrickSkins={Default=true},DropEffects={Default=true},GhostEffects={Default=true},SoundPacks={Default=true},Badges={}},
		Equipped={BrickSkin="Default",DropEffect="Default",GhostEffect="Default",SoundPack="Default"},Quests={},SocialRewards={Seen={},Day=0,Count=0},
		Season={Id=0,Rating=1000,Wins=0,History={}},ProcessedMatchIds={},MatchReceipts={},Reservations={},Pairs={},Achievements={},Login={LastDay=-1,Index=0},Settings={Sound=true,ReducedMotion=false,Master=1,MusicVolume=0.5,SFXVolume=0.8,UIScale=1,ClassicHUD=false,SwapRotation=false},CreatedAt=now,
	}
end
function P.validate(data,now,catalog,config)
	assert(type(data)=="table","Invalid profile")
	assert(not data.SchemaVersion or data.SchemaVersion<=1,"Unsupported newer data schema")
	local defaults=P.default(now)
	local function merge(dst,src)
		for k,v in pairs(src) do if dst[k]==nil then dst[k]=clone(v) elseif type(v)=="table" and type(dst[k])=="table" then merge(dst[k],v) elseif type(dst[k])~=type(v) then dst[k]=clone(v) end end
	end
	merge(data,defaults); data.SchemaVersion=1; data.Cash=int(data.Cash,0)
	data.Energy.Current=int(data.Energy.Current,10,config and config.BonusEnergyCap or 20); data.Energy.LastRegenTimestamp=int(data.Energy.LastRegenTimestamp,now,now)
	data.Rank.Tier=math.clamp(int(data.Rank.Tier,1),1,7); data.Rank.Stars=int(data.Rank.Stars,0,7); data.Rank.Rating=int(data.Rank.Rating,1000,100000)
	data.Rank.Stars=data.Rank.Tier==7 and 0 or math.min(data.Rank.Stars,P.Stars[data.Rank.Tier]-1)
	data.Season.Id=int(data.Season.Id,0); data.Season.Wins=int(data.Season.Wins,0); data.Season.Rating=int(data.Season.Rating,1000,100000)
	for key in pairs(defaults.Stats) do data.Stats[key]=int(data.Stats[key],0) end
	for key,pair in pairs(data.Pairs) do
		if type(pair)~="table" then data.Pairs[key]=nil else pair.Day=int(pair.Day,0); pair.Count=int(pair.Count,0); pair.Last=int(pair.Last,0,now) end
	end
	for category,slot in pairs(catalog.Slots) do
		local inventory={Default=true}
		for key,value in pairs(data.Inventory[category]) do
			local id=type(key)=="number" and value or key
			if type(id)=="string" and catalog.Items[category..":"..id] and (type(key)=="number" or value==true) then inventory[id]=true end
		end
		data.Inventory[category]=inventory
		if not data.Inventory[category][data.Equipped[slot]] or not catalog.Items[category..":"..data.Equipped[slot]] then data.Equipped[slot]="Default" end
	end
	return data
end
function P.refresh(d,now,c)
	local e=d.Energy
	if e.Current>=c.EnergyCap then e.LastRegenTimestamp=now else
		local steps=math.max(0,math.floor((now-e.LastRegenTimestamp)/c.EnergyInterval))
		e.Current=math.min(c.EnergyCap,e.Current+steps); e.LastRegenTimestamp+=steps*c.EnergyInterval
		if e.Current==c.EnergyCap then e.LastRegenTimestamp=now end
	end
	local day=math.floor(now/86400); local week=math.floor((day+3)/7)
	for group,window in pairs({Daily=day,Weekly=week}) do
		local state=d.Quests[group]
		if type(state)~="table" or state.Window~=window or type(state.Progress)~="table" or type(state.Claimed)~="table" then d.Quests[group]={Window=window,Progress={},Claimed={}} end
		for _,q in ipairs(P[group]) do d.Quests[group].Progress[q.Id]=int(d.Quests[group].Progress[q.Id],0,q.Target) end
	end
	if d.SocialRewards.Day~=day then d.SocialRewards.Day=day; d.SocialRewards.Count=0 end
	local id=math.max(1,math.floor((now-c.SeasonStart)/(c.SeasonDays*86400))+1)
	if d.Season.Id~=id then
		if d.Season.Id>0 then
			table.insert(d.Season.History,{Id=d.Season.Id,Rating=d.Season.Rating,Wins=d.Season.Wins})
			if #d.Season.History>12 then table.remove(d.Season.History,1) end
			d.Cash+=math.min(c.SeasonCashCap,d.Season.Wins*c.SeasonCashPerWin)
			if d.Season.Wins>0 then d.Inventory.Badges["Season"..d.Season.Id]=true end
		end
		d.Season.Id=id; d.Season.Rating=c.SeasonResetRating; d.Season.Wins=0
	end
	return d
end
function P.nextEnergy(d,now,c) return d.Energy.Current>=c.EnergyCap and 0 or math.max(0,c.EnergyInterval-(now-d.Energy.LastRegenTimestamp)) end
function P.questProgress(d,delta)
	for group,definitions in pairs({Daily=P.Daily,Weekly=P.Weekly}) do
		for _,q in ipairs(definitions) do local p=d.Quests[group].Progress; p[q.Id]=math.min(q.Target,(p[q.Id] or 0)+(delta[q.Stat] or 0)) end
	end
end
local function energy(d,n,c) d.Energy.Current=math.min(c.BonusEnergyCap,d.Energy.Current+n) end
function P.claimQuest(d,group,id,c)
	local state=d.Quests[group]; if not state then return false,"Unknown quest group" end
	for _,q in ipairs(group=="Daily" and P.Daily or P.Weekly) do
		if q.Id==id then
			if state.Claimed[id] then return false,"Already claimed" end
			if (state.Progress[id] or 0)<q.Target then return false,"Quest incomplete" end
			state.Claimed[id]=true; d.Cash+=q.Cash or 0; energy(d,q.Energy or 0,c)
			if group=="Daily" then P.questProgress(d,{DailyClaims=1}) end
			return true,"Quest reward claimed"
		end
	end
	return false,"Unknown quest"
end
function P.login(d,now,c)
	local day=math.floor(now/86400); if d.Login.LastDay==day then return false,"Already claimed today" end
	-- Missed days do not erase progress; the cycle advances only when claimed.
	d.Login.LastDay=day; d.Login.Index=d.Login.Index%7+1
	d.Cash+=c.LoginCash[d.Login.Index]; energy(d,c.LoginEnergy[d.Login.Index],c); return true,"Day "..d.Login.Index.." reward claimed"
end
function P.purchase(d,category,id,catalog,free)
	local item=catalog.Items[category..":"..id]; if not item then return false,"Unknown cosmetic" end
	if d.Inventory[category][id] then return false,"Already owned" end
	local price=free and 0 or item.Price; if d.Cash<price then return false,"Not enough Cash" end
	d.Cash-=price; d.Inventory[category][id]=true; return true,"Purchased "..item.Name
end
function P.equip(d,category,id,catalog,free)
	local slot=type(category)=="string" and catalog.Slots[category]
	if not slot or type(id)~="string" or not catalog.Items[category..":"..id] then return false,"This cosmetic is unavailable.","Unavailable" end
	if not d.Inventory[category] or not d.Inventory[category][id] and not free then return false,"You don't own this cosmetic yet.","NotOwned" end
	d.Equipped[slot]=id; return true,"Equipped "..id
end
function P.settle(d,result,c)
	if d.ProcessedMatchIds[result.id] then return false end
	d.ProcessedMatchIds[result.id]=true; table.insert(d.MatchReceipts,result.id)
	-- Retain receipts for the current and recent seasons; IDs also never reused.
	if #d.MatchReceipts>512 then local old=table.remove(d.MatchReceipts,1); d.ProcessedMatchIds[old]=nil end
	if result.kind=="Refund" then
		if d.Reservations[result.roomId] then energy(d,c.RankedCost,c); d.Reservations[result.roomId]=nil end
		return true
	end
	if result.kind=="Social" then
		local social=d.SocialRewards; local key=tostring(result.friendId)
		if not social.Seen[key] and social.Count<c.SocialDailyLimit then social.Seen[key]=true; social.Count+=1; energy(d,c.SocialEnergy,c) end
		return true
	end
	if result.kind=="Solo" then
		local delta={Lines=result.lines,TSpins=result.spins,Tetrises=result.tetrises,PerfectClears=result.perfect}
		for k,v in pairs(delta) do d.Stats[k]+=v end
		P.questProgress(d,delta); d.BestSoloScore=math.max(d.BestSoloScore or 0,result.score); return true
	end
	local stats=d.Stats; local delta={Matches=1,Lines=result.lines,TSpins=result.spins,Tetrises=result.tetrises,PerfectClears=result.perfect,Sent=result.sent,KOs=result.kos}
	d.Reservations[result.id]=nil
	delta[result.outcome=="Win" and "Wins" or result.outcome=="Lose" and "Losses" or "Draws"]=1
	for k,v in pairs(delta) do stats[k]=(stats[k] or 0)+v end
	if result.outcome=="Win" then stats.CurrentWinStreak+=1; stats.BestWinStreak=math.max(stats.BestWinStreak,stats.CurrentWinStreak) else stats.CurrentWinStreak=0 end
	local reward=result.rewardEligible
	if reward then
		local pair=d.Pairs[tostring(result.opponentId)]
		if not pair or pair.Day~=result.day then pair={Day=result.day,Count=0,Last=0}; d.Pairs[tostring(result.opponentId)]=pair end
		pair.Count+=1; pair.Last=result.timestamp
		if result.outcome=="Win" then
			d.Cash+=c.WinCash[result.startTier]; d.Season.Wins+=1; stats.QualifiedWins+=1
			if d.Rank.Tier<7 then d.Rank.Stars+=1; if d.Rank.Stars>=P.Stars[d.Rank.Tier] then d.Rank.Tier+=1; d.Rank.Stars=0 end end
		elseif result.outcome=="Lose" and d.Rank.Tier<7 then
			if d.Rank.Stars>0 then d.Rank.Stars-=1 elseif d.Rank.Tier>1 and c.AllowDemotion then d.Rank.Tier-=1; d.Rank.Stars=P.Stars[d.Rank.Tier]-1 end
		end
		local actual=result.outcome=="Win" and 1 or result.outcome=="Lose" and 0 or 0.5
		local adjustment=math.floor(c.MasterK*(actual-1/(1+10^((result.opponentRating-result.startRating)/400)))+0.5)
		d.Rank.Rating=math.max(0,d.Rank.Rating+adjustment); d.Season.Rating=math.max(0,d.Season.Rating+adjustment)
		P.questProgress(d,delta)
	end
	for _,a in ipairs({{"FirstWin","Wins",1},{"TenWins","Wins",10},{"HundredWins","Wins",100},{"FirstSpin","TSpins",1},{"HundredSpins","TSpins",100},{"PerfectClear","PerfectClears",1},{"ThousandLines","Lines",1000},{"Streak5","BestWinStreak",5}}) do
		if stats[a[2]]>=a[3] then d.Achievements[a[1]]=true; d.Inventory.Badges[a[1]]=true end
	end
	if d.Rank.Tier>=6 then d.Achievements.Diamond=true; d.Inventory.Badges.Diamond=true end
	if d.Rank.Tier>=7 then d.Achievements.Master=true; d.Inventory.Badges.Master=true end
	return true
end
return P
