# Retro synthwave UI — testing guide

This redesign runs in the existing Rojo project. Restart **Play** after Rojo syncs the files. Open **Output** and look for `[Tetris Battle] Retro synthwave client ready.` There should be one main UI and one artwork background.

## What changed

| Files in `src/client` | Purpose |
| --- | --- |
| `RetroTheme.luau`, `NeonUI.luau` | Shared colors, bundled fonts, thin borders, buttons, focus groups and Reduced Motion transitions. The existing NeonUI module name remains compatible with the project. |
| `RetroArtwork.luau` | Original native UI illustration: striped sunset, distant skyline and quiet perspective grid. No uploaded artwork or image asset IDs are required. |
| `NeonLayout.luau`, `TetrisUI.client.luau` | Main menu, live Solo/Battle boards, profiles, timers, incoming garbage meters, touch controls and settings. Phone layouts give the local board more room; desktop battle keeps two large boards. Short menus and settings scroll. |
| `BrickStyles.luau`, `BrickRenderer.luau` | Ten brick treatments and ghost definitions shared by gameplay, Hold, Next and the shop. |
| `BrickPreviewRenderer.luau`, `CosmeticRenderer.luau` | Real tetromino samples, ghost/drop demonstrations, landing particles and cleanup. Samples are explicitly labeled cosmetic samples; match boards always use received game state. |
| `PortalUI.luau` | Shop, inventory, quests, player profile, global/season leaderboards, daily login, energy, friends, audio, matchmaking and result screens. Long rows size to their text. |
| `AudioController.luau` | A short sound pack sample that waits for loading, applies pack overrides and respects mute/volume without equipping the pack. |
| `tests/build-harnesses.js`, `tests/fixtures/ui-*.luau`, generated `tests/UIHarness.luau` | Reproducible UI regression checks with Roblox instance mocks. |

The server modules, engine, rules, progression, Catalog prices, DataStore implementation, `GameClient`, `InputController`, initializers, `default.project.json`, `rokit.toml` and **SoundConfig IDs** are unchanged. No commit, push or publish is part of this update.

## 1. Main menu

1. Start Play on desktop. Check the striped sun and skyline, the two line arcade title and the smaller navigation buttons. All text should remain readable without heavy glow.
2. Check that Cash, energy, rank and stars match **Player Profile**. These values come from the server.
3. Open Global Top 100, Season Top 100, Cosmetic Shop, Daily Quests and Player Profile. Use Back after each. Open **More / Inventory** to reach inventory, login rewards, energy, friends and audio.
4. Resize Studio while the menu is open. On a short portrait screen, scroll the menu and confirm the balance and all navigation entries remain reachable while Settings stays at the top.

## 2. Solo Practice

1. Choose Solo Practice. Check the 10×20 board, Hold, five Next pieces, score, lines, level and timer.
2. Move, rotate both directions, hold, soft drop and hard drop. Confirm the active piece, its projected landing position and Hold/Next colors are consistent.
3. Open Settings. Solo should pause. Toggle Reduced Motion and sound, open Music / SFX Volumes, then return. Restart Solo and Lobby should still work.
4. On touch emulation, use all seven controls. Controls must stay below the board. The layout changes between portrait and landscape; the local board remains the largest board in a portrait battle.

## 3. Ranked 1v1 and results

1. Start **Server & Clients** with two clients. Select Ranked 1v1 in both.
2. Check search/cancel, opponent found, countdown, avatars, names, ranks/stars, two separate boards and the shared timer. Move pieces on each client and confirm the other board updates.
3. Clear lines and inspect the incoming garbage meter and attack notification. Confirm KO and the final timer warning remain readable. Opening settings during a battle must leave the match running.
4. Finish a match. Check the real result, score/attack statistics, rank progress, Cash reward, Rematch and Return to Lobby. Compare resulting profile and quest progress with the server's response.

## 4. Cosmetic shop and inventory

1. In **Bricks**, inspect all ten skins: Default Classic, Neon Club, Cyber Core, Ocean Wave, Galaxy, Gold Elite, Lava, Crystal Glass, Retro Pixel and Holographic.
2. Each entry should show an actual T piece, name, rarity, Cash price, Locked/Owned/Equipped status and Preview/Buy/Equip controls. An equipped default is labeled Equipped. Owned items disable Buy; locked items disable Equip.
3. Press Preview on several skins. Desktop uses the right preview area; phone and tablet use a focused sample panel. Landscape phones put the board beside the description. The preview must not spend Cash or change your equipped skin.
4. Purchase an affordable item, wait for the server profile response, then Equip. Enter Solo and compare the sample's edges, highlights and pattern with the live board, Hold and Next. Check Inventory filters to owned items.
5. Open **Drop FX**. Preview a nondefault effect: a T piece falls and triggers its landing effect. Open **Ghost FX** and inspect the active piece and projected landing position. With Reduced Motion on, samples remain still and landing particles stop.
6. Switch previews repeatedly and close the shop. Samples and effects must disappear without accumulating UI instances or Output errors. Default Drop has no particle effect by design.

