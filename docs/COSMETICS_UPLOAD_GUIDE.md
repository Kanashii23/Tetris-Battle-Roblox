# Cosmetic image upload and ID mapping

Upload the supplied PNG files as Roblox images. Copy each real image ID and paste it between the empty quotes in its matching line in `src/shared/Config/CosmeticsAssetIds.luau`. Digit-only strings and full `rbxassetid://` content URIs are accepted. Leave every unuploaded image empty; native fallback remains available. Never paste a local path or an unquoted placeholder.

1. Open the intended experience in Studio under the account/group that owns the images. Keep the ZIP folders and filenames intact.
2. Import the 35 individual gameplay PNGs using Studio's image upload workflow. Preserve transparency; comparison PNG/GIF previews are documentation only.
3. Use distinct upload names identifying DefaultClassic, piece and component (for example DefaultClassic_L_DropFX_WhiteBase).
4. Copy the actual image content ID. If an upload exposes a decal/container, use the image ID in its Texture property; do not guess it.
5. Paste the copied ID between the empty quotes in the exact matching line below. Repeat for all seven colors and five entries per color.
6. Sync Rojo and restart Play. Test board, ghost, HOLD/NEXT and the Preview panel with all seven pieces. Loading problems need upload processing/experience access checks.
7. Add future theme IDs to the reserved tables when corresponding art has actually been supplied. No renderer changes are needed.

The `Default` table maps to canonical DefaultClassic without changing saved catalog/equip IDs. The other eleven tables reserve future assets; their empty slots do not mean artwork was supplied. Readiness, aliases and animation timings are separate in CosmeticsAssetMetadata. All renderers use CosmeticsAssetResolver.

Example (leave empty until you have copied the real image ID):
```luau
Default = {
    ["Brick Default L"] = "",
    ["Drop Default L Ripple"] = "",
    ["Drop Default L WhiteBase"] = "",
    ["Drop Default L Droplet"] = "",
    ["GhostFx Default GhostFX L"] = "",
}
```

Paths below are relative to `assets/cosmetics/DefaultClassic_ExactTemplate_7Colors`.

| PNG | Exact configuration field |
| --- | --- |
| `Bricks/DefaultClassic/I.png` | `CosmeticsAssetIds.Default["Brick Default I"]` |
| `DropFX/DefaultClassic/I/Ripple.png` | `CosmeticsAssetIds.Default["Drop Default I Ripple"]` |
| `DropFX/DefaultClassic/I/WhiteBase.png` | `CosmeticsAssetIds.Default["Drop Default I WhiteBase"]` |
| `DropFX/DefaultClassic/I/Droplet.png` | `CosmeticsAssetIds.Default["Drop Default I Droplet"]` |
| `GhostFX/DefaultClassic/I.png` | `CosmeticsAssetIds.Default["GhostFx Default GhostFX I"]` |
| `Bricks/DefaultClassic/O.png` | `CosmeticsAssetIds.Default["Brick Default O"]` |
| `DropFX/DefaultClassic/O/Ripple.png` | `CosmeticsAssetIds.Default["Drop Default O Ripple"]` |
| `DropFX/DefaultClassic/O/WhiteBase.png` | `CosmeticsAssetIds.Default["Drop Default O WhiteBase"]` |
| `DropFX/DefaultClassic/O/Droplet.png` | `CosmeticsAssetIds.Default["Drop Default O Droplet"]` |
| `GhostFX/DefaultClassic/O.png` | `CosmeticsAssetIds.Default["GhostFx Default GhostFX O"]` |
| `Bricks/DefaultClassic/T.png` | `CosmeticsAssetIds.Default["Brick Default T"]` |
| `DropFX/DefaultClassic/T/Ripple.png` | `CosmeticsAssetIds.Default["Drop Default T Ripple"]` |
| `DropFX/DefaultClassic/T/WhiteBase.png` | `CosmeticsAssetIds.Default["Drop Default T WhiteBase"]` |
| `DropFX/DefaultClassic/T/Droplet.png` | `CosmeticsAssetIds.Default["Drop Default T Droplet"]` |
| `GhostFX/DefaultClassic/T.png` | `CosmeticsAssetIds.Default["GhostFx Default GhostFX T"]` |
| `Bricks/DefaultClassic/S.png` | `CosmeticsAssetIds.Default["Brick Default S"]` |
| `DropFX/DefaultClassic/S/Ripple.png` | `CosmeticsAssetIds.Default["Drop Default S Ripple"]` |
| `DropFX/DefaultClassic/S/WhiteBase.png` | `CosmeticsAssetIds.Default["Drop Default S WhiteBase"]` |
| `DropFX/DefaultClassic/S/Droplet.png` | `CosmeticsAssetIds.Default["Drop Default S Droplet"]` |
| `GhostFX/DefaultClassic/S.png` | `CosmeticsAssetIds.Default["GhostFx Default GhostFX S"]` |
| `Bricks/DefaultClassic/Z.png` | `CosmeticsAssetIds.Default["Brick Default Z"]` |
| `DropFX/DefaultClassic/Z/Ripple.png` | `CosmeticsAssetIds.Default["Drop Default Z Ripple"]` |
| `DropFX/DefaultClassic/Z/WhiteBase.png` | `CosmeticsAssetIds.Default["Drop Default Z WhiteBase"]` |
| `DropFX/DefaultClassic/Z/Droplet.png` | `CosmeticsAssetIds.Default["Drop Default Z Droplet"]` |
| `GhostFX/DefaultClassic/Z.png` | `CosmeticsAssetIds.Default["GhostFx Default GhostFX Z"]` |
| `Bricks/DefaultClassic/J.png` | `CosmeticsAssetIds.Default["Brick Default J"]` |
| `DropFX/DefaultClassic/J/Ripple.png` | `CosmeticsAssetIds.Default["Drop Default J Ripple"]` |
| `DropFX/DefaultClassic/J/WhiteBase.png` | `CosmeticsAssetIds.Default["Drop Default J WhiteBase"]` |
| `DropFX/DefaultClassic/J/Droplet.png` | `CosmeticsAssetIds.Default["Drop Default J Droplet"]` |
| `GhostFX/DefaultClassic/J.png` | `CosmeticsAssetIds.Default["GhostFx Default GhostFX J"]` |
| `Bricks/DefaultClassic/L.png` | `CosmeticsAssetIds.Default["Brick Default L"]` |
| `DropFX/DefaultClassic/L/Ripple.png` | `CosmeticsAssetIds.Default["Drop Default L Ripple"]` |
| `DropFX/DefaultClassic/L/WhiteBase.png` | `CosmeticsAssetIds.Default["Drop Default L WhiteBase"]` |
| `DropFX/DefaultClassic/L/Droplet.png` | `CosmeticsAssetIds.Default["Drop Default L Droplet"]` |
| `GhostFX/DefaultClassic/L.png` | `CosmeticsAssetIds.Default["GhostFx Default GhostFX L"]` |

Start Play after Rojo sync. The startup line identifies the installed UI version. Loading failures warn once and retain native drawing. Confirm delivery in Studio; an entered ID alone does not prove permission or processing.

The supplied WhiteBase is a rounded horizontal flash. Its square transparent canvas is preserved and rotated 90 degrees for the vertical flash. Ripple stays horizontal. Each confirmed hard drop produces six separated droplets, one WhiteBase and one Ripple; Reduced Motion suppresses animation. ZIP previews are documentation only.
