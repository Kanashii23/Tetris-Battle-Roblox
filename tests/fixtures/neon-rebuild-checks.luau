local U=modules.NeonUI
local function same(a,b) return a.R==b.R and a.G==b.G and a.B==b.B end
app.portal:close(true); U.reducedMotion=false
for _,button in ipairs({app.menuObjects.solo,app.menuObjects.battle,app.menuObjects.cash,app.menuObjects.energy}) do
 local outline=button.Outline; local color=outline.Color; local last
 for i=1,18 do
  button.MouseEnter:fire(); assert(button:GetAttribute("HoverActive")); local chosen=outline.Color
  if last then assert(not same(chosen,last),"Consecutive hover entries reused accent") end; last=chosen
  assert(outline.Thickness==2 and button.NeonHalo1.Outline.Transparency<0.8)
  button.InputBegan:fire({UserInputType=Enum.UserInputType.MouseButton1}); button.MouseLeave:fire(); button.InputEnded:fire({UserInputType=Enum.UserInputType.MouseButton1})
  assert(not button:GetAttribute("HoverActive") and same(outline.Color,color) and outline.Thickness==1.5 and outline.Transparency==0.18)
  assert(button.NeonHalo1.Outline.Transparency==0.92 and button.CastShadow.Position.Y.Offset==4)
 end
 button.SelectionGained:fire(); assert(button:GetAttribute("HoverActive")); button.SelectionLost:fire(); assert(not button:GetAttribute("HoverActive"))
 button.InputBegan:fire({UserInputType=Enum.UserInputType.Touch}); button.InputEnded:fire({UserInputType=Enum.UserInputType.Touch}); assert(not button:GetAttribute("HoverActive"))
 button.MouseEnter:fire(); U.enabled(button,false); assert(not button:GetAttribute("HoverActive")); button.MouseEnter:fire(); assert(not button:GetAttribute("HoverActive")); U.enabled(button,true)
 button.MouseEnter:fire(); app.menu.Visible=false; assert(not button:GetAttribute("HoverActive")); app.menu.Visible=true
 U.reducedMotion=true; button.MouseEnter:fire(); button.MouseLeave:fire(); assert(same(outline.Color,color)); U.reducedMotion=false
 assert(button.Surface:FindFirstChildOfClass("UIGradient") and not button:FindFirstChildOfClass("UIGradient") and not button:FindFirstChildOfClass("UIPadding"))
end
print("PASS shuffled hover bag, rapid exit while pressed, focus/touch, disabled/hidden reset, reduced motion and separate surface gradient")
for _,size in ipairs({{390,780},{844,326},{768,1024},{1024,768},{1366,768}}) do
 app.portal:layout(size[1],size[2]); app.portal:open("Shop"); assert(not app.portal.Sample and not app.portal.PreviewPanel)
 local view=app.portal.ShopView; assert(view.Grid and view.Grid.Grid.CellSize.X.Offset>=180)
 assert(view.Balance.Body.Position.X.Offset>=46 and view.Balance.Body.Position.Y.Offset>=32)
 local card=view.Cards.Default; card.Buttons[1].Activated:fire(); assert(app.portal.PreviewPanel and U.ActiveModal==app.portal.PreviewPanel)
 local count=#requests; card.Buttons[3].Activated:fire(); assert(#requests==count,"Underlying grid accepted input through preview")
 app.portal.PreviewPanel.ClosePreview.Activated:fire(); assert(not app.portal.Sample and not app.portal.PreviewPanel)
 app.portal:close(true); app.portal:open("Inventory"); assert(app.portal.ShopView.Grid and not app.portal.Sample); app.portal:close(true)
 app.portal:open("Quests"); local row=app.portal.Scroll:FindFirstChild("Row"); if size[1]>=600 then assert(row.Size.Y.Offset<=104) end
 assert(app.portal.QuestReset.Parent==app.portal.Shell and app.portal.QuestReset.Position.Y.Offset+20<=app.portal.BodyTop)
 assert(row.RewardIcon and row.QuestProgress.Fill.ProgressShine)
 app.portal:close(true)
end
app.layout()
local pink=app.root:FindFirstChild("PinkCabinet",true); local cyan=app.root:FindFirstChild("CyanCabinet",true)
assert(pink and cyan and pink.InnerRail and pink.CastShadow and pink.NeonHalo3)
assert(pink.Size.X.Offset==app.own.Frame.Size.X.Offset+16 and pink.Size.Y.Offset==app.own.Frame.Size.Y.Offset+16)
print("PASS responsive full-width product grids, demand-only isolated previews, compact quest/reward zones and clipped-board sibling cabinet layers")
