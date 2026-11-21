if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUIQoL_Alerts.lua
--  Center-screen text alerts that share ONE movable anchor (Unlock Mode: Alerts).
--  Each alert is a line stacked under the anchor, with its own text, size and
--  color. Short alerts fade out by themselves; a persistent one stays until its
--  condition ends or its alert dismisses it. The lines never take the mouse, so
--  nothing behind them is blocked.
--    Combat Alert     (EllesmereUIQoL.lua)   short
--    Potion Ready     (below)                short
--    Unspent Talents  (below)                persistent
--  Nothing is built or registered for an alert until it is enabled.
--  Every alert's settings and the anchor's spot are per profile, through the
--  extras store (EllesmereUI.QoLExtrasGet / QoLExtrasSet): a profile that never
--  set a key reads the account-wide value saved before the alerts followed profiles.
-------------------------------------------------------------------------------

local ns = select(2, ...)
local EUI = EllesmereUI
local DEFAULT_SIZE = 22
local DEFAULT_POS = { point = "CENTER", relPoint = "CENTER", x = 0, y = 169 }
local GAP = 4

local function DB(key) return EUI.QoLExtrasGet(key) end

-------------------------------------------------------------------------------
--  General Notification (addon-owned frames only)
-------------------------------------------------------------------------------
local GN = {}
EUI.GeneralNotification = GN
do
    local anchor, entries, byFrame, registered, layingOut
    local function Width() return math.max(160, math.min(1200, tonumber(DB("generalNotificationWidth")) or 400)) end
    local function Position()
        return DB("generalNotificationPos") or { point = "CENTER", relPoint = "CENTER", x = 0, y = 160 }
    end
    local function Place()
        if not anchor then return end
        local p = Position()
        anchor:ClearAllPoints()
        anchor:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
    end
    local function EnsureAnchor()
        if anchor then return end
        entries, byFrame = {}, {}
        anchor = CreateFrame("Frame", nil, UIParent)
        anchor:EnableMouse(false)
        anchor:SetSize(Width(), 36)
        Place()
    end
    GN.GetWidth = Width
    local function ResetText(fs)
        if not fs then return end
        fs:ClearAllPoints()
        fs:SetPoint("CENTER")
        fs:SetWidth(0); fs:SetHeight(0)
        fs:SetWordWrap(true); fs:SetNonSpaceWrap(false)
        fs:SetJustifyH("CENTER")
    end
    function GN.IsAttached(frame) return byFrame and byFrame[frame] ~= nil end
    function GN.Layout()
        if not anchor or layingOut or not DB("generalNotificationEnabled") then return end
        layingOut = true
        local width, offset = Width(), 0
        local grow = DB("generalNotificationGrow") or "CENTER"
        if grow ~= "LEFT" and grow ~= "RIGHT" then grow = "CENTER" end
        local point = grow == "CENTER" and "TOP" or ("TOP" .. grow)
        local wrap = DB("generalNotificationWrap") == true
        for _, entry in ipairs(entries) do
            local f, fs = entry.frame, entry.text
            if f:IsVisible() then
                if fs then
                    local left, right = entry.left or 0, entry.right or 0
                    fs:ClearAllPoints()
                    fs:SetPoint(point, f, point, grow == "LEFT" and left or (grow == "RIGHT" and -right or (left - right) / 2), 0)
                    fs:SetWidth(math.max(1, width - left - right))
                    fs:SetHeight(0)
                    fs:SetJustifyH(grow)
                    fs:SetWordWrap(wrap)
                    fs:SetNonSpaceWrap(wrap)
                    local _, fontSize = fs:GetFont()
                    local minimum = (fontSize or DEFAULT_SIZE) + 14
                    local height = fs:GetStringHeight()
                    if (issecretvalue and issecretvalue(height)) or type(height) ~= "number" then
                        height = minimum
                        fs:SetHeight(height)
                    end
                    f:SetSize(width, math.max(minimum, height + 8))
                end
                f:ClearAllPoints()
                f:SetPoint(point, anchor, point, 0, -offset)
                offset = offset + f:GetHeight() + GAP
            end
        end
        anchor:SetSize(width, 36)
        layingOut = false
    end
    function GN.Detach(frame)
        local entry = byFrame and byFrame[frame]
        if not entry then return end
        byFrame[frame] = nil
        for i, e in ipairs(entries) do if e == entry then table.remove(entries, i); break end end
        frame:SetScript("OnShow", entry.onShow)
        frame:SetScript("OnHide", entry.onHide)
        frame:SetSize(entry.width, entry.height)
        ResetText(entry.text)
        if entry.restore then entry.restore() end
        GN.Layout()
    end
    function GN.Sync(frame, text, enabled, order, restore, left, right)
        if not enabled or not DB("generalNotificationEnabled") then GN.Detach(frame); return false end
        EnsureAnchor()
        local entry = byFrame[frame]
        if not entry then
            entry = { frame = frame, text = text, order = order, restore = restore,
                width = frame:GetWidth(), height = frame:GetHeight(),
                onShow = frame:GetScript("OnShow"), onHide = frame:GetScript("OnHide") }
            byFrame[frame] = entry
            entries[#entries + 1] = entry
            table.sort(entries, function(a, b) return a.order < b.order end)
            frame:SetScript("OnShow", function(self, ...)
                if entry.onShow then entry.onShow(self, ...) end
                GN.Layout()
            end)
            frame:SetScript("OnHide", function(self, ...)
                if entry.onHide then entry.onHide(self, ...) end
                GN.Layout()
            end)
        end
        if entry.text ~= text then ResetText(entry.text) end
        entry.text, entry.left, entry.right = text, left, right
        return true
    end
    local function RegisterUnlock()
        if registered then return end
        registered = true
        EUI:RegisterUnlockElements({ EUI.MakeUnlockElement({
            key = "EUI_GeneralNotification", label = "General Notification", group = "Quality of Life", order = 719,
            noResize = true,
            isHidden = function() return not DB("generalNotificationEnabled") end,
            getFrame = function() if DB("generalNotificationEnabled") then EnsureAnchor(); return anchor end end,
            getSize = function() return Width(), anchor and anchor:GetHeight() or 36 end,
            savePos = function(_, point, relPoint, x, y)
                if not point then return end
                EUI.QoLExtrasSet("generalNotificationPos", { point = point, relPoint = relPoint, x = x, y = y })
                if not EUI._unlockActive then Place(); GN.Layout() end
            end,
            loadPos = Position,
            clearPos = function() EUI.QoLExtrasSet("generalNotificationPos", false); Place(); GN.Layout() end,
            applyPos = function() Place(); GN.Layout() end,
        }) })
    end
    function GN.Apply()
        if DB("generalNotificationEnabled") then
            RegisterUnlock(); EnsureAnchor(); Place()
        elseif not entries or not entries[1] then
            return
        else
            while entries[1] do GN.Detach(entries[1].frame) end
            if EUI._applyMovementAlert then EUI._applyMovementAlert() end
            return
        end
        if EUI.Alerts then EUI.Alerts.Refresh() end
        if EUI._applyGroupDeathAlert then EUI._applyGroupDeathAlert() end
        if EUI._applyMovementAlert then EUI._applyMovementAlert() end
        if EUI._applyTimeSpiral then EUI._applyTimeSpiral() end
        if EUI._applyGateway then EUI._applyGateway() end
        GN.Layout()
    end
    EUI._applyGeneralNotification = GN.Apply
end

-------------------------------------------------------------------------------
--  Core: anchor + stacked lines
-------------------------------------------------------------------------------
local Alerts = {}
EUI.Alerts = Alerts

-- Stack order, top first. sizeKey/enabledKey are the alert's own settings.
local DEFS = {
    { id = "talent", sizeKey = "talentAlertTextSize", enabledKey = "talentAlertEnabled", persistent = true },
    { id = "combat", sizeKey = "combatAlertTextSize", enabledKey = "combatAlertEnabled", hold = 1.2 },
    { id = "potion", sizeKey = "potionAlertTextSize", enabledKey = "potionAlertEnabled", hold = 3 },
}
local lines = {}
local anchor

-- Defaults for the two new alerts; the options cogs read these too.
Alerts.DEFAULTS = {
    potionAlert = { text = "Potion Ready",          color = { r = 0.1, g = 1,    b = 0.1 } },
    talentAlert = { text = "Unspent talent points", color = { r = 1,   g = 0.82, b = 0   } },
}

local function SizeOf(def) return DB(def.sizeKey) or DEFAULT_SIZE end

local function AnyEnabled()
    for _, def in ipairs(DEFS) do
        if DB(def.enabledKey) then return true end
    end
    return false
end

local function AnyStandaloneEnabled()
    for _, def in ipairs(DEFS) do
        if DB(def.enabledKey) and not (DB("generalNotificationEnabled") and DB(def.id .. "AlertGeneralNotification")) then return true end
    end
    return false
end

local function MaxSize()
    local m = DEFAULT_SIZE
    for _, def in ipairs(DEFS) do
        if DB(def.enabledKey) then m = math.max(m, SizeOf(def)) end
    end
    return m
end

-- The old Combat Alert position carries over until the anchor is moved.
local function AnchorPos()
    local p = DB("alertsPos")
    if p and p.point then return p end
    p = DB("combatAlertPos")
    if p and p.point then return p end
    return DEFAULT_POS
end

local function PlaceAnchor()
    if not anchor then return end
    local size = MaxSize()
    anchor:SetSize(size * 7, size + 14)
    local pos = AnchorPos()
    anchor:ClearAllPoints()
    anchor:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
end

local function EnsureAnchor()
    if anchor then return end
    anchor = CreateFrame("Frame", nil, UIParent)
    anchor:EnableMouse(false)
    anchor:SetMouseClickEnabled(false)
    PlaceAnchor()
end

local function Layout()
    if not anchor then return end
    local offset = 0
    for i, def in ipairs(DEFS) do
        local line = lines[def.id]
        local attached = line and GN.Sync(line.frame, line.text, DB(def.enabledKey) and DB(def.id .. "AlertGeneralNotification"), i, Alerts.Refresh)
        if line and line.frame:IsShown() and not attached then
            line.frame:ClearAllPoints()
            line.frame:SetPoint("TOP", anchor, "TOP", 0, -offset)
            offset = offset + line.frame:GetHeight() + GAP
        end
    end
    GN.Layout()
end

local function Style(line)
    local outline = (EUI.GetFontOutlineFlag("extras")) or ""
    if not outline:find("OUTLINE") then
        outline = (outline == "") and "OUTLINE" or (outline .. ", OUTLINE")
    end
    local size = SizeOf(line.def)
    EUI.ApplyModuleFont(line.text, nil, size, "extras", outline)
    line.frame:SetSize(size * 7, size + 14)
end

local function NewLine(def)
    local line = { def = def }
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(60)
    f:EnableMouse(false)
    f:Hide()
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("CENTER")
    line.frame, line.text = f, fs

    -- Short: fade in, hold, fade out, then hide. Also used for previews.
    local short = f:CreateAnimationGroup()
    local a1 = short:CreateAnimation("Alpha")
    a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.15); a1:SetOrder(1)
    local a2 = short:CreateAnimation("Alpha")
    a2:SetFromAlpha(1); a2:SetToAlpha(1); a2:SetDuration(def.hold or 1.2); a2:SetOrder(2)
    local a3 = short:CreateAnimation("Alpha")
    a3:SetFromAlpha(1); a3:SetToAlpha(0); a3:SetDuration(0.5); a3:SetOrder(3)
    short:SetScript("OnFinished", function() f:Hide() end)

    -- Persistent: fade in and stay.
    local stay = f:CreateAnimationGroup()
    local s1 = stay:CreateAnimation("Alpha")
    s1:SetFromAlpha(0); s1:SetToAlpha(1); s1:SetDuration(0.15); s1:SetOrder(1)

    f:SetScript("OnShow", Layout)
    f:SetScript("OnHide", function()
        short:Stop(); stay:Stop()
        line.persistentShown = false
        Layout()
    end)

    -- preview: play the short animation even on a persistent line, and never
    -- disturb a real persistent alert that is already up.
    function line.Show(text, r, g, b, preview)
        if EUI._unlockActive then return end
        local real = def.persistent and not preview
        if preview and line.persistentShown then return end
        EnsureAnchor(); PlaceAnchor(); Style(line)
        fs:SetText(text)
        fs:SetTextColor(r or 1, g or 1, b or 1)
        Layout()
        if real and line.persistentShown then return end   -- already up: only the text changed
        short:Stop(); stay:Stop()
        f:SetAlpha(1)
        f:Show()
        if real then
            line.persistentShown = true
            stay:Play()
        else
            short:Play()
        end
    end

    function line.Hide() f:Hide() end

    function line.Dismiss()
        f:Hide()
        if line.onDismiss then line.onDismiss() end
    end

    return line
