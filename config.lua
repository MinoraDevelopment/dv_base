Config = {}

-- ===================================================================
-- GENERAL SETTINGS
-- ===================================================================
Config.Debug              = false
Config.Locale             = 'de'

Config.DbTable            = 'dv_base_structures' -- table name for storing structure metadata

-- Placement / raycast tuning
Config.Placement = {
    maxPlaceDistance    = 15.0,   -- max distance player can place from
    rayDistance         = 50.0,   -- length of the top-down raycast
    rayStartHeight      = 25.0,   -- how far above the ped the ray starts
    previewAlpha        = 170,
    rotationStep        = 5.0,    -- degrees per tick when rotating with arrow keys
    mouseRotationStep   = 2.0,    -- degrees per mouse wheel tick
    heightStep          = 0.02,   -- meters per tick when adjusting height manually
    maxHeightOffset     = 2.0,    -- clamp for manual Z offset
    gridSnapSize        = 1.0,    -- meters
    gridSnapAngle        = 45.0,   -- degrees, hold [G] to enable
    invalidPlacementSlope = 35.0, -- max ground slope (degrees) considered valid
}

Config.Controls = {
    confirm        = 0x7F86AF1D, -- INPUT_ATTACK (LMB)
    cancel         = 0xA0F502E4, -- INPUT_FRONTEND_CANCEL (RMB)
    rotateLeft     = 0xA65EBAB4, -- INPUT_FRONTEND_LB
    rotateRight    = 0xDEB34313, -- INPUT_FRONTEND_RB
    heightUp       = 0x7D30E016, -- INPUT_FRONTEND_UP
    heightDown     = 0xD9D0E1C0, -- INPUT_FRONTEND_DOWN
    toggleSnap     = 0x760A9C6F, -- INPUT_FRONTEND_Y (G default key bound in ox_lib fallback, remapped below)
}
-- NOTE: raw hashes above are illustrative; client/main.lua binds the actual
-- keys via GetControlInstantButtonPressed / IsDisabledControlJustPressed
-- using the readable control IDs (24, 25, 174, 175, 187, 188, 47) for
-- maximum compatibility across keyboard layouts.

-- ===================================================================
-- STRUCTURE DEFINITIONS
-- ===================================================================
-- key            = ox_inventory item name that triggers placement (exports.dv_tentsystem:startPlacing('key'))
-- label          = display name
-- category       = 'camp' | 'fence' | 'defense' | 'utility'
-- model          = prop model string (converted via joaat at runtime)
-- zOffset        = base pivot correction applied on top of ground height
-- durability     = max HP
-- buildTime      = ms for the build progressbar
-- materials      = { itemName = amount } consumed from the player's inventory
-- hasStash       = whether this structure registers an ox_inventory stash
-- stash          = { slots = n, weight = n }
-- subProps       = array of decorative / functional child props, each with a
--                   relative offset {x, y, z, h} to the main structure and
--                   an optional own zOffset correction
-- repair         = { item = 'itemname', amount = n, healPercent = n } -- % of max hp restored per repair action

