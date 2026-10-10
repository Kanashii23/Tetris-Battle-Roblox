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
 print("PASS leaderboard canonical query routing, echoed request identity, legacy requests, busy recovery and invalid-category rejection")
end)()
