-- luacheck: globals Settings SettingsPanel StaticPopupDialogs StaticPopup_Show C_AddOns C_UI OKAY CANCEL CLOSE
local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedDamageMeter")
local serializer = LibStub("AceSerializer-3.0", true)
local deflate = LibStub("LibDeflate", true)

local EXPORT_KIND = "damageMeter"
local EXPORT_VERSION = 1
local DIALOG_EXPORT = "EDM_DAMAGE_METER_EXPORT"
local DIALOG_IMPORT = "EDM_DAMAGE_METER_IMPORT"

local function db()
	if type(addon.db) ~= "table" then addon.db = {} end
	return addon.db
end

local function copyValue(value)
	if type(value) == "table" then return CopyTable(value) end
	return value
end

local function sanitizeProfileData(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return nil end
	seen[value] = true
	local result = {}
	for key, child in pairs(value) do
		if type(key) == "string" or type(key) == "number" then
			local sanitized = sanitizeProfileData(child, seen)
			if sanitized ~= nil then result[key] = sanitized end
		end
	end
	seen[value] = nil
	return result
end

local function isDamageMeterProfileKey(key)
	return type(key) == "string" and key:find("^damageMeter") ~= nil
end

local function refreshDamageMeter()
	local meter = addon.DamageMeter
	if not meter then return end
	meter.normalizedWindowsDB = nil
	if meter.MarkAllStylesDirty then meter:MarkAllStylesDirty() end
	if meter.UpdateEventState then meter:UpdateEventState() end
	if meter.Refresh then meter:Refresh() end
end

local function encodePayload(payload)
	if not serializer or not deflate then return nil, "NO_LIB" end
	local ok, serialized = pcall(serializer.Serialize, serializer, payload)
	if not ok or type(serialized) ~= "string" or serialized == "" then return nil, "SERIALIZE" end
	local compressed = deflate:CompressDeflate(serialized)
	if not compressed then return nil, "COMPRESS" end
	return deflate:EncodeForPrint(compressed)
end

local function decodePayload(encoded)
	if not serializer or not deflate then return nil, "NO_LIB" end
	encoded = tostring(encoded or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if encoded == "" then return nil, "NO_INPUT" end
	local decoded = deflate:DecodeForPrint(encoded) or deflate:DecodeForWoWChatChannel(encoded) or deflate:DecodeForWoWAddonChannel(encoded)
	if not decoded then return nil, "DECODE" end
	local decompressed = deflate:DecompressDeflate(decoded)
	if not decompressed then return nil, "DECOMPRESS" end
	local ok, payload = serializer:Deserialize(decompressed)
	if not ok or type(payload) ~= "table" then return nil, "DESERIALIZE" end
	local meta = payload.meta
	if type(meta) ~= "table" or meta.kind ~= EXPORT_KIND then return nil, "INVALID" end
	if meta.addon ~= addonName and meta.addon ~= "EnhanceQoL" then return nil, "INVALID" end
	return payload
end

local function captureDamageMeterState()
	local source = db()
	local data = {}
	for key, value in pairs(source) do
		if isDamageMeterProfileKey(key) then data[key] = copyValue(value) end
	end
	return next(data) and data or nil
end

local function exportDamageMeter()
	local data = captureDamageMeterState()
	if type(data) ~= "table" or not next(data) then return nil, "NO_DATA" end
	return encodePayload({
		meta = {
			addon = addonName,
			kind = EXPORT_KIND,
			version = tostring(C_AddOns.GetAddOnMetadata(addonName, "Version") or ""),
			profileVersion = EXPORT_VERSION,
		},
		data = sanitizeProfileData(data),
	})
end

local function importDamageMeter(encoded)
	local payload, reason = decodePayload(encoded)
	if not payload then return false, reason end
	local data = sanitizeProfileData(payload.data)
	if type(data) ~= "table" or not next(data) then return false, "NO_DATA" end
	local target = db()
	for key in pairs(target) do
		if isDamageMeterProfileKey(key) then target[key] = nil end
	end
	local applied = false
	for key, value in pairs(data) do
		if isDamageMeterProfileKey(key) then
			target[key] = value
			applied = true
		end
	end
	if not applied then return false, "NO_DATA" end
	refreshDamageMeter()
	return true
end

local function errorMessage(reason)
	if reason == "NO_LIB" then return "Required import/export libraries are missing." end
	if reason == "NO_INPUT" then return "No import code entered." end
	if reason == "NO_DATA" then return "No Damage Meter settings found." end
	if reason == "INVALID" then return "The import code is not a Damage Meter export." end
	return "The import code could not be read."
end

local function showExportDialog(code)
	StaticPopupDialogs[DIALOG_EXPORT] = StaticPopupDialogs[DIALOG_EXPORT]
		or {
			text = L["Export"] or "Export",
			button1 = CLOSE,
			hasEditBox = true,
			editBoxWidth = 320,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	StaticPopupDialogs[DIALOG_EXPORT].text = string.format("%s %s", L["Export"] or "Export", L["damageMeterTitle"] or "Damage Meter")
	StaticPopupDialogs[DIALOG_EXPORT].OnShow = function(self)
		self:SetFrameStrata("TOOLTIP")
		local editBox = self.editBox or self:GetEditBox()
		editBox:SetText(code or "")
		editBox:HighlightText()
		editBox:SetFocus()
	end
	StaticPopup_Show(DIALOG_EXPORT)
end

local function showImportDialog()
	StaticPopupDialogs[DIALOG_IMPORT] = StaticPopupDialogs[DIALOG_IMPORT]
		or {
			text = "",
			button1 = OKAY,
			button2 = CANCEL,
			hasEditBox = true,
			editBoxWidth = 320,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	StaticPopupDialogs[DIALOG_IMPORT].text = string.format(
		"%s %s\n\n%s",
		L["Import"] or "Import",
		L["damageMeterTitle"] or "Damage Meter",
		L["damageMeterImportConfirm"] or "Importing will overwrite your Damage Meter settings in the active profile."
	)
	StaticPopupDialogs[DIALOG_IMPORT].OnShow = function(self)
		self:SetFrameStrata("TOOLTIP")
		local editBox = self.editBox or self:GetEditBox()
		editBox:SetText("")
		editBox:SetFocus()
	end
	StaticPopupDialogs[DIALOG_IMPORT].EditBoxOnEnterPressed = function(editBox)
		local parent = editBox:GetParent()
		if parent and parent.button1 then parent.button1:Click() end
	end
	StaticPopupDialogs[DIALOG_IMPORT].OnAccept = function(self)
		local editBox = self.editBox or self:GetEditBox()
		local ok, reason = importDamageMeter(editBox:GetText())
		if not ok then
			print("|cff00ff98Enhanced Damage Meter|r: " .. errorMessage(reason))
			return
		end
		print("|cff00ff98Enhanced Damage Meter|r: " .. (L["damageMeterImportSuccess"] or "Damage Meter settings imported."))
	end
	StaticPopup_Show(DIALOG_IMPORT)
end

local function registerProxySetting(category, variable, varType, name, defaultValue, getter, setter)
	return Settings.RegisterProxySetting(category, variable, varType, name, defaultValue, getter, setter)
end

local function createCheckbox(category, key, label, description, defaultValue, getter, setter)
	local setting = registerProxySetting(category, "EDM_" .. key, Settings.VarType.Boolean, label, defaultValue, getter, setter)
	Settings.CreateCheckbox(category, setting, description)
	return setting
end

local function createSlider(category, key, label, description, defaultValue, minValue, maxValue, step, getter, setter)
	local setting = registerProxySetting(category, "EDM_" .. key, Settings.VarType.Number, label, defaultValue, getter, setter)
	local options = Settings.CreateSliderOptions(minValue, maxValue, step)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return string.format("%.1fs", value)
	end)
	Settings.CreateSlider(category, setting, options, description)
	return setting
end

local function createButton(category, label, buttonText, callback)
	if type(label) ~= "string" then label = "" end
	local initializer = CreateSettingsButtonInitializer(label, buttonText, callback, nil, false)
	SettingsPanel:GetLayout(category):AddInitializer(initializer)
	return initializer
end

local function registerSettings()
	if addon.settingsRegistered or not Settings then return end
	addon.settingsRegistered = true
	local category = Settings.RegisterVerticalLayoutCategory("Enhanced Damage Meter")
	Settings.RegisterAddOnCategory(category)
	category:SetShouldSortAlphabetically(false)

	createSlider(category, "damageMeterUpdateRate", L["damageMeterUpdateRate"] or "Update rate", L["damageMeterUpdateRateDesc"] or "How often the damage meter refreshes while live data changes.", 0.1, 0.1, 5, 0.1, function()
		return tonumber(db().damageMeterUpdateRate) or 0.1
	end, function(value)
		db().damageMeterUpdateRate = math.max(0.1, math.min(5, tonumber(value) or 0.1))
		refreshDamageMeter()
	end)

	createCheckbox(category, "damageMeterEditModeSample", L["damageMeterEditModeSample"] or "Show sample data in Edit Mode", L["damageMeterEditModeSampleDesc"] or "Shows sample rows while Edit Mode is open so styling changes are visible without active combat.", true, function()
		return db().damageMeterEditModeSample ~= false
	end, function(value)
		db().damageMeterEditModeSample = value == true
		refreshDamageMeter()
	end)

	createButton(category, "", string.format("%s %s", L["Export"] or "Export", L["damageMeterTitle"] or "Damage Meter"), function()
		local code, reason = exportDamageMeter()
		if not code then
			print("|cff00ff98Enhanced Damage Meter|r: " .. errorMessage(reason))
			return
		end
		showExportDialog(code)
	end)

	createButton(category, "", string.format("%s %s", L["Import"] or "Import", L["damageMeterTitle"] or "Damage Meter"), function()
		showImportDialog()
	end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", registerSettings)
