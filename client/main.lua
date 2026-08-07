local ESX = exports['es_extended']:getSharedObject()

local PlayerData        = {}
local isPlacing          = false

-- id -> { data = {..server meta..}, entity = handle|nil, subEntities = {handle,..}, spawned = bool, damageThread = bool }
local Structures         = {}

-- ===================================================================
-- INIT
-- ===================================================================
CreateThread(function()
    while ESX.GetPlayerData == nil do Wait(50) end
    PlayerData = ESX.GetPlayerData()
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
    TriggerServerEvent('dv_tentsystem:server:requestStructures')
end)

RegisterNetEvent('esx:setJob', function(job)
    PlayerData.job = job
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(1000)
    TriggerServerEvent('dv_tentsystem:server:requestStructures')
end)

-- ===================================================================
-- UTILITY
-- ===================================================================

--- Rotates a local {x,y,z} offset by a heading (degrees) and adds it to a base coord
local function GetRotatedOffset(baseCoords, baseHeading, offset)
    local rad = math.rad(baseHeading)
    local cos, sin = math.cos(rad), math.sin(rad)
    local x = baseCoords.x + (offset.x * cos - offset.y * sin)
    local y = baseCoords.y + (offset.x * sin + offset.y * cos)
    local z = baseCoords.z + offset.z
    local h = (baseHeading + (offset.h or 0.0)) % 360.0
    return vector3(x, y, z), h
end

--- Top-down raycast from above the target xy down through the world to find ground height.
--- Prevents floating / clipping props by never trusting the ped's raw Z.
local function GetGroundZ(x, y, aroundZ)
    local startZ = (aroundZ or 0.0) + Config.Placement.rayStartHeight
    local endZ   = (aroundZ or 0.0) - Config.Placement.rayDistance
    local rayHandle = StartShapeTestRay(x, y, startZ, x, y, endZ, 1, PlayerPedId(), 0)
    local _, hit, endCoords, normal, _ = GetShapeTestResult(rayHandle)
    if hit == 1 then
        return endCoords.z, normal
    end
    return aroundZ, vector3(0.0, 0.0, 1.0)
end

local function CalculateSlopeDegrees(normal)
    -- angle between the ground normal and world-up (0,0,1)
    local dot = normal.z -- since world-up is (0,0,1), dot = normal.z
    dot = math.max(-1.0, math.min(1.0, dot))
    return math.deg(math.acos(dot))
end

local function LoadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    lib.requestModel(hash, 10000)
    return hash
end

local function PlayBuildAnim()
    lib.requestAnimDict('amb@world_human_gardener_plant@male@base')
    TaskPlayAnim(PlayerPedId(), 'amb@world_human_gardener_plant@male@base', 'base', 8.0, -8.0, -1, 1, 0, false, false, false)
end

-- ===================================================================
-- PLACEMENT SYSTEM
-- ===================================================================

