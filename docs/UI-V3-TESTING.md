# UI V3 integration and Studio test guide

## Upload and configuration

The supplied ZIP was extracted into `assets/ui/TetrisBattle_UI_Assets` in the existing project. The pack's nested example `default.project.json` and sample source are reference files only: the project's actual Rojo tree is unchanged. Rojo loads the integrated configuration from `ReplicatedStorage.Shared.Config.UIAssetConfig`; the PNG folder is outside the Rojo tree and must be uploaded separately.

Use the root `ASSET_ID_CHECKLIST.md` to upload the original PNG filenames and paste IDs. All 58 PNGs were visually inspected. All supplied ID slots remain empty; there are no invented IDs. Numeric strings and `rbxassetid://` strings are accepted; blank/invalid slots fall back safely. The existing sound IDs, RankIconConfig and CurrencyIconConfig are preserved. Existing rank icons take priority over optional reference icons.

Typography uses the documented built-in Press Start 2P family through `UIThemeConfig.FontAsset`; no custom font upload is required. Roblox font-family documentation: https://create.roblox.com/docs/reference/engine/datatypes/Font . Override centrally with an authorized font-family URI if desired.

The pack includes no background/board frames/Perfect Clear sticker; these remain procedural with optional image slots. Demon Wave has no existing catalog item and is kept as optional reference artwork. Neon Comet/Plasma/Solar and Spectral map to existing effects through `CosmeticArtwork`; those marketing thumbnails do not alter the actual live renderer. Optional reference rank names differ from actual ranks; their switch remains disabled unless you explicitly configure display mappings. See More > Assets for unmatched/reference artwork. Rank names, thresholds and rewards never change.

## Functional changes

- Lobby: avatar/rank header, separate Cash/Energy buttons, mail/settings, two play buttons and six icon destinations. More holds secondary links in a compact grid. Portrait and narrow landscape can scroll lobby content while keeping the header accessible.
- Shop: desktop category sidebar and catalog/live-preview split; responsive cards; rarity borders/selection and modest pulse. Purchases/equips show a pending state, reject duplicate clicks and recover after a failure. Ownership always comes from a server Profile response.
- Inventory: owned item grid, actual tetromino rendering, equipped/owned states and access to the same live preview. The engine-driven falling tetromino demo is preserved. Artwork does not replace it.
- Preview: pause/play, rotate, replay, change piece, speed and manual SFX sample controls. They act only on the isolated demo engine. Reduced Motion freezes automatic movement. Closing previews stops samples/cleans up the demo.
- Gameplay: neon magenta/cyan frames, full player headers, central yellow timer, HOLD/NEXT lanes and sent/K.O. counters, configurable star icons and progress. Standard phone landscape (760+ usable pixels wide) retains both HOLD/NEXT groups; narrower portrait prioritizes the local board and shows a compact opponent. Desktop Solo centers the board.
- Garbage: shared server-confirmed Attack events drive bounded, staggered hollow-square arcs, optional block textures, direction arrow and target meter pulses. Actual newly appearing gray board cells receive a short tint pulse; no rows are fabricated and no incoming delivery is delayed. Both clients receive the same event and draw it from their local/opponent perspective. Fully canceled attacks remain silent visually. Combo, K.O., countdown and Perfect Clear use optional artwork with real-value text/procedural fallback. Opponent announcements now read the real replicated opponent event stream.
- Quests: actual progress bars, reset countdown, incomplete/claimable/claimed states and restrained claim highlighting. Energy uses authoritative current count, segmented meter and timestamp-based regeneration countdown; it grants no energy locally.
- Navigation: nested Back, selection and scroll retention, modal click blocking, focus entry and phone-preview isolation. Settings opened over gameplay continue using the existing pause/block behavior.

The actual server, engine, ProfileStore, player-data services, Rules, SoundConfig, CosmeticConfig prices and progression modules are unchanged in V3. GameClient changes concern pending UI operations only. There is no data migration or reset and no Git commit/push.