end

-- The line for an alert, built on first use.
function Alerts.Line(id)
    if not lines[id] then
        for _, def in ipairs(DEFS) do
            if def.id == id then lines[id] = NewLine(def) end
        end
    end
    return lines[id]
end

function Alerts.Hide(id)
    if lines[id] then lines[id].Hide() end
end

-- Re-apply size, position and stacking (Text Size sliders, Unlock Mode).
function Alerts.Refresh()
    if anchor or AnyEnabled() then EnsureAnchor(); PlaceAnchor() end
    for _, line in pairs(lines) do Style(line) end
    Layout()
end

-- Custom color, or the player's class color when that toggle is on.
function Alerts.Color(prefix, dr, dg, db)
    if DB(prefix .. "UseClassColor") then
        local _, token = UnitClass("player")
        if token then
            local c = EUI.GetClassColor(token)
            return c.r, c.g, c.b
        end
    end
    local c = DB(prefix .. "Color")
    if c then return c.r, c.g, c.b end
    return dr, dg, db
end

local function RegisterUnlock()
    EUI:RegisterUnlockElements({
        EUI.MakeUnlockElement({
            key      = "EUI_CombatAlert",
            label    = "Alerts",
            group    = "Quality of Life",
            order    = 721,
            noResize = true,
            isHidden = function() return not AnyStandaloneEnabled() end,
            getFrame = function()
                if not AnyStandaloneEnabled() then return nil end
                EnsureAnchor()
                return anchor
            end,
            getSize = function()
                local size = MaxSize()
                return size * 7, size + 14
            end,
            savePos = function(_, point, relPoint, x, y)
                if not point then return end
                EUI.QoLExtrasSet("alertsPos", { point = point, relPoint = relPoint, x = x, y = y })
                if anchor and not EUI._unlockActive then PlaceAnchor(); Layout() end
            end,
            loadPos = function()
                local p = AnchorPos()
                return { point = p.point, relPoint = p.relPoint, x = p.x, y = p.y }
            end,
            clearPos = function()
                -- false, not nil: an unset key would read the old account-wide spot.
                EUI.QoLExtrasSet("alertsPos", false)
                EUI.QoLExtrasSet("combatAlertPos", false)
                if anchor then PlaceAnchor(); Layout() end
            end,
            applyPos = function()
                if anchor or AnyEnabled() then EnsureAnchor(); PlaceAnchor(); Layout() end
            end,
        }),
    })
