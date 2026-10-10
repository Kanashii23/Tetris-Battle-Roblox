-- UI images only. This module does not define or change gameplay or rank progression.
-- Upload PNGs to Roblox, then paste each numeric asset ID as a string.
-- Empty strings intentionally mean that the image has not been uploaded yet.
local Config = {}
Config.Images = {
    menu = {
        shop = "94361316332676",
        inventory = "123753104644903",
        quests = "128502063060177",
        leaderboards = "115073353171908",
        friends = "137519695549604",
        login_rewards = "125109999218173",
        more = "138299792303867",
        help = "115312356601455",
        redeem_code = "114648844041582",
        profile = "129706316970463",
        mail = "127101827740432",
        audio = "126371828796385",
        settings = "98351939637217",
        emoji = "120925967109343",
        chat = "84018472809981",
    },
    shop = {
        cash_small = "72723524730871",
        cash_large = "120611092225895",
        energy_small = "125752821084293",
        cash_medium = "138587302528799",
        energy_large = "113468277542980",
        energy_medium = "101965825679363",
    },
    currency = {
        cash = "82735643243365",
        energy = "114837522786255",
    },
    quests = {
        ranked_wins = "75594822928945",
        t_spins = "128301206627586",
        send_lines = "133886755760634",
        practice = "138774400411053",
        play_time = "89653442613769",
    },
    battle = {
        attack_arrow = "88704230548226",
        ko = "102742382889812",
        garbage_projectile = "101569083739853",
        countdown_3 = "103377808301922",
        countdown_2 = "85863778056295",
        combo = "129035048860615",
        go = "134953757387806",
        countdown_1 = "80953988857699",
        star_filled = "106261336470546",
        star_empty = "124302015213414",
    },
    cosmetics = {
        brick_default = "93574909915435",
        brick_neon_club = "115119379954676",
        brick_cyber_core = "127473501785104",
        brick_gold_elite = "138020524311881",
        brick_ocean_wave = "114708752349254",
        drop_neon_comet = "73519339454279",
        drop_plasma = "72757477162533",
        brick_demon_wave = "81382009604412",
        drop_solar = "110032080596026",
        ghost_hologram = "92530685195609",
        ghost_spectral = "116452999066257",
        sound_pack = "133954722628357",
        ghost_gold = "113596057422617",
    },
}

Config.OptionalReferenceRanks = {
    Enabled = true,
    Images = {
        rookie = "99619762052996",
        amateur = "73216878404801",
        expert = "88982625989642",
        master = "93070497943983",
        pro = "131295782237157",
        immortal = "117806290369674",
    },
}

Config.Images.artwork = {preview="", background="", board_frame_pink="", board_frame_cyan="", perfect_clear=""}
Config.CosmeticArtwork = {BrickSkins={Default="brick_default",NeonClub="brick_neon_club",CyberCore="brick_cyber_core",OceanWave="brick_ocean_wave",GoldElite="brick_gold_elite"},DropEffects={NeonSparks="drop_neon_comet",LightningStrike="drop_plasma",FireBurst="drop_solar"},GhostEffects={Hologram="ghost_hologram",Prism="ghost_spectral",GoldenTrace="ghost_gold"}}
-- Explicit optional display mappings; these never alter actual rank labels or progression.
Config.OptionalReferenceRanks.Mapping = {Rookie="rookie",Master="master"}

function Config.ImageUri(assetId: string): string
    if type(assetId)~="string" then return "" end
    if assetId == "" then return "" end
    if string.match(assetId, "^%d+$") then return "rbxassetid://" .. assetId end
    if string.match(assetId, "^rbxassetid://%d+$") then return assetId end
    return "" -- Invalid/unuploaded IDs fall back safely.
end

return Config
