# ProfileStore installation, migration and verification

## Installed implementation and Rojo path

`src/server/ProfileStore.luau` contains the full source supplied in your reply, without implementation edits. Its SHA256 is `fcd13745eb01a94f8ac0b95eb59f1e93bf66c3e416760b2309b529c581055e94` (64,518 UTF-8 bytes; final newline added).

Your existing `default.project.json` maps `src/server` to `ServerScriptService.Server`. Rojo therefore creates exactly one **ModuleScript** at **ServerScriptService → Server → ProfileStore**. It is never placed in ReplicatedStorage. No Rojo mapping changes or second project are needed.

| File | Change |
| --- | --- |
| `src/server/ProfileStore.luau` | Exact supplied MAD STUDIO library. |
| `src/server/PlayerDataService.luau` | Central loading/session authority using New, StartSessionAsync, AddUserId, Reconcile, OnSessionEnd, IsActive and EndSession. Critical mutations wait for a matching LastSavedData token; pending results are cleared only after confirmation. |
| `src/server/LegacyPlayerDataService.luau` | Unmodified copy of the existing service, retained during the guarded live rollout. This is the existing backend, not a replacement library. |
| `src/server/ProfileStoreMigration.luau` | Preflight reads, immutable original-record backup and conditional legacy-envelope conversion. |
| `src/server/GameConfig.luau` | Test namespace, timeouts and rollout switches. Original DataStore name, player keys, economy values and debug privileges are retained. |
| `src/server/LeaderboardService.luau` | Uses the data service namespace so persistence tests cannot write existing live or Studio leaderboards. Live names remain the same. |
| `src/client/PortalUI.luau` | Updates shop cards in place; retains scroll position and reads current equipped state in callbacks. Art, fonts, spacing and layouts are unchanged. |
| `tests/build-harnesses.js`, fixtures and generated harnesses | Reproducible supplied-library persistence and shop regression checks. Test service doubles are confined to `tests`; production uses the actual supplied library. |

Game engine, input bindings, progression rules, matchmaking, UI theme/artwork, prices, sound IDs and remote protocol are unchanged. No commit, push or publication is included.

## Current rollout state

The update deliberately **does not switch existing live players to ProfileStore before testing**.

| Environment | Default backend / namespace |
| --- | --- |
| Live server, `ProfileStoreLiveEnabled=false` | Original service and `TetrisBattle_Player_v1_Live`; original numeric string keys and result inbox. |
| Studio, normal `Debug=true` and `ProfileStoreStudioPersistence=false` | Explicit ProfileStore.Mock for development only; no persistent gameplay saves. |
| Studio, `ProfileStoreStudioPersistence=true` | Actual ProfileStore and `TetrisBattle_ProfileStoreTest_v1`, plus isolated results and leaderboards. API access is required; failures never substitute a production mock. |
| Live after verified rollout, `ProfileStoreLiveEnabled=true` | Actual ProfileStore and the existing `TetrisBattle_Player_v1_Live`, with the same `tostring(UserId)` keys. |

`ProfileStoreStudioPersistence=true` suppresses Studio's free/infinite debug privileges for that test. This is necessary to test real Cash costs, energy and qualifying ranked rewards. The switches do not affect the supplied library's constants or API.

The library performs its original `____PS` Studio API availability probe. That code is unchanged.

## Migration requirements — read before live rollout

The old service saves `{Data=..., Lease=...}` (and can read raw schema-v1 data). The supplied ProfileStore requires `Data`, `MetaData` and `GlobalUpdates`. Loading the old envelope directly through the library would classify it as invalid and replace it with defaults. **This integration preflights the record before StartSessionAsync.**

For recognized legacy records, the migration:

1. Rejects active legacy leases, invalid core field types, malformed ProfileStore envelopes and unsupported newer schemas.
2. Copies the complete original record to `<namespace>_Backup` under the same player key, including its old lease and source version.
3. Converts the envelope only if the player record still has that source version and its legacy lease is inactive. A concurrent edit or failed backup stops the load.
4. Keeps the original `Data` payload, including unknown fields. The existing Progression validation and ProfileStore reconciliation add missing defaults; they do not replace a valid existing profile with a new one.
5. On subsequent joins, recognizes the ProfileStore envelope and skips conversion.

No cloud migration or save reset is executed by the local installer or automated harnesses. Runtime conversion runs only in the selected backend's namespace. The original `_Studio` saves are not imported into the fresh, isolated test namespace.

**Before enabling ProfileStore in production:** complete the separate test pass, archive the current place/version, and close every server running the old save service. Do not run old and new save code against the same live records. After conversion, rolling back to the old service against converted records is unsafe: the old writer would discard ProfileStore session metadata. Restore deliberately from the per-key backups only while all writers are stopped; this integration provides no automatic destructive rollback.

Leave `ProfileStoreLiveEnabled=false` until the above has been verified. No production deployment is authorized by this change.

## Data and session safety

