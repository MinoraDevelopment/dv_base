local ESX = exports['es_extended']:getSharedObject()

-- In-memory cache, mirrors the DB table for fast access.
-- Structures[id] = {
--   id, identifier, item_name, coords = vector3, heading, hp,
--   allowed_citizens = { identifier, identifier, ... }
-- }
local Structures = {}
local NextId = 1

-- ===================================================================
-- HELPERS
-- ===================================================================

local function GetIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end
    return xPlayer.identifier
end

local function IsOwner(structure, identifier)
    return structure.identifier == identifier
end

local function HasAccess(structure, identifier)
    if IsOwner(structure, identifier) then return true end
    for _, allowedId in ipairs(structure.allowed_citizens) do
        if allowedId == identifier then return true end
    end
    return false
end

local function GetDistanceToStructure(source, structure)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return math.huge end
    local coords = GetEntityCoords(ped)
    return #(coords - structure.coords)
end

local function ToClientPayload(structure, identifier)
    return {
        id               = structure.id,
        item_name        = structure.item_name,
        coords           = structure.coords,
        heading          = structure.heading,
        hp               = structure.hp,
        allowed_citizens = structure.allowed_citizens,
        is_owner         = structure.identifier == identifier,
    }
end

local function BuildStashName(id)
    return 'dv_tent_' .. id
end

local function RegisterStructureStash(structure)
    local def = Config.Structures[structure.item_name]
    if not def or not def.hasStash then return end

    exports.ox_inventory:RegisterStash(
        BuildStashName(structure.id),
        def.label .. ' #' .. structure.id,
        def.stash.slots or 40,
        def.stash.weight or 80000,
        false -- owner restriction handled manually via ox_target canInteract + access checks below
    )
end

local function BroadcastToNearbyOrAll(event, ...)
    -- Simple broadcast; clients themselves decide whether to spawn/despawn based on distance.
    TriggerClientEvent(event, -1, ...)
end

local function SyncStructureToAll(structure)
    for _, playerId in ipairs(GetPlayers()) do
        local identifier = GetIdentifier(tonumber(playerId))
        if identifier then
            TriggerClientEvent('dv_tentsystem:client:structurePlaced', tonumber(playerId), ToClientPayload(structure, identifier))
        end
    end
end

-- ===================================================================
-- STARTUP: table + cache load
-- ===================================================================

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ]] .. Config.DbTable .. [[ (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(64) NOT NULL,
            `item_name` VARCHAR(50) NOT NULL,
            `coords` LONGTEXT NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0,
            `hp` INT NOT NULL DEFAULT 100,
            `allowed_citizens` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    local rows = MySQL.query.await('SELECT * FROM ' .. Config.DbTable, {})
    for _, row in ipairs(rows or {}) do
        local coordsData = json.decode(row.coords)
        local structure = {
            id               = row.id,
            identifier       = row.identifier,
            item_name        = row.item_name,
            coords           = vector3(coordsData.x, coordsData.y, coordsData.z),
            heading          = row.heading,
            hp               = row.hp,
            allowed_citizens = row.allowed_citizens and json.decode(row.allowed_citizens) or {},
        }
        Structures[structure.id] = structure
        if structure.id >= NextId then NextId = structure.id + 1 end
        RegisterStructureStash(structure)
    end

    if Config.Debug then
        print(('[dv_tentsystem] Loaded %d structures from database.'):format(#rows or 0))
    end
end)

-- ===================================================================
-- CLIENT -> SERVER: request full metadata list
-- ===================================================================
RegisterNetEvent('dv_tentsystem:server:requestStructures', function()
    local source = source
    local identifier = GetIdentifier(source)
    if not identifier then return end

    local payload = {}
    for _, structure in pairs(Structures) do
        payload[#payload + 1] = ToClientPayload(structure, identifier)
    end

    TriggerClientEvent('dv_tentsystem:client:loadStructures', source, payload)
end)

-- ===================================================================
-- PLACE STRUCTURE
-- ===================================================================
RegisterNetEvent('dv_tentsystem:server:placeStructure', function(itemKey, coords, heading)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local def = Config.Structures[itemKey]
    if not def then
        if Config.Debug then print(('[dv_tentsystem] placeStructure: invalid item key %s from source %d'):format(tostring(itemKey), source)) end
        return
    end

    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return end
    coords = vector3(coords.x, coords.y, coords.z)
    heading = tonumber(heading) or 0.0

    -- validate & consume materials via ox_inventory
    for _, mat in ipairs(def.materials) do
        local count = exports.ox_inventory:GetItemCount(source, mat.item)
        if count < mat.amount then
            TriggerClientEvent('dv_tentsystem:client:notify', source, 'Dir fehlen die benötigten Materialien.', 'error')
            return
        end
    end

    for _, mat in ipairs(def.materials) do
        local removed = exports.ox_inventory:RemoveItem(source, mat.item, mat.amount)
        if not removed then
            TriggerClientEvent('dv_tentsystem:client:notify', source, 'Fehler beim Verbrauchen der Materialien.', 'error')
            return
        end
    end

    local identifier = xPlayer.identifier
    local coordsJson = json.encode({ x = coords.x, y = coords.y, z = coords.z })

    local insertId = MySQL.insert.await(
        'INSERT INTO ' .. Config.DbTable .. ' (identifier, item_name, coords, heading, hp, allowed_citizens) VALUES (?, ?, ?, ?, ?, ?)',
        { identifier, itemKey, coordsJson, heading, def.durability, json.encode({}) }
    )

    if not insertId then
        TriggerClientEvent('dv_tentsystem:client:notify', source, 'Datenbankfehler beim Platzieren.', 'error')
        return
    end

    local structure = {
        id               = insertId,
        identifier       = identifier,
        item_name        = itemKey,
        coords           = coords,
        heading          = heading,
        hp               = def.durability,
        allowed_citizens = {},
    }

    Structures[insertId] = structure
    if insertId >= NextId then NextId = insertId + 1 end

    RegisterStructureStash(structure)
    SyncStructureToAll(structure)
end)

-- ===================================================================
-- DAMAGE
-- ===================================================================
RegisterNetEvent('dv_tentsystem:server:damageStructure', function(id, amount)
    local source = source
    local structure = Structures[id]
    if not structure then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 or amount > 1000 then return end -- sanity clamp against exploited events

    if GetDistanceToStructure(source, structure) > 40.0 then return end -- ignore clearly spoofed reports

    structure.hp = math.max(0, structure.hp - math.floor(amount))

    if structure.hp <= 0 then
        MySQL.query('DELETE FROM ' .. Config.DbTable .. ' WHERE id = ?', { id })
        Structures[id] = nil
        TriggerClientEvent('dv_tentsystem:client:destroyStructure', -1, id, structure.coords)
    else
        MySQL.update('UPDATE ' .. Config.DbTable .. ' SET hp = ? WHERE id = ?', { structure.hp, id })
        TriggerClientEvent('dv_tentsystem:client:updateHP', -1, id, structure.hp)
    end
end)

-- ===================================================================
-- REPAIR
-- ===================================================================
RegisterNetEvent('dv_tentsystem:server:repairStructure', function(id)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local structure = Structures[id]
    if not structure then return end

    local identifier = xPlayer.identifier
    if not HasAccess(structure, identifier) then
        TriggerClientEvent('dv_tentsystem:client:accessDenied', source)
        return
    end

    if GetDistanceToStructure(source, structure) > 5.0 then
        TriggerClientEvent('dv_tentsystem:client:notify', source, 'Du bist zu weit entfernt.', 'error')
        return
    end

    local def = Config.Structures[structure.item_name]
    if not def or not def.repair then return end

    local count = exports.ox_inventory:GetItemCount(source, def.repair.item)
    if count < def.repair.amount then
        TriggerClientEvent('dv_tentsystem:client:notify', source, 'Dir fehlen Reparatur-Materialien (' .. def.repair.item .. ').', 'error')
        return
    end

    if structure.hp >= def.durability then
        TriggerClientEvent('dv_tentsystem:client:notify', source, 'Struktur ist bereits vollständig intakt.', 'inform')
        return
    end

    local removed = exports.ox_inventory:RemoveItem(source, def.repair.item, def.repair.amount)
    if not removed then return end

    local healAmount = math.floor(def.durability * (def.repair.healPercent / 100))
    structure.hp = math.min(def.durability, structure.hp + healAmount)

    MySQL.update('UPDATE ' .. Config.DbTable .. ' SET hp = ? WHERE id = ?', { structure.hp, id })
    TriggerClientEvent('dv_tentsystem:client:updateHP', -1, id, structure.hp)
    TriggerClientEvent('dv_tentsystem:client:notify', source, 'Struktur repariert.', 'success')
end)

-- ===================================================================
-- DEMOLISH
-- ===================================================================
RegisterNetEvent('dv_tentsystem:server:demolishStructure', function(id)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local structure = Structures[id]
    if not structure then return end

    if not IsOwner(structure, xPlayer.identifier) then
        TriggerClientEvent('dv_tentsystem:client:accessDenied', source)
        return
    end

    if GetDistanceToStructure(source, structure) > 5.0 then
        TriggerClientEvent('dv_tentsystem:client:notify', source, 'Du bist zu weit entfernt.', 'error')
        return
    end

    MySQL.query('DELETE FROM ' .. Config.DbTable .. ' WHERE id = ?', { id })
    Structures[id] = nil

    TriggerClientEvent('dv_tentsystem:client:removeStructure', -1, id)
    TriggerClientEvent('dv_tentsystem:client:notify', source, 'Bauwerk abgebaut.', 'success')
end)

-- ===================================================================
-- PERMISSIONS
-- ===================================================================
RegisterNetEvent('dv_tentsystem:server:grantAccess', function(id, targetServerId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local structure = Structures[id]
    if not structure then return end

    if not IsOwner(structure, xPlayer.identifier) then
        TriggerClientEvent('dv_tentsystem:client:accessDenied', source)
        return
    end

    local targetPlayer = ESX.GetPlayerFromId(tonumber(targetServerId))
    if not targetPlayer then
        TriggerClientEvent('dv_tentsystem:client:notify', source, 'Spieler nicht gefunden.', 'error')
        return
    end

    if #structure.allowed_citizens >= Config.Permissions.maxAllowedPerStructure then
        TriggerClientEvent('dv_tentsystem:client:notify', source, 'Maximale Anzahl an Berechtigungen erreicht.', 'error')
        return
    end

    for _, allowedId in ipairs(structure.allowed_citizens) do
        if allowedId == targetPlayer.identifier then
            TriggerClientEvent('dv_tentsystem:client:notify', source, 'Spieler ist bereits berechtigt.', 'inform')
            return
        end
    end

    table.insert(structure.allowed_citizens, targetPlayer.identifier)
    MySQL.update('UPDATE ' .. Config.DbTable .. ' SET allowed_citizens = ? WHERE id = ?', { json.encode(structure.allowed_citizens), id })

    TriggerClientEvent('dv_tentsystem:client:notify', source, 'Spieler berechtigt.', 'success')
    TriggerClientEvent('dv_tentsystem:client:notify', targetPlayer.source, 'Du wurdest für ein Bauwerk berechtigt.', 'inform')
end)

RegisterNetEvent('dv_tentsystem:server:revokeAccess', function(id, targetIdentifier)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local structure = Structures[id]
    if not structure then return end

    if not IsOwner(structure, xPlayer.identifier) then
        TriggerClientEvent('dv_tentsystem:client:accessDenied', source)
        return
    end

    for i, allowedId in ipairs(structure.allowed_citizens) do
        if allowedId == targetIdentifier then
            table.remove(structure.allowed_citizens, i)
            break
        end
    end

    MySQL.update('UPDATE ' .. Config.DbTable .. ' SET allowed_citizens = ? WHERE id = ?', { json.encode(structure.allowed_citizens), id })
    TriggerClientEvent('dv_tentsystem:client:notify', source, 'Berechtigung entfernt.', 'success')
end)

-- ===================================================================
-- ox_inventory STASH ACCESS GUARD
-- Blocks stash access for players who aren't owner/allowed, by hooking
-- into ox_inventory's stash open request if the export/event is exposed.
-- ===================================================================
AddEventHandler('ox_inventory:openedInventory', function(source, invId) end) -- placeholder hook point

exports('CanAccessStash', function(source, stashId)
    local id = tonumber(string.match(stashId or '', '^dv_tent_(%d+)$'))
    if not id then return true end -- not one of ours

    local structure = Structures[id]
    if not structure then return false end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    return HasAccess(structure, xPlayer.identifier)
end)