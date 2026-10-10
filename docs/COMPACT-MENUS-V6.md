# Compact menus and shared backdrop v6

Startup marker: `2026-10-11-compact-menus-v6`.

## Implemented

Quests, Leaderboards, More, Friends, Profile, Login Rewards, Energy, Help, Audio Settings and Redeem Code now have centered foreground windows with destination-specific maximum widths (520–960 design pixels), 16px safe margins and heights based on measured content. Longer lists scroll inside the window while header/Back/tabs stay accessible. Narrow windows stack the header instead of shrinking text. Fullscreen overlay is an input guard with a translucent dim layer, revealing the single existing sunset/city/grid backdrop.

Daily/Weekly tabs form one centered equal-width group above the quest list. Active state remains cyan through hover exit. Reset countdown has separate header bounds. Existing authoritative progress/claim/reset behavior remains intact.

The shared contentCard helper uses the existing quest card's shaded surface, gradient, top rail, restrained edge, short cast shadow, halo and corners. Generic information/player/reward/audio cards use that helper; More's clickable tiles retain the same shared depth layers. Cards fit measured real text. Music Volume/SFX Volume and leaderboard tab captions are readable display labels, while server keys are unchanged. Player avatars have reserved text space.

Energy retains its real capacity/refill state, cyan segments, three illustrated pack cards and truthful unavailable state. Redeem remains honestly unavailable. Existing hover states, navigation stack, focus/input guarding and preview controls remain covered.

## Supplied video inspection and motion approximation

The attached `2026-10-11 00-16-38.mp4` was decoded using the already-installed FFmpeg. It is 1920x1080, 60 fps and 9.033 seconds. Nine full-frame samples and an eighteen-frame sun-region contact sheet were inspected across the clip. The scene is a Steam profile with a neon roadside/cyan surface background. The sun disc, its horizontal cutouts and the distant skyline remain fixed. Roadside foreground elements pass leftward; cyan surface streaks change. Cursor movement, notification/tooltips and window-switch overlays are recording/UI changes and were not treated as background motion.

The existing Roblox scene has a perspective neon floor rather than the video's road/water/car scene. The least disruptive adaptation retains the original sun/stripe/city/horizon/grid geometry and adds 24 small clipped horizontal surface streaks moving left. It does not bob/rotate the sun, scroll its stripes, recolor/pulse the scene or translate the whole backdrop. Roadside poles/car were not introduced. This is a procedural surface-flow approximation, not an exact reconstruction of the video.

One Art controller runs from the existing RenderStepped callback; no controller/listener is created when a menu opens. Elapsed-time normalized motion has a 0.12 viewport-width/second starting speed and a constructed 10.83-second offscreen wrap cycle. The nine-second reference does not establish that exact repeating period; precise pace and appearance remain subject to Studio comparison. Wrap endpoints are outside the clipped floor. Resize preserves elapsed phase; navigation never resets it. Reduced Motion and fully covered/hidden backdrops freeze it. Gameplay scenery is not newly animated unless a compact menu is opened. Teardown uses the existing callback disconnection and destroys its bounded layers.

## Preserved scope

No engine/server/rules/progression/persistence/catalog/cosmetic configuration or renderer changes. All entered asset IDs and the 12-theme/420-slot named format remain untouched. DefaultClassic textures and confirmed three-component FX remain unchanged. Solo/Ranked gameplay screens are not rebuilt. Roblox controls/third-party overlays are untouched. No commit, push, merge or publication.

## Validation

All 46 Luau source files compile; Rojo build succeeds. Current-source UI, server, input and ProfileStore harnesses pass; all 19 engine tests pass. Added checks cover all ten menu windows at 390x780, 844x326, 768x1024 and 1366x768, centered tabs and switching, shared card depth, short-screen height, long text, 100-player scrolling, clear audio labels, fixed sunset layers, leftward surface flow, more than two seamless cycles, low frame rate, navigation/resize phase continuity, hidden/Reduced Motion freezing and teardown. Existing hover/transactions/cosmetic/preview/gameplay tests still pass.

The supplied screenshots provide the pre-change appearance. Actual post-change Studio captures/recording were unavailable during implementation. Automated mock-instance tests and builds do not prove visual matching. Verify all menu screens in Studio and compare at least two background cycles against the video, especially surface pace, clipping, foreground stillness, phone/tablet sizing and Reduced Motion. No pixel-perfect or actual runtime visual match is claimed.
