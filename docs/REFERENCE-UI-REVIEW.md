# Reference UI revision

This revision uses the supplied existing asset IDs without inventing or replacing IDs. Menu/body text uses Roblox Gotham for readability; display headings retain Press Start 2P. UI images explicitly use white tint and zero transparency and are preloaded asynchronously, with deduplicated per-ID failure messages prefixed [Tetris UI image] in Studio Output. No gradients are attached to buttons, preventing their text and images from being tinted by a button gradient. Mail/settings show text until their images load.

The reference More menu contains Profile, Leaderboards, Login Rewards, Friends, Energy, Help / Info, Audio Settings, Redeem Code. Assets is excluded and cannot be opened as a player page. Inventory artwork is larger while actual miniature/live engine previews remain. The native backdrop has taller illuminated buildings, stronger perspective lines and a yellow-to-pink sunset.

Gameplay/effect modules, authoritative state, server code, saved data, audio, asset IDs and responsive layout calculations remain byte-for-byte unchanged. Reference cash/energy prices and rank progression are illustrative: the existing backend controls them. No payment flow or ranks are fabricated.

Validation: all Luau source files compile; the complete UI harness passes existing gameplay effects, countdown/results, preview isolation/controls, pending server actions and nine viewport checks. Additional checks exercise actual configured IDs, image tint/transparency, readable button colors and eight More destinations. Missing-image suites use a deliberately empty configuration copy; the actual project config is preserved. Rojo build passes.

The harness uses mocked Roblox services and does not prove actual image delivery or pixel-perfect rendering. After synchronization, restart Play and inspect the UI plus Studio Output. Failed assets produce [Tetris UI image] messages with the content ID/status. Those messages are needed to distinguish permission/moderation problems from layout problems. The procedural backdrop is an approximation; the reference pack has no uploaded skyline background ID.
