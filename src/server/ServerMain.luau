local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local Shared=RS:WaitForChild("Shared")
local E=require(Shared:WaitForChild("TetrisEngine"))
local R=require(Shared:WaitForChild("Config"):WaitForChild("Rules"))
local P=require(Shared:WaitForChild("Progression"))
local Catalog=require(Shared:WaitForChild("Catalog"))
local Data=require(script.Parent:WaitForChild("PlayerDataService"))
local Leaders=require(script.Parent:WaitForChild("LeaderboardService"))
local C=Data.Config
local Network=Instance.new("RemoteEvent"); Network.Name="Network"; Network.Parent=Shared
local S={Sessions={},Rooms={},Queue={},Results={},Invites={},Loading={},Busy={},Buckets={},Closing=false}
local function send(player,kind,payload)
	if player.Parent==Players then Network:FireClient(player,kind,payload) end
end
local function message(player,text) send(player,"Message",text) end
local function profile(player) send(player,"Profile",Data:public(player)) end
local function cosmeticReply(player,kind,category,id,ok,code,text)
	if RunService:IsStudio() and C.CosmeticDebugLogging then
		print(string.format("[Cosmetic] result action=%s category=%s id=%s success=%s code=%s",kind,tostring(category),tostring(id),tostring(ok),tostring(code)))
	end
	send(player,"CosmeticResult",{Action=kind,Category=category,Id=id,Success=ok,Code=code,Message=text})
	message(player,text)
end
local function cosmetic(player,kind,payload)
	local category=type(payload)=="table" and payload.Category or nil
	local id=type(payload)=="table" and payload.Id or nil
	local valid=type(category)=="string" and #category<=32 and type(id)=="string" and #id<=64
	local slot=valid and Catalog.Slots[category] or nil
	local item=slot and Catalog.Items[category..":"..id] or nil
	local d=Data:get(player); local entry=Data.Profiles[player.UserId]
	local isActive=entry and entry.Active and (not entry.Profile or entry.Profile:IsActive()) or false
	local owned=d and slot and d.Inventory[category] and d.Inventory[category][id]==true or false
	local free=Data.Debug and (kind=="Buy" and C.FreeShopPurchasesInDebug or kind=="Equip" and C.FreeCosmeticsInDebug) or false
	if RunService:IsStudio() and C.CosmeticDebugLogging then
		print(string.format("[Cosmetic] request action=%s category=%s id=%s loaded=%s active=%s configured=%s owned=%s debugFree=%s slot=%s fieldExists=%s",kind,valid and category or "invalid",valid and id or "invalid",tostring(d~=nil),tostring(isActive),tostring(item~=nil),tostring(owned),tostring(free),tostring(slot),tostring(d and slot and d.Equipped[slot]~=nil or false)))
	end
	if not d then cosmeticReply(player,kind,valid and category or nil,valid and id or nil,false,"DataNotLoaded","Your player data is still loading."); return end
	if not item then cosmeticReply(player,kind,nil,nil,false,"Unavailable","This cosmetic is unavailable."); return end
	local ok,text,code=Data:mutate(player,function(nextData)
		if kind=="Buy" then return P.purchase(nextData,category,id,Catalog,free) end
		return P.equip(nextData,category,id,Catalog,free)
	end,{Action=kind,Category=category,Id=id})
	profile(player)
	if not ok then
		if RunService:IsStudio() and C.CosmeticDebugLogging then warn("[Cosmetic] rejected internalCode="..tostring(code).." reason="..tostring(text)) end
		code=code or (text=="Data not loaded" and "DataNotLoaded" or "SaveFailed")
		text=code=="NotOwned" and "You don't own this cosmetic yet." or code=="Unavailable" and "This cosmetic is unavailable." or code=="DataNotLoaded" and "Your player data is still loading." or kind=="Equip" and "Unable to equip right now. Please try again." or code=="InternalError" and "Unable to purchase right now. Please try again." or text or "Unable to purchase right now. Please try again."
	end
	cosmeticReply(player,kind,category,id,ok,ok and "OK" or code,text or "Saved")
	if ok then send(player,"Action",{Sound=kind=="Buy" and "Purchase" or "Equip"}) end
end
local function unqueue(player)
	for i=#S.Queue,1,-1 do if S.Queue[i]==player then table.remove(S.Queue,i) end end
