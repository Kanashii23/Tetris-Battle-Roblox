# Neon UI rebuild v5

Startup marker: `2026-10-10-neon-rebuild-v5`. Changes are applied to the existing Rojo project. No commit, push, merge or publication.

## Visible changes

- Shared buttons/panels: offset dark silhouette, thin bright edge, top highlight and three progressively fading halo layers. Gradient is on a separate surface, with untinted icon/text layers and no padding-shifted decorative boxes.
- Solo, Ranked, Cash and Energy: shuffled neon hover bag, no consecutive repeated accent, coordinated outline/halo tweens, exact rest restoration. Cancelled transitions, focus/touch states, disabled-state reset, ancestor-hide reset, teardown of external listeners. No per-button render loop or hover sound spam.
- Lobby: smaller striped warm sun, taller skyline and magenta haze, compact play/navigation composition, larger centered navigation artwork/captions and real Energy current/capacity.
- More: bounded centered cabinet, Back and existing eight destinations. Assets remains inaccessible.
- Shop and Inventory: full usable product width, responsive 1–4 column grid and category rail. Compact balance strip has separate icon/text bounds. Live 10x20 preview is a selected-item modal at every size, with all six controls and authoritative purchase/equip actions preserved. Hidden preview is destroyed.
- Cash/Energy: illustrated responsive pack cards remain UNAVAILABLE because verified paid backend is not configured. Existing real quantities/capacity/refill timing are used; no invented prices or values.
- Quests: shorter desktop rows, reward icon/value, cyan inset progress, muted incomplete state and gold claimable treatment. Reset time sits in header bounds and updates once per second from authoritative window timestamps. Long phone text can grow safely.
- Solo/Ranked: board cabinets are siblings behind the clipped logical grids, with pink/cyan outer edge, cast shadow, fading glow and inset rail. NEXT spacing is bounded, HOLD/NEXT headings stronger, live gold clock has a timer plate. Ranked retains actual two-player boards; Solo adds no opponent.

## Assets and preserved behavior

CosmeticsAssetIds now contains exactly 12 root theme tables with 35 explicit named strings each. Default maps to canonical DefaultClassic. All 420 slots were empty in the live source before migration. Existing menu/currency/shop/quest/battle cosmetic-marketing image IDs are unchanged. Metadata/readiness and the checked shared resolver are separate. Upload guide and all 35 normalized config fields use the exact new naming convention.

The engine, server, persistence, rules, progression and catalog data are unchanged. DefaultClassic animation/rendering code and all supplied PNG bytes are unchanged; only its metadata dependency moved. Confirmed landing origin, six droplets, vertical WhiteBase, horizontal Ripple, event deduplication, pools, Reduced Motion and fallback remain covered.

## Verification

All 46 Luau source files compile. Current-source UI, server, input and ProfileStore harnesses pass. Engine suite passes 19 tests. The 35 supplied PNG dimensions, hashes and transparent RGBA checks pass. Rojo build succeeds.

UI harness coverage includes 420 slots, all seven uploaded-image mock paths, failed delivery, FX origin before clear, duplicate suppression, bounded cleanup, ownership/transaction authority, preview actions/isolation, modal Back/focus, device bounds, rapid repeated hover entry/exit while pressed, shuffled accents, hidden/disabled controls, touch/gamepad, Reduced Motion, separate gradients, compact quest zones and demand-only product previews at 390x780, 844x326, 768x1024, 1024x768 and 1366x768.

## Actual Studio visual verification pending

The supplied current screenshots and both target reference images guided this rebuild. Automated mock-instance tests and a Rojo build do not render Roblox UI. Actual Studio before/after captures and two-client Ranked play were unavailable in this session; no pixel-perfect or runtime screenshot comparison is claimed. Verify actual lobby, hover/rest states, More, Shop, Inventory, Quests, Solo and real Ranked after Rojo sync.

Shadow/glow, skyline, sun and timer plate are procedural GUI approximations. No background/cabinet texture IDs were supplied, and the 35 DefaultClassic gameplay IDs await the user's uploads. Press Start 2P retains the supported fallback; dense descriptions/actions use readable Gotham. The supplied WhiteBase is a rounded flash rather than spiky art; square padding is preserved and it is rotated vertically.
