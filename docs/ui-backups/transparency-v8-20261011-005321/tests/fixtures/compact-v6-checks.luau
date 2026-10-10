local U=modules.NeonUI; app.portal:close(true)
local pages={"Quests","Leaderboards","Hub","Friends","Profile","Login","Energy","Help","Audio","Redeem"}
for _,size in ipairs({{390,780},{844,326},{768,1024},{1366,768}}) do
 app.portal:layout(size[1],size[2])
 for _,page in ipairs(pages) do
  app.portal:open(page); local portal=app.portal; local shell=portal.Shell
  assert(portal.Compact and shell:GetAttribute("CompactWindow"))
  assert(math.abs(shell.Position.X.Offset+(shell.Size.X.Offset-size[1])/2)<0.01)
  assert(math.abs(shell.Position.Y.Offset+(shell.Size.Y.Offset-size[2])/2)<0.01)
  assert(shell.Size.X.Offset<=size[1]-32 and shell.Size.Y.Offset<=size[2]-32)
  assert(portal.Scroll.ClipsDescendants and portal.Scroll.Parent==shell and portal.Back.Parent==shell)
  assert(portal.Scroll.Position.Y.Offset+portal.Scroll.Size.Y.Offset<=shell.Size.Y.Offset-19)
  assert(portal.Overlay.BackgroundTransparency>=0.6)
  if page=="Quests" then
   local a,b=portal.Tabs.Tab1,portal.Tabs.Tab2
   assert(math.abs((a.Position.X.Offset+b.Position.X.Offset+b.Size.X.Offset)/2-portal.ListWidth/2)<0.01)
   assert(a.Size.X.Offset==b.Size.X.Offset and a.Size.Y.Offset>=44 and b.Size.Y.Offset>=44)
   assert(portal.QuestReset.Parent==shell and portal.QuestReset.Position.Y.Offset>=portal.Tabs.Position.Y.Offset+44)
   b.Activated:fire(); assert(portal.QuestGroup=="Weekly" and portal.Tabs.Tab2:GetAttribute("ActiveTab")); portal.QuestGroup="Daily"
  end
  for _,card in ipairs(portal.Scroll:GetChildren()) do
   if card.Name=="Row" then
    assert(card:GetAttribute("ContentCard") and card.Surface.SurfaceGradient and card.PixelEdge and card.CastShadow)
    assert(card.Body.Position.Y.Offset>=card.Title.Position.Y.Offset+card.Title.Size.Y.Offset)
   end
  end
  if (page=="Redeem" or page=="Help" or page=="Friends") and size[2]>=700 then assert(shell.Size.Y.Offset<400) end
  portal:close(true)
 end
end
-- Long measured content stays scrollable without expanding beyond viewport.
app.portal:layout(390,780); app.portal:open("Help")
local row=app.portal:row("Long heading",string.rep("Readable long content ",180),"CONTROLS",function() end); app.portal:fitWindow()
assert(row.Size.Y.Offset>600 and app.portal.ContentHeight>app.portal.Scroll.Size.Y.Offset and app.portal.Shell.Size.Y.Offset<=748)
app.portal:close(true); app.portal:layout(1366,768); app.portal:open("Leaderboards")
local rows={}; for i=1,100 do rows[i]={Position=i,Name="Player "..i,Value=1000-i,UserId=100+i,Rank="Rookie"} end
app.portal.BoardData={Rows=rows,Kind="GlobalRating",Notice="Actual test payload"}; app.portal:render(true)
assert(app.portal.ContentHeight>7000 and app.portal.Shell.Size.Y.Offset==app.portal.BodyTop+420+20)
app.portal:close(true); app.portal:open("Audio")
local found={}; for _,card in ipairs(app.portal.Scroll:GetChildren()) do if card.Name=="Row" then found[card.Title.Text]=true end end
assert(found["Music Volume"] and found["SFX Volume"]); app.portal:close(true)
print("PASS all ten compact centered windows, centered Daily/Weekly switching, shared shaded cards, content-sized short screens and 100-row/long-text scroll bounds")
-- One backdrop, fixed sun/city/grid, elapsed-time flow and seamless offscreen wrapping.
local art=app.art; art:layout(1366,768,false); local sun=art.Sun.Position; local city=art.City.Position; local horizon=art.Horizon.Position; local line=art.Lines[1].Position
local before=art.Elapsed; art:tick(0.1,false,true); assert(art.Elapsed==before+0.1)
local first=art.Streaks[1].Frame.Position.X.Scale; art:tick(0.1,false,true); assert(art.Streaks[1].Frame.Position.X.Scale<first)
local phase=art.Elapsed
for _,page in ipairs({"Hub","Energy","Leaderboards"}) do app.portal:open(page); assert(art.Elapsed==phase) end
app.portal:close(true); assert(art.Elapsed==phase)
art:tick(1,true,true); assert(art.Elapsed==phase); art:tick(1,false,false); assert(art.Elapsed==phase)
art:tick(25,false,true); assert(art.Sun.Position==sun and art.City.Position==city and art.Horizon.Position==horizon and art.Lines[1].Position==line)
assert(#art.Streaks==24 and #art.Flow:GetChildren()==24)
local frozen=art.Elapsed; art:layout(390,780,true); assert(art.Elapsed==frozen)
local separate=modules.RetroArtwork.new(app.root,U); separate:layout(844,326,false)
local period=1.3/separate.Speed; local x=separate.Streaks[1].Frame.Position.X.Scale
separate:tick(period*2,false,true); assert(math.abs(x-separate.Streaks[1].Frame.Position.X.Scale)<0.000001)
for i=1,200 do separate:tick(0.19,false,true); for _,streak in ipairs(separate.Streaks) do assert(streak.Frame.Position.X.Scale>=-0.15 and streak.Frame.Position.X.Scale<1.15) end end
separate:destroy(); separate:tick(1,false,true); assert(separate.Destroyed and #separate.Streaks==0)
app.portal:close(true)
print("PASS fixed sunset layers, leftward bounded surface flow, elapsed-time low-FPS/two-cycle wrap, navigation/resize phase continuity, Reduced Motion/hidden freeze and teardown")
