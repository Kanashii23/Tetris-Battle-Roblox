# Default Classic cosmetics upload guide

Stage 1 supplies 35 gameplay PNGs. They are wired to the real client renderers, with safe native fallback visuals until usable Roblox image IDs are entered. The other 11 themes have explicit seven-color placeholder entries only; their PNGs are not supplied. The eventual 420-file matrix is not uploaded or complete.

1. Extract the original ZIP without changing filenames/folders. Open the intended Tetris Battle experience in Studio using the account/group that should own the images.
2. Open Asset Manager from Window or Home and use its Import control if available. Current Studio also supports File > Import for images and multiple-file import queues. Select only the 35 separate Bricks, GhostFX and DropFX PNGs; preserve alpha. Exclude Previews/SevenColorComparison.png and SevenColorAnimation.gif. Documentation: [Studio Importer](https://create.roblox.com/docs/studio/importer), [Studio interface](https://create.roblox.com/docs/studio/ui-overview).
3. Use clear upload names: DefaultClassic_I_Bricks, DefaultClassic_I_GhostFX, DefaultClassic_I_DropFX_WhiteBase, DefaultClassic_I_DropFX_Droplet, DefaultClassic_I_DropFX_Ripple; repeat for O, T, S, Z, J, L. Choose the intended creator and verify import/processing errors.
4. Copy the usable image content ID from Studio into `src/shared/Config/CosmeticsAssetIds.luau`, at the heading **COSMETICS / BRICKS — PASTE ROBLOX IMAGE IDS HERE**. Numeric strings and complete rbxassetid content URIs are accepted. If importing yields a decal/container ID, inspect its image/texture content property for the actual image ID. Never guess a neighboring ID. Keep unrelated UIAssetConfig IDs intact.
5. Use the table below. Example in words: paste the uploaded DefaultClassic I Brick image ID into CosmeticsAssetIds.Themes.DefaultClassic.I.Bricks. Every executable placeholder is currently an empty string; no IDs are fabricated. `Readiness` records supplied/awaiting-upload versus not-supplied themes; update Uploaded/Status only after all components are verified. Runtime still checks each component independently.
6. Let the existing Rojo session sync (or build the existing project), then restart Play. Confirm `2026-10-10-classic-stage1-v4` in Output. Test all seven colors on the real board, ghosts, HOLD/NEXT and Shop/Inventory previews. Preview's PIECE control cycles seven colors. Test actual floor/stack/edge/rotated/line-clearing hard drops. Warnings identify a missing or failed theme/piece/component; check IDs, processing/moderation and experience access/ownership. [Roblox asset permissions](https://create.roblox.com/docs/projects/assets/privacy).
7. Later, place each genuinely supplied theme pack into the same mapping and fill its existing fields. Add verified file records to the companion normalized manifest and mark its readiness appropriately. The resolver/renderer does not need another per-theme ID module. Existing saved catalog IDs remain unchanged: the Default save key renders DefaultClassic.

## Exact upload mapping

Paths are relative to assets/cosmetics/DefaultClassic_ExactTemplate_7Colors. The extracted original AssetManifest.json covers only 21 FX PNGs and is preserved unchanged; NormalizedManifest.json records all 35 supplied gameplay files, dimensions and checksums. Local paths are packaging metadata and never runtime Image values.

| PNG path | Configuration field | Roblox ID |
|---|---|---|
| `Bricks/DefaultClassic/I.png` | `CosmeticsAssetIds.Themes.DefaultClassic.I.Bricks` |  |
| `GhostFX/DefaultClassic/I.png` | `CosmeticsAssetIds.Themes.DefaultClassic.I.GhostFX` |  |
| `DropFX/DefaultClassic/I/WhiteBase.png` | `CosmeticsAssetIds.Themes.DefaultClassic.I.DropFX.WhiteBase` |  |
| `DropFX/DefaultClassic/I/Droplet.png` | `CosmeticsAssetIds.Themes.DefaultClassic.I.DropFX.Droplet` |  |
| `DropFX/DefaultClassic/I/Ripple.png` | `CosmeticsAssetIds.Themes.DefaultClassic.I.DropFX.Ripple` |  |
| `Bricks/DefaultClassic/O.png` | `CosmeticsAssetIds.Themes.DefaultClassic.O.Bricks` |  |
| `GhostFX/DefaultClassic/O.png` | `CosmeticsAssetIds.Themes.DefaultClassic.O.GhostFX` |  |
| `DropFX/DefaultClassic/O/WhiteBase.png` | `CosmeticsAssetIds.Themes.DefaultClassic.O.DropFX.WhiteBase` |  |
| `DropFX/DefaultClassic/O/Droplet.png` | `CosmeticsAssetIds.Themes.DefaultClassic.O.DropFX.Droplet` |  |
| `DropFX/DefaultClassic/O/Ripple.png` | `CosmeticsAssetIds.Themes.DefaultClassic.O.DropFX.Ripple` |  |
| `Bricks/DefaultClassic/T.png` | `CosmeticsAssetIds.Themes.DefaultClassic.T.Bricks` |  |
| `GhostFX/DefaultClassic/T.png` | `CosmeticsAssetIds.Themes.DefaultClassic.T.GhostFX` |  |
| `DropFX/DefaultClassic/T/WhiteBase.png` | `CosmeticsAssetIds.Themes.DefaultClassic.T.DropFX.WhiteBase` |  |
| `DropFX/DefaultClassic/T/Droplet.png` | `CosmeticsAssetIds.Themes.DefaultClassic.T.DropFX.Droplet` |  |
| `DropFX/DefaultClassic/T/Ripple.png` | `CosmeticsAssetIds.Themes.DefaultClassic.T.DropFX.Ripple` |  |
| `Bricks/DefaultClassic/S.png` | `CosmeticsAssetIds.Themes.DefaultClassic.S.Bricks` |  |
| `GhostFX/DefaultClassic/S.png` | `CosmeticsAssetIds.Themes.DefaultClassic.S.GhostFX` |  |
| `DropFX/DefaultClassic/S/WhiteBase.png` | `CosmeticsAssetIds.Themes.DefaultClassic.S.DropFX.WhiteBase` |  |
| `DropFX/DefaultClassic/S/Droplet.png` | `CosmeticsAssetIds.Themes.DefaultClassic.S.DropFX.Droplet` |  |
| `DropFX/DefaultClassic/S/Ripple.png` | `CosmeticsAssetIds.Themes.DefaultClassic.S.DropFX.Ripple` |  |
| `Bricks/DefaultClassic/Z.png` | `CosmeticsAssetIds.Themes.DefaultClassic.Z.Bricks` |  |
| `GhostFX/DefaultClassic/Z.png` | `CosmeticsAssetIds.Themes.DefaultClassic.Z.GhostFX` |  |
| `DropFX/DefaultClassic/Z/WhiteBase.png` | `CosmeticsAssetIds.Themes.DefaultClassic.Z.DropFX.WhiteBase` |  |
| `DropFX/DefaultClassic/Z/Droplet.png` | `CosmeticsAssetIds.Themes.DefaultClassic.Z.DropFX.Droplet` |  |
| `DropFX/DefaultClassic/Z/Ripple.png` | `CosmeticsAssetIds.Themes.DefaultClassic.Z.DropFX.Ripple` |  |
| `Bricks/DefaultClassic/J.png` | `CosmeticsAssetIds.Themes.DefaultClassic.J.Bricks` |  |
| `GhostFX/DefaultClassic/J.png` | `CosmeticsAssetIds.Themes.DefaultClassic.J.GhostFX` |  |
| `DropFX/DefaultClassic/J/WhiteBase.png` | `CosmeticsAssetIds.Themes.DefaultClassic.J.DropFX.WhiteBase` |  |
| `DropFX/DefaultClassic/J/Droplet.png` | `CosmeticsAssetIds.Themes.DefaultClassic.J.DropFX.Droplet` |  |
| `DropFX/DefaultClassic/J/Ripple.png` | `CosmeticsAssetIds.Themes.DefaultClassic.J.DropFX.Ripple` |  |
| `Bricks/DefaultClassic/L.png` | `CosmeticsAssetIds.Themes.DefaultClassic.L.Bricks` |  |
| `GhostFX/DefaultClassic/L.png` | `CosmeticsAssetIds.Themes.DefaultClassic.L.GhostFX` |  |
| `DropFX/DefaultClassic/L/WhiteBase.png` | `CosmeticsAssetIds.Themes.DefaultClassic.L.DropFX.WhiteBase` |  |
| `DropFX/DefaultClassic/L/Droplet.png` | `CosmeticsAssetIds.Themes.DefaultClassic.L.DropFX.Droplet` |  |
| `DropFX/DefaultClassic/L/Ripple.png` | `CosmeticsAssetIds.Themes.DefaultClassic.L.DropFX.Ripple` |  |

## Artwork limitation and timings

The actual supplied WhiteBase PNG is a rounded horizontal flash on a 256x256 square canvas. It is **not a spiky vertical splash**. The renderer preserves the source/padding and rotates WhiteBase 90 degrees into a compact vertical flash. No source PNG was edited. Ripple stays horizontal at zero rotation and uses its original 4:1 transparent canvas. A sharper spiky silhouette would require a replacement WhiteBase file supplied/uploaded later.

DefaultClassic uses one WhiteBase (160 ms), six separate copies of that piece color's Droplet (320 ms each, staggered by 20 ms), and one horizontal Ripple (260 ms, scaling 0.5 to 1.45). There is no fourth image type, circular ripple, 3D emitter, or recoloring of uploaded PNGs. Fully colored images retain white ImageColor3. Native fallback flash/line/square droplets are explicitly temporary visuals. Reduced Motion suppresses drop movement.
