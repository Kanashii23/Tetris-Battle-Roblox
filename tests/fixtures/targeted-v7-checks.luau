;(function()
local portal=app.portal
portal:close(true); portal:layout(1366,768); portal:open("Leaderboards")
local tabs=portal.BoardControls; local back=portal.Back; local cabinet=portal.Shell
local height=cabinet.Size.Y.Offset
local keys={"GlobalRating","GlobalWins","SeasonRating","SeasonWins"}
for i,key in ipairs(keys) do
 local before=#requests
 tabs[key].Activated:fire()
 local pending=portal.BoardPending
 assert(pending.Kind==key and requests[#requests].Payload.Kind==key)
 assert(#requests-before<=1)
 assert(tabs[key]:GetAttribute("ActiveTab"))
 portal:receiveLeaderboard({Kind=key,RequestId=pending.RequestId,Rows={{Name=key,Position=1,UserId=900+i,Value=i}}})
 assert(portal.BoardData.Kind==key and portal.BoardControls==tabs and portal.Back==back and portal.Shell==cabinet)
 assert(cabinet.Size.Y.Offset==math.min(portal.Height-32,portal.BodyTop+math.max(56,portal.ContentHeight)+20))
 local n=#requests; tabs[key].Activated:fire(); assert(#requests==n+1)
 tabs[key].Activated:fire(); assert(#requests==n+1)
 portal:receiveLeaderboard({Kind=key,RequestId=portal.BoardPending.RequestId,Rows={}})
end
tabs.GlobalRating.Activated:fire(); local old=portal.BoardPending.RequestId
tabs.GlobalWins.Activated:fire(); local middle=portal.BoardPending.RequestId
tabs.GlobalRating.Activated:fire(); local latest=portal.BoardPending.RequestId
portal:receiveLeaderboard({Kind="GlobalRating",RequestId=old,Rows={}}); assert(portal.BoardData==nil)
portal:receiveLeaderboard({Kind="GlobalWins",RequestId=middle,Rows={}}); assert(portal.BoardData==nil)
portal:receiveLeaderboard({Kind="GlobalRating",RequestId=latest,Rows={},Unavailable=true,Notice="Actual error"})
assert(portal.BoardData.Unavailable and portal.BoardControls==tabs)
tabs.SeasonWins.Activated:fire(); portal.BoardPending.At=os.clock()-13; portal:tick(0)
assert(portal.BoardData.Unavailable and portal.BoardPending==nil)
portal:close(true); portal:open("Quests"); portal:open("Leaderboards")
assert(portal.Tabs.Tab1==portal.BoardControls.GlobalRating)
local pending=portal.BoardPending.RequestId; portal:close(true)
portal:receiveLeaderboard({Kind=portal.Leaderboard,RequestId=pending,Rows={}})
portal:open("Leaderboards"); assert(portal.BoardPending.RequestId~=pending)
portal:close(true)
local shadow=app.menu:FindFirstChild("TitleShadow")
assert(shadow.TextColor3.R==1 and shadow.TextColor3.G==0 and shadow.TextColor3.B==1)
for _,size in ipairs({{390,780},{1366,768},{844,326}}) do
 app.art:layout(size[1],size[2],size[1]<size[2])
 assert(#app.art.Sun:GetChildren()==64 and app.art.Sun.ZIndex==2)
 for index=0,63 do local band=app.art.Sun:FindFirstChild("SunBand"..index); assert(band and band.ZIndex==2 and not band.Active) end
end
assert(app.backdrop.ZIndexBehavior==Enum.ZIndexBehavior.Sibling and #app.art.Rails==5)
local x=app.art.Rails[1].Frame.Position.X.Scale; app.art:tick(0.01,false,true)
assert(app.art.Rails[1].Frame.Position.X.Scale<x)
print("PASS four canonical tabs, one request per selection, repeated clicks, ABA stale-response filtering, errors/timeouts, retained controls/cabinet, reopen, exact magenta and 64 noninteractive ZIndex-2 bands")

end)()
