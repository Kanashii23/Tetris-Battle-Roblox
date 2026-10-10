# Tetris Battle UI Asset Pack

57 individually generated PNGs inspired by the two supplied UI reference images.
Artwork uses the built-in image generation tool. All PNGs retain generated transparency.
See manifest.json for names, dimensions, checksums, and empty Roblox asset-ID fields.
See prompts.json for the final generation prompt for each image.

## Roblox / Rojo

1. Upload each PNG through Roblox Studio's asset workflow.
2. Copy its image asset ID into the matching string in src/ReplicatedStorage/UIAssetConfig.luau.
3. Merge the supplied Rojo tree fragment into your existing project, or use the module directly.
4. Example: imageLabel.Image = Config.ImageUri(Config.Images.menu.shop).

The Rojo project maps only the Luau module. PNG uploads and IDs require Roblox's asset workflow.
The manifest assetId fields are a tracking convenience; the Luau module is the runtime config.
No actual IDs are invented, and no existing Config module is overwritten.

## Ranks

The reference screenshot labels Rookie, Amateur, Pro, Expert, Master and Immortal as examples.
These six badges live exclusively under assets/optional_reference_ranks and
Config.OptionalReferenceRanks, with Enabled = false. They define no rank thresholds,
ordering, rewards, or replacements. Keep your existing rank system and map a badge only
if it matches your established ranks. The retrieved conversation did not expose the
existing rank definitions.

## Categories and use

- menu: main menu, More menu, settings, mail, emoji and chat icons.
- currency: cash coin and energy bolt.
- shop: three cash pack and three energy pack illustrations.
- quests: practice, ranked wins, T-spins, sent lines and play time.
- battle: attack arrow/projectile, COMBO, K.O!, countdown, GO! and progress stars.
- cosmetics: six brick skins, three drop effects, three ghost effects and a sound pack.
- optional_reference_ranks: six optional example badges.

Cosmetic PNGs are static thumbnails showing vertical descent. Battle effect PNGs are
static overlays or particles; animate them in your UI code. Labels, timers, prices,
progress bars, board grids, chat filtering and gameplay remain UI/game logic.
New drop/ghost variants are additions inspired by the requested richer effects.
These are newly generated interpretations rather than crops of the reference UI.

Use ScaleType.Fit for icons and avoid stretching. The preview contact sheet uses a
dark background for visibility; the individual asset backgrounds are transparent.
