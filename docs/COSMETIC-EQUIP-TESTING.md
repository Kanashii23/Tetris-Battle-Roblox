# Cosmetic equip fix and Studio verification

## Confirmed cause

`ServerMain.luau` referenced `Catalog` in Buy/Equip without requiring `Shared.Catalog`. In Roblox this passed nil into `Progression.equip`, which indexed `catalog.Slots`. `PlayerDataService:mutate` caught the exception and replaced it with `Data operation failed`. The Profile and Message events carried the unchanged state and generic error to the client.

The isolated remote regression reproduced this exact message before the fix. Earlier ServerHarness tests inherited an enclosing `Catalog` variable and never exercised a successful equip remote. The harness now blocks that accidental dependency and requires ServerMain to import its own Catalog.

This was a server dependency bug, not a ProfileStore library or ownership-key mismatch. Existing canonical categories are `BrickSkins`, `DropEffects`, `GhostEffects`, `SoundPacks`; slots are `BrickSkin`, `DropEffect`, `GhostEffect`, `SoundPack`. Every category's default is the ID `Default`, consistently configured and owned through reconciliation/validation. Hard-drop effects use the category `DropEffects`.

## Changed files

- `src/server/ServerMain.luau`: missing Catalog import; bounded request validation; Studio diagnostics; structured CosmeticResult alongside the existing Profile, Message and Action events.
- `src/shared/Progression.luau`: equip validation returns safe player messages and internal rejection codes. Equipping still never deducts Cash.
- `src/server/PlayerDataService.luau` and `LegacyPlayerDataService.luau`: mutation exceptions retain their server traceback in Studio Output and return InternalError without exposing the trace to players.
- `src/server/GameConfig.luau`: temporary `CosmeticDebugLogging=true`, effective only in Studio. Turn this off after verification. All persistence/economy switches retain their previous values.
- `src/client/GameClient.luau`: consumes CosmeticResult for inspection/optional hooks. Only the server Profile event changes equipped state; existing board and audio rendering consume that profile.
- `tests/build-harnesses.js`, `fixtures/equip-checks.luau`, `profile-network-setup.luau`, `profile-mocks.luau`, `ui-checks.luau`, and generated Server/UI/ProfileStore harnesses: remote equip regression coverage and service doubles.

PortalUI, UI appearance, scroll-preserving cards, prices, input/gameplay, SoundConfig IDs, Rojo configuration and the supplied ProfileStore library are unchanged. No DataStore names, keys, schema, migration or production switches changed; no cloud records were accessed by automated checks. No commit/push was made.

## Studio steps

1. Let Rojo sync, stop Play, clear Output and restart Play. Find `[PlayerData] ProfileStore / ...` to identify the backend. Default configuration uses Studio mock sessions, which do not persist across stopping Play. This is the existing development configuration, not a fabricated success response.
2. Open Shop, scroll down, equip an owned brick skin, then switch categories and equip a hard-drop effect, ghost and sound pack. Cash must remain unchanged. The existing card should update without the list jumping or collecting duplicate button handlers. An equipped nondefault card says UNEQUIP; its ownership label says EQUIPPED.
3. Return each category to Default using UNEQUIP. Default remains owned and becomes equipped. A default card that is already equipped disables its equip button, intentionally.
4. Repeat selection several times; Preview/Buy/Equip should preserve current category/scroll. Purchase an item when using the real persistence backend; verify equipping it does not charge a second time.
5. In Solo Practice check the board/ghost, trigger a hard drop and confirm the selected effect. Sound-pack playback requires valid existing audio IDs in SoundConfig. Profile changes already update the audio pack and next gameplay snapshot; no cosmetic-only fake board data is generated.
6. In Output expect a request line showing `loaded=true active=true configured=true owned=true` (or `debugFree=true` for existing Studio privileges), the canonical slot and `fieldExists=true`, followed by `success=true code=OK`. On rejection, the code/reason appears only in Output; callback exceptions include a server traceback. No full profile is logged.
7. For real persistence, use a separate published test experience, enable Studio API Services, set `ProfileStoreStudioPersistence=true`, keep `ProfileStoreLiveEnabled=false`, restart Play, and check `isolated persistence test`. Buy/equip one item in each category, record Cash, stop/rejoin and verify ownership and all four slots. Do not infer persistence from the mock backend.
8. Test strict rejection in that persistence mode, which disables existing free Studio cosmetic privileges. From Studio's client command bar, request an unowned item with the existing remote, e.g. `game.ReplicatedStorage.Shared.Network:FireServer("Equip", {Category="BrickSkins", Id="Holographic"})` if Holographic is unowned. Expect `You don't own this cosmetic yet.`; Cash/slot must remain unchanged. An invented ID must return `This cosmetic is unavailable.`
9. If a profile cannot load, no equip/purchase should succeed. Disabled API access in actual persistence mode must fail loading rather than silently opening a mock profile. If the error remains, paste the `[Cosmetic] request`, rejection/result lines and any `[PlayerData] Mutation exception` traceback. Do not paste full profiles.

## What was tested

104 automated PASS groups, 44 compiled Luau files and a successful Rojo build. The exact ProfileStore implementation's hash remains unchanged. Remote tests execute actual ServerMain, Progression and data services using simulated Roblox services, covering the legacy backend, Studio ProfileStore.Mock and the actual-store code path (including Studio persistence configuration). Tested defaults and owned cosmetics in all four categories, repeated switching, purchase/equip/rejoin, unchanged Cash, unowned/invalid requests, loading rejection and safe exception diagnostics. UI checks cover server-authoritative state, retained scrolling/card identity and one callback after repeated refreshes. Existing engine/input/economy/persistence regressions pass.

Native Roblox Studio appearance, real client/server transport, live API permissions/cloud persistence, physical devices, audio playback and real cross-server behavior were not tested here. Follow the steps above and the existing PROFILESTORE-INTEGRATION.md guide for those checks.