end
local function persist(player,result)
	-- Retry the durable inbox. Once written, recovery is idempotent on reconnect.
	for _=1,6 do if Data:settle(player,result) then profile(player); return true end; task.wait(2) end
	warn("[Tetris] Result remains pending or journal unavailable: "..result.id); return false
end
local function playerProfile(player)
	local d=Data:get(player)
	return {UserId=player.UserId,Name=player.Name,DisplayName=player.DisplayName,Rank=d and P.Ranks[d.Rank.Tier] or "Rookie",Stars=d and d.Rank.Stars or 0,Rating=d and d.Rank.Rating or 1000,Equipped=d and P.clone(d.Equipped) or {}}
end
local function refund(room)
	for player,charged in pairs(room.Charged) do if charged then room.Charged[player]=false; persist(player,{id=room.Id..":refund",kind="Refund",roomId=room.Id}) end end
end
local function resultFor(room,player,winner,reason)
	local session=S.Sessions[player]; local start=room.Profiles[player]; local other=room.Players[1]==player and room.Players[2] or room.Players[1]
	local d=Data:get(player); local st=session.Engine.stats
	local outcome=winner==nil and "Draw" or winner==player and "Win" or "Lose"
	local eligible=room.Ranked and (Data.Debug or room.Played>=C.MinRewardSeconds)
	if eligible and not Data.Debug and d then
		local key=tostring(other.UserId); local pair=d.Pairs[key]; local day=math.floor(os.time()/86400)
		if pair and pair.Day==day and (pair.Count>=C.PairRewardsPerDay or os.time()-pair.Last<C.OpponentRewardCooldown) then eligible=false end
	end
	return {id=room.Id,outcome=outcome,score=session.Engine.score,lines=session.Engine.lines,spins=st.TSpins,tetrises=st.Tetrises,perfect=st.PerfectClears,sent=st.Sent,kos=winner==player and reason=="KO" and 1 or 0,startTier=start.Tier,startRating=start.Rating,opponentRating=room.Profiles[other].Rating,rewardEligible=eligible,opponentId=other.UserId,day=math.floor(os.time()/86400),timestamp=os.time()}
end
local function finish(room,winner,reason)
	if room.Ended then return end
	room.Ended=true; S.Rooms[room.Id]=nil
	if not room.Started then
		refund(room)
		for _,player in ipairs(room.Players) do S.Sessions[player]=nil; send(player,"Lobby",{}); message(player,"Match cancelled before gameplay; energy refunded.") end
		return
	end
	local summaries={}
	if winner and reason=="KO" then S.Sessions[winner].Engine.stats.KOs+=1 end
	for _,player in ipairs(room.Players) do summaries[player]=resultFor(room,player,winner,reason) end
	for _,player in ipairs(room.Players) do
		message(player,"Match finished. Saving results...")
		local session=S.Sessions[player]; local summary=summaries[player]
		local before=Data:get(player) and P.clone(Data:get(player))
		local settled=true
		if room.Ranked then settled=persist(player,summary); if settled then Leaders:update(player) end end
		local after=Data:get(player)
		local other=room.Players[1]==player and room.Players[2] or room.Players[1]
		local payload={Outcome=summary.outcome,Reason=reason,Own=E.pack(session.Engine),Opponent=E.pack(S.Sessions[other].Engine),Profiles=room.PublicProfiles,Ranked=room.Ranked,Rewards=summary.rewardEligible and settled,SettlementPending=not settled,
			Cash=before and after and after.Cash-before.Cash or 0,BeforeRank=before and before.Rank,AfterRank=after and P.clone(after.Rank),Id=room.Id}
		S.Results[player]={Other=other,Ready=false,Ranked=room.Ranked}; send(player,"Result",payload)
	end
	for _,player in ipairs(room.Players) do S.Sessions[player]=nil end
