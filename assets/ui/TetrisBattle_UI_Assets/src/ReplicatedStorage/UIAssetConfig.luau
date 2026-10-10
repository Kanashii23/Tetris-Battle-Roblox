-- UI images only. This module does not define or change gameplay or rank progression.
-- Upload PNGs to Roblox, then paste each numeric asset ID as a string.
-- Empty strings intentionally mean that the image has not been uploaded yet.
local Config = {}
Config.Images = {
    menu = {
        shop = "",
        inventory = "",
        quests = "",
        leaderboards = "",
        friends = "",
        login_rewards = "",
        more = "",
        help = "",
        redeem_code = "",
        profile = "",
        mail = "",
        audio = "",
        settings = "",
        emoji = "",
        chat = "",
    },
    shop = {
        cash_small = "",
        cash_large = "",
        energy_small = "",
        cash_medium = "",
        energy_large = "",
        energy_medium = "",
    },
    currency = {
        cash = "",
        energy = "",
    },
    quests = {
        ranked_wins = "",
        t_spins = "",
        send_lines = "",
        practice = "",
        play_time = "",
    },
    battle = {
        attack_arrow = "",
        ko = "",
        garbage_projectile = "",
        countdown_3 = "",
        countdown_2 = "",
        combo = "",
        go = "",
        countdown_1 = "",
        star_filled = "",
        star_empty = "",
    },
    cosmetics = {
        brick_default = "",
        brick_neon_club = "",
        brick_cyber_core = "",
        brick_gold_elite = "",
        brick_ocean_wave = "",
        drop_neon_comet = "",
        drop_plasma = "",
        brick_demon_wave = "",
        drop_solar = "",
        ghost_hologram = "",
        ghost_spectral = "",
        sound_pack = "",
        ghost_gold = "",
    },
}

Config.OptionalReferenceRanks = {
    Enabled = false,
    Images = {
        rookie = "",
        amateur = "",
        expert = "",
        master = "",
        pro = "",
        immortal = "",
    },
}

function Config.ImageUri(assetId: string): string
    if assetId == "" then return "" end
    if string.match(assetId, "^%d+$") then return "rbxassetid://" .. assetId end
    if string.match(assetId, "^rbxassetid://%d+$") then return assetId end
    error("Expected a numeric Roblox image asset ID")
end

return Config
