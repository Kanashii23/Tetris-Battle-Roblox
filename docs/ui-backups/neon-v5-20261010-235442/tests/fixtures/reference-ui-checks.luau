
-- Existing suites above exercise missing-image fallbacks. Now exercise real configured IDs.
UIAssetConfig.Images=configuredImages
local A=modules.UIAssets; local U=modules.NeonUI
assert(A.uri("Images.menu.shop")=="rbxassetid://94361316332676")
assert(A.currency("Cash")=="rbxassetid://82735643243365")
local button=U.button("Readable",app.root,"SHOP",U.colors.pink,function() end)
local image=A.icon(U,button,"Images.menu.shop")
assert(image.Image=="rbxassetid://94361316332676" and image.Visible and image.ImageTransparency==0)
assert(image.ImageColor3.R==1 and image.ImageColor3.G==1 and image.ImageColor3.B==1)
assert(button.TextColor3.R>0.9 and button.TextTransparency==0)
assert(not button:FindFirstChildOfClass("UIGradient"),"Gradient would tint button text")
button:Destroy()
app.portal:close(true); app.portal:layout(1366,768); app.portal:open("Hub")
local grid=app.portal.Scroll.MoreGrid
for _,name in ipairs({"Profile","Leaderboards","Login","Friends","Energy","Help","Audio","Redeem"}) do assert(grid:FindFirstChild("More"..name)) end
assert(not grid:FindFirstChild("MoreAssets"))
local oldPage=app.portal.Page; app.portal:open("Assets"); assert(app.portal.Page==oldPage)
app.portal:close(true)
print("PASS configured IDs, untinted images/readable buttons, reference More destinations and developer-page exclusion")
