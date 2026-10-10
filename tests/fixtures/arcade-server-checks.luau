local p,q,outside=player(22001),player(22002),player(22003)
Players.PlayerAdded:fire(p); Players.PlayerAdded:fire(q); Players.PlayerAdded:fire(outside)
S.Buckets={}; send(p,"Queue"); send(q,"Queue"); tick(0.6)
local duel=S.Sessions[p].Room; assert(sent[p].State.StartAt==sent[q].State.StartAt and sent[p].State.MatchId==duel.Id)
assert(sent[p].State.Remaining==R.MatchDuration and not duel.Started)
send(p,"Input",{Action="HardDrop",Down=true}); assert(S.Sessions[p].Engine.score==0)
tick(3.2); assert(duel.Started and math.abs(duel.EndAt-duel.StartAt-R.MatchDuration)<0.001)
print("PASS synchronized countdown blocks early movement and starts the full 120-second clock")
local function well(player,incoming)
	local engine=S.Sessions[player].Engine
	for y=1,24 do for x=1,10 do engine.board[y][x]=0 end end
	for y=21,24 do for x=1,10 do if x~=5 then engine.board[y][x]="G" end end end
	engine.board[20][1]="G"; engine.piece={kind="I",rotation=1,x=3,y=21}; engine.pending={}; engine.b2b=false; engine.combo=-1
	if incoming>0 then E.addGarbage(engine,incoming) end
	send(player,"Input",{Action="HardDrop",Down=false}); tick(0.1); send(player,"Input",{Action="HardDrop",Down=true})
end
well(p,3); assert(sent[q].BattleEvent.Kind=="Attack" and sent[q].BattleEvent.Lines==1)
assert(sent[q].BattleEvent.From==p.UserId and sent[q].BattleEvent.To==q.UserId and sent[q].BattleEvent.MatchId==duel.Id)
assert(E.pending(S.Sessions[q].Engine)==1 and not sent[outside].BattleEvent)
local eventId=duel.EventId; well(p,4); assert(duel.EventId==eventId)
well(q,0); assert(sent[p].BattleEvent.From==q.UserId and sent[p].BattleEvent.Lines==4)
print("PASS post-cancellation attack amounts, zero-attack suppression, reverse direction and match isolation")
S.Buckets={}; send(p,"Emote",3); assert(sent[q].BattleEvent.Text=="WOW!")
local id=duel.EventId; S.Buckets={}; send(p,"Emote",3); assert(duel.EventId==id)
S.Buckets={}; send(p,"Emote","unfiltered text"); assert(duel.EventId==id)
S.Buckets={}; send(p,"Settings",{ReducedMotion=true,Master=0.6,SFXVolume=0.4,ClassicHUD=true,SwapRotation=true})
assert(Data:get(p).Settings.SFXVolume==0.4 and not S.Sessions[p].Engine.paused)
print("PASS emotes are preset-only and rate-limited; ranked settings never pause the clock")
S.Sessions[q].Engine.alive=false; tick(0.1)
assert(S.Sessions[p].Engine.stats.KOs==1 and not duel.Ended); local resetAt=S.Sessions[q].RespawnAt
tick(0.4); assert(S.Sessions[p].Engine.stats.KOs==1 and S.Sessions[q].RespawnAt==resetAt)
tick(R.KORecovery); assert(S.Sessions[q].Engine.alive and not S.Sessions[q].RespawnAt)
S.Sessions[q].Engine.alive=false; tick(0.1); assert(S.Sessions[p].Engine.stats.KOs==2)
duel.Played=25; duel.StartAt=now-25; duel.EndAt=now+0.04; tick(0.1)
assert(sent[p].Result.Outcome=="Win" and sent[p].Result.Own.stats.KOs==2 and Data:get(p).Stats.KOs==2)
assert(sent[p].Result.Cash==50 and Data:get(p).Cash==50)
local cash=Data:get(p).Cash; tick(1); assert(Data:get(p).Cash==cash)
print("PASS repeated KOs recover once each, persist cumulative totals, decide the timed winner and settle one reward")