## What remains unavailable

This project has no existing Developer Product purchase/receipt flow. Cash/Energy pack artwork is wired to unavailable cards; no price, product ID or reward is fabricated. `DeveloperProductConfig` is a disabled configuration stub, not a payment implementation. Supplying image IDs will not enable paid purchases. Code redemption also had no backend and displays an unavailable screen. Image integration preserves working systems; it does not claim these absent systems exist.

## Studio steps

1. Stop Play, let your existing Rojo session synchronize, and restart. Inspect Output. With all image IDs empty, every screen must remain functional and readable with fallbacks. Upload one menu, currency, countdown and projectile image first; confirm that entering IDs in UIAssetConfig is sufficient. Test an invalid/unavailable image and check Output/permissions; failed image delivery cannot be verified by local harnesses.
2. Inspect lobby, More, Profile, Shop, Inventory, Quests, Login, Leaderboards, Friends, Audio, Energy, Cash and Settings. Confirm real profile values, names and existing prices. No decorative screenshot replaces an interactive board.
3. Try nested navigation: More > Energy > Quests > Back > Back. Confirm return to Energy, then More. Open Shop, select/scroll to a cosmetic, open Profile, then Back: selection and scroll must return. Open a phone preview and try tapping the catalog/lobby behind it; no action should fire. Test Escape, gamepad B and focus.
4. Preview every cosmetic category. Pause a falling piece, rotate/change it, replay and change speed. Confirm your live match/profile does not change. Compare real skin preview cells with gameplay cells. Sound Pack sample requires a click, respects volume and stops on close. Test Reduced Motion while a preview/effect is active.
5. With free-cosmetic/purchase debug privileges disabled in a separate test setup, Buy/Equip must display WAIT during the operation. Confirm prices/ownership/loadout update only after the server's profile; click repeatedly and simulate a recoverable failure. Scroll must stay stable. Test Inventory grid and phone preview return.
6. Check Daily and Weekly quests: incomplete cannot claim, eligible claim is highlighted, claimed disables. Progress bars and reset clock must agree with saved progress. Energy countdown reaches zero without granting a client-side unit; subsequent server profile provides regenerated count.
7. Start two clients and Ranked. Verify identical 3/2/1/GO and 120-second timing, actual boards/HOLD/NEXT, K.O. recovery/counts and results. Send lines both ways: positive post-cancellation counts, hollow blocks along a staggered arc, correct target meter and newly inserted real gray rows. Full cancellation must emit no fake attack. Trigger combos, T-Spins, Back-to-Back and a perfect clear; check priority/caps, green burst and existing sounds. Test final-seconds warning and Reduced Motion.
8. Device Emulator: 320x568, 390x780, 568x320, 844x326, 1024x768, 768x1024, 1366x768 and 1920x1080; test safe areas and physical touch/gamepad separately. Watch label clipping with Press Start 2P and uploaded art; inspect board/frame visibility, controls, scrolling and HUD proportions. Confirm standard landscape shows both HOLD/NEXT columns.
9. Rejoin an isolated persistence-enabled TEST experience following PROFILESTORE-INTEGRATION.md. Confirm existing Cash, Energy, rank, cosmetics, quests/settings survive. This UI update does not change the existing backend rollout switches.

## Verification record

Automated suites verify asset URI parsing/fallbacks, built-in font selection, modal guards, nested Back, scroll retention, inventory grid, preview control isolation, pending operation recovery, quest states, shared attack events, optional textures and layout/control bounds. The asset audit checks all 58 original PNGs plus manifest dimensions/checksums/config/checklist coverage. Luau compilation and a Rojo build are also run.

Harnesses use Roblox service/UI doubles. Native Studio rendering, uploaded images/audio permissions, physical touch/gamepad devices, cloud persistence/session locking, latency and mobile frame rate require the manual tests above. Pixel-perfect reproduction and performance at 100 players have not been verified.
