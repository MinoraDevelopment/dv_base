Config.Structures = {

    -- ============================ CAMP / LAGER ============================
    ['tent_camp'] = {
        label = 'Camping-Zelt', category = 'camp', model = 'm23_2_prop_m32_tent_01a',
        zOffset = 0.0, durability = 250, buildTime = 8000, snapLength = nil,
        materials = { { item = 'wood', amount = 15 }, { item = 'rope', amount = 4 }, { item = 'cloth', amount = 6 } },
        hasStash = true, stash = { slots = 40, weight = 80000 }, isGate = false, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'repairkit', amount = 1, healPercent = 35 },
        subProps = {
            { model = 'prop_box_wood05a', label = 'Vorratskiste', offset = { x = 0.0, y = 1.5, z = 0.0, h = 90.0 }, zOffset = 0.0 },
            { model = 'p_amb_bedroll_01_s', label = 'Schlafsack', offset = { x = -0.6, y = -1.3, z = 0.0, h = 20.0 }, zOffset = 0.0 },
        },
    },

    ['campfire'] = {
        label = 'Lagerfeuer', category = 'camp', model = 'prop_beach_fire',
        zOffset = -0.5, durability = 100, buildTime = 3000, snapLength = nil,
        materials = { { item = 'wood', amount = 5 } },
        hasStash = false, isGate = false, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'wood', amount = 2, healPercent = 50 }, subProps = {},
    },

    ['large_tent'] = {
        label = 'Großes Basis-Zelt', category = 'camp', model = 'prop_tent_03',
        zOffset = 0.0, durability = 450, buildTime = 15000, snapLength = nil,
        materials = { { item = 'wood', amount = 35 }, { item = 'rope', amount = 10 }, { item = 'cloth', amount = 16 }, { item = 'metalscrap', amount = 8 } },
        hasStash = true, stash = { slots = 80, weight = 160000 }, isGate = false, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'repairkit', amount = 1, healPercent = 25 },
        subProps = { { model = 'prop_gascanister_01a', label = 'Generator-Tank', offset = { x = 2.0, y = -1.0, z = 0.0, h = 0.0 }, zOffset = 0.0 } },
    },

    -- ========================= ZÄUNE & WÄNDE (MIT SNAPPING) =========================
    ['wooden_fence'] = {
        label = 'Holzzaun', category = 'fence', model = 'prop_fncwood_16a',
        zOffset = -0.05, durability = 120, buildTime = 4000, snapLength = 2.0, -- snapLength definiert die Länge für das Anhaften
        materials = { { item = 'wood', amount = 8 } },
        hasStash = false, isGate = false, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'wood', amount = 4, healPercent = 40 }, subProps = {},
    },

    ['wood_wall_high'] = {
        label = 'Hohe Holz-Wand', category = 'fence', model = 'prop_fncwood_16c',
        zOffset = 0.0, durability = 200, buildTime = 6000, snapLength = 2.5,
        materials = { { item = 'wood', amount = 15 } },
        hasStash = false, isGate = false, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'wood', amount = 5, healPercent = 40 }, subProps = {},
    },

    ['chainlink_fence'] = {
        label = 'Maschendrahtzaun', category = 'fence', model = 'prop_fnclink_01a',
        zOffset = 0.0, durability = 150, buildTime = 5000, snapLength = 3.0,
        materials = { { item = 'metalscrap', amount = 10 } },
        hasStash = false, isGate = false, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'metalscrap', amount = 4, healPercent = 40 }, subProps = {},
    },

    ['concrete_wall'] = {
        label = 'Betonwand', category = 'fence', model = 'prop_fence_02a',
        zOffset = 0.0, durability = 500, buildTime = 10000, snapLength = 2.5,
        materials = { { item = 'stone', amount = 20 } }, -- 'stone' muss evtl in ox_inventory angelegt werden
        hasStash = false, isGate = false, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'stone', amount = 5, healPercent = 40 }, subProps = {},
    },

    ['metal_fence_modern'] = {
        label = 'Moderner Metallzaun', category = 'fence', model = 'prop_fence_03a',
        zOffset = 0.0, durability = 300, buildTime = 7000, snapLength = 2.0,
        materials = { { item = 'metalscrap', amount = 15 }, { item = 'iron', amount = 5 } },
        hasStash = false, isGate = false, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'metalscrap', amount = 6, healPercent = 40 }, subProps = {},
    },

    -- ============================ TORE (GATES) ============================
    ['gate_chainlink'] = {
        label = 'Kettenglied-Tor', category = 'fence', model = 'prop_fnclink_02gate7',
        zOffset = 0.0, durability = 300, buildTime = 8000, snapLength = 3.0,
        materials = { { item = 'metalscrap', amount = 15 }, { item = 'iron', amount = 5 } },
        hasStash = false, isGate = true, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'metalscrap', amount = 5, healPercent = 40 }, subProps = {},
    },

    ['gate_residential'] = {
        label = 'Metalltor (Breit)', category = 'fence', model = 'prop_fncres_09gate',
        zOffset = 0.0, durability = 400, buildTime = 10000, snapLength = 3.5,
        materials = { { item = 'metalscrap', amount = 25 }, { item = 'iron', amount = 10 } },
        hasStash = false, isGate = true, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'metalscrap', amount = 8, healPercent = 40 }, subProps = {},
    },

    ['gate_heist'] = {
        label = 'Sicherheitstor', category = 'fence', model = 'h4_prop_h4_gate_04a',
        zOffset = 0.0, durability = 600, buildTime = 15000, snapLength = 4.0,
        materials = { { item = 'metalscrap', amount = 40 }, { item = 'iron', amount = 20 } },
        hasStash = false, isGate = true, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'metalscrap', amount = 10, healPercent = 40 }, subProps = {},
    },

    -- ============================ VERTEIDIGUNG ============================
    ['sandbag_wall'] = {
        label = 'Sandsack-Wand', category = 'defense', model = 'prop_sandbag_01a',
        zOffset = 0.0, durability = 200, buildTime = 5000, snapLength = 1.5,
        materials = { { item = 'sand', amount = 10 }, { item = 'cloth', amount = 6 } },
        hasStash = false, isGate = false, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'sand', amount = 5, healPercent = 30 }, subProps = {},
    },

    ['watchtower'] = {
        label = 'Wachturm', category = 'defense', model = 'prop_scaffold_lift',
        zOffset = 0.0, durability = 600, buildTime = 20000, snapLength = nil,
        materials = { { item = 'wood', amount = 60 }, { item = 'metalscrap', amount = 25 }, { item = 'iron', amount = 15 } },
        hasStash = false, isGate = false, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'repairkit', amount = 2, healPercent = 20 }, subProps = {},
    },

    ['metal_barricade'] = {
        label = 'Stahl-Barrikade', category = 'defense', model = 'prop_mp_barrier_02a',
        zOffset = 0.0, durability = 300, buildTime = 7000, snapLength = nil,
        materials = { { item = 'metalscrap', amount = 20 }, { item = 'iron', amount = 5 } },
        hasStash = false, isGate = false, isCraftingBench = false, isPowerSource = false,
        repair = { item = 'metalscrap', amount = 8, healPercent = 30 }, subProps = {},
    },

    -- ========================== WERKBÄNKE / UTILITY ==========================
    ['crafting_bench'] = {
        label = 'Werkbank', category = 'utility', model = 'prop_tool_bench02',
        zOffset = 0.0, durability = 180, buildTime = 6000, snapLength = nil,
        materials = { { item = 'wood', amount = 20 }, { item = 'metalscrap', amount = 10 } },
        hasStash = false, isGate = false, isCraftingBench = true, isPowerSource = false,
        repair = { item = 'wood', amount = 6, healPercent = 40 }, subProps = {},
    },

    ['generator'] = {
        label = 'Generator', category = 'utility', model = 'prop_generator_01a',
        zOffset = 0.0, durability = 150, buildTime = 9000, snapLength = nil,
        materials = { { item = 'metalscrap', amount = 15 }, { item = 'iron', amount = 10 }, { item = 'electronickit', amount = 3 } },
        hasStash = false, isGate = false, isCraftingBench = false, isPowerSource = true,
        repair = { item = 'electronickit', amount = 1, healPercent = 25 }, subProps = {},
    },
}