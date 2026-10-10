;(function()
 S.Buckets={}; S.Busy[a]=nil
 for i,key in ipairs({"GlobalRating","GlobalWins","SeasonRating","SeasonWins"}) do
  send(a,"Leaderboard",{Kind=key,RequestId=100+i})
  assert(sent[a].Leaderboard.Kind==key and sent[a].Leaderboard.RequestId==100+i)
  assert(type(sent[a].Leaderboard.Rows)=="table")
 end
 S.Buckets={}; send(a,"Leaderboard","GlobalRating")
 assert(sent[a].Leaderboard.Kind=="GlobalRating" and sent[a].Leaderboard.RequestId==nil)
 S.Buckets={}; S.Busy[a]=true
 send(a,"Leaderboard",{Kind="SeasonWins",RequestId=200})
 assert(sent[a].Leaderboard.Unavailable and sent[a].Leaderboard.RequestId==200)
 S.Busy[a]=nil; S.Buckets={}
 local previous=sent[a].Leaderboard
 send(a,"Leaderboard",{Kind="Unknown",RequestId=201}); assert(sent[a].Leaderboard==previous)
 S.Buckets={}; S.Sessions[a]=nil
 send(a,"Solo"); tick(R.Countdown+0.1)
 local equipped=Data:get(a).Equipped.DropEffect
 send(a,"Input",{Action="HardDrop",Down=true})
 local seen=false
 for _,event in ipairs(S.Sessions[a].Engine.events) do if event.name=="HardDrop" then assert(event.data.DropEffect==equipped); seen=true end end
 assert(seen); send(a,"Exit")
 print("PASS captured hard-drop theme before next-piece/line-clear snapshot")
 print("PASS leaderboard canonical query routing, echoed request identity, legacy requests, busy recovery and invalid-category rejection")
end)()
