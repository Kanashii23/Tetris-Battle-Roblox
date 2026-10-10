local U=modules.NeonUI; local Feedback=modules.ArcadeFeedback; local Config=BattleEffectsConfig
U.reducedMotion=false; local audio=modules.AudioController.new(); local fx=Feedback.new(app.root,U,audio,app.own,app.enemy)
fx:layout(modules.NeonLayout.resolve(1366,768,true)); fx:reset("test-round")
fx:battle({Id=1,Kind="Attack",MatchId="other",Lines=6,From=123,To=321},123); assert(#fx.Queues[1]==0)
fx:battle({Id=2,Kind="Attack",MatchId="test-round",Lines=0,From=123,To=321},123); assert(#fx.Queues[1]==0)
fx:battle({Id=3,Kind="Attack",MatchId="test-round",Lines=6,From=123,To=321},123)
fx:battle({Id=3,Kind="Attack",MatchId="test-round",Lines=6,From=123,To=321},123); assert(#fx.Queues[1]==1)
fx:tick(0.1,100); assert(fx.Labels[1].Text=="+6 LINES"); local first=fx.Particles[1]; local x=first.Frame.Position.X.Offset
fx:tick(0.1,100); assert(first.Frame.Position.X.Offset>x)
for i=4,15 do fx:battle({Id=i,Kind="Attack",MatchId="test-round",Lines=20,From=321,To=123},123) end
local active=0; for _,v in ipairs(fx.Particles) do if v.Age then active+=1 end end; assert(active<=Config.Attack.MaxActive and #fx.Queues[2]<=Config.Announcements.QueueLimit)
fx:tick(2,100); for _,v in ipairs(fx.Particles) do assert(not v.Age and not v.Frame.Visible) end
U.reducedMotion=true; fx:battle({Id=16,Kind="Attack",MatchId="test-round",Lines=1,From=123,To=321},123); for _,v in ipairs(fx.Particles) do assert(not v.Age) end
fx:reset("next-round"); assert(#fx.Queues[1]==0 and not fx.Labels[1].Visible)
print("PASS confirmed attack direction/count, duplicate/foreign/zero suppression, bounded pools and Reduced Motion")
local old={}; for _,key in ipairs({"GarbageWarningLow","GarbageWarningMedium","GarbageWarningHigh","GarbageWarningCritical"}) do old[key]=SoundConfig.Sounds[key]; SoundConfig.Sounds[key]="12345" end
assert(audio:warning(1,0)); assert(audio.Warning.SoundId=="rbxassetid://12345" and audio.Warning.Volume<=audio.Master*audio.SFXVolume)
assert(not audio:warning(12,0.1)); audio.Warning:Stop(); assert(not audio:warning(12,0.5)); assert(audio:warning(12,3.1))
audio:settings(0.5,0.5,0.2,true); assert(audio.Warning.Volume==0 and not audio.Warning.IsPlaying and not audio:warning(20,8))
audio:settings(1,0.5,0.8,false); audio:warning(0,10); assert(not audio.Warning.IsPlaying)
for key,value in pairs(old) do SoundConfig.Sounds[key]=value end
assert(not audio:warning(12,11))
print("PASS garbage warnings honor thresholds, cooldown, exclusive channel, mute/SFX volume and empty IDs")
fx:reset("countdown"); fx:state({MatchId="countdown",StartAt=103,Mode="Ranked",Own={alive=true,pending=0}})
fx:tick(0.1,100); assert(fx.Countdown.Text=="3"); fx:tick(0.1,101); assert(fx.Countdown.Text=="2"); fx:tick(0.1,102); assert(fx.Countdown.Text=="1"); fx:tick(0.1,103); assert(fx.Countdown.Text=="GO!")
fx:reset("late"); fx:state({MatchId="late",StartAt=100,Mode="Ranked",Own={alive=true,pending=0}}); fx:tick(0.1,110); assert(not fx.Countdown.Visible)
for i=1,10 do fx:event({name=i==10 and "PerfectClear" or "Combo",data={combo=i}}) end; assert(#fx.Queues[1]<=Config.Announcements.QueueLimit and fx.Queues[1][1].Text=="PERFECT CLEAR!")
print("PASS server-time countdown catches up without restarting; announcements prioritize and cap clear feedback")
local host=U.new("Frame","ResultTest",app.root); local sounds={}; local client={Audio={play=function(_,key) table.insert(sounds,key) end},send=function() error("Results attempted to grant/send during animation") end}
local result={Id="verified",Outcome="Win",Cash=50,Rewards=true,Own={lines=4,stats={Sent=6,KOs=2,BestCombo=3}},Opponent={stats={KOs=1}},BeforeRank={Tier=1,Stars=2,Rating=1000},AfterRank={Tier=2,Stars=0,Rating=1012}}
U.reducedMotion=false; local sequence=modules.ArcadeResults.new(host,U,client,result,440); assert(sequence.Title.Text=="YOU WIN!" and not sequence.Cash.Visible)
sequence:tick(3); assert(sequence.KO.Text=="FINAL K.O.  2 : 1" and sequence.Cash.Text=="+50 CASH" and sequence.RankLabel.Text:find("RANK UP!",1,true))
assert(sequence.Stars.Text:find("+1 STAR",1,true)); local count=#sounds; sequence:tick(10); assert(#sounds==count and result.Cash==50)
sequence:destroy(); local repeatView=modules.ArcadeResults.new(host,U,client,result,440); repeatView:tick(5); assert(#sounds==count)
repeatView:destroy(); host:Destroy()
print("PASS confirmed result timeline, real KO/Cash, promotion star delta and once-only sound phases without reward grants")
local sample=modules.BrickPreviewRenderer.new(app.root,U)
for _,category in ipairs(Catalog.Categories) do sample:set(Catalog.list(category)[2],d.Equipped); for _=1,38 do sample:tick(0.05) end; assert(sample.Landed and sample.View.Rows==20 and sample.Engine.score>0) end
sample:set(Catalog.Items["BrickSkins:RoyalPrism"],d.Equipped); for _=1,140 do sample:tick(0.05) end; assert(sample.Round>=3)
sample.Round=2; sample:begin(); for _=1,38 do sample:tick(0.05) end; assert(sample.Engine.lines==4 and sample.Engine.stats.PerfectClears==1)
local elapsed=sample.Elapsed; sample.Frame.Visible=false; sample:tick(10); assert(sample.Elapsed==elapsed)
U.reducedMotion=true; sample.Frame.Visible=true; local y=sample.Engine.piece.y; sample:tick(10); assert(sample.Engine.piece.y==y); sample:destroy()
print("PASS every cosmetic category uses a looping isolated 10x20 engine demo with real hard drops/clears and hidden/frozen cleanup")
fx:destroy(); audio:destroy(); U.reducedMotion=false
