-- Run: lua scripts/test_standalone.lua <built EnhancedDamageMeter directory>
local root = assert(arg[1], "built addon directory required")
local interfaceVersion = tonumber(arg[2]) or 16001
local function read(path)
	local file = assert(io.open(root .. "/" .. path))
	local text = file:read("*a")
	file:close()
	return text
end
local function section(source, first, last)
	local start = assert(source:find(first, 1, true), first)
	return source:sub(start, assert(source:find(last, start + #first, true), last) - 1)
end
local function compile(source, env)
	if setfenv then return setfenv(assert(loadstring(source)), env) end
	return assert(load(source, "standalone integration", "t", env))
end
local noop = function() end
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for k, v in pairs(value) do result[k] = copy(v) end
	return result
end
local types = { Checkbox = 1, Slider = 2, Color = 3, Dropdown = 4, CheckboxColor = 5, DropdownColor = 6, Collapsible = 7, Divider = 8, MultiDropdown = 9, Input = 10, Label = 11 }
local locale = setmetatable({}, { __index = function(_, key) return key end })
local frames, queue = {}, {}
local parent = {}
local addon = {}
local env = setmetatable({
	EnhanceQoL = parent,
	STANDARD_TEXT_FONT = "fallback", CopyTable = copy,
	GetBuildInfo = function() return "", "", "", interfaceVersion end,
	CreateFrame = function()
		local frame = { RegisterEvent = noop }
		function frame:SetScript(kind, callback) self[kind] = callback end
		frames[#frames + 1] = frame
		return frame
	end,
	LibStub = function(name)
		if name == "AceLocale-3.0" then
			return { GetLocale = function(_, namespace) assert(namespace == "EnhancedDamageMeter"); return locale end }
		end
		if name == "LibSharedMedia-3.0" then
			return { HashTable = function() return { delayed = "delayed", fallback = "fallback" } end }
		end
	end,
	C_Timer = { After = function(_, callback) queue[#queue + 1] = callback end },
	InCombatLockdown = function() return false end,
}, { __index = _G })
env._G = env
local function loadFile(path) return compile(read(path), env)("EnhancedDamageMeter", addon) end
loadFile("Core.lua")
assert(env.EnhancedDamageMeter == addon and env.EnhanceQoL == parent)
frames[1].OnEvent(frames[1], "ADDON_LOADED", "EnhancedDamageMeter")
assert(addon.variables.isTBC == false and addon.db.damageMeterEnabled)
-- The modern Blizzard selection label reads system:GetSystemName() on click.
-- Exercise the actual shared-library initialization with the standalone host.
local selection = { Label = { SetText = noop } }
local selectionEnv = setmetatable({
	addon = addon, selection = selection,
	frame = { editModeName = "Standalone meter", GetName = function() return "StandaloneFrame" end },
}, { __index = env })
local library = read("libs/EnhanceQoLEditMode/EnhanceQoLEditMode.lua")
compile(section(library, "\tif (addon.variables and addon.variables.isForever)", "\n\tState.selectionRegistry[frame]"), selectionEnv)()
assert(selection.system:GetSystemName() == "Standalone meter", "selected frame label missing")
selection.labelHidden = true
assert(selection.system:GetSystemName() == "", "hidden selection label must remain hidden")
assert(addon.variables.isForever == (interfaceVersion >= 16000 and interfaceVersion < 17000))
print("Standalone selection label passed for interface " .. interfaceVersion)
loadFile("Functions.lua")
loadFile("General/DurationText.lua")
assert(type(addon.functions.ConfigureDurationTextBinding) == "function")
addon.EditModeLib = {
	SettingType = types, activeLayoutName = "test", GetActiveLayoutIndex = function() return 1 end,
	internal = { CreateSettingsView = noop, IsSettingShown = function() return true end },
	AddFrameSettings = function(self, frame, settings) self.settings = settings end,
	SetFrameSettingsNavigation = function(self, frame, navigation) self.navigation = navigation end,
	ConfigureManagerTogglePanel = function(self, options) self.panel = options end,
}
loadFile("Core/EditMode.lua")
loadFile("Core/EditModeNavigation.lua")
loadFile("Core/EditModeNavigationDefaults.lua")
loadFile("Core/EditModeNavigationProfiles.lua")
assert(addon.EditModeNavigation and not parent.EditModeNavigation, "navigation leaked to parent addon")
addon.EditMode:_configureManagerTogglePanel()
assert(addon.EditModeLib.panel.title)
local source = read("DamageMeter.lua")
local defaults = section(source, "local DEFAULT_WINDOW =", "\n}") .. "\n}\nreturn DEFAULT_WINDOW"
env.DEFAULT_WINDOW = compile(defaults, env)()
env.addon, env.L, env.SettingType = addon, locale, types
local configs = {}
local meter = { windows = {} }
function meter:GetConfig(index) configs[index] = configs[index] or {}; return configs[index] end
function meter:SetConfigValue(index, key, value) self:GetConfig(index)[key] = value end
function meter:IsWindowEnabled() return true end
env.DamageMeter = meter
env.GLOBAL_FONT_KEY, env.GLOBAL_STYLE_KEY = "__EQOL_GLOBAL_FONT__", "__EQOL_GLOBAL_STYLE__"
env.clampNumber = compile(section(source, "local function clampNumber(", "\nend") .. "\nend\nreturn clampNumber", env)()
env.normalizeColor = compile(section(source, "local function normalizeColor(", "\nend") .. "\nend\nreturn normalizeColor", env)()
env.normalizeAnchorV = compile(section(source, "local function normalizeAnchorV(", "\nend") .. "\nend\nreturn normalizeAnchorV", env)()
local constructor = section(source, "function DamageMeter:BuildWindowSettings(", "function DamageMeter:BuildWindowButtons(")
for name in constructor:gmatch("(build%w+Options)%(") do env[name] = function() return {} end end
compile(section(source, "local function dropdownSetting(", "local function requestEditModeSettingsRefresh(") .. constructor, env)()
for index = 1, 3 do
	local settings = meter:BuildWindowSettings(index)
	local id = "EDM_DamageMeter" .. index
	addon.EditMode.frames[id] = { frame = {}, navigationRegistration = { managerCategory = "damageMeter" } }
	addon.EditMode:RegisterSettings(id, settings)
	local nav = addon.EditModeNavigation:New({ GetNavigationSettings = function() return settings end })
	nav.options = addon.EditModeLib.navigation
	local model = nav:BuildModel(settings)
	local seen, count = {}, 0
	for _, tab in pairs(model.tabs) do
		assert(nav:CanReset(tab), "missing factory reset: " .. tab.id)
		for _, data in ipairs(tab.settings) do assert(not seen[data]); seen[data] = true end
	end
	for _, data in ipairs(settings) do
		if data.kind ~= types.Collapsible then assert(seen[data], "lost setting: " .. tostring(data.name)); count = count + 1 end
	end
	assert(#nav:Search(model, "damageMeterRowHeight") > 0, "search cannot find row height")
	meter:GetConfig(index).rowHeight, configs[index].texture = 99, "preserve-other-tab"
	nav:ApplyTabDefaults(assert(model.tabs["damageMeterBar" .. index .. "Layout"]))
	assert(configs[index].rowHeight == env.DEFAULT_WINDOW.rowHeight)
	assert(configs[index].texture == "preserve-other-tab", "tab reset changed another tab")
	print("Standalone window " .. index .. ": " .. count .. " settings retained; navigation, search and scoped reset passed")
end
-- Exercise the real standalone font helper together with the current meter.
env.DEFAULT_FONT = "fallback"
env.getGlobalFontStateVersion = function() return 0 end
compile(section(source, "local function applyCachedFontString(", "function DamageMeter:ApplyStatusFontString("), env)()
local available, calls, writes = false, 0, {}
local frame = { index = 1 }
local header = { _damageMeterPlainText = "Damage Done" }
function header:GetParent() return frame end
function header:SetFont(face) calls = calls + 1; return face ~= "delayed" or available end
function header:SetText(value) writes[#writes + 1] = value end
meter.windows[1] = frame
configs[1] = { titleFontFace = "delayed", titleFontSize = 14, titleFontOutline = "OUTLINE" }
local ok, requested = addon.functions.ApplyFontString(header, "delayed", 14, "OUTLINE", "fallback")
assert(ok and requested == false, "fallback must preserve the requested font failure")
meter:ApplyTitleFontString(header, configs[1])
assert(#queue == 1 and header._damageMeterTitleFontPending, "missing font recovery")
meter:ApplyTitleFontString(header, configs[1])
assert(#queue == 1, "duplicate recovery timers")
available = true
table.remove(queue, 1)()
assert(not header._damageMeterTitleFontPending and #queue == 0)
assert(#writes == 2 and writes[1] == "" and writes[2] == "Damage Done", "header glyph layout not refreshed")
local previousCalls = calls
meter:ApplyTitleFontString(header, configs[1])
assert(calls == previousCalls, "successful font not cached")
available = false
header._damageMeterFontPrefix = nil
meter:ApplyTitleFontString(header, configs[1])
for _ = 1, 3 do assert(table.remove(queue, 1))() end
assert(#queue == 0 and header._damageMeterTitleFontRetryCount == 3, "unbounded font retry")
print("Standalone delayed font recovery: fallback, retry coalescing, glyph refresh, cache and retry limit passed")
