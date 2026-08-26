Config = {}

-- ===================================================================
-- GENERAL SETTINGS
-- ===================================================================
Config.Debug              = false
Config.Locale             = 'de'
Config.DbTable            = 'dv_base_structures'

Config.Placement = {
    maxPlaceDistance    = 15.0,
    rayDistance         = 50.0,
    rayStartHeight      = 25.0,
    previewAlpha        = 200,
    rotationStep        = 5.0,
    heightStep          = 0.02,
    maxHeightOffset     = 2.0,
    invalidPlacementSlope = 35.0,
    fenceSnapping       = true,   -- Snapping aktiviert (Rust-Style)
    fenceSnapDistance   = 6.0,    -- Radius in dem nach Zäunen gesucht wird
}

-- ===================================================================
-- STREAMING / CULLING SYSTEM (Entladen bei Abwesenheit)
-- ===================================================================
Config.Streaming = {
    renderDistance      = 200.0,  -- Lädt die Objekte, wenn der Spieler within 200m kommt
    unloadDistance      = 250.0,  -- Entfernt die Objekte, wenn der Spieler weiter als 250m weg ist
    checkInterval        = 2000,   -- Prüft alle 2 Sekunden die Distanz
    requestInterval       = 15000, -- Fordert alle 15 Sekunden die Metadaten vom Server an
}

Config.Damage = {
    pollInterval        = 750,
    minDeltaToSync      = 1,
    destroyEffect       = 'exp_grd_grenade_smoke',
    allowVehicleDamage  = true,
    allowWeaponDamage   = true,
}

Config.Permissions = {
    maxAllowedPerStructure = 10,
}