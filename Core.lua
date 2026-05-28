local addonName, addon = ...

_G[addonName] = addon

addon.name = addonName
addon.displayName = "Enhanced Damage Meter"
addon.DamageMeterHost = {
	localeName = "EnhancedDamageMeter",
	displayName = "Enhanced Damage Meter",
	framePrefix = "EnhancedDamageMeter",
	editModePrefix = "EDM_DamageMeter",
	popupPrefix = "EDM_DAMAGE_METER",
	menuHistoryTag = "MENU_EDM_DAMAGE_METER_HISTORY",
}

local function ensureDB()
	if type(_G.EnhancedDamageMeterDB) ~= "table" then _G.EnhancedDamageMeterDB = {} end
	local root = _G.EnhancedDamageMeterDB
	if type(root.profiles) ~= "table" then root.profiles = {} end
	local profileName = root.activeProfile
	if type(profileName) ~= "string" or profileName == "" then
		profileName = "Default"
		root.activeProfile = profileName
	end
	if type(root.profiles[profileName]) ~= "table" then root.profiles[profileName] = {} end
	addon.db = root.profiles[profileName]
	return addon.db
end

local function setDefault(db, key, value)
	if db[key] == nil then db[key] = value end
end

local function initializeProfile()
	local db = ensureDB()
	setDefault(db, "damageMeterEnabled", true)
	setDefault(db, "damageMeterWindowCount", 1)
	setDefault(db, "damageMeterUpdateRate", 0.1)
	setDefault(db, "damageMeterEditModeSample", true)
	setDefault(db, "damageMeterAutomaticClear", "never")
	if type(db.damageMeterAutomaticClearInstances) ~= "table" then
		db.damageMeterAutomaticClearInstances = {
			party = true,
			raid = true,
			scenario = true,
		}
	end
	return db
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
	if event == "ADDON_LOADED" and loadedAddon == addonName then
		initializeProfile()
	elseif event == "PLAYER_LOGIN" then
		initializeProfile()
		if addon.DamageMeter and addon.DamageMeter.Init then addon.DamageMeter:Init() end
	end
end)
