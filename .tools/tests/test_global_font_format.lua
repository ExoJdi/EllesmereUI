local file = assert(io.open("EllesmereUI.lua"))
local source = file:read("*a")
file:close()
local fonts = {}
local secret = {}
local EUI = { GetFontsDB = function() return fonts end,
    L = function(text) return text end,
    ResolveActiveAccent = function() return 0, 0.5, 1 end }
local env = setmetatable({ EllesmereUI = EUI, issecretvalue = function(v) return v == secret end }, { __index = _G })
local chunk = assert(loadstring(assert(source:match("(function EllesmereUI.GetTimeFormatDB.-)\n%-%- Realm"))))
setfenv(chunk, env)()
assert(EUI.FormatDuration(180) == "3m")
assert(EUI.FormatDuration(3660) == "1h 1m")
assert(EUI.FormatDuration(90000) == "1d 1h")
assert(EUI.FormatDuration(-1) == "0m")
assert(EUI.FormatDuration(nil) == "" and EUI.FormatDuration(secret) == "")
assert(EUI.FormatDurationClock(secret) == nil)
assert(EUI.ColorDurationUnits(secret) == secret)
local f = EUI.GetTimeFormatDB()
f.minutesClock = true
assert(EUI.FormatDuration(180) == "3:00")
assert(EUI.FormatDuration(239) == "3:59")
f.hoursClock = true
assert(EUI.FormatDuration(3660) == "1:01")
assert(EUI.FormatDuration(86400) == "1d 0h")
f.minutesClock, f.hoursClock = nil, nil
f.unitColor = "accent"
assert(EUI.FormatDuration(1380) == "23|cff0080ffm|r")
f.unitColor, f.m = "custom", { r=1, g=0, b=0 }
assert(EUI.FormatDuration(1380) == "23|cffff0000m|r")
local points = { { format="%dm" }, { format="%dh" }, { format="%dd" } }
EUI.ApplyDurationFormatRules(points)
assert(points[1].format == "%dm")
f.minutesClock, f.hoursClock = true, true
EUI.ApplyDurationFormatRules(points)
assert(points[1].format == "%d:%02d" and points[1].components[2].mod == 60)
assert(points[2].format == "%d:%02d" and points[2].components[2].div == 60)
assert(points[3].format == "%dd")
chunk = assert(loadstring("local LOCALE_FONT_FALLBACK, EXPRESSWAY = ...\n" .. assert(source:match("(function EllesmereUI.GetOptionsFontPath.-)\nlocal function MakeFont"))))
EUI.ResolveFontName = function(key) return "resolved:" .. key end
setfenv(chunk, env)(nil, "Expressway")
assert(EUI.GetOptionsFontPath() == "Expressway")
env.EllesmereUIDB = { fonts = { optionsFont="smf:Cyrillic" } }
assert(EUI.GetOptionsFontPath() == "resolved:smf:Cyrillic")
env.EllesmereUIDB.fonts.optionsFont = nil
setfenv(chunk, env)("LocaleFallback", "Expressway")
assert(EUI.GetOptionsFontPath() == "LocaleFallback")
print("Global font and duration format tests passed")
