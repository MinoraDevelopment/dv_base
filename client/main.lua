local ESX = exports['es_extended']:getSharedObject()

local PlayerData        = {}
local isPlacing          = false
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

local function GetRotatedOffset(baseCoords, baseHeading, offset)
    local rad = math.rad(baseHeading)
    local cos, sin = math.cos(rad), math.sin(rad)
    local x = baseCoords.x + (offset.x * cos - offset.y * sin)
    local y = baseCoords.y + (offset.x * sin + offset.y * cos)
    local z = baseCoords.z + offset.z
    local h = (baseHeading + (offset.h or 0.0)) % 360.0
    return vector3(x, y, z), h
end

local function GetGroundZ(x, y, aroundZ)
    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, (aroundZ or 0.0) + 10.0, false)
    if foundGround then
        return groundZ, vector3(0.0, 0.0, 1.0)
    end
    return aroundZ or 0.0, vector3(0.0, 0.0, 1.0)
end

local function CalculateSlopeDegrees(normal)
    local dot = normal.z
    dot = math.max(-1.0, math.min(1.0, dot))
    return math.deg(math.acos(dot))
end

local function LoadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelValid(hash) then 
        print('[dv_base] FEHLER: Modell ist ungültig: ' .. tostring(model))
        return nil 
    end
    lib.requestModel(hash, 1000)
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
    if isPlacing then return end
    
    local structDef = Config.Structures[itemKey]
    if not structDef then
        print('[dv_base] FEHLER: Struktur-Key nicht gefunden: ' .. tostring(itemKey))
        return
    end

    local hash = LoadModel(structDef.model)
    if not hash then
        lib.notify({ description = 'FEHLER: 3D-Modell fehlt auf dem Server!', type = 'error' })
        return
    end

    isPlacing = true

    local previewEntity = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(previewEntity, 200, false)
    SetEntityCollision(previewEntity, false, false)
    SetEntityVisible(previewEntity, true)
    
    -- SetEntityDrawOutline entfernt, da es oft zu unsichtbaren Objekten führt!
    
    local heading = 0.0
    local zOffsetManual = 0.0
    local validSpot = false
    local currentCoords = GetEntityCoords(previewEntity)
    local currentDistance = 5.0

    lib.showTextUI('[LMB] Bestätigen  |  [RMB] Abbrechen  |  Pfeiltasten: Drehen  |  Mausrad: Entfernung', { position = 'bottom-center' })

    while isPlacing do
        Wait(0)

        DisableControlAction(0, 1, true)
        DisableControlAction(0, 2, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)

        local camCoords = GetGameplayCamCoord()
        local camRot    = GetGameplayCamRot(2)
        local dir       = RotationToDirection(camRot)
        
        local targetX   = camCoords.x + dir.x * currentDistance
        local targetY   = camCoords.y + dir.y * currentDistance

        local groundZ, normal = GetGroundZ(targetX, targetY, pedCoords.z)
        local slope = CalculateSlopeDegrees(normal)
        validSpot = slope <= Config.Placement.invalidPlacementSlope

        local finalX, finalY = targetX, targetY
        
        -- EXAKTES BOUNDING-BOX GRID-SNAPPING
        if Config.Placement.fenceSnapping then
            local closestDist = Config.Placement.fenceSnapDistance
            local snapTarget = nil
            
            for id, entry in pairs(Structures) do
                if entry.spawned and entry.data.item_name == itemKey then
                    local dist = #(entry.data.coords - vector3(finalX, finalY, groundZ))
                    if dist < closestDist then
                        closestDist = dist
                        snapTarget = entry
                    end
                end
            end
            
            if snapTarget then
                local targetHeading = snapTarget.data.heading
                local rad = math.rad(targetHeading)
                local forwardX = -math.sin(rad)
                local forwardY = math.cos(rad)
                
                local minDim, maxDim = GetModelDimensions(hash)
                local frontEdge = maxDim.y
                local backEdge = minDim.y 
                local straightDist = frontEdge - backEdge
                
                local options = {
                    { x = snapTarget.data.coords.x + (forwardX * straightDist), y = snapTarget.data.coords.y + (forwardY * straightDist), h = targetHeading },
                    { x = snapTarget.data.coords.x - (forwardX * straightDist), y = snapTarget.data.coords.y - (forwardY * straightDist), h = targetHeading },
                    { x = snapTarget.data.coords.x + (forwardX * frontEdge), y = snapTarget.data.coords.y + (forwardY * frontEdge), h = (targetHeading + 90.0) % 360.0 },
                    { x = snapTarget.data.coords.x + (forwardX * frontEdge), y = snapTarget.data.coords.y + (forwardY * frontEdge), h = (targetHeading - 90.0) % 360.0 },
                    { x = snapTarget.data.coords.x - (forwardX * frontEdge), y = snapTarget.data.coords.y - (forwardY * frontEdge), h = (targetHeading + 90.0) % 360.0 },
                    { x = snapTarget.data.coords.x - (forwardX * frontEdge), y = snapTarget.data.coords.y - (forwardY * frontEdge), h = (targetHeading - 90.0) % 360.0 },
                }
                
                local bestOption = nil
                local closestDistToAim = 999.0
                for _, opt in ipairs(options) do
                    local dist = #(vector3(finalX, finalY, 0) - vector3(opt.x, opt.y, 0))
                    if dist < closestDistToAim then
                        closestDistToAim = dist
                        bestOption = opt
                    end
                end
                
                if bestOption then
                    finalX = bestOption.x
                    finalY = bestOption.y
                    heading = bestOption.h
                end
            end
        end

        local finalZ = groundZ + (structDef.zOffset or 0.0) + zOffsetManual
        currentCoords = vector3(finalX, finalY, finalZ)

        SetEntityCoords(previewEntity, finalX, finalY, finalZ, false, false, false, false)
        SetEntityHeading(previewEntity, heading)

        -- Einfache Farbbestätigung durch Transparenz
        if validSpot then
            SetEntityAlpha(previewEntity, 200, false) -- Leicht sichtbar = gültig
        else
            SetEntityAlpha(previewEntity, 100, false) -- Sehr transparent = ungültig
        end

        if IsDisabledControlPressed(0, 174) then 
            heading = (heading - Config.Placement.rotationStep) % 360.0
        elseif IsDisabledControlPressed(0, 175) then 
            heading = (heading + Config.Placement.rotationStep) % 360.0
        end

        if IsDisabledControlJustPressed(0, 241) then 
            currentDistance = math.max(2.0, currentDistance - 0.5)
        elseif IsDisabledControlJustPressed(0, 242) then 
            currentDistance = math.min(Config.Placement.maxPlaceDistance, currentDistance + 0.5)
        end

        if IsDisabledControlPressed(0, 172) then 
            zOffsetManual = math.min(Config.Placement.maxHeightOffset, zOffsetManual + Config.Placement.heightStep)
        elseif IsDisabledControlPressed(0, 173) then 
            zOffsetManual = math.max(-Config.Placement.maxHeightOffset, zOffsetManual - Config.Placement.heightStep)
        end

        if IsDisabledControlJustPressed(0, 24) then
            if not validSpot then
                lib.notify({ description = 'Untergrund ungeeignet.', type = 'error' })
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
                    useWhileDead = false, canCancel = true,
                    disable = { move = true, car = true, combat = true },
                })
                ClearPedTasks(ped)

                if ok then
                    local gateCode = nil
                    if structDef.isGate then
                        local input = lib.inputDialog('Tor-Code festlegen', {
                            { type = 'number', label = '4-stelliger Code (z.B. 1234)', required = true, min = 1000, max = 9999 }
                        })
                        if input and input[1] then gateCode = tostring(input[1]) else
                            lib.notify({ description = 'Tor-Platzierung abgebrochen (Code fehlt).', type = 'error' })
                            return
                        end
                    end
                    TriggerServerEvent('dv_tentsystem:server:placeStructure', itemKey, finalCoords, finalHeading, gateCode)
                else
                    lib.notify({ description = 'Bauvorgang abgebrochen.', type = 'error' })
                end
                return
            end
        end

        if IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 202) then
            DeleteObject(previewEntity)
            lib.hideTextUI()
            isPlacing = false
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

-- ===================================================================
-- EXPORTS & EVENTS (ox_inventory Fix)
-- ===================================================================

local function parseItemKey(itemKey)
    if type(itemKey) == 'table' then
        return itemKey.name or itemKey[1]
    end
    return itemKey
end

exports('startPlacing', function(itemKey)
    local key = parseItemKey(itemKey)
    print('[dv_base] Export startPlacing aufgerufen mit Key: ' .. tostring(key))
    StartPlacement(key)
end)

RegisterNetEvent('dv_tentsystem:client:startPlacing', function(itemKey)
    local key = parseItemKey(itemKey)
    StartPlacement(key)
end)

-- ===================================================================
-- GATE LOGIC
-- ===================================================================
local function ToggleGate(id)
    local entry = Structures[id]
    if not entry or not entry.spawned or not entry.entity then return end
    local obj = entry.entity
    if not DoesEntityExist(obj) then return end

    entry.gateOpen = not entry.gateOpen
    local targetHeading = entry.gateOpen and (entry.data.heading + 90.0) or entry.data.heading

    FreezeEntityPosition(obj, false)
    CreateThread(function()
        local currentH = GetEntityHeading(obj)
        local diff = targetHeading - currentH
        if diff > 180 then diff = diff - 360 elseif diff < -180 then diff = diff + 360 end
        local steps = 30
        local stepSize = diff / steps
        for i = 1, steps do
            if not DoesEntityExist(obj) then return end
            currentH = currentH + stepSize
            SetEntityHeading(obj, currentH)
            Wait(10)
        end
        SetEntityHeading(obj, targetHeading)
        FreezeEntityPosition(obj, true)
    end)
