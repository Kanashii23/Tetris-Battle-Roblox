# Playable Tetris Battle: Studio validation

The existing project now uses a reusable deterministic engine, server-controlled Solo and 1v1 gameplay, and progression services. This guide replaces the earlier **visual-preview** checklist.

**Evidence available:** 19 pure engine tests, 10 pure progression tests, 9 groups of mocked server integration checks, 4 input checks, and 4 client/UI smoke checks. The user confirmed Solo movement, rotation, hold and drop, plus two-client matchmaking with opponent-board updates in Studio. Luau compilation and the Rojo build pass. Mocked checks do not certify cloud DataStore, physical devices, or 100-player performance.

## Start safely

1. Save VS Code files and keep the existing Rojo connection running.
2. Stop all Play sessions, allow Rojo to sync, then start Play again.
3. Keep `src/server/GameConfig.luau` set to `Debug = true` for the first tests. Debug privileges are effective only when `RunService:IsStudio()` is true. Data is temporary in this mode: no API-access setup is needed, and restarting the test resets the test profile.
4. Look for `[Tetris Battle] Playable neon client ready.` in Output. Red errors in either the server or client must be fixed before moving to later tests.

## Milestones 1–2: Solo and competitive mechanics

Open **Solo Practice**. The bottom row of the spawn piece is immediately visible; the remaining four spawn rows are hidden. Hold and the five-piece queue must update from actual engine state.

| Action | PC | Default gamepad |
| --- | --- | --- |
| Left / right | A/D or Left/Right | D-pad left/right |
| Soft drop | S or Down | D-pad down |
| Clockwise / counterclockwise | X/Up and Z | A and B |
| Hard drop | Space | Y |
| Hold | C or Left Shift | X |
| Pause/menu | Settings, Escape where supported | Start |

On mobile there are seven buttons with separate CW and CCW rotation. Hold left/right/down; release outside the button; use two fingers; release one finger while holding another direction. The controls must stop cleanly when released or when focus is lost. Down must never rotate or hard-drop.

Verify all seven pieces, gravity, walls, floor kicks, hard-drop landing versus ghost, hold once per piece, next queue, line clears, score/level changes, and top-out. Open Settings: Solo stops and its elapsed timer stops. Back to Arcade resumes; Restart Solo clears the board; Exit returns to the lobby without spending Energy.

The automated suite covers T-Spin corner classification, fifth-kick promotion, singles/doubles/triples, Mini scoring, combos, back-to-back, perfect clears, delayed garbage, cancellation and overflow. Reproduce tricky placements in Studio before relying on them competitively.

## Milestone 3: actual multiplayer

Use Roblox Studio's **Server & Clients** testing mode and choose **2 clients**. Roblox documents multi-client testing in [Studio testing modes](https://create.roblox.com/docs/studio/testing-modes).

1. In each client, choose Ranked 1v1. One client alone must keep searching; no opponent is fabricated.
2. Confirm elapsed search time, profile/rank information, opponent-found notice and a shared three-second countdown.
3. Move a piece in client A. Client B's opponent board must show A's actual movement and locked cells. Repeat in the other direction.
4. Clear a Tetris or T-Spin. Confirm incoming garbage on the other client, delayed insertion on a non-clear lock, and cancellation by counter-attacks.
5. Top out one client. Both must see the same KO outcome, while rewards are applied once.
6. Repeat with an idle 120-second match: compare the shared timer, 30-second warning, final-ten-second notice and deterministic result.
7. Queue then cancel; double-click Find Match; leave during countdown; close a client during play. Check cleanup and countdown refunds.
8. Request Rematch on both results screens. No rematch begins unless both agree and remain available.
9. Repeat with **4 clients** and two matches. An action or attack in one match must never update the other match's clients.

Defaults: one round, first top-out loses, both top out in the same resolution step is a draw. On time expiry compare **garbage sent after cancellation**, then lines, then score; equal values draw. Leaving after gameplay starts forfeits. Online Settings never pauses the other player or the battle clock.

## Milestone 4: persistence, ranks, Cash and Energy

With Debug true, use quick test matches to inspect rank, rewards and quests. With normal live settings, reward eligibility requires at least 20 seconds of play; ranked rewards from the same opponent have a ten-minute cooldown and a three-per-day cap. Ineligible matches still have a result but award no standard rank/Cash/quest progress or competitive leaderboard win.

