local Assets=modules.UIAssets; local U=modules.NeonUI
assert(UIAssetConfig.ImageUri("123")=="rbxassetid://123")
assert(UIAssetConfig.ImageUri("rbxassetid://456")=="rbxassetid://456")
assert(UIAssetConfig.ImageUri("not-an-id")=="" and UIAssetConfig.ImageUri(nil)=="")
assert(Assets.uri("Images.menu.shop")=="")
assert(U.theme.Face.Family=="rbxasset://fonts/families/PressStart2P.json")
UIAssetConfig.Images.menu.shop="123"; assert(Assets.uri("Images.menu.shop")=="rbxassetid://123"); UIAssetConfig.Images.menu.shop=""
local oldRank=RankIconConfig.Icons.Rookie; RankIconConfig.Icons.Rookie="456"; assert(Assets.rank("Rookie")=="rbxassetid://456"); RankIconConfig.Icons.Rookie=oldRank
print("PASS central asset IDs validate/fall back safely, preserve existing rank overrides and use Press Start 2P")

app.portal:close(true); app.portal:layout(1366,768); app.portal:open("Hub")
assert(app.portal.Scroll:FindFirstChild("MoreGrid"):FindFirstChild("Tiles"))
local n=#requests; app.menuObjects.solo.Activated:fire(); assert(#requests==n,"Background Solo action escaped modal")
app.portal:open("Energy"); app.portal:open("Quests"); app.portal:close(); assert(app.portal.Page=="Energy" and app.portal.Overlay.Visible); app.portal:close(); assert(app.portal.Page=="Hub"); app.portal:close(); assert(not app.portal.Overlay.Visible and U.ActiveModal==nil)
print("PASS background modal actions blocked; nested Back returns Quests to Energy to More to its opener")

app.portal:open("Shop"); app.portal.Category="BrickSkins"; app.portal:render(); app.portal.Selected="Galaxy"; app.portal:render(true); app.portal.Scroll.CanvasPosition=Vector2.new(0,700)
app.portal:open("Profile"); app.portal:close(); assert(app.portal.Page=="Shop" and app.portal.Selected=="Galaxy" and app.portal.Scroll.CanvasPosition.Y==700)
app.portal:open("Inventory"); assert(app.portal.Scroll:FindFirstChild("InventoryGrid"):FindFirstChild("Grid")); assert(app.portal.Sidebar); app.portal:close(true)
print("PASS Shop navigation preserves selection/scroll; Inventory uses owned real-rendered grid and category sidebar")

app.portal:open("Shop"); app.portal.Selected="Galaxy"; app.portal.PreviewOpen=true; app.portal:render(true)
local sample=app.portal.Sample; U.reducedMotion=false; local y=sample.Engine.piece.y; sample:control("Pause"); sample:tick(1); assert(sample.Engine.piece.y==y and sample.Paused)
sample:control("Rotate"); assert(sample.Engine.piece.rotation~=0); sample:control("Speed"); assert(sample.Speed==0.5); local round=sample.Round; sample:control("Next"); assert(sample.Round==round+1); sample:control("Pause"); assert(not sample.Paused)
local realBoard=app.client.State and app.client.State.Own; local count=#requests; sample:control("Replay"); assert(#requests==count and (not realBoard or app.client.State.Own==realBoard))
app.portal:layout(390,780); app.portal.PreviewOpen=true; app.portal:render(true); assert(U.ActiveModal==app.portal.PreviewPanel); count=#requests; app.menuObjects.battle.Activated:fire(); assert(#requests==count); app.portal.PreviewPanel.ClosePreview.Activated:fire(); assert(U.ActiveModal==app.portal.Overlay)
app.portal:close(true)
print("PASS preview pause/rotate/piece/replay/speed are isolated; phone preview also blocks underlying actions")

app.portal:layout(1366,768); app.portal:open("Shop"); app.portal.Category="BrickSkins"; app.portal:render()
d.DebugPrivileges=nil; app.client.PendingCosmetic=nil; d.Inventory.BrickSkins.Galaxy=true; d.Equipped.BrickSkin="Default"; Network.OnClientEvent:fire("Profile",d)
local card=app.portal.ShopView.Cards.Galaxy; local current=app.client.Profile.Equipped.BrickSkin
card.Buttons[3].Activated:fire(); assert(app.client.PendingCosmetic and card.Buttons[3]:GetAttribute("Disabled")); local count=#requests; card.Buttons[3].Activated:fire(); assert(#requests==count)
Network.OnClientEvent:fire("CosmeticResult",{Action="Equip",Category="BrickSkins",Id="Galaxy",Success=false,Message="Not ready"}); assert(not app.client.PendingCosmetic and app.client.Profile.Equipped.BrickSkin==current and not card.Buttons[3]:GetAttribute("Disabled"))
app.portal:close(true)
print("PASS pending operations disable duplicates, failed operations keep authoritative ownership and recover controls")

