-- Relative sibling layers inside each board. Foreground controls remain outside its clipped root.
local L={Grid=1,Empty=2,Ghost=3,Solid=5,Native=1,NativeDetail=2,Texture=4,FX=12,Ripple=1,WhiteBase=2,Droplet=3,Control=1}
function L.cell(tile,ghost,empty)
 local base=tile.Frame.Parent.ZIndex or 1
 tile.Frame.ZIndex=base+(empty and L.Empty or ghost and L.Ghost or L.Solid)
 tile.Face.ZIndex=tile.Frame.ZIndex+L.Native
 tile.Shine.ZIndex=tile.Frame.ZIndex+L.NativeDetail; tile.Detail.ZIndex=tile.Shine.ZIndex
 for _,facet in ipairs(tile.Facets) do facet.ZIndex=tile.Shine.ZIndex end
 tile.Image.ZIndex=tile.Frame.ZIndex+L.Texture
end
return L
