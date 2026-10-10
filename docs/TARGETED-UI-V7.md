# Targeted UI v7

Startup marker: `2026-10-11-targeted-ui-v7`.

Main-menu TitleShadow now uses exactly RGB(255,0,255). Its text, alpha, offset and ordering and the foreground title are preserved. No theme/update path overwrites this color.

Leaderboard defects confirmed in code: tab clicks sent twice (explicit send followed by render's send); every response was accepted regardless of category/request age; responses reconstructed the controls. The existing command bucket and busy guard can drop duplicate/rapid requests. Tabs now retain their instances, selection/focus and Back while only entries refresh. Four canonical keys remain unchanged, with readable labels. One request identity is echoed by the server and filtered by the client, including A->B->A races. Repeat clicks while the same request is pending are suppressed. Busy, unavailable, empty and 12-second timeout states remain navigable and expose retry. The cabinet has a consistent bounded body height while results scroll. Legacy string server requests remain supported. LeaderboardService, OrderedDataStore names, ranking calculations and Studio standings behavior are untouched.

All 64 named SunBand0..63 Frames exist and have ZIndex 2. Gap bands are transparent rather than omitted. The native background is at 1, sun parent at 2, city/buildings at 3; backdrop explicitly uses Sibling ordering and stays below the foreground ScreenGui. Bands and motion decorations are noninteractive. Resize only changes geometry/color, preserving ZIndex.

Both supplied videos were decoded and sampled. Current recording shows the compact Roblox scene; target shows a synthwave roadside scene in a Steam profile. The target sun silhouette/horizontal cutouts remain stationary, with passing leftward foreground supports and changing cyan surface streaks. v7 brightens existing clipped surface streaks and adds five bounded leftward passing supports using the same time-based controller and phase. Sun, skyline, perspective grid and foreground menus stay fixed. Offscreen wrap, resize/navigation phase, Reduced Motion/hidden freeze and cleanup are preserved. This adapts observed motion to the existing floor composition; it does not reproduce the target's car/road/water artwork or prove an exact matching pace.

Validation: all 46 source files compile; Rojo build succeeds; UI/server/input/ProfileStore harnesses and 19 engine tests pass. Focused checks cover each canonical tab, request identity, repeat/rapid ABA switching, busy/error/timeout recovery, retained controls/window bounds, reopening, exact magenta, and 64 noninteractive ZIndex-2 bands across three viewports. Existing tests cover touch/gamepad input/hover and two motion cycles. These are mock-instance tests, not actual Studio visual evidence.

Studio Play verification remains pending: click all tabs using mouse/touch/gamepad; verify actual matching standings, Back/reopen, magenta shadow and sun layering; record two motion cycles and compare pace/appearance with the target, including portrait, short landscape, Reduced Motion, and More/Energy/Leaderboards navigation. No after-change Studio capture or exact visual-match claim is made.

Gameplay, data, asset IDs, cosmetics modules and preview renderers are preserved. Changes are backed up before copying. No commit, push, merge or publication.
