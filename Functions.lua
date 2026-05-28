local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedDamageMeter")
local SharedMedia = LibStub("LibSharedMedia-3.0", true)

addon.functions = addon.functions or {}

local GLOBAL_FONT_CONFIG_KEY = "__EQOL_GLOBAL_FONT__"
local GLOBAL_FONT_CONFIG_LABEL = "Use global font config"
local GLOBAL_FONT_STYLE_CONFIG_KEY = "__EQOL_GLOBAL_FONT_STYLE__"
local GLOBAL_FONT_STYLE_CONFIG_LABEL = "Use global font styling"
local FONT_STYLE_NONE = "NONE"
local FONT_STYLE_OUTLINE = "OUTLINE"
local FONT_STYLE_THICKOUTLINE = "THICKOUTLINE"
local FONT_STYLE_MONOCHROME = "MONOCHROME"
local FONT_STYLE_MONOCHROMEOUTLINE = "MONOCHROMEOUTLINE"
local FONT_STYLE_MONOCHROMETHICKOUTLINE = "MONOCHROMETHICKOUTLINE"
local FONT_STYLE_SHADOW = "SHADOW"
local FONT_STYLE_SHADOWOUTLINE = "SHADOWOUTLINE"
local FONT_STYLE_SHADOWTHICKOUTLINE = "SHADOWTHICKOUTLINE"
local GLOBAL_FONT_STATE_VERSION = 0
local EMPTY_TABLE = {}
local LSM_CACHE = {}
local FONT_STYLE_ORDER = {
	FONT_STYLE_NONE,
	FONT_STYLE_OUTLINE,
	FONT_STYLE_THICKOUTLINE,
	FONT_STYLE_MONOCHROME,
	FONT_STYLE_MONOCHROMEOUTLINE,
	FONT_STYLE_MONOCHROMETHICKOUTLINE,
	FONT_STYLE_SHADOW,
	FONT_STYLE_SHADOWOUTLINE,
	FONT_STYLE_SHADOWTHICKOUTLINE,
}
local FONT_STYLE_ALIASES = {
	[""] = FONT_STYLE_NONE,
	NONE = FONT_STYLE_NONE,
	OUTLINE = FONT_STYLE_OUTLINE,
	THICKOUTLINE = FONT_STYLE_THICKOUTLINE,
	MONOCHROME = FONT_STYLE_MONOCHROME,
	MONOCHROMEOUTLINE = FONT_STYLE_MONOCHROMEOUTLINE,
	MONOCHROMETHICKOUTLINE = FONT_STYLE_MONOCHROMETHICKOUTLINE,
	["OUTLINE,MONOCHROME"] = FONT_STYLE_MONOCHROMEOUTLINE,
	["MONOCHROME,OUTLINE"] = FONT_STYLE_MONOCHROMEOUTLINE,
	["THICKOUTLINE,MONOCHROME"] = FONT_STYLE_MONOCHROMETHICKOUTLINE,
	["MONOCHROME,THICKOUTLINE"] = FONT_STYLE_MONOCHROMETHICKOUTLINE,
	DROPSHADOW = FONT_STYLE_SHADOW,
	STRONGDROPSHADOW = FONT_STYLE_SHADOW,
	SHADOW = FONT_STYLE_SHADOW,
	SHADOWOUTLINE = FONT_STYLE_SHADOWOUTLINE,
	SHADOWTHICKOUTLINE = FONT_STYLE_SHADOWTHICKOUTLINE,
}
local FONT_STYLE_DESCRIPTORS = {
	[FONT_STYLE_NONE] = { flags = nil, shadowAlpha = 0, shadowX = 0, shadowY = 0 },
	[FONT_STYLE_OUTLINE] = { flags = "OUTLINE", shadowAlpha = 0, shadowX = 0, shadowY = 0 },
	[FONT_STYLE_THICKOUTLINE] = { flags = "THICKOUTLINE", shadowAlpha = 0, shadowX = 0, shadowY = 0 },
	[FONT_STYLE_MONOCHROME] = { flags = "MONOCHROME", shadowAlpha = 0, shadowX = 0, shadowY = 0 },
	[FONT_STYLE_MONOCHROMEOUTLINE] = { flags = "OUTLINE,MONOCHROME", shadowAlpha = 0, shadowX = 0, shadowY = 0 },
	[FONT_STYLE_MONOCHROMETHICKOUTLINE] = { flags = "THICKOUTLINE,MONOCHROME", shadowAlpha = 0, shadowX = 0, shadowY = 0 },
	[FONT_STYLE_SHADOW] = { flags = nil, shadowAlpha = 1, shadowX = 1, shadowY = -1 },
	[FONT_STYLE_SHADOWOUTLINE] = { flags = "OUTLINE", shadowAlpha = 0.6, shadowX = 1, shadowY = -1 },
	[FONT_STYLE_SHADOWTHICKOUTLINE] = { flags = "THICKOUTLINE", shadowAlpha = 0.6, shadowX = 1, shadowY = -1 },
}