end

local coreBoot = CreateFrame("Frame")
coreBoot:RegisterEvent("PLAYER_LOGIN")
coreBoot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    RegisterUnlock()
    GN.Apply()
end)

-------------------------------------------------------------------------------
--  Potion Ready
--  The potion you drank is found from its on-use spell (UNIT_SPELLCAST_SUCCEEDED),
--  its cooldown is read once from the item API, and one timer fires at the end.
--  The item cooldown API is not secret-restricted, so it is readable in combat.
--  BAG_UPDATE_COOLDOWN is only listened to while a potion is waiting to start or
--  finish, so presses of other abilities cost nothing in between.
-------------------------------------------------------------------------------
do
    local POTION_CLASS = Enum.ItemClass.Consumable
    local POTION_SUBCLASS = 1   -- Enum.ItemConsumableSubclass.Potion
    local MIN_CD = 1.5   -- anything longer is the potion's own cooldown, not the GCD
    local GetInstant = C_Item and C_Item.GetItemInfoInstant
    local GetUseSpell = C_Item and C_Item.GetItemSpell

    local watcher
    local installed = false
    local spellToItem = {}  -- on-use spellID -> itemID, for potions seen in bags
    local seen = {}         -- itemID -> true (mapped potion) / false (not a potion)
    local timer, pendingItem, usedItem

    local function ShowAlert(preview)
        local D = Alerts.DEFAULTS.potionAlert
        local r, g, b = Alerts.Color("potionAlert", D.color.r, D.color.g, D.color.b)
        Alerts.Line("potion").Show(DB("potionAlertText") or D.text, r, g, b, preview)
    end

    -- start, duration; nil if the item has no cooldown data.
    local function ReadCD(itemID)
        local start, dur = C_Container.GetItemCooldown(itemID)
        if not start or issecretvalue(start) or issecretvalue(dur) then return nil end
        return start, dur
    end

    local function UpdateCooldownEvent()
        if not watcher then return end
        if installed and (pendingItem or usedItem) then
            watcher:RegisterEvent("BAG_UPDATE_COOLDOWN")
        else
            watcher:UnregisterEvent("BAG_UPDATE_COOLDOWN")
        end
    end

    local function CancelTimer()
        if timer then timer:Cancel(); timer = nil end
        pendingItem = nil
    end

    local ArmTimer

    local function OnReady()
        timer = nil
        local itemID = pendingItem
        pendingItem = nil
        if not itemID then UpdateCooldownEvent(); return end
        -- Last one used up: nothing to be ready for.
        if (C_Item.GetItemCount(itemID) or 0) <= 0 then UpdateCooldownEvent(); return end
        -- A cooldown extended since we armed is re-read here, so the alert is
        -- only for a potion that is really ready.
        local start, dur = ReadCD(itemID)
        if start and dur and dur > MIN_CD then
            local left = start + dur - GetTime()
            if left > 0.5 then ArmTimer(itemID, left); return end
        end
        UpdateCooldownEvent()
        ShowAlert()
    end

    ArmTimer = function(itemID, delay)
        CancelTimer()
        pendingItem = itemID
        timer = C_Timer.NewTimer(math.max(delay, 0), OnReady)
        UpdateCooldownEvent()
    end

    -- Try to start tracking the potion just used. Returns true once armed or given up.
    local function TrackUsed()
        local itemID = usedItem
        if not itemID then return true end
        local start, dur = ReadCD(itemID)
        if not start then
            usedItem = nil
            UpdateCooldownEvent()
            return true
        end
        if dur > MIN_CD then
            usedItem = nil
            ArmTimer(itemID, start + dur - GetTime())
            return true
        end
        return false   -- cooldown not started yet; wait for BAG_UPDATE_COOLDOWN
    end

    -- Item IDs only (no per-slot tables); each item is classified once.
    local function ScanBag(bag)
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and seen[id] == nil then
                local _, _, _, _, _, classID, subID = GetInstant(id)
                if classID == POTION_CLASS and subID == POTION_SUBCLASS then
                    local _, spellID = GetUseSpell(id)
                    if spellID then spellToItem[spellID] = id; seen[id] = true end
                else
                    seen[id] = false
                end
            end
        end
    end

    -- Every bag when turned on; afterwards only the bags BAG_UPDATE flagged.
    local dirtyBags = {}
    local function ScanBags(onlyDirty)
        if not (GetInstant and GetUseSpell) then return end
        for bag = 0, NUM_BAG_SLOTS do
            if not onlyDirty or dirtyBags[bag] then
                dirtyBags[bag] = nil
                ScanBag(bag)
            end
        end
    end

    local function OnEvent(_, event, ...)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            local _, _, spellID = ...
            if issecretvalue(spellID) then return end
            local itemID = spellToItem[spellID]
            if not itemID then return end
            usedItem = itemID
            if not TrackUsed() then
                UpdateCooldownEvent()
                -- No cooldown ever appeared (nothing to wait for): stop listening.
                C_Timer.After(2, function()
                    if usedItem == itemID then usedItem = nil; UpdateCooldownEvent() end
                end)
            end
        elseif event == "BAG_UPDATE_COOLDOWN" then
            if usedItem and TrackUsed() then return end
            if pendingItem then
                -- A reset (encounter end, death) makes the potion ready early.
                local start, dur = ReadCD(pendingItem)
                if start and dur and dur <= MIN_CD then
                    if timer then timer:Cancel(); timer = nil end
                    OnReady()
                end
            end
        elseif event == "BAG_UPDATE" then
            local bag = ...
            if bag then dirtyBags[bag] = true end
        elseif event == "BAG_UPDATE_DELAYED" then
            ScanBags(true)
        end
    end

    local function Apply()
        local on = DB("potionAlertEnabled")
        if on and not installed then
            watcher:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
            watcher:RegisterEvent("BAG_UPDATE")
            watcher:RegisterEvent("BAG_UPDATE_DELAYED")
            installed = true
            ScanBags()
        elseif not on and installed then
            watcher:UnregisterAllEvents()
            installed = false
            CancelTimer()
            usedItem = nil
            Alerts.Hide("potion")
        end
        if installed then UpdateCooldownEvent() end
        Alerts.Refresh()
    end

    watcher = CreateFrame("Frame")
    watcher:SetScript("OnEvent", OnEvent)

    EUI._applyPotionAlert = Apply
    EUI._potionAlertFrame = Alerts.Refresh
    EUI._potionAlertPreview = function() ShowAlert(true) end

    local boot = CreateFrame("Frame")
    boot:RegisterEvent("PLAYER_LOGIN")
    boot:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        Apply()
    end)