end
local function startPair(a,b,ranked)
	if S.Sessions[a] or S.Sessions[b] or not Data:get(a) or not Data:get(b) then return end
	local count=0; for _ in pairs(S.Rooms) do count+=1 end
	if count>=C.MaxMatches then
		for _,player in ipairs({a,b}) do send(player,"Lobby",{}); message(player,"All arenas are busy; please search again.") end
		return
	end
	unqueue(a); unqueue(b); S.Results[a]=nil; S.Results[b]=nil
	local room={Id=Http:GenerateGUID(false),Players={a,b},Ranked=ranked,Profiles={},PublicProfiles={playerProfile(a),playerProfile(b)},Charged={},Played=0,Countdown=R.Countdown,Ended=false,Started=false,Preparing=true}
	S.Rooms[room.Id]=room
	local seed=math.random(1,2147483646)
	for _,player in ipairs(room.Players) do
		room.Profiles[player]=P.clone(Data:get(player).Rank)
		S.Sessions[player]={Room=room,Engine=E.new(seed,R),Mode=ranked and "Ranked" or "Challenge"}
		send(player,"Found",{Profiles=room.PublicProfiles,Ranked=ranked})
	end
	for _,player in ipairs(room.Players) do
		if ranked and not (Data.Debug and C.InfiniteEnergyInDebug) then
			local ok=Data:mutate(player,function(d)
				if d.Energy.Current<C.RankedCost then return false,"Not enough Energy" end
				d.Energy.Current-=C.RankedCost; d.Reservations[room.Id]={At=os.time()}; return true
			end)
			if not ok then finish(room,nil,"Energy unavailable"); return end
			room.Charged[player]=true; profile(player)
		end
		if room.Cancelled or player.Parent~=Players then finish(room,nil,"Cancelled"); return end
	end
	room.Preparing=false; room.StartAt=workspace:GetServerTimeNow()+R.Countdown
end
local function leave(player)
	unqueue(player)
	local session=S.Sessions[player]
	if session then
		if session.Room then
			local room=session.Room; local other=room.Players[1]==player and room.Players[2] or room.Players[1]
			if room.Preparing then room.Cancelled=true else finish(room,other,"Opponent left") end
		else
			persist(player,{id=session.Id,kind="Solo",score=session.Engine.score,lines=session.Engine.lines,spins=session.Engine.stats.TSpins,tetrises=session.Engine.stats.Tetrises,perfect=session.Engine.stats.PerfectClears})
			S.Sessions[player]=nil
		end
	end
end
local function solo(player)
	leave(player); S.Results[player]=nil
	if S.Sessions[player] then return end
	S.Sessions[player]={Id=Http:GenerateGUID(false),Engine=E.new(math.random(1,2147483646),R),Mode="Solo"}
end
local function queue(player)
	if S.Sessions[player] then return end
	if Data.Debug and not C.TestRankedMatches then message(player,"Test ranked matches disabled"); return end
	local d=P.refresh(P.clone(Data:get(player)),os.time(),C)
	if not (Data.Debug and C.InfiniteEnergyInDebug) and d.Energy.Current<C.RankedCost then message(player,"No Energy. Regeneration, quests and free Solo are available."); profile(player); return end
	S.Results[player]=nil
	unqueue(player); table.insert(S.Queue,player); send(player,"Searching",{Profile=playerProfile(player),StartedAt=workspace:GetServerTimeNow()})
end
local validInputs={Left=true,Right=true,SoftDrop=true,CW=true,CCW=true,Hold=true,HardDrop=true}
local function command(player,kind,payload)
	if kind=="Buy" or kind=="Equip" then cosmetic(player,kind,payload); return end
	if not Data:get(player) then message(player,"Profile is still loading"); return end
	if kind=="Refresh" then profile(player)
	elseif kind=="Hello" then profile(player); if not S.Sessions[player] then send(player,"Lobby",{}) end
	elseif kind=="Solo" then solo(player)
	elseif kind=="Queue" then queue(player)
	elseif kind=="Cancel" or kind=="Exit" then leave(player); S.Results[player]=nil; send(player,"Lobby",{})
	elseif kind=="Pause" then local s=S.Sessions[player]; if s and s.Mode=="Solo" then s.Engine.paused=payload==true; E.release(s.Engine) end
	elseif kind=="Restart" then local s=S.Sessions[player]; if s and s.Mode=="Solo" then solo(player) end
	elseif kind=="Rematch" then
		local result=S.Results[player]; if not result or result.Other.Parent~=Players then message(player,"Opponent unavailable; use Find Match"); return end
		local other=S.Results[result.Other]
		if not other or other.Other~=player then message(player,"Opponent returned to lobby; use Find Match"); return end
		result.Ready=true; message(player,"Rematch requested. Waiting for opponent.")
		if other and other.Other==player and other.Ready then startPair(player,result.Other,result.Ranked) end
	elseif kind=="ClaimQuest" then
		if type(payload)~="table" or not ({Daily=true,Weekly=true})[payload.Group] or type(payload.Id)~="string" then return end
		local ok,text=Data:mutate(player,function(d) return P.claimQuest(d,payload.Group,payload.Id,C) end); profile(player); message(player,text); if ok then send(player,"Action",{Sound="QuestClaim"}) end
	elseif kind=="Login" then local ok,text=Data:mutate(player,function(d) return P.login(d,os.time(),C) end); profile(player); message(player,text); if ok then send(player,"Action",{Sound="CashEarned"}) end
	elseif kind=="Leaderboard" then
		if type(payload)~="string" then return end
		local rows,text=Leaders:read(player,payload); send(player,"Leaderboard",{Rows=rows or {},Kind=payload,Notice=text,Unavailable=not rows})
	elseif kind=="Challenge" then
		if type(payload)~="number" or S.Sessions[player] then return end
		local other=Players:GetPlayerByUserId(payload); if not other or other==player or S.Sessions[other] then return end
		local ok,isFriend=pcall(function() return player:IsFriendsWithAsync(other.UserId) end)
		if not ok or not isFriend then message(player,"Choose a friend in this server"); return end
		S.Invites[other]={From=player,Expires=os.clock()+30}; send(other,"Challenge",playerProfile(player)); message(player,"Friend challenge sent")
	elseif kind=="AcceptChallenge" then
		local invitation=S.Invites[player]; S.Invites[player]=nil
		if invitation and invitation.Expires>os.clock() and invitation.From.Parent==Players then startPair(player,invitation.From,false) end
	elseif kind=="Settings" then
		if type(payload)~="table" then return end
		Data:mutate(player,function(d) if type(payload.Sound)=="boolean" then d.Settings.Sound=payload.Sound end; if type(payload.ReducedMotion)=="boolean" then d.Settings.ReducedMotion=payload.ReducedMotion end; return true end); profile(player)
	end
