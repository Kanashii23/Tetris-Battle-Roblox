;(function()
 local B=modules.BrickRenderer; local A=modules.CosmeticsAssets; local FX=modules.CosmeticRenderer; local L=modules.RenderLayers
 local host=U.new("Frame","LayerProof",app.root); host.AbsoluteSize=Vector2.new(200,400)
 local tile=B.tile(host,"Brick",U)
 local uri=CosmeticsAssetResolver.resolve("Bricks","Default","T")
 A.Status[uri]="Failed"; tile.Image.IsLoaded=true
 B.paint(tile,"T","Default","Default",false,false,0)
 assert(tile.Image.Visible and not tile.Face.Visible and tile.Image.Image==uri)
 assert(tile.Image.ZIndex>tile.Shine.ZIndex and tile.Image.BackgroundTransparency==1)
 tile.Image.ZIndex=1; tile.Image.Visible=false; tile.Image.ImageTransparency=1; tile.Frame.ZIndex=1
 B.paint(tile,"T","Default","Default",false,false,0)
 assert(tile.Image.Visible and tile.Image.ImageTransparency==0 and tile.Image.ZIndex==host.ZIndex+L.Solid+L.Texture)
 tile.Image.IsLoaded=false; A.Status[uri]="Ready"
 B.paint(tile,"T","Default","Default",false,false,0)
 assert(not tile.Image.Visible and tile.Face.Visible)
 tile.Image.IsLoaded=true; assert(tile.Image.Visible and not tile.Face.Visible)
 B.paint(tile,"T","Default","Default",true,false,0)
 assert(tile.Frame.ZIndex==host.ZIndex+L.Ghost and tile.Frame.BackgroundTransparency==1)
 FX.drop(host,"Default",false,{X=0.5,Y=0.8},"T",1)
 local parts=FX.Pools[host][1].Parts
 assert(parts[2].Frame.ZIndex<parts[1].Frame.ZIndex and parts[1].Frame.ZIndex<parts[3].Frame.ZIndex)
 assert(FX.Layers[host].ZIndex>tile.Image.ZIndex)
 for _,part in ipairs(parts) do assert(part.Image.BackgroundTransparency==1 and not part.Frame.Active) end
 FX.clear(host,true); host:Destroy()
 print("PASS authoritative per-ImageLabel readiness over preload cache; runtime layer/visibility reset; ghost/native/texture/FX component order and noninteractive transparent overlays")
end)()
