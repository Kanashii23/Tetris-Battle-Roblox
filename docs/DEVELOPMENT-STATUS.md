# Implementation status and changed files

Date: 10 October 2026 (Asia/Manila). Existing project: `E:\ROBLOX PROJECT USING VSCODE\Tetris Battle`. The user confirmed Solo movement, rotation, hold and drop, and two-client matchmaking with opponent-board updates in Roblox Studio during this implementation session.

This is a broad functional implementation requiring Studio/cloud validation before release. No Git commit, push, publication or second project was created. `default.project.json`, `rokit.toml`, the original client initializer and shared Hello module remain unchanged.

| Milestone | Implementation and files | Evidence | Outstanding validation |
| --- | --- | --- | --- |
| 1. Core gameplay | `src/shared/TetrisEngine.luau`, `src/shared/Config/Rules.luau`, `src/client/GameClient.luau`, `InputController.luau`, refactored `TetrisUI.client.luau`; server-controlled Solo | Pure engine, input, client and server checks; user-confirmed Studio controls | Clear timing, edge cases and device visuals |
| 2. Competitive mechanics | Engine scoring, attacks, SRS, T-Spins, combo, B2B, PC, garbage | Engine fixtures, seeded invariant checks | Historical rule fidelity and tricky real placements |
| 3. Multiplayer | `src/server/ServerMain.luau`, `init.server.luau`; queue, reservation, countdown, isolated boards, timer, KO, results, rematch, challenge | Mocked real server implementation tests; user-confirmed two-client matching and boards | Garbage, results, rematch, four-client isolation, latency and disconnect races |
| 4. Progression | `src/shared/Progression.luau`, `src/server/GameConfig.luau`, `PlayerDataService.luau` | Pure economy + mocked lease/save/recovery checks | Published cloud persistence, budgets and failures |
| 5. Retention | Progression, server social flow and `src/client/PortalUI.luau`; quests, login, streak/achievement badges, friend rewards | Pure daily/weekly/login/idempotence checks | Real friend accounts and UTC rollover in Studio/cloud |
| 6. Cosmetics | `src/shared/Catalog.luau`, `src/client/CosmeticRenderer.luau`, portal shop/inventory | Pure purchase/equip checks and UI smoke tests | All visual effects, asset packs and reconnect inventory |
| 7. Leaderboards/seasons | `src/server/LeaderboardService.luau`, Progression and portal tabs/profile | Pure season rollover and client rendering | Live OrderedDataStore standings and cache behavior |
| 8. Polish | `AudioController.luau`, `src/shared/Config/SoundConfig.luau`, neon helpers/layout and portal | Compilation, mocked client flows, layout calculations | Permitted IDs must be supplied; real mobile/tablet/controller QA |
| 9. Testing | `tests/*`, this guide, README | 19 engine + 10 progression + 9 server + 4 input + 4 UI checks (46 total) | Full Studio/cloud/load acceptance suite |

The lobby exposes real data-driven Profile, Shop, Inventory, Quests, Leaderboards, Login, Energy, Friends and Audio pages. Some related screens are combined into tabs/cards: rank progression appears in Profile/Results; Opponent Found is a notice before the synchronized countdown. These are functional flows rather than eighteen separate scene files.

The menu's hero board is decorative artwork. Solo/battle boards and opponent state use actual server engine snapshots; no fake opponent is inserted.

Cross-server MemoryStore/Teleport matchmaking is intentionally deferred, as requested. `ServerMain.Matchmaking` exposes enqueue/cancel/start seams for a later adapter. Same-server capacity limits are configured; actual Roblox server capacity and 100-player profiling remain release gates.

The shop has native UI tints, silhouettes and bounded particles. Sound-pack IDs remain empty until configured. Achievement/season/streak cosmetic rewards are profile badges; catalog purchases remain Cash-only. More elaborate commercial artwork, optional extra leaderboard metrics and client prediction can be added after acceptance testing.

Cloud guarantees are not certified. During an extended outage, result/social settlement can remain pending; if even the durable result inbox cannot be written after retries, operators must review the warning before promising rewards. Ordinary failed purchases retain cached balances and ownership, as exercised by the fault test.

Follow [GAMEPLAY-TESTING.md](GAMEPLAY-TESTING.md) in dependency order. Do not call the game production-ready until the outstanding checks pass.