end
Network.OnServerEvent:Connect(function(player,kind,payload)
	if S.Closing or type(kind)~="string" or #kind>30 then return end
	local now=os.clock(); local b=S.Buckets[player] or {Time=now,Input=80,Command=8}; S.Buckets[player]=b
	local dt=now-b.Time; b.Time=now; b.Input=math.min(80,b.Input+dt*60); b.Command=math.min(8,b.Command+dt*2)
	if kind=="Input" then
		if type(payload)~="table" or not validInputs[payload.Action] or type(payload.Down)~="boolean" then return end
		local session=S.Sessions[player]
		if not session or (session.Room and (session.Room.Ended or not session.Room.Started)) then return end
		-- A rate-limited press must never prevent releasing an already held key.
		if not session.Engine or b.Input<1 and (payload.Down or not session.Engine.controls[payload.Action]) then return end
		b.Input=math.max(0,b.Input-1)
		if payload.Action=="HardDrop" and payload.Down then if now-(session.LastDrop or 0)<0.08 then return end; session.LastDrop=now end
		local attack=E.input(session.Engine,payload.Action,payload.Down)
		if attack>0 and session.Room then local other=session.Room.Players[1]==player and session.Room.Players[2] or session.Room.Players[1]; if S.Sessions[other] then E.addGarbage(S.Sessions[other].Engine,attack) end end
		return
	end
	if b.Command<1 or S.Busy[player] then return end; b.Command-=1; S.Busy[player]=true
	local ok,err=pcall(command,player,kind,payload); S.Busy[player]=nil
	if not ok then warn("[Tetris server] "..tostring(err)); message(player,"Operation failed; please retry") end
end)
local accumulator=0; local snapshotTime=0; local queueTime=0
RunService.Heartbeat:Connect(function(dt)
	accumulator=math.min(0.5,accumulator+dt); snapshotTime+=dt; queueTime+=dt
	local now=workspace:GetServerTimeNow()
	for _,room in pairs(S.Rooms) do if not room.Preparing and not room.Started and now>=room.StartAt then room.Started=true; room.EndAt=room.StartAt+R.MatchDuration end end
	while accumulator>=1/60 do
		accumulator-=1/60
		for player,session in pairs(S.Sessions) do
			local room=session.Room
			if session.Engine and (not room or room.Started and not room.Ended) then
				local attack=E.step(session.Engine,1/60)
				if room and attack>0 then local other=room.Players[1]==player and room.Players[2] or room.Players[1]; if S.Sessions[other] then E.addGarbage(S.Sessions[other].Engine,attack) end end
			end
		end
	end
	for _,room in pairs(S.Rooms) do
		if room.Started and not room.Ended then
			room.Played=math.max(0,now-room.StartAt)
			local a,b=room.Players[1],room.Players[2]; local sa,sb=S.Sessions[a],S.Sessions[b]
			if sa and sb then
				if not sa.Engine.alive or not sb.Engine.alive then
					local winner=sa.Engine.alive and a or sb.Engine.alive and b or nil
					task.spawn(finish,room,winner,"KO")
				elseif now>=room.EndAt then
					-- Deterministic policy: sent garbage, then cleared lines, then score.
					local winner
					for _,values in ipairs({{sa.Engine.stats.Sent,sb.Engine.stats.Sent},{sa.Engine.lines,sb.Engine.lines},{sa.Engine.score,sb.Engine.score}}) do if values[1]~=values[2] then winner=values[1]>values[2] and a or b; break end end
					task.spawn(finish,room,winner,"Time expired")
				end
			end
		end
	end
	if snapshotTime>=1/R.SnapshotHz then
		snapshotTime=0
		for player,session in pairs(S.Sessions) do
			local room=session.Room
			if session.Engine and (not room or not room.Ended) then
				local other=room and (room.Players[1]==player and room.Players[2] or room.Players[1]); local osession=other and S.Sessions[other]
				send(player,"State",{Mode=session.Mode,Own=E.pack(session.Engine),Opponent=osession and E.pack(osession.Engine),Profiles=room and room.PublicProfiles,Countdown=room and not room.Started and math.max(0,math.ceil((room.StartAt or now+3)-now)) or 0,Remaining=room and room.Started and math.max(0,room.EndAt-now) or nil,Round=1})
			end
		end
	end
	if queueTime>=0.5 then
		queueTime=0
		for i=#S.Queue,1,-1 do local p=S.Queue[i]; if p.Parent~=Players or not Data:get(p) or S.Sessions[p] then table.remove(S.Queue,i) end end
		while #S.Queue>=2 do
			local a=table.remove(S.Queue,1); local b=table.remove(S.Queue,1)
			-- Reserve before a yielding data transaction can let another queue request race.
			S.Sessions[a]={Reserved=true}; S.Sessions[b]={Reserved=true}
			task.spawn(function() S.Sessions[a]=nil; S.Sessions[b]=nil; startPair(a,b,true) end)
		end
	end
end)
local function joined(player)
	if S.Loading[player] or Data:get(player) then return end
	S.Loading[player]=true
	local ok,text=Data:load(player); S.Loading[player]=nil
	if not ok then player:Kick(text); return end
	if player.Parent~=Players then Data:release(player); return end
	profile(player); send(player,"Lobby",{})
	-- Alternative to invite attribution: a verified first-time friend session.
	task.delay(C.SocialMinSeconds,function()
		local newcomer=Data:get(player)
		if player.Parent~=Players or not newcomer or os.time()-newcomer.CreatedAt>600 or player.AccountAge<C.SocialMinAccountAge then return end
		for _,host in ipairs(Players:GetPlayers()) do
			if host~=player and Data:get(host) then
				local success,friend=pcall(function() return host:IsFriendsWithAsync(player.UserId) end)
				local hostData=P.refresh(P.clone(Data:get(host)),os.time(),C)
				if success and friend and not newcomer.SocialRewardHost and hostData.SocialRewards.Count<C.SocialDailyLimit and not hostData.SocialRewards.Seen[tostring(player.UserId)] then
					local reserved=Data:mutate(player,function(d)
						if d.SocialRewardHost then return false end
						d.SocialRewardHost=host.UserId; return true
					end)
					if not reserved then return end
					persist(host,{id="social:"..player.UserId,kind="Social",friendId=player.UserId})
					return
				end
			end
		end
	end)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player) leave(player); Data:release(player); S.Results[player]=nil; S.Invites[player]=nil; S.Buckets[player]=nil; S.Busy[player]=nil end)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(joined,player) end
game:BindToClose(function()
	S.Closing=true
	for _,room in pairs(S.Rooms) do if not room.Started then room.Cancelled=true; if not room.Preparing then finish(room,nil,"Server closing") end end end
	local pending=0
	for _,player in ipairs(Players:GetPlayers()) do pending+=1; task.spawn(function() leave(player); Data:release(player); pending-=1 end) end
	local deadline=os.clock()+25; while pending>0 and os.clock()<deadline do task.wait(0.1) end
end)
S.Matchmaking={Enqueue=queue,Cancel=unqueue,StartPair=startPair}
return S