For cloud persistence, use a **published test experience**, set Debug false, and enable Studio API access for that test experience if testing in Studio. Studio uses `TetrisBattle_Player_v1_Studio`; published Roblox servers use `_Live`. These namespaces are separate. See [Roblox DataStores](https://create.roblox.com/docs/cloud-services/data-stores).

1. Record Cash, stars, rating, Energy, equipped cosmetics and quest progress.
2. Complete an eligible match and rejoin. Verify they survive reconnecting.
3. Confirm ranked costs one Energy only after a pair is reserved. Searching alone costs nothing. Cancel before gameplay begins and verify one refund per reservation.
4. Confirm a winner gains one star and Cash based on their **rank at match start**; a loser loses one star; Rookie cannot fall below zero. Promotion/demotion behavior and Master Elo rating are configurable.
5. Spend Energy below ten, rejoin after regeneration time, and verify offline regeneration. Bonus quest/social rewards may reach twenty. No normal regeneration occurs above ten.
6. Interrupt a save in a private test and verify that a failed purchase changes neither Cash nor ownership. Do not deliberately damage production data.

Profiles use UpdateAsync and renewable session leases, serialized per-player mutations, retries, autosave, leave/shutdown saves, match receipts, durable result inboxes and unresolved-reservation refunds. [Roblox's session-locking guidance](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing) explains the underlying risk. Extended service outages still require operations review: no code can certify persistence by mocked tests alone.

## Milestone 5: quests, daily login, achievements and friends

Open **Shop / Quests / Profile**, then the relevant screen.

- Daily and weekly quests: play qualifying ranked games or clear lines/T-Spins in server-controlled Solo, exit Solo to settle its statistics, then claim. Each quest must claim once. Daily reset is 00:00 UTC; weekly reset is Monday 00:00 UTC.
- Login: claim once per UTC day. The seven-day cycle advances only when claimed; missing a day does not erase previously earned rewards.
- Profile: verify wins, lines, T-Spins, streaks, rank, achievements, season history and cosmetic badges.
- Friends: Invite uses Roblox's supported prompt after eligibility checking. Clicking it never grants Energy. The alternative social reward verifies a first-time participant, friendship, account age of at least seven days, two-minute server presence, per-account attribution and per-host daily limits. Verify this with real friend accounts in a published test experience; Studio dummy clients are not real friends.
- Friend Challenge: choose a real friend in the same server; accept their invitation within thirty seconds. The unranked duel must cost zero Energy and award no ranked stars/Cash.

If a social reward cannot be durably completed, fail safely and investigate the profile logs rather than inventing accepted-invite attribution. Roblox's [SocialService](https://create.roblox.com/docs/reference/engine/classes/SocialService) and [friendship API](https://create.roblox.com/docs/reference/engine/classes/Player/IsFriendsWithAsync) are the relevant supported signals.

## Milestone 6: shop and inventory

The catalog includes Brick Skins, Drop Effects, Ghost Effects and Sound Packs. Every item has an ID, rarity, price, description, preview and cosmetic configuration. The featured item rotates by UTC day while the full Cash catalog remains available.

1. Browse and preview each category. With debug privileges enabled, equip items without grinding.
2. With Debug false, buy an affordable item. Cash should fall by the displayed price once; ownership must persist across reconnects.
3. Equip/unequip, return to Solo, and inspect block tint, ghost appearance, drop particles or permitted configured sound-pack overrides.
4. Click Buy again on an owned item; it must not spend again. Try an unaffordable item; it must be rejected.
5. Compare identical seed/rules with different cosmetics. Collision, timing, score and attacks must be identical.

Cosmetic presentation is an initial native-UI implementation, not final commercial art. Particle effects are capped and Reduced Motion removes them. Sound packs are silent until their editable IDs are supplied.

## Milestone 7: leaderboards and seasons

Leaderboards provide Global Rating, Global Qualified Wins, Season Rating and Season Wins. Live standings use cached OrderedDataStore Top 100 pages. Debug shows explicitly labeled server-local test standings.

After a qualifying win, rejoin and inspect each tab. Check rating/win values, names, rank badges, avatar and placement. An exact position outside Top 100 is deliberately not guessed. Season rollover preserves Cash and cosmetics, saves history, resets season rating/wins, and grants a one-time reward/badge based on the completed season's wins. Lifetime rank and statistics remain.

In an isolated test only, move `SeasonStart` backward enough to trigger the next season, restart, and verify the one-time rollover. Restore the configuration afterward.

## Milestone 8: audio, animations and device checks

Use the README's **HOW TO ADD YOUR OWN SOUNDS** section. All sound IDs start empty intentionally. Mute, master/music/SFX controls, pack overrides and missing IDs must behave without errors. Test permitted assets in the published test experience as well as Studio.

Use [Device Simulator](https://create.roblox.com/docs/studio/device-simulator) or your Studio version's Device Emulator for phone portrait, short landscape and tablets. Rotate while on the menu, Solo, a battle, the shop and results. Test physical touch and a physical controller before launch; emulation does not prove real-device behavior.

Controls must remain separate from the boards. The local board stays larger on phones; desktop ranked mode shows two substantial boards side by side. Check text clipping, safe areas, modal input blocking, gamepad focus, pause/resume and Reduced Motion.

## Milestone 9: regression and performance gates

If the official standalone [Luau tools](https://github.com/luau-lang/luau/releases) are installed, run from the project folder:

```text
luau tests/Engine.spec.luau
luau tests/Progression.spec.luau
luau tests/ServerHarness.luau
luau tests/InputHarness.luau
luau tests/UIHarness.luau
```

Server/Input/UI harnesses are generated snapshots of source plus mocks. They exercise real implementation code but are not substitutes for Studio tests. Rebuild them after implementation changes with Node.js: `node tests/build-harnesses.js`.

The code limits concurrent rooms to fifty and targets one hundred players. Boards are packed into 200-character strings and sent only to participants at twelve updates per second. **The 100-player target is unverified.** Use Studio/server MicroProfiler and Developer Console to record frame time, heap, replication traffic, remote rates, DataStore budgets and low-end client performance. Introduce latency/jitter using [Network Simulator](https://create.roblox.com/docs/studio/network-simulator); server authority adds control latency, and prediction is a future improvement if testing shows it is necessary.

Before release: pass all tests above, set Debug false, confirm live data isolation, configure permitted sounds, configure the experience's actual server capacity in Roblox, profile progressively from two to many clients, validate the cloud failure/recovery paths, and review any unresolved errors. Publishing, committing and pushing remain manual approval steps.

## Historical fidelity

This is an original neon game inspired by classic Facebook Tetris Battle. Exact historical scoring, garbage timings, KO respawn rules and reward values have not been verified. Configured defaults are consistent approximations: standard SRS kick tables, three-corner T detection, front-corner Mini classification/fifth-kick promotion, full-spin promotion for two-or-more-line Minis, additive combo/B2B/perfect-clear attacks, one-round sudden death and the tie-break described above. Edit `Rules.luau` and `GameConfig.luau` to tune them; do not advertise an exact recreation.