end

-------------------------------------------------------------------------------
--  Unspent Talents (persistent)
--  Same check and trigger events as Blizzard's own talent micro button alert
--  (C_ClassTalents.HasUnspent*), evaluated once after a burst of events.
--  The line stays up while points are unspent, until the talent window opens
--  (Blizzard's PlayerSpellsFrame.TalentTab.Show, an EventRegistry callback); it
--  comes back when new points appear (a level-up), and waits for combat to end
--  before showing. One that came due while Unlock Mode was open shows once it
--  closes.
-------------------------------------------------------------------------------
do
    -- Blizzard's own trigger events for its talent alert.
    local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_TALENT_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_LEVEL_CHANGED" }

    local watcher
    local installed = false
    local lastHad = false
    local dismissed = false
    local dirty = false

    local function HasUnspent()
        if not C_SpecializationInfo.CanPlayerUseTalentUI() then return false end
        return (C_ClassTalents.HasUnspentTalentPoints() or C_ClassTalents.HasUnspentHeroTalentPoints()) and true or false
    end

    local function Line()
        local line = Alerts.Line("talent")
        line.onDismiss = function() dismissed = true end
        return line
    end

    local function ShowAlert(preview)
        local D = Alerts.DEFAULTS.talentAlert
        local r, g, b = Alerts.Color("talentAlert", D.color.r, D.color.g, D.color.b)
        Line().Show(DB("talentAlertText") or D.text, r, g, b, preview)
    end

    local function Evaluate()
        dirty = false
        if not installed then return end
        if InCombatLockdown() then ns.CombatQueue.Defer("TalentAlert", Evaluate); return end
        local has = HasUnspent()
        if has then
            if not lastHad then dismissed = false end        -- new points: show again
            if not dismissed then ShowAlert() end
        else
            dismissed = false
            Alerts.Hide("talent")
        end
        lastHad = has
    end

    local function MarkDirty()
        if dirty then return end
        dirty = true
        C_Timer.After(0, Evaluate)   -- next frame: one pass per burst of events
    end

    local listening = false
    local function Apply()
        local on = DB("talentAlertEnabled")
        if on and not installed then
            for _, e in ipairs(EVENTS) do watcher:RegisterEvent(e) end
            installed = true
            lastHad, dismissed = false, false
            if not listening then
                listening = true
                EUI:RegisterUnlockModeListener("EUI_TalentAlert", function(active)
                    if not active and installed then MarkDirty() end
                end)
                -- Opening the talents counts as seeing the alert.
                EventRegistry:RegisterCallback("PlayerSpellsFrame.TalentTab.Show", function()
                    if installed then Line().Dismiss() end
                end, "EUI_TalentAlert")
            end
            MarkDirty()
        elseif not on and installed then
            watcher:UnregisterAllEvents()
            installed = false
            Alerts.Hide("talent")
        elseif on then
            -- Already on (a profile switch): a line that is up takes this profile's text and color.
            MarkDirty()
        end
        Alerts.Refresh()
    end

    watcher = CreateFrame("Frame")
    watcher:SetScript("OnEvent", function(_, event)
        -- A level-up brings new points: a dismissed alert shows again.
        if event == "PLAYER_LEVEL_CHANGED" then dismissed = false end
        MarkDirty()
    end)

    EUI._applyTalentAlert = Apply
    EUI._talentAlertFrame = Alerts.Refresh
    EUI._talentAlertPreview = function()
        -- A live alert gets its text/color refreshed; otherwise a short sample.
        ShowAlert(not Line().persistentShown)
    end

    local boot = CreateFrame("Frame")
    boot:RegisterEvent("PLAYER_LOGIN")
    boot:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        Apply()
    end)
end