local function StartPlacement(itemKey)
    if isPlacing then
        lib.notify({ description = 'Du platzierst bereits etwas.', type = 'error' })
        return
    end

    local structDef = Config.Structures[itemKey]
    if not structDef then
        if Config.Debug then print(('[dv_tentsystem] Unknown structure key: %s'):format(itemKey)) end
        return
    end

    isPlacing = true

    local hash = LoadModel(structDef.model)
    local previewEntity = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(previewEntity, Config.Placement.previewAlpha, false)
    SetEntityCollision(previewEntity, false, false)
    SetEntityInvincible(previewEntity, true)

    local heading   = 0.0
    local zOffsetManual = 0.0
    local gridSnap  = false
    local validSpot = false
    local currentCoords = GetEntityCoords(previewEntity)

    lib.showTextUI(
        '[LMB] Bestätigen  |  [RMB] Abbrechen  |  Mausrad / Pfeile: Drehen  |  Bild-Hoch/Runter: Höhe  |  [G] Raster',
        { position = 'bottom-center' }
    )

    while isPlacing do
        Wait(0)

        DisableControlAction(0, 1, true)  -- LookLeftRight (keep camera though; only block if needed)
        DisableControlAction(0, 2, true)  -- LookUpDown
        DisableControlAction(0, 24, true) -- Attack (raw LMB) -- we intercept manually below
        DisableControlAction(0, 25, true) -- Aim

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)

        -- forward-cast to find where the player is looking / aiming on the ground plane in front of them,
        -- clamped to max place distance, then top-down raycast for accurate ground Z
        local camCoords = GetGameplayCamCoord()
        local camRot    = GetGameplayCamRot(2)
        local dir       = RotationToDirection(camRot)
        local targetX   = camCoords.x + dir.x * Config.Placement.maxPlaceDistance
        local targetY   = camCoords.y + dir.y * Config.Placement.maxPlaceDistance

        local groundZ, normal = GetGroundZ(targetX, targetY, pedCoords.z)
        local slope = CalculateSlopeDegrees(normal)
        validSpot = slope <= Config.Placement.invalidPlacementSlope

        local finalX, finalY = targetX, targetY
        if gridSnap then
            finalX = math.floor((finalX / Config.Placement.gridSnapSize) + 0.5) * Config.Placement.gridSnapSize
            finalY = math.floor((finalY / Config.Placement.gridSnapSize) + 0.5) * Config.Placement.gridSnapSize
        end

        local finalZ = groundZ + (structDef.zOffset or 0.0) + zOffsetManual
        currentCoords = vector3(finalX, finalY, finalZ)

        SetEntityCoords(previewEntity, finalX, finalY, finalZ, false, false, false, false)
        SetEntityHeading(previewEntity, heading)
        SetEntityAlpha(previewEntity, Config.Placement.previewAlpha, false)

        -- tint preview red/green depending on validity by toggling outline (best-effort, no shader access)
        if validSpot then
            SetEntityDrawOutline(previewEntity, true)
            SetEntityDrawOutlineColor(60, 220, 90, 255)
        else
            SetEntityDrawOutline(previewEntity, true)
            SetEntityDrawOutlineColor(220, 60, 60, 255)
        end
        SetEntityDrawOutlineShader(0)

        -- rotation: arrow keys
        if IsDisabledControlPressed(0, 174) then -- INPUT_FRONTEND_LEFT
            heading = (heading - Config.Placement.rotationStep) % 360.0
        elseif IsDisabledControlPressed(0, 175) then -- INPUT_FRONTEND_RIGHT
            heading = (heading + Config.Placement.rotationStep) % 360.0
        end

        -- rotation: mouse wheel
        if IsDisabledControlJustPressed(0, 241) then -- INPUT_FRONTEND_AXIS_Y (wheel up alt) fallback
        end
        if IsControlJustPressed(0, 15) then -- INPUT_MOVE_UP_ONLY / wheel up (context dependent, safe fallback)
            heading = (heading + Config.Placement.mouseRotationStep) % 360.0
        elseif IsControlJustPressed(0, 16) then -- wheel down
            heading = (heading - Config.Placement.mouseRotationStep) % 360.0
        end

        -- height offset
        if IsDisabledControlPressed(0, 172) then -- INPUT_FRONTEND_UP
            zOffsetManual = math.min(Config.Placement.maxHeightOffset, zOffsetManual + Config.Placement.heightStep)
        elseif IsDisabledControlPressed(0, 173) then -- INPUT_FRONTEND_DOWN
            zOffsetManual = math.max(-Config.Placement.maxHeightOffset, zOffsetManual - Config.Placement.heightStep)
        end

        -- grid snap toggle
        if IsControlJustPressed(0, 47) then -- INPUT_MELEE_ATTACK_ALT / 'G' default bind
            gridSnap = not gridSnap
            lib.notify({ description = gridSnap and 'Raster-Snapping aktiviert' or 'Raster-Snapping deaktiviert', type = 'inform', duration = 1500 })
        end

        -- confirm
        if IsDisabledControlJustPressed(0, 24) then
            if not validSpot then
                lib.notify({ description = 'Untergrund ungeeignet (zu steil / instabil).', type = 'error' })
            elseif #(pedCoords - currentCoords) > Config.Placement.maxPlaceDistance + 2.0 then
                lib.notify({ description = 'Zu weit entfernt.', type = 'error' })
            else
                local finalCoords = currentCoords
                local finalHeading = heading

                DeleteObject(previewEntity)
                lib.hideTextUI()
                isPlacing = false

                PlayBuildAnim()
                local ok = lib.progressBar({
                    duration = structDef.buildTime,
                    label = ('Baue %s auf...'):format(structDef.label),
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, car = true, combat = true },
                })
                ClearPedTasks(ped)

                if ok then
                    TriggerServerEvent('dv_tentsystem:server:placeStructure', itemKey, finalCoords, finalHeading)
                else
                    lib.notify({ description = 'Bauvorgang abgebrochen.', type = 'error' })
                end
                return
            end
        end

        -- cancel
        if IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 202) then -- RMB or ESC
            DeleteObject(previewEntity)
            lib.hideTextUI()
            isPlacing = false
            lib.notify({ description = 'Platzierung abgebrochen.', type = 'inform' })
            return
        end
    end
end

function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

exports('startPlacing', function(itemKey)
    StartPlacement(itemKey)
end)

RegisterNetEvent('dv_tentsystem:client:startPlacing', function(itemKey)
    StartPlacement(itemKey)
end)