app.portal:open("Quests"); app.portal.QuestGroup="Daily"; d.Quests.Daily.Progress.play=0; d.Quests.Daily.Claimed.play=nil; app.portal:render(); local row=app.portal.Scroll:FindFirstChild("Row"); assert(row.Action1.Text=="INCOMPLETE" and row.Action1:GetAttribute("Disabled")); local count=#requests; row.Action1.Activated:fire(); assert(#requests==count)
d.Quests.Daily.Progress.play=3; Network.OnClientEvent:fire("Profile",d); row=app.portal.Scroll:FindFirstChild("Row"); assert(row.Action1.Text=="CLAIM" and not row.Action1:GetAttribute("Disabled")); assert(row.QuestProgress.Fill.Size.X.Scale==1)
d.Quests.Daily.Claimed.play=true; Network.OnClientEvent:fire("Profile",d); row=app.portal.Scroll:FindFirstChild("Row"); assert(row.Action1.Text=="CLAIMED" and row.Action1:GetAttribute("Disabled")); app.portal:close(true)
for _,page in ipairs({"Cash","Featured","Help","Redeem"}) do app.portal:open(page); assert(app.portal.Overlay.Visible); app.portal:close(true) end
assert(not DeveloperProductConfig.PurchasesEnabled)
print("PASS quest incomplete/claimable/claimed states follow confirmed profile; cash/energy products remain safely unavailable")

UIAssetConfig.Images.battle.garbage_projectile="12345"; local a=modules.AudioController.new(); local f=modules.ArcadeFeedback.new(app.root,U,a,app.own,app.enemy); f:layout(modules.NeonLayout.resolve(1366,768,true)); f:reset("assets-test")
assert(f.Particles[1].Frame.BlockTexture.Image=="rbxassetid://12345"); f:battle({MatchId="assets-test",Id=1,Kind="Attack",From=123,To=321,Lines=2},123); f:tick(0.1,100)
assert(f.Particles[1].Frame.BackgroundTransparency==1 and f.Particles[1].Frame:GetAttribute("ServerEventId")==1)
local x=f.Particles[1].Frame.Position.X.Offset; f:tick(0.1,100); assert(f.Particles[1].Frame.Position.X.Offset>x)
f:state({Mode="Ranked",MatchId="assets-test",Own={alive=true,pending=0},Opponent={events={{id=1,name="PerfectClear",data={}}}}}); f:tick(0.01,100); assert(f.Labels[2].Text=="PERFECT CLEAR!"); assert(f.Rays[1].Visible)
f:destroy(); a:destroy(); UIAssetConfig.Images.battle.garbage_projectile=""
print("PASS optional projectile textures retain confirmed hollow-square arcs and opponent Perfect Clear uses authoritative events")

for _,size in ipairs({{320,568},{390,780},{568,320},{844,326},{1024,768},{768,1024},{1366,768}}) do
 local l=modules.NeonLayout.resolve(size[1],size[2],true)
 for _,key in ipairs({"header","cash","energy","settings","mail"}) do bounds(l.menu[key],l.width,l.height,key) end
 assert(not overlap(l.menu.header,l.menu.cash) and not overlap(l.menu.cash,l.menu.energy))
 app.portal:layout(size[1],size[2]); app.portal:open("Shop"); app.portal.PreviewOpen=true; app.portal:render(true)
 local p=app.portal.PreviewPanel; local b=app.portal.Sample.Frame; assert(b.Size.X.Offset>0 and b.Size.Y.Offset==b.Size.X.Offset*2)
 for _,key in ipairs({"PreviewPause","PreviewReplay","PreviewRotate","PreviewNext","PreviewSpeed","PreviewAudio","DetailBuy","DetailEquip"}) do local button=p:FindFirstChild(key); assert(button.Size.X.Offset>=44 and button.Size.Y.Offset>=44); assert(button.Position.Y.Offset+button.Size.Y.Offset<=p.Size.Y.Offset) end
 app.portal:close(true)
end
print("PASS reference lobby header and preview controls stay bounded with 44px targets on phones, tablets and desktop")