Config.Structures = {

    -- ============================ CAMP / LAGER ============================
    ['tent_camp'] = {
        label       = 'Camping-Zelt',
        category    = 'camp',
        model       = 'prop_tent_01a',
        zOffset     = 0.0,
        durability  = 250,
        buildTime   = 8000,
        materials   = {
            { item = 'wood',  amount = 15 },
            { item = 'rope',  amount = 4  },
            { item = 'cloth', amount = 6  },
        },
        hasStash    = true,
        stash       = { slots = 40, weight = 80000 },
        repair      = { item = 'repairkit', amount = 1, healPercent = 35 },
        subProps    = {
            {
                model   = 'prop_camp_fire',
                label   = 'Lagerfeuer',
                offset  = { x = 1.6, y = 0.0, z = 0.0, h = 0.0 },
                zOffset = 0.0,
            },
            {
                model   = 'prop_box_wood04a',
                label   = 'Vorratskiste',
                offset  = { x = -1.4, y = 0.8, z = 0.0, h = 90.0 },
                zOffset = 0.0,
            },
            {
                model   = 'p_sleepingbag_01_s',
                label   = 'Schlafsack',
                offset  = { x = -0.6, y = -1.3, z = 0.0, h = 20.0 },
                zOffset = 0.0,
            },
        },
    },

    ['large_tent'] = {
        label       = 'Großes Basis-Zelt',
        category    = 'camp',
        model       = 'prop_tent_01b',
        zOffset     = 0.0,
        durability  = 450,
        buildTime   = 15000,
        materials   = {
            { item = 'wood',  amount = 35 },
            { item = 'rope',  amount = 10 },
            { item = 'cloth', amount = 16 },
            { item = 'metalscrap', amount = 8 },
        },
        hasStash    = true,
        stash       = { slots = 80, weight = 160000 },
        repair      = { item = 'repairkit', amount = 1, healPercent = 25 },
        subProps    = {
            {
                model   = 'prop_gascanister_01a',
                label   = 'Generator-Tank',
                offset  = { x = 2.0, y = -1.0, z = 0.0, h = 0.0 },
                zOffset = 0.0,
            },
        },
    },

    -- ========================= ABSPERRUNGEN / ZÄUNE =========================
    ['wooden_fence'] = {
        label       = 'Holzzaun',
        category    = 'fence',
        model       = 'prop_fnclink_02a',
        zOffset     = -0.05,
        durability  = 120,
        buildTime   = 4000,
        materials   = {
            { item = 'wood', amount = 8 },
        },
        hasStash    = false,
        repair      = { item = 'wood', amount = 4, healPercent = 40 },
        subProps    = {},
    },

    ['construction_barrier'] = {
        label       = 'Baustellen-Barrikade',
        category    = 'fence',
        model       = 'prop_barrier_work05',
        zOffset     = 0.0,
        durability  = 90,
        buildTime   = 2500,
        materials   = {
            { item = 'metalscrap', amount = 5 },
        },
        hasStash    = false,
        repair      = { item = 'metalscrap', amount = 3, healPercent = 50 },
        subProps    = {},
    },

    -- ============================ VERTEIDIGUNG ============================
    ['sandbag_wall'] = {
        label       = 'Sandsack-Wand',
        category    = 'defense',
        model       = 'prop_sandbag_01a',
        zOffset     = 0.0,
        durability  = 200,
        buildTime   = 5000,
        materials   = {
            { item = 'sand', amount = 10 },
            { item = 'cloth', amount = 6 },
        },
        hasStash    = false,
        repair      = { item = 'sand', amount = 5, healPercent = 30 },
        subProps    = {},
    },

    ['watchtower'] = {
        label       = 'Wachturm',
        category    = 'defense',
        model       = 'prop_scaffold_lift',
        zOffset     = 0.0,
        durability  = 600,
        buildTime   = 20000,
        materials   = {
            { item = 'wood',  amount = 60 },
            { item = 'metalscrap', amount = 25 },
            { item = 'iron', amount = 15 },
        },
        hasStash    = false,
        repair      = { item = 'repairkit', amount = 2, healPercent = 20 },
        subProps    = {},
    },

    ['metal_barricade'] = {
        label       = 'Stahl-Barrikade',
        category    = 'defense',
        model       = 'prop_mp_barrier_02a',
        zOffset     = 0.0,
        durability  = 300,
        buildTime   = 7000,
        materials   = {
            { item = 'metalscrap', amount = 20 },
            { item = 'iron', amount = 5 },
        },
        hasStash    = false,
        repair      = { item = 'metalscrap', amount = 8, healPercent = 30 },
        subProps    = {},
    },

    -- ========================== WERKBÄNKE / UTILITY ==========================
    ['crafting_bench'] = {
        label       = 'Werkbank',
        category    = 'utility',
        model       = 'prop_tool_bench02',
        zOffset     = 0.0,
        durability  = 180,
        buildTime   = 6000,
        materials   = {
            { item = 'wood', amount = 20 },
            { item = 'metalscrap', amount = 10 },
        },
        hasStash    = false,
        isCraftingBench = true,
        repair      = { item = 'wood', amount = 6, healPercent = 40 },
        subProps    = {},
    },

    ['generator'] = {
        label       = 'Generator',
        category    = 'utility',
        model       = 'prop_generator_01a',
        zOffset     = 0.0,
        durability  = 150,
        buildTime   = 9000,
        materials   = {
            { item = 'metalscrap', amount = 15 },
            { item = 'iron', amount = 10 },
            { item = 'electronickit', amount = 3 },
        },
        hasStash    = false,
        isPowerSource = true,
        repair      = { item = 'electronickit', amount = 1, healPercent = 25 },
        subProps    = {},
    },
}

-- ===================================================================
-- STREAMING / CULLING
-- ===================================================================
Config.Streaming = {
    renderDistance      = 120.0,  -- meters: props are spawned within this radius
    unloadDistance       = 150.0,  -- meters: props are despawned beyond this radius (hysteresis buffer)
    checkInterval        = 3000,   -- ms between distance checks
    requestInterval       = 15000,  -- ms between client -> server metadata refresh requests
}

-- ===================================================================
-- DAMAGE / HEALTH
-- ===================================================================
Config.Damage = {
    pollInterval        = 750,    -- ms between local health polls per spawned structure
    minDeltaToSync       = 1,      -- minimum HP delta before we bother the server
    destroyEffect        = 'exp_grd_grenade_smoke',
    allowVehicleDamage    = true,
    allowWeaponDamage     = true,
}

-- ===================================================================
-- PERMISSIONS
-- ===================================================================
Config.Permissions = {
    maxAllowedPerStructure = 10,
}

return Config