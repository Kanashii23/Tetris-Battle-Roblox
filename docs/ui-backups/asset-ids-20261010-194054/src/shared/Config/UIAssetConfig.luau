-- UI images only. This module does not define or change gameplay or rank progression.
-- Upload PNGs to Roblox, then paste each numeric asset ID as a string.
-- Empty strings intentionally mean that the image has not been uploaded yet.
local Config = {}
Config.Images = {
    menu = {
        shop = "100977894197765",
        inventory = "125529379943006",
        quests = "97443859193714",
        leaderboards = "96347343459414",
        friends = "117959950512208",
        login_rewards = "104998355930939",
        more = "117387578183988",
        help = "131145039642523",
        redeem_code = "81707707995999",
        profile = "72058769042022",
        mail = "80827806485554",
        audio = "137022571368234",
        settings = "102562816593669",
        emoji = "99456822338894",
        chat = "118489637148257",
    },
    shop = {
        cash_small = "99988868578719",
        cash_large = "121505045560360",
        energy_small = "83049676864316",
        cash_medium = "131351262503849",
        energy_large = "121523316700698",
        energy_medium = "92985306200523",
    },
    currency = {
        cash = "127416396462489",
        energy = "77327347842836",
    },
    quests = {
        ranked_wins = "78473288720431",
        t_spins = "134479500409994",
        send_lines = "83443835269848",
        practice = "99317077635472",
        play_time = "76889533053404",
    },
    battle = {
        attack_arrow = "85556927563756",
        ko = "130251791936611",
        garbage_projectile = "103816532666035",
        countdown_3 = "91549369271612",
        countdown_2 = "79196971821199",
        combo = "107454481376423",
        go = "86584339888658",
        countdown_1 = "86490886295077",
        star_filled = "79671500335951",
        star_empty = "87756130212291",
    },
    cosmetics = {
        brick_default = "126624386457108",
        brick_neon_club = "89389425396664",
        brick_cyber_core = "78997769796344",
        brick_gold_elite = "72028217958101",
        brick_ocean_wave = "95875408262021",
        drop_neon_comet = "116951832287036",
        drop_plasma = "82680889235551",
        brick_demon_wave = "93095194250937",
        drop_solar = "116739232607014",
        ghost_hologram = "101686550390509",
        ghost_spectral = "86401399494518",
        sound_pack = "83525147853569",
        ghost_gold = "94845972661172",
    },
}

Config.OptionalReferenceRanks = {
    Enabled = false,
    Images = {
        rookie = "106820511151180",
        amateur = "98163712415815",
        expert = "91903781725894",
        master = "85321971335614",
        pro = "91659302320875",
        immortal = "93022638597067",
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