local function normalizeMediaType(mediaType)
	if type(mediaType) ~= "string" or mediaType == "" then return nil end
	return string.lower(mediaType)
end

local function getSharedMedia()
	if SharedMedia and SharedMedia.HashTable then return SharedMedia end
	SharedMedia = LibStub("LibSharedMedia-3.0", true)
	return SharedMedia
end

local function rebuildLSMCache(mediaType)
	local key = normalizeMediaType(mediaType)
	if not key then return nil end
	local cache = LSM_CACHE[key]
	if cache and not cache.dirty then return cache end
	cache = cache or {}
	cache.dirty = false
	cache.hash = EMPTY_TABLE
	cache.names = {}
	local lsm = getSharedMedia()
	if lsm and lsm.HashTable then
		cache.hash = lsm:HashTable(key) or EMPTY_TABLE
		for name in pairs(cache.hash) do
			if type(name) == "string" then cache.names[#cache.names + 1] = name end
		end
		table.sort(cache.names)
	end
	LSM_CACHE[key] = cache
	return cache
end

local function normalizeMediaValue(value)
	if type(value) ~= "string" or value == "" then return nil end
	return value
end

local function isMediaPath(value)
	return type(value) == "string" and (value:find("\\", 1, true) or value:find("/", 1, true)) ~= nil
end

local function isGlobalFontConfigValue(value) return normalizeMediaValue(value) == GLOBAL_FONT_CONFIG_KEY end
local function isGlobalFontStyleConfigValue(value) return normalizeMediaValue(value) == GLOBAL_FONT_STYLE_CONFIG_KEY end

local function normalizeFontStyleValue(value)
	if type(value) ~= "string" then return nil end
	value = value:gsub("^%s+", ""):gsub("%s+$", "")
	if value == "" then return FONT_STYLE_NONE end
	return FONT_STYLE_ALIASES[string.upper(value)]
end

local function isKnownFontAsset(value)
	if type(value) ~= "string" or value == "" then return false end
	local fileAssetAPI = _G.C_UIFileAsset
	if not (fileAssetAPI and fileAssetAPI.IsKnownFile) then return true end
	local ok, known = pcall(fileAssetAPI.IsKnownFile, value)
	return ok and known == true
end

local function getFontStyleLabel(style)
	if style == FONT_STYLE_NONE then return _G.NONE or "None" end
	if style == FONT_STYLE_OUTLINE then return L["Outline"] or "Outline" end
	if style == FONT_STYLE_THICKOUTLINE then return L["Thick Outline"] or "Thick Outline" end
	if style == FONT_STYLE_MONOCHROME then return L["Monochrome"] or "Monochrome" end
	if style == FONT_STYLE_MONOCHROMEOUTLINE then return L["Monochrome Outline"] or "Monochrome Outline" end
	if style == FONT_STYLE_MONOCHROMETHICKOUTLINE then return L["Monochrome Thick"] or "Monochrome Thick" end
	if style == FONT_STYLE_SHADOW then return L["Drop shadow"] or "Drop shadow" end
	if style == FONT_STYLE_SHADOWOUTLINE then return L["Shadow Outline"] or "Shadow Outline" end
	if style == FONT_STYLE_SHADOWTHICKOUTLINE then return L["Shadow Thick"] or "Shadow Thick" end
	return tostring(style or "")
end

function addon.functions.GetLSMMediaNames(mediaType)
	local cache = rebuildLSMCache(mediaType)
	return (cache and cache.names) or EMPTY_TABLE
end

function addon.functions.GetGlobalFontConfigKey() return GLOBAL_FONT_CONFIG_KEY end

function addon.functions.GetGlobalFontConfigLabel()
	return (L and L["useGlobalFontConfig"]) or GLOBAL_FONT_CONFIG_LABEL
end

function addon.functions.ResolveLSMMedia(mediaType, configured, fallback, allowPath)
	local mediaKind = normalizeMediaType(mediaType)
	local fallbackValue = normalizeMediaValue(fallback)
	local configuredValue = normalizeMediaValue(configured)
	if isGlobalFontConfigValue(configuredValue) then return fallbackValue end
	if not configuredValue then return fallbackValue end
	if configuredValue == fallbackValue then return configuredValue end
	local lsm = getSharedMedia()
	if mediaKind and lsm then
		if lsm.IsValid and lsm:IsValid(mediaKind, configuredValue) then
			local fetched = lsm.Fetch and lsm:Fetch(mediaKind, configuredValue, true)
			if type(fetched) == "string" and fetched ~= "" then return fetched end
			return fallbackValue
		end
		if lsm.HashTable then
			local hash = lsm:HashTable(mediaKind) or {}
			local byName = hash[configuredValue]
			if type(byName) == "string" and byName ~= "" then return byName end
			for _, path in pairs(hash) do
				if path == configuredValue then return configuredValue end
			end
		end
	end
	if allowPath ~= false and mediaKind ~= "font" and isMediaPath(configuredValue) then return configuredValue end
	return fallbackValue
end

function addon.functions.GetGlobalFontStyleConfigKey() return GLOBAL_FONT_STYLE_CONFIG_KEY end

function addon.functions.GetGlobalFontStyleConfigLabel()
	return (L and L["useGlobalFontStyleConfig"]) or GLOBAL_FONT_STYLE_CONFIG_LABEL
end

function addon.functions.GetGlobalFontStateVersion() return GLOBAL_FONT_STATE_VERSION end

function addon.functions.GetFontStyleOptionList(includeGlobalOption)
	local list = {}
	if includeGlobalOption == true then
		list[#list + 1] = {
			value = GLOBAL_FONT_STYLE_CONFIG_KEY,
			label = addon.functions.GetGlobalFontStyleConfigLabel(),
		}
	end
	for i = 1, #FONT_STYLE_ORDER do
		local key = FONT_STYLE_ORDER[i]
		list[#list + 1] = {
			value = key,
			label = getFontStyleLabel(key),
		}
	end
	return list
end

function addon.functions.NormalizeFontStyleChoice(style, fallback, keepGlobalOption)
	local configured = normalizeMediaValue(style)
	if keepGlobalOption ~= false and isGlobalFontStyleConfigValue(configured) then return configured end
	local normalized = normalizeFontStyleValue(configured)
	if normalized then return normalized end
	local fallbackValue = normalizeMediaValue(fallback)
	if keepGlobalOption ~= false and isGlobalFontStyleConfigValue(fallbackValue) then return fallbackValue end
	return normalizeFontStyleValue(fallbackValue) or FONT_STYLE_OUTLINE
end

function addon.functions.ResolveFontStyleChoice(style, fallback)
	local choice = addon.functions.NormalizeFontStyleChoice(style, fallback, true)
	if isGlobalFontStyleConfigValue(choice) then
		return addon.functions.NormalizeFontStyleChoice(addon.db and addon.db.globalFontStyle, FONT_STYLE_OUTLINE, false)
	end
	return addon.functions.NormalizeFontStyleChoice(choice, fallback, false)
end

function addon.functions.ApplyFontString(fontString, fontFace, size, style, fallbackFace, fallbackStyle)
	if not (fontString and fontString.SetFont) then return false end
	local face = addon.functions.ResolveLSMMedia("font", fontFace, fallbackFace or STANDARD_TEXT_FONT, false) or fallbackFace or STANDARD_TEXT_FONT
	if isGlobalFontConfigValue(fontFace) then face = fallbackFace or STANDARD_TEXT_FONT end
	local styleChoice = addon.functions.ResolveFontStyleChoice(style, fallbackStyle or FONT_STYLE_OUTLINE)
	local descriptor = FONT_STYLE_DESCRIPTORS[styleChoice] or FONT_STYLE_DESCRIPTORS[FONT_STYLE_OUTLINE]
	local flags = descriptor.flags
	local fontSize = tonumber(size) or 12
	local ok = isKnownFontAsset(face) and fontString:SetFont(face, fontSize, flags)
	if not ok and fallbackFace and fallbackFace ~= face then ok = fontString:SetFont(fallbackFace, fontSize, flags) end
	if fontString.SetShadowColor and fontString.SetShadowOffset then
		if descriptor.shadowAlpha and descriptor.shadowAlpha > 0 then
			fontString:SetShadowColor(0, 0, 0, descriptor.shadowAlpha)
			fontString:SetShadowOffset(descriptor.shadowX or 1, descriptor.shadowY or -1)
		else
			fontString:SetShadowColor(0, 0, 0, 0)
			fontString:SetShadowOffset(0, 0)
		end
	end
	return ok
end