end

-- ===================================================================
-- STRUCTURE SPAWNING & TARGET
-- ===================================================================
local function BuildTargetOptions(id)
    local entry = Structures[id]
    local def = Config.Structures[entry.data.item_name]
    local options = {}

    options[#options + 1] = { name = 'dv_tent_repair_' .. id, icon = 'fa-solid fa-hammer', label = 'Reparieren', distance = 2.5, onSelect = function() TriggerServerEvent('dv_tentsystem:server:repairStructure', id) end }

    if def.isGate then
        options[#options + 1] = {
            name = 'dv_tent_gate_' .. id, icon = 'fa-solid fa-door-open', label = 'Tor öffnen/schließen', distance = 2.5,
            onSelect = function()
                if entry.data.is_owner then
                    ToggleGate(id)
                else
                    local input = lib.inputDialog('Tor-Code', { { type = 'number', label = 'Code eingeben', required = true } })
                    if input and input[1] and tostring(input[1]) == tostring(entry.data.code) then
                        ToggleGate(id)
                    else
                        lib.notify({ description = 'Falscher Code.', type = 'error' })
                    end
                end
            end,
        }
    end

    if def.hasStash then
        options[#options + 1] = { name = 'dv_tent_stash_' .. id, icon = 'fa-solid fa-box-open', label = 'Lager öffnen', distance = 2.5, onSelect = function() exports.ox_inventory:openInventory('stash', 'dv_tent_' .. id) end }
    end
    if def.isCraftingBench then
        options[#options + 1] = { name = 'dv_tent_craft_' .. id, icon = 'fa-solid fa-screwdriver-wrench', label = 'Herstellen', distance = 2.5, onSelect = function() TriggerEvent('dv_tentsystem:client:openCrafting', id) end }
    end

    if def.hasStash or def.isGate then
        options[#options + 1] = {
            name = 'dv_tent_manage_' .. id, icon = 'fa-solid fa-users', label = 'Zugriff verwalten', distance = 2.5,
            onSelect = function() OpenPermissionMenu(id) end, canInteract = function() return entry.data.is_owner == true end,
        }
    end

    options[#options + 1] = {
        name = 'dv_tent_demolish_' .. id, icon = 'fa-solid fa-trash', label = 'Abbauen', distance = 2.5,
        onSelect = function()
            local confirmed = lib.alertDialog({ header = 'Struktur abbauen', content = 'Wirklich unwiderruflich entfernen?', centerButtons = true, cancel = true })
            if confirmed == 'confirm' then TriggerServerEvent('dv_tentsystem:server:demolishStructure', id) end
        end,
        canInteract = function() return entry.data.is_owner == true end,
    }

    return options
end

function OpenPermissionMenu(id)
    local entry = Structures[id]
    local allowed = entry.data.allowed_citizens or {}
    local options = {
        { title = 'Spieler berechtigen', description = 'In der Nähe befindliche Spieler-ID hinzufügen', icon = 'user-plus', onSelect = function()
            local input = lib.inputDialog('Spieler berechtigen', { { type = 'number', label = 'Server-ID des Spielers', required = true } })
            if input and input[1] then TriggerServerEvent('dv_tentsystem:server:grantAccess', id, tonumber(input[1])) end
        end },
    }
    if entry.data.code then
        options[#options + 1] = { title = 'Tor-Code anzeigen', description = 'Der aktuelle Code lautet: ' .. entry.data.code, icon = 'key' }
    end
    for _, cid in ipairs(allowed) do
        options[#options + 1] = { title = 'Entfernen: ' .. tostring(cid), icon = 'user-minus', onSelect = function() TriggerServerEvent('dv_tentsystem:server:revokeAccess', id, cid) end }
    end
    lib.registerContext({ id = 'dv_tent_permissions_' .. id, title = 'Zugriffsverwaltung', options = options })
    lib.showContext('dv_tent_permissions_' .. id)
end

local function SpawnStructure(id)
    local entry = Structures[id]
    if not entry or entry.spawned then return end

    local def = Config.Structures[entry.data.item_name]
    if not def then return end

    local hash = LoadModel(def.model)
    if not hash then return end

    local coords = entry.data.coords
    local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 10.0, false)
    local spawnZ = foundGround and groundZ or coords.z
    
    local obj = CreateObject(hash, coords.x, coords.y, spawnZ + (def.zOffset or 0.0), false, false, true)
    SetEntityHeading(obj, entry.data.heading)
    if not foundGround then PlaceObjectOnGroundProperly(obj); SetEntityHeading(obj, entry.data.heading) end
    
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, true, true)
    SetEntityCanBeDamaged(obj, true)
    SetEntityMaxHealth(obj, def.durability)
    SetEntityHealth(obj, math.max(1, entry.data.hp or def.durability))

    entry.entity = obj
    entry.subEntities = {}
    entry.spawned = true

    if def.subProps then
        for _, sub in ipairs(def.subProps) do
            local subHash = LoadModel(sub.model)
            if subHash then
                local subCoords, subHeading = GetRotatedOffset(coords, entry.data.heading, sub.offset)
                local subFound, subGroundZ = GetGroundZFor_3dCoord(subCoords.x, subCoords.y, subCoords.z + 10.0, false)
                local subSpawnZ = subFound and subGroundZ or subCoords.z
                local subObj = CreateObject(subHash, subCoords.x, subCoords.y, subSpawnZ + (sub.zOffset or 0.0), false, false, true)
                SetEntityHeading(subObj, subHeading)
                if not subFound then PlaceObjectOnGroundProperly(subObj); SetEntityHeading(subObj, subHeading) end
                FreezeEntityPosition(subObj, true)
                entry.subEntities[#entry.subEntities + 1] = subObj
            end
        end
    end

    exports.ox_target:addLocalEntity(obj, BuildTargetOptions(id))
end

local function DespawnStructure(id)
    local entry = Structures[id]
    if not entry or not entry.spawned then return end
    if entry.entity and DoesEntityExist(entry.entity) then
        exports.ox_target:removeLocalEntity(entry.entity)
        DeleteObject(entry.entity)
    end
    if entry.subEntities then
        for _, sub in ipairs(entry.subEntities) do
            if DoesEntityExist(sub) then DeleteObject(sub) end
        end
    end
    entry.entity = nil; entry.subEntities = {}; entry.spawned = false
end

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

CreateThread(function()
    while true do
        Wait(Config.Streaming.requestInterval)
        TriggerServerEvent('dv_tentsystem:server:requestStructures')
    end
end)

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
    if #(GetEntityCoords(ped) - data.coords) <= Config.Streaming.renderDistance then
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
        RequestNamedPtfxAsset('core')
        while not HasNamedPtfxAssetLoaded('core') do Wait(0) end
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord(Config.Damage.destroyEffect, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
    end
    if entry then DespawnStructure(id) end
    Structures[id] = nil
end)

RegisterNetEvent('dv_tentsystem:client:removeStructure', function(id)
    local entry = Structures[id]
    if entry then DespawnStructure(id) end
    Structures[id] = nil
end)

RegisterNetEvent('dv_tentsystem:client:accessDenied', function() lib.notify({ description = 'Kein Zugriff.', type = 'error' }) end)
RegisterNetEvent('dv_tentsystem:client:notify', function(msg, msgType) lib.notify({ description = msg, type = msgType or 'inform' }) end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id, entry in pairs(Structures) do
        if entry.spawned then DespawnStructure(id) end
    end
end)