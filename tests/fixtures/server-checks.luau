local a,b,c=player(1),player(2),player(3)
Players.PlayerAdded:fire(a); Players.PlayerAdded:fire(b); Players.PlayerAdded:fire(c)
local function send(p,kind,data) remote.OnServerEvent:fire(p,kind,data) end
send(a,"Solo"); tick(0.2); assert(sent[a].State.Mode=="Solo" and #sent[a].State.Own.grid==200)
local y=S.Sessions[a].Engine.piece.y
send(a,"Input",{Action="SoftDrop",Down=true}); tick(0.1); assert(S.Sessions[a].Engine.piece.y>y and S.Sessions[a].Engine.piece.rotation==0)
send(a,"Input",{Action="SoftDrop",Down=false}); send(a,"Pause",true); y=S.Sessions[a].Engine.piece.y; tick(1); assert(S.Sessions[a].Engine.piece.y==y)
send(a,"Pause",false); send(a,"Input",{Action="Left",Down=true}); S.Buckets[a].Input=0
send(a,"Input",{Action="Left",Down=false}); assert(not S.Sessions[a].Engine.controls.Left)
send(a,"Pause",false); send(a,"Exit"); assert(not S.Sessions[a]); assert(Data:get(a).Energy.Current==10)
print("PASS Solo controls, real state, pause, rate-limited release, exit and free energy")
-- Command tokens refill in wall-clock time in production. Reset fixture buckets between phases.
S.Buckets={}
send(a,"Queue"); send(a,"Queue"); assert(#S.Queue==1)
send(b,"Queue"); tick(0.6)
local room=S.Sessions[a].Room; assert(room==S.Sessions[b].Room and not room.Started)
assert(Data:get(a).Energy.Current==9 and Data:get(b).Energy.Current==9)
send(a,"Cancel"); assert(not S.Sessions[a] and Data:get(a).Energy.Current==10 and Data:get(b).Energy.Current==10)
print("PASS duplicate queue guard, paired reservation and countdown refund")
S.Buckets={}; send(a,"Queue"); send(b,"Queue"); tick(3.8)
room=S.Sessions[a].Room; assert(room.Started)
assert(S.Sessions[a].Engine.piece.kind==S.Sessions[b].Engine.piece.kind)
local state=S.Sessions[a].Engine
for y=21,24 do for x=1,10 do if x~=5 then state.board[y][x]="G" end end end
state.board[20][1]="G"; state.piece={kind="I",rotation=1,x=3,y=21}
send(a,"Input",{Action="HardDrop",Down=true}); tick(0.2)
assert(S.Sessions[b].Engine.pending[1].lines==4)
local opponent=E.unpack(sent[b].State.Opponent); assert(opponent.lines==4 and opponent.board[20][1]=="G")
send(a,"Input",{Action="invented",Down=true}); send(a,"Input",{Action="CW",Down="invalid"})
assert(not sent[c].State or sent[c].State.Mode=="Solo")
print("PASS authoritative garbage, actual opponent board and isolated replication")
room.StartAt=now-25; room.Played=25; S.Sessions[b].Engine.alive=false; tick(0.1)
assert(sent[a].Result.Outcome=="Win" and sent[b].Result.Outcome=="Lose")
assert(sent[a].Result.Own.stats.KOs==1 and sent[b].Result.Opponent.stats.KOs==1)
assert(Data:get(a).Cash==50 and Data:get(a).Rank.Stars==1 and Data:get(a).Stats.QualifiedWins==1)
local cash=Data:get(a).Cash; assert(Data:settle(a,{id=room.Id})); assert(Data:get(a).Cash==cash)
print("PASS KO result, rank, Cash, competitive win and settlement idempotence")
S.Buckets={}; send(a,"Queue"); send(b,"Queue"); tick(3.8)
room=S.Sessions[a].Room; room.EndAt=now+0.05; tick(0.1)
assert(sent[a].Result.Outcome=="Draw" and sent[b].Result.Outcome=="Draw")
print("PASS server-clock expiration and deterministic draw")
S.Buckets={}; send(a,"Rematch"); assert(not S.Sessions[a]); send(b,"Rematch"); assert(S.Sessions[a].Room==S.Sessions[b].Room)
tick(3.2); room=S.Sessions[a].Room; room.EndAt=now+0.05; tick(0.1)
S.Buckets={}; send(a,"Rematch"); send(a,"Exit"); send(b,"Rematch"); assert(not S.Sessions[a] and not S.Sessions[b] and not S.Results[a])
print("PASS mutual rematch consent and lobby exit revokes stale consent")
-- Durable data survives release/reacquisition; a second session cannot overwrite a live lease.
local cash=Data:get(a).Cash; Data:release(a); assert(Data:load(a)); assert(Data:get(a).Cash==cash)
local namespace=C.DataStoreName.."_Live"
local old=records[namespace][tostring(a.UserId)]; old.Lease.Owner="other-server"; old.Lease.Expires=os.time()+180
assert(not Data:load(player(1)))
old.Lease.Owner="mock-server"
print("PASS persistence round-trip and active-session locking")
-- Recover pending awards before allowing another game; a failed recovery blocks loading.
Data:release(c)
records[namespace.."_Results"][tostring(c.UserId)]={recover={id="recover",outcome="Win",score=0,lines=0,spins=0,tetrises=0,perfect=0,sent=0,kos=0,startTier=1,startRating=1000,opponentRating=1000,rewardEligible=true,opponentId=99,day=math.floor(os.time()/86400),timestamp=os.time()}}
rejectAfterInboxRead=true
local loaded
task.spawn(function() loaded=Data:load(c) end); tick(10)
assert(loaded==false and not Data:get(c)); rejectAfterInboxRead=false; failWrites=false
assert(Data:load(c)); assert(Data:get(c).Cash==50); assert(Data:load(c) and Data:get(c).Cash==50)
print("PASS durable pending result recovery blocks on failure and credits once on reconnect")
-- Save rejection must not mutate cached balance or grant the item.
local item=Catalog.list("BrickSkins")[2]
Data:mutate(a,function(d) d.Cash=1000; return true end)
local before=Data:get(a).Cash; failWrites=true
task.spawn(function() Data:mutate(a,function(d) return P.purchase(d,item.Category,item.Id,Catalog,false) end) end)
tick(5); failWrites=false
assert(Data:get(a).Cash==before and not Data:get(a).Inventory.BrickSkins[item.Id] and not a.Kicked)
print("PASS transient save failure does not spend Cash or grant unsaved ownership")
print("Server integration checks passed with mocked Roblox services, not Studio clients.")

S.Buckets={}; send(a,"Equip",{Category="BrickSkins",Id="Default"})
assert(sent[a].Message=="Equipped Default", "Default equip remote failed: "..tostring(sent[a].Message))
print("PASS default equip remote imports its own Catalog")