-- ===================================================================
-- STRUCTURE SPAWNING
-- ===================================================================

local function BuildTargetOptions(id)
    local entry = Structures[id]
    local def = Config.Structures[entry.data.item_name]
    local options = {}

    options[#options + 1] = {
        name = 'dv_tent_repair_' .. id,
        icon = 'fa-solid fa-hammer',
        label = 'Reparieren',
        distance = 2.5,
        onSelect = function()
            TriggerServerEvent('dv_tentsystem:server:repairStructure', id)
        end,
    }

    if def.hasStash then
        options[#options + 1] = {
            name = 'dv_tent_stash_' .. id,
            icon = 'fa-solid fa-box-open',
            label = 'Lager öffnen',
            distance = 2.5,
            onSelect = function()
                exports.ox_inventory:openInventory('stash', 'dv_tent_' .. id)
            end,
        }
    end

    if def.isCraftingBench then
        options[#options + 1] = {
            name = 'dv_tent_craft_' .. id,
            icon = 'fa-solid fa-screwdriver-wrench',
            label = 'Herstellen',
            distance = 2.5,
            onSelect = function()
                TriggerEvent('dv_tentsystem:client:openCrafting', id)
            end,
        }
    end

    options[#options + 1] = {
        name = 'dv_tent_manage_' .. id,
        icon = 'fa-solid fa-users',
        label = 'Zugriff verwalten',
        distance = 2.5,
        onSelect = function()
            OpenPermissionMenu(id)
        end,
        canInteract = function()
            return entry.data.is_owner == true
        end,
    }

    options[#options + 1] = {
        name = 'dv_tent_demolish_' .. id,
        icon = 'fa-solid fa-trash',
        label = 'Abbauen',
        distance = 2.5,
        onSelect = function()
            local confirmed = lib.alertDialog({
                header = 'Struktur abbauen',
                content = 'Willst du dieses Bauwerk wirklich unwiderruflich entfernen?',
                centerButtons = true,
                cancel = true,
            })
            if confirmed == 'confirm' then
                TriggerServerEvent('dv_tentsystem:server:demolishStructure', id)
            end
        end,
        canInteract = function()
            return entry.data.is_owner == true
        end,
    }

    return options
end

function OpenPermissionMenu(id)
    local entry = Structures[id]
    local allowed = entry.data.allowed_citizens or {}

    local options = {
        {
            title = 'Spieler berechtigen',
            description = 'In der Nähe befindliche Spieler-ID hinzufügen',
            icon = 'user-plus',
            onSelect = function()
                local input = lib.inputDialog('Spieler berechtigen', {
                    { type = 'number', label = 'Server-ID des Spielers', required = true },
                })
                if input and input[1] then
                    TriggerServerEvent('dv_tentsystem:server:grantAccess', id, tonumber(input[1]))
                end
            end,
        },
    }

    for _, cid in ipairs(allowed) do
        options[#options + 1] = {
            title = 'Entfernen: ' .. tostring(cid),
            icon = 'user-minus',
            onSelect = function()
                TriggerServerEvent('dv_tentsystem:server:revokeAccess', id, cid)
            end,
        }
    end

    lib.registerContext({
        id = 'dv_tent_permissions_' .. id,
        title = 'Zugriffsverwaltung',
        options = options,
    })
    lib.showContext('dv_tent_permissions_' .. id)
end

local function StartDamageMonitor(id)
    CreateThread(function()
        local entry = Structures[id]
        if not entry then return end
        entry.damageThread = true

        local lastHealth = GetEntityHealth(entry.entity)

        while entry.spawned and entry.damageThread do
            Wait(Config.Damage.pollInterval)
            entry = Structures[id]
            if not entry or not entry.spawned or not DoesEntityExist(entry.entity) then break end

            local currentHealth = GetEntityHealth(entry.entity)
            if currentHealth < lastHealth then
                local delta = lastHealth - currentHealth
                if delta >= Config.Damage.minDeltaToSync then
                    TriggerServerEvent('dv_tentsystem:server:damageStructure', id, delta)
                end
            end
            lastHealth = currentHealth
        end
    end)
end

