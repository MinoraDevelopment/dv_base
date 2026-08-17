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
    previewAlpha        = 170,
    rotationStep        = 5.0,
    heightStep          = 0.02,
    maxHeightOffset     = 2.0,
    gridSnapSize        = 1.0,
    invalidPlacementSlope = 35.0,
    
    -- NEU: Grid & Snapping Einstellungen
    fenceSnapping       = true,   -- Wenn true, haften Zäune automatisch aneinander
    fenceSnapDistance   = 3.0,    -- In welchem Radius wir nach bestehenden Zäunen suchen
}

Config.Streaming = {
    renderDistance      = 120.0,
    unloadDistance      = 150.0,
    checkInterval       = 3000,
    requestInterval     = 15000,
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

return Config