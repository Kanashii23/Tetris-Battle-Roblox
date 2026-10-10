# Arcade V2: implementation and Studio testing

This update adds configurable premium cosmetics and real engine-driven previews, synchronized countdowns, timed ranked K.O. recovery, authoritative attack feedback, incoming danger alerts, and a results animation driven by the server's settlement. Existing cosmetic IDs, ownership, sound IDs, reward rates, attack calculations, DataStore names and ProfileStore source are preserved. No Git commit or push is part of this update.

## Configuration

- `SoundConfig`: existing audio IDs remain intact. GarbageWarningLow/Medium/High/Critical, RankProgress, StarEarned, StarLost and VictoryFanfare are empty until you upload permitted audio. Warning volume, cooldown, minimum interval and sample length are configurable here. Packs contains event overrides; previews play only when pressed.
- `BattleEffectsConfig`: garbage thresholds (1/4/8/12 pending lines), meter colors, critical flashing, bounded attack particles, announcement priorities/durations and results timing/intensity.
- `CosmeticConfig`: stable catalog IDs and individual styles; rarity Cash prices are Common 2,500, Rare 7,500, Epic 20,000, Legendary 50,000 and Mythic 125,000. Defaults remain free. Earning rates are unchanged. Existing purchases remain owned.
- `BrickSkinConfig`, `GhostEffectConfig`, `DropEffectConfig`: shared gameplay/preview rendering definitions.
- `ShopPreviewConfig`: isolated engine preview speed, frame rate and sample length. The small board uses the real engine, including rotations, drops and clears; it never grants progression or sends gameplay inputs.
- `RankIconConfig` and `CurrencyIconConfig`: blank upload slots with readable fallback symbols. No invented image IDs.
- `Rules`: ranked duration remains 120 seconds; TimedKO enables a 2.5 second board recovery. Each ranked top-out awards one K.O.; the match continues until the deadline. Challenge retains sudden-death behavior. Countdown blocks early input. Existing garbage cancellation and reward formulas are unchanged.

New controllers are `ArcadeFeedback` and `ArcadeResults`. Existing AudioController, GameClient, InputController, board/cosmetic renderers, PortalUI, responsive layout, HUD, ServerMain and test harnesses were updated. Progression only adds settings defaults; its reward calculations are unchanged.

## What was actually verified

113 automated check groups passed across engine, progression, server, input, UI and ProfileStore harnesses. All 56 Luau scripts compiled and Rojo built the project. These tests use Roblox service/UI doubles; they are not a Studio rendering or live persistence test. The supplied ProfileStore library hash remains unchanged.

Checks include post-cancellation attack counts and fully canceled attacks, room isolation, countdown input blocking/full match duration, repeated K.O. recovery and one settlement, warnings/cooldowns/muting, bounded effects, duplicate events, Reduced Motion, real preview drops and perfect clears, existing equip/scroll behavior, layout bounds, and profile load/save failure safeguards.

## Studio pass: restart Play after Rojo synchronization

1. **Lobby and responsive HUD:** inspect Solo, Ranked, Shop, Inventory, Quests, Profile, leaderboards, settings and results. In Device Emulator try desktop, tablet, landscape phone and portrait phone. Confirm boards dominate, labels fit, buttons stay reachable and mobile controls do not cover cells. Test gamepad focus and Back. Verify uploaded rank icons appear after configuring their IDs.
2. **Solo:** verify 3/2/1/GO; moving, rotating or holding before GO must have no effect. Then test move, both rotations, hold, soft/hard drop and pause. Toggle Swap Rotation and Reduced Motion. Clear lines, combos, T-Spins and a perfect clear; check announcements and matching existing sounds. Solo retains its existing end condition.
3. **Two clients:** Studio Test > Server & Clients > 2. Queue both into Ranked. Both must share the countdown and a full 2:00 timer. Watch real opponent HOLD/NEXT, sent lines, K.O.s and boards. Send an attack while receiving garbage: display only the server's remaining post-cancellation amount. Full cancellation displays no outgoing attack. Other matches must receive no events.
4. **K.O. recovery:** top out one board; opponent gains exactly one K.O. The losing board resets after recovery and both continue under the same clock. Top out again, then finish the timer. Confirm winner uses K.O.s first and existing tie breakers afterward; final K.O. count, Cash and stars must agree with the server profile. Closing/reopening or resizing results must not replay rewards or duplicate sounds. Test loss/draw and promotion/demotion as well as win. Rematch queues again; Lobby exits.
5. **Garbage warnings:** temporarily supply permitted IDs for the four new warning keys. Test pending values crossing 1/4/8/12 through real attacks. Confirm faster warnings at higher danger, no overlapping warning clips, SFX/master volume scaling and silence at zero/muted volume. Critical meter flashes with motion enabled and stays readable/static with Reduced Motion. Empty sound IDs are deliberately silent.
6. **Shop/inventory:** inspect each category and rarity. Scroll down and click Preview, Equip, Unequip and Buy; the list must retain its position. Change categories and return. Preview a different skin and confirm its cells match the gameplay board after equipping. Drop and ghost previews show their selected effects on a real engine board. The recurring I-piece well demonstrates an actual four-line perfect clear. Hide/close previews and confirm activity stops. Sound previews require a click and stop when closed; Reduced Motion freezes the sample.
7. **Results audio:** supply IDs for optional RankProgress, StarEarned, StarLost and VictoryFanfare. Existing Victory/Defeat/Draw/RankUp/RankDown/CashEarned remain configured. Test duplicate result delivery/reopening, SFX off and Reduced Motion. Rank changes and reward text must use confirmed settlement; failed/unavailable progression shows a pending message rather than granting anything.
8. **Settings/social:** change volumes, control preferences and desktop UI scale. Rejoin in a persistence-enabled test and confirm settings return. Emotes are server-approved presets with a cooldown; no arbitrary text is relayed. Native chat uses Roblox's existing enabled input and permissions; verify on eligible accounts in a published test. No custom unfiltered chat is added.

## Real persistence is a separate test

The existing `GameConfig` has Studio debug/free-cosmetic flags enabled, `ProfileStoreStudioPersistence=false` and `ProfileStoreLiveEnabled=false`. Those switches were not changed. Default Studio testing cannot prove purchases or real ProfileStore persistence. Use a separately published TEST experience and follow `PROFILESTORE-INTEGRATION.md`: enable API access and the Studio persistence switch, use the existing isolated test namespace, and disable free-cosmetic/free-purchase/infinite-energy debug overrides when testing real costs. Do not test new saves against production data.

Record Cash, Energy, timestamp, rank/stars, ownership, loadout, quest progress and settings; leave, allow session release, then rejoin. Verify offline energy regeneration and separate players. Disable API access to verify failed loads block purchases/rewards without default-data overwrite. Test reconnect/session conflict and server shutdown. This update does not enable a live backend migration.

Still requires manual verification: actual Studio visuals and tween behavior, audio asset permissions/playback, touch/gamepad hardware, native chat access, network latency, real cloud persistence/session conflicts and mobile frame rate. No 100-player performance claim has been validated.