Cash, energy and regeneration timestamp; rank/stars/rating; wins/losses/streaks; seasons/history; all cosmetic ownership and four equipped slots; daily/weekly quests; login rewards; achievements/badges; settings; reward receipts; energy reservations and social reward state use the existing schema.

`Data:get()` returns a profile only after load, validation, pending-result recovery and its initial save complete. Existing server handlers gate purchases and rewards through it. Failed loads do not expose defaults to gameplay. Session termination clears access and disconnects the player. Departing players end their library session.

Results are first journaled to the existing `<namespace>_Results` inbox. The reward and its processed ID save together. Inbox deletion happens only after the saved snapshot contains that ID, so recovery is idempotent.

An interrupted critical save is inherently ambiguous: Roblox may have accepted it even if this server did not receive confirmation. The service blocks further actions and ends the session. It preserves the atomic Cash/item update for the library's final save rather than announcing an unverified rollback. The player should reconnect to check whether the operation completed. There is no promise that a disconnected network can be made durable by local code.

## First Studio test — separate test experience

1. Use a separate published **test experience**, connected to this existing Rojo project. Enable that test experience's **Studio API Services**. Do not publish these changes to the production experience yet.
2. In `GameConfig.luau`, set `ProfileStoreStudioPersistence=true`. Keep `ProfileStoreLiveEnabled=false`. Stop/restart Play; do not change persistence switches during an active session.
3. Check Output for `[PlayerData] ProfileStore / isolated persistence test / TetrisBattle_ProfileStoreTest_v1`. Check Explorer for one server-only ProfileStore ModuleScript. If API access is unavailable, loading must fail visibly; the shop must not become usable with a fresh free profile.
4. Join with two Studio clients and check separate balances, equipped cosmetics and profile information. Stop the test, wait for final saves, and restart using the same test player IDs. Values must return.
5. To obtain test Cash quickly, use the **server** command below while Studio is running. It is guarded to the isolated namespace and goes through the real data service. This is optional test setup, not a production grant.

```lua
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Studio test setup only")
local Data = require(game.ServerScriptService.Server.PlayerDataService)
assert(not Data.Debug and Data.Namespace == "TetrisBattle_ProfileStoreTest_v1")
local player = game.Players:GetPlayers()[1]
assert(player and Data:get(player), "Wait for the profile to finish loading")
assert(Data:mutate(player, function(data)
    data.Cash = math.max(data.Cash, 1000)
    return true
end))
```

6. Buy a brick skin, drop effect, ghost effect and sound pack; equip each. Restart Play and check the exact balance, ownership and all four selections. Return to Solo to verify appearance. Leave SoundConfig IDs unchanged.
7. Play a ranked round for at least the existing minimum reward duration (20 seconds), finish it, and check rank/stars and quest changes after rejoin. Duplicate result delivery must not grant rewards twice.
8. Spend energy in a ranked match, finish it normally, note the regeneration timer, and rejoin after at least 600 seconds. Energy should regenerate from the saved timestamp, capped at the existing normal cap. A cancelled-before-start match should refund only once.
9. Claim login/quest rewards; change sound and Reduced Motion settings; rejoin and check their saved state.

For real cross-server locking and shutdown verification, publish only to the separate test experience and enable the live switch there. Its universe has separate DataStores. Attempt rapid reconnects between test servers, server closure during a match, two different real accounts, and repeated purchases. Never run legacy and converted backends concurrently against that test namespace.

## Shop scrolling regression

1. Scroll near Galaxy, Crystal Glass or Holographic. Record the visible cards.
2. Press Preview, close the phone preview if applicable, Buy an unowned item, then Equip/Unequip it. The list must stay at the same position. Cash/status/buttons should update without the list flashing or being recreated.
3. Wait for the periodic profile refresh and repeat on desktop, portrait phone and tablet. Gamepad selection should remain on the surviving card action.
4. Inventory can add newly owned cards; category changes intentionally open the new list at the top. Actual content removal or viewport changes may clamp an invalid scroll position to the new legal range.

## Automated verification and limitations

The generated ProfileStore harness executes the **exact supplied library**, with simulated Roblox DataStore, scheduler and messaging services. It tests session ownership and termination, all required fields, rejoining, offline regeneration, backup conversion, concurrent edits, failures/cancellation, result recovery, once-only refunds, and ambiguous critical-save behavior. It does not replace the library with fake Profile objects.

Engine, progression, legacy live-backend server flows, input and UI regression suites also run. UI tests simulate canvas collapse during destructive rebuilding and verify card identity and CanvasPosition for Preview/Buy/Equip responses.

Actual Roblox API permissions, cloud persistence, DataStore budgets, real multiple-server behavior, Studio's native scrolling/focus and shutdown ordering remain manual test requirements. A Rojo build proves mapping/compilation, not those runtime guarantees. Report the active backend line, steps and red Output errors for a failure.

References: [ProfileStore API](https://madstudioroblox.github.io/ProfileStore/api/), [ProfileStore author repository](https://github.com/MadStudioRoblox/ProfileStore). Installation uses your supplied implementation, not a downloaded substitute.