Studio's existing debug privileges may make cosmetics free or already available. Keep those privileges unchanged. Verify normal Locked/Buy/Equip states with a nondebug test account when available; automated checks exercise both states without contacting live services.

## 5. Sound packs

**No existing SoundConfig IDs are changed by this redesign.** The existing configuration contains empty IDs until you add your own audio.

1. Upload your WAV through your normal Roblox audio workflow and grant the experience permission to use it.
2. Paste its ID into an appropriate existing entry in `src/shared/Config/SoundConfig.luau`, such as `Sounds.HardDrop`. You can use `"123456789"` or `"rbxassetid://123456789"`.
3. Restart Play, open Shop → Sound Packs and press Preview or Play Sound Sample. The sample chooses the first configured HardDrop, Rotate, Tetris or Move sound and plays up to 1.6 seconds after loading.
4. Preview another pack and verify it does not equip that pack. Mute and volume controls should affect the sample. Empty IDs show a clear unavailable message; inaccessible audio can generate a load warning.

Later, place event overrides in the existing `SoundConfig.Packs.RetroArcade.Sounds`, `Cyber.Sounds`, `Crystal.Sounds` or `NeonClub.Sounds` tables. Preview uses those overrides and falls back to `SoundConfig.Sounds`. The default configured pack pitch is also respected.

## 6. Remaining menus

| Screen | Checks |
| --- | --- |
| Daily / Weekly Quests | Correct targets, progress, claimed state and reward; claim requests reach the existing server handler. |
| Global / Seasonal Leaderboards | All four rating/win tabs load server standings; long names and avatars fit; empty or unavailable standings show the real notice. |
| Player Profile | Rank progress, stars/rating, lifetime stats, badges, season and history. |
| Daily Login / Energy | Seven reward days, current energy and server regeneration information; long descriptions must not cover actions. |
| Friends | Invite and friend challenge actions, incoming duel invitation and acceptance. Studio may restrict the real invitation dialog. |
| Audio / Settings | All volume options, mute, Reduced Motion, Return, Restart Solo and Exit; scroll when the viewport is short. |
| Search / Results | Cancel search once, real opponent data, settlement notices, reward/rank progress and rematch. |

## 7. Device and controller pass

Use Studio's device emulator for phone portrait/landscape and tablet portrait/landscape, then resize the desktop viewport. Suggested usable sizes: 320×568, 360×640, 390×780, 430×932, 844×326, 768×1024, 1024×768, 1366×768 and 1920×1080. Actual safe areas depend on the device and Roblox top bar, so repeat on real hardware when possible.

Connect a gamepad. Navigate the main menu and tabs with the D-pad/stick and activate with A. Check selected borders, scrolling to offscreen items, Settings opening on Return, preview opening on Back, and B returning from preview/portal. Gameplay controls retain the existing controller bindings. Focus must stay inside open settings or the preview panel.

## Verification status

Automated checks compile the Luau source, build the existing Rojo project and run engine, progression, server, input and UI harnesses. UI checks cover nine device sizes, shared brick appearance, preview isolation, Reduced Motion, effect budgets/cleanup, sound overrides/loading, server-authoritative shop requests and controller focus.

Native UI layouts have also been inspected through code-derived geometry/palette renders. Those renders approximate fonts, omit Roblox avatar loading and are **not Studio screenshots**.

Studio testing of this redesign, actual audio permissions, real touch/gamepad hardware and cloud DataStore behavior still require the manual passes above. The previously confirmed Solo controls and two-client matching were tested before this redesign.

Report the screen/device, steps and any **red Output error** for a failure. A Studio screenshot is useful for font, clipping or spacing problems.

API references used: [Roblox fonts](https://create.roblox.com/docs/reference/engine/enums/Font), [UI selection groups](https://create.roblox.com/docs/reference/engine/classes/GuiBase2d), [text measurement](https://create.roblox.com/docs/reference/engine/classes/TextService), [sound loading](https://create.roblox.com/docs/reference/engine/classes/Sound).
