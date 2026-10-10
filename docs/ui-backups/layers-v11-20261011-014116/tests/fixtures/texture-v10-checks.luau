;(function()
 local A=modules.CosmeticsAssets; local B=modules.BrickRenderer; local FX=modules.CosmeticRenderer
 local host=U.new("Frame","AsyncTextureTest",app.root); host.AbsoluteSize=Vector2.new(200,400)
 local tile=B.tile(host,"Brick",U); tile.Image.IsLoaded=false
 local uri=CosmeticsAssetResolver.resolve("Bricks","Default","T")
 local oldProvider=services.ContentProvider.PreloadAsync; local waiting
 A.Status[uri]=nil
 services.ContentProvider.PreloadAsync=function(_,uris,callback)
  waiting=coroutine.running(); coroutine.yield(); callback(uris[1],Enum.AssetFetchStatus.Success)
 end
 B.paint(tile,"T","Default","Default",false,false,0)
 assert(tile.Image.Image==uri and not tile.Image.Visible and tile.Face.Visible)
 assert(coroutine.resume(waiting))
 assert(tile.Image.Visible and not tile.Face.Visible and tile.Image.Image==uri)
 -- A completion for a previous cell assignment cannot overwrite the current piece.
 A.Status[uri]=nil; B.paint(tile,"T","Default","Default",false,false,0)
 B.paint(tile,"J","Default","Default",false,false,0)
 local current=tile.Image.Image; assert(coroutine.resume(waiting)); assert(tile.Image.Image==current)
 services.ContentProvider.PreloadAsync=oldProvider
 B.paint(tile,0,"Default","Default",false,false,0); assert(tile.Image.Image=="" and not tile.Image.Visible)
 FX.drop(host,"Default",false,{X=0.5,Y=0.8},"T",1)
 assert(FX.Layers[host].Name=="DropFXForeground" and FX.Layers[host].ZIndex>tile.Frame.ZIndex)
 for _,part in ipairs(FX.Pools[host][1].Parts) do assert(part.Frame.Parent==FX.Layers[host] and part.Image.ZIndex>tile.Image.ZIndex) end
 host.ZIndex=50; FX.tick(0.01,host,false); assert(FX.Layers[host].ZIndex==62)
 FX.clear(host,true); assert(not FX.Layers[host]); host:Destroy()
 app.portal:close(true); app.portal:layout(1366,768)
 for _,category in ipairs({"BrickSkins","GhostEffects","DropEffects"}) do
  app.portal:open("Shop"); app.portal.Category=category; app.portal.Selected=nil; app.portal:render()
  for _,card in pairs(app.portal.ShopView.Cards) do
   assert(card.Mini and not card.Row:FindFirstChild("CosmeticArtwork"))
   assert(card.Mini.Frame.Size.X.Offset==80 and card.Mini.Frame.Size.Y.Offset==40)
   assert(card.Row:FindFirstChild("Name").Position.Y.Offset>card.Mini.Frame.Position.Y.Offset+card.Mini.Frame.Size.Y.Offset)
  end
  app.portal.Selected="Default"; app.portal.PreviewOpen=true; app.portal:render(true)
  local sample=app.portal.Sample; assert(sample.Item.Category==category)
  sample:control("Replay"); sample:control("Next"); sample:control("Rotate")
  app.portal:close(true); assert(not app.portal.Sample)
 end
 print("PASS delayed preload refresh without redraw, stale completion protection, pooled image clearing, foreground FX layering/resize/cleanup, simple cards and all three selected preview categories")
end)()