local function SpawnStructure(id)
    local entry = Structures[id]
    if not entry or entry.spawned then return end

    local data = entry.data
    local def = Config.Structures[data.item_name]
    if not def then return end

    local hash = LoadModel(def.model)
    local coords = data.coords

    local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, true)
    SetEntityHeading(obj, data.heading)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, true, true)
    SetEntityInvincible(obj, false)
    SetEntityCanBeDamaged(obj, true)
    SetEntityMaxHealth(obj, def.durability)
    SetEntityHealth(obj, math.max(1, data.hp or def.durability))

    entry.entity = obj
    entry.subEntities = {}
    entry.spawned = true

    if def.subProps then
        for _, sub in ipairs(def.subProps) do
            local subHash = LoadModel(sub.model)
            local subCoords, subHeading = GetRotatedOffset(coords, data.heading, sub.offset)
            local subZ = subCoords.z + (sub.zOffset or 0.0)
            local subObj = CreateObject(subHash, subCoords.x, subCoords.y, subZ, false, false, true)
            SetEntityHeading(subObj, subHeading)
            FreezeEntityPosition(subObj, true)
            SetEntityCollision(subObj, true, true)
            entry.subEntities[#entry.subEntities + 1] = subObj
        end
    end

    exports.ox_target:addLocalEntity(obj, BuildTargetOptions(id))

    StartDamageMonitor(id)
end

local function DespawnStructure(id)
    local entry = Structures[id]
    if not entry or not entry.spawned then return end

    entry.damageThread = false

    if entry.entity and DoesEntityExist(entry.entity) then
        exports.ox_target:removeLocalEntity(entry.entity)
        DeleteObject(entry.entity)
    end

    if entry.subEntities then
        for _, sub in ipairs(entry.subEntities) do
            if DoesEntityExist(sub) then DeleteObject(sub) end
        end
    end

    entry.entity = nil
    entry.subEntities = {}
    entry.spawned = false
end

local function PlayDestroyEffect(coords)
    RequestNamedPtfxAsset('core')
    while not HasNamedPtfxAssetLoaded('core') do Wait(0) end
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord(Config.Damage.destroyEffect, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
end

-- ===================================================================
-- STREAMING LOOP
-- ===================================================================
CreateThread(function()
    while true do
        Wait(Config.Streaming.checkInterval)
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            local pedCoords = GetEntityCoords(ped)
            for id, entry in pairs(Structures) do
                local dist = #(pedCoords - entry.data.coords)
                if not entry.spawned and dist <= Config.Streaming.renderDistance then
                    SpawnStructure(id)
                elseif entry.spawned and dist > Config.Streaming.unloadDistance then
                    DespawnStructure(id)
                end
            end
        end
    end
end)

-- periodic metadata refresh (keeps far-away structures' hp / permission data in sync
-- even while not spawned, so they render correctly once the player approaches)
CreateThread(function()
    while true do
        Wait(Config.Streaming.requestInterval)
        TriggerServerEvent('dv_tentsystem:server:requestStructures')
    end
end)

-- ===================================================================
-- SERVER -> CLIENT EVENTS
-- ===================================================================

RegisterNetEvent('dv_tentsystem:client:loadStructures', function(list)
    for _, data in ipairs(list) do
        if not Structures[data.id] then
            Structures[data.id] = { data = data, entity = nil, subEntities = {}, spawned = false }
        else
            Structures[data.id].data = data
        end
    end
end)

RegisterNetEvent('dv_tentsystem:client:structurePlaced', function(data)
    Structures[data.id] = { data = data, entity = nil, subEntities = {}, spawned = false }
    local ped = PlayerPedId()
    local dist = #(GetEntityCoords(ped) - data.coords)
    if dist <= Config.Streaming.renderDistance then
        SpawnStructure(data.id)
    end
    lib.notify({ description = 'Bauwerk erfolgreich errichtet.', type = 'success' })
end)

RegisterNetEvent('dv_tentsystem:client:updateHP', function(id, hp)
    local entry = Structures[id]
    if not entry then return end
    entry.data.hp = hp
    if entry.spawned and entry.entity and DoesEntityExist(entry.entity) then
        SetEntityHealth(entry.entity, math.max(1, hp))
    end
end)

RegisterNetEvent('dv_tentsystem:client:destroyStructure', function(id, coords)
    local entry = Structures[id]
    if entry and entry.spawned then
        PlayDestroyEffect(coords)
    end
    if entry then DespawnStructure(id) end
    Structures[id] = nil
end)

RegisterNetEvent('dv_tentsystem:client:removeStructure', function(id)
    local entry = Structures[id]
    if entry then DespawnStructure(id) end
    Structures[id] = nil
end)

RegisterNetEvent('dv_tentsystem:client:accessDenied', function()
    lib.notify({ description = 'Du hast keinen Zugriff auf dieses Bauwerk.', type = 'error' })
end)

RegisterNetEvent('dv_tentsystem:client:notify', function(msg, msgType)
    lib.notify({ description = msg, type = msgType or 'inform' })
end)

-- ===================================================================
-- CLEANUP
-- ===================================================================
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id, entry in pairs(Structures) do
        if entry.spawned then DespawnStructure(id) end
    end
end)