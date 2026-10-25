-- WoWFA Panel.lua - Persian addon panel + Settings entry + compartment.
-- Design language: the wowfarsi site's "fantasy minimal, smoked glass" -
-- no heavy boxes, 1px gold lines that fade at both ends, diamond/ring/dot
-- sigils (Media/*.tga, drawn white and tinted here).
-- WoW has no real blur: the glass is faked with layered semi-transparent
-- gradients (bg 0.80-0.88 alpha) and a faint gold glow at the top.
--
-- Persian text: every Persian string goes through WoWFA:ShapeText() (the
-- /wowfa mode pipeline shared with the tooltip). refresh() re-shapes all
-- labels so switching modes updates the panel live.

local M = WoWFA
local C = M.C
local FONT = M.FONT
local MEDIA = M.MEDIA
local WHITE = "Interface\\Buttons\\WHITE8X8"

local PANEL_W = 380
local MARGIN = 24

-- read-only copy comes here once the CurseForge page exists; until then the
-- whole "نسخهٔ جدید؟" EditBox branch stays hidden
local CURSEFORGE_URL = nil

local frame = CreateFrame("Frame", "WoWFAPanel", UIParent)
frame:SetFrameStrata("DIALOG")
frame:SetFrameLevel(100)
frame:SetWidth(PANEL_W)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
frame:Hide()
tinsert(UISpecialFrames, "WoWFAPanel") -- ESC closes

-- ------------------------------------------------------------- background
local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetTexture(WHITE)
bg:SetGradient("VERTICAL", CreateColor(C.bg1.r, C.bg1.g, C.bg1.b, 0.88), CreateColor(C.bg2.r, C.bg2.g, C.bg2.b, 0.80))

local topGlow = frame:CreateTexture(nil, "BORDER")
topGlow:SetTexture(MEDIA .. "glow")
topGlow:SetSize(PANEL_W * 0.9, 110)
topGlow:SetPoint("TOP", frame, "TOP", 0, 26)
topGlow:SetVertexColor(C.gold.r, C.gold.g, C.gold.b, 0.10)

local function edge(tex, w, h)
        tex:SetTexture(MEDIA .. (w >= h and "line_h" or "line_v"))
        tex:SetSize(w, h)
        tex:SetVertexColor(C.goldDark.r, C.goldDark.g, C.goldDark.b, 0.9)
        return tex
end

edge(frame:CreateTexture(nil, "BORDER"), PANEL_W - 2, 1):SetPoint("TOP", frame, "TOP", 0, -1)
edge(frame:CreateTexture(nil, "BORDER"), PANEL_W - 2, 1):SetPoint("BOTTOM", frame, "BOTTOM", 0, 1)
-- vertical edges use two-point anchors: the panel height is only known after
-- the whole stack is built (SetHeight at the bottom of this file)
local edgeL = frame:CreateTexture(nil, "BORDER")
edgeL:SetTexture(MEDIA .. "line_v")
edgeL:SetWidth(1)
edgeL:SetVertexColor(C.goldDark.r, C.goldDark.g, C.goldDark.b, 0.9)
edgeL:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
edgeL:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
local edgeR = frame:CreateTexture(nil, "BORDER")
edgeR:SetTexture(MEDIA .. "line_v")
edgeR:SetWidth(1)
edgeR:SetVertexColor(C.goldDark.r, C.goldDark.g, C.goldDark.b, 0.9)
edgeR:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
edgeR:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

-- --------------------------------------------------------------- helpers
local function fs(parent, size, color, justify)
        local f = parent:CreateFontString(nil, "OVERLAY")
        f:SetFont(FONT, size, "")
        f:SetTextColor(color.r, color.g, color.b, 1)
        f:SetJustifyH(justify or "RIGHT")
        f:SetWordWrap(true)
        return f
end

local function tex(parent, name, w, h, color, alpha)
        local t = parent:CreateTexture(nil, "OVERLAY")
        t:SetTexture(MEDIA .. name)
        t:SetSize(w, h)
        t:SetVertexColor(color.r, color.g, color.b, alpha or 1)
        return t
end

local shaped = {} -- fontstring -> logical Persian text (re-shaped on refresh)
local function set_fa(f, text)
        shaped[f] = text
        f:SetText(M:ShapeText(text))
end

-- section header: line ── · title · ── line  (lines fade at both ends)
local function section(parent, title, y)
        local f = fs(parent, 13, C.gold, "CENTER")
        set_fa(f, title)
        f:SetPoint("TOP", parent, "TOP", 0, y)
        local left = parent:CreateTexture(nil, "OVERLAY")
        left:SetTexture(MEDIA .. "line_h")
        left:SetHeight(1)
        left:SetVertexColor(C.goldDark.r, C.goldDark.g, C.goldDark.b, 0.7)
        left:SetPoint("RIGHT", f, "LEFT", -10, 0)
        left:SetPoint("LEFT", parent, "LEFT", MARGIN, 0)
        local right = parent:CreateTexture(nil, "OVERLAY")
        right:SetTexture(MEDIA .. "line_h")
        right:SetHeight(1)
        right:SetVertexColor(C.goldDark.r, C.goldDark.g, C.goldDark.b, 0.7)
        right:SetPoint("LEFT", f, "RIGHT", 10, 0)
        right:SetPoint("RIGHT", parent, "RIGHT", -MARGIN, 0)
        local dl = tex(parent, "dot", 3, 3, C.goldDark)
        dl:SetPoint("RIGHT", f, "LEFT", -3, 0)
        local dr = tex(parent, "dot", 3, 3, C.goldDark)
        dr:SetPoint("LEFT", f, "RIGHT", 3, 0)
        return f
end

-- diamond on/off toggle (rotated square, gold when on)
local function make_diamond(parent, size)
        local hit = CreateFrame("Frame", nil, parent) -- anchor only, click-transparent
        hit:SetSize(size + 12, size + 12)
        local glow = tex(hit, "glow", size * 2.4, size * 2.4, C.gold, 0.35)
        glow:SetDrawLayer("OVERLAY", -1)
        glow:SetPoint("CENTER", hit, "CENTER", 0, 0)
        local fill = tex(hit, "diamond", size, size, C.gold)
        fill:SetPoint("CENTER", hit, "CENTER", 0, 0)
        local hollow = tex(hit, "diamond_hollow", size, size, C.goldDark)
        hollow:SetPoint("CENTER", hit, "CENTER", 0, 0)
        return {
                frame = hit,
                set_state = function(state, available)
                        glow:SetShown(state and available)
                        fill:SetShown(state and available)
                        hollow:SetShown(not (state and available))
                        if not available then
                                fill:SetVertexColor(C.off.r, C.off.g, C.off.b)
                                hollow:SetVertexColor(C.off.r, C.off.g, C.off.b)
                        else
                                fill:SetVertexColor(C.gold.r, C.gold.g, C.gold.b)
                                hollow:SetVertexColor(C.goldDark.r, C.goldDark.g, C.goldDark.b)
                        end
                end,
        }
end

-- sigil button: no box - a fading top line, two fading bottom lines broken in
-- the middle by ring + dot + two side dots; hover brightens + shows a diamond
local function sigil_button(parent, label, onClick, primary)
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(120, 34)
        local lineColor = primary and C.blue or C.goldDark
        local top = b:CreateTexture(nil, "OVERLAY")
        top:SetTexture(MEDIA .. "line_h")
        top:SetSize(64, 1)
        top:SetPoint("TOP", b, "TOP", 0, -3)
        top:SetVertexColor(lineColor.r, lineColor.g, lineColor.b, 0.8)
        local bl = b:CreateTexture(nil, "OVERLAY")
        bl:SetTexture(MEDIA .. "line_h")
        bl:SetHeight(1)
        bl:SetVertexColor(lineColor.r, lineColor.g, lineColor.b, 0.6)
        bl:SetPoint("RIGHT", b, "CENTER", -12, 0)
        bl:SetPoint("LEFT", b, "LEFT", 4, 0)
        bl:SetPoint("BOTTOM", b, "BOTTOM", 0, 4)
        local br = b:CreateTexture(nil, "OVERLAY")
        br:SetTexture(MEDIA .. "line_h")
        br:SetHeight(1)
        br:SetVertexColor(lineColor.r, lineColor.g, lineColor.b, 0.6)
        br:SetPoint("LEFT", b, "CENTER", 12, 0)
        br:SetPoint("RIGHT", b, "RIGHT", -4, 0)
        br:SetPoint("BOTTOM", b, "BOTTOM", 0, 4)
        local ring = tex(b, "ring", 12, 12, lineColor)
        ring:SetPoint("BOTTOM", b, "BOTTOM", 0, 0)
        local dot = tex(b, "dot", 4, 4, primary and C.goldLight or C.gold)
        dot:SetPoint("CENTER", ring, "CENTER", 0, 0)
        local sl = tex(b, "dot", 2, 2, lineColor)
        sl:SetPoint("CENTER", ring, "CENTER", -10, 0)
        local sr = tex(b, "dot", 2, 2, lineColor)
        sr:SetPoint("CENTER", ring, "CENTER", 10, 0)
        local text = fs(b, 12, primary and C.goldLight or C.text, "CENTER")
        set_fa(text, label)
        text:SetPoint("CENTER", b, "CENTER", 0, -4)
        local hoverDiamond = tex(b, "diamond", 7, 7, C.goldLight)
        hoverDiamond:SetPoint("BOTTOM", top, "TOP", 0, 4)
        hoverDiamond:SetAlpha(0)
        if primary then
                local blueGlow = b:CreateTexture(nil, "BACKGROUND")
                blueGlow:SetTexture(MEDIA .. "glow")
                blueGlow:SetSize(110, 26)
                blueGlow:SetPoint("BOTTOM", b, "BOTTOM", 0, 4)
                blueGlow:SetVertexColor(C.blue.r, C.blue.g, C.blue.b, 0.12)
                local goldGlow = b:CreateTexture(nil, "BACKGROUND")
                goldGlow:SetTexture(MEDIA .. "glow")
                goldGlow:SetSize(70, 16)
                goldGlow:SetPoint("BOTTOM", b, "BOTTOM", 0, 2)
                goldGlow:SetVertexColor(C.gold.r, C.gold.g, C.gold.b, 0.18)
        end
        b:SetScript("OnEnter", function(self)
                top:SetVertexColor(C.goldLight.r, C.goldLight.g, C.goldLight.b, 1)
                bl:SetVertexColor(C.goldLight.r, C.goldLight.g, C.goldLight.b, 0.9)
                br:SetVertexColor(C.goldLight.r, C.goldLight.g, C.goldLight.b, 0.9)
                ring:SetVertexColor(C.goldLight.r, C.goldLight.g, C.goldLight.b)
                hoverDiamond:SetAlpha(1)
                text:SetTextColor(C.goldLight.r, C.goldLight.g, C.goldLight.b)
        end)
        b:SetScript("OnLeave", function(self)
                top:SetVertexColor(lineColor.r, lineColor.g, lineColor.b, 0.8)
                bl:SetVertexColor(lineColor.r, lineColor.g, lineColor.b, 0.6)
                br:SetVertexColor(lineColor.r, lineColor.g, lineColor.b, 0.6)
                ring:SetVertexColor(lineColor.r, lineColor.g, lineColor.b)
                hoverDiamond:SetAlpha(0)
                text:SetTextColor(primary and C.goldLight.r or C.text.r, primary and C.goldLight.g or C.text.g, primary and C.goldLight.b or C.text.b)
        end)
        b:SetScript("OnClick", onClick)
        return b
end

-- ------------------------------------------------------------- header area
local emblem = frame:CreateTexture(nil, "OVERLAY")
emblem:SetTexture(MEDIA .. "ring")
emblem:SetSize(26, 26)
emblem:SetVertexColor(C.gold.r, C.gold.g, C.gold.b)
emblem:SetPoint("TOP", frame, "TOP", 0, -18)
local emblemDot = tex(frame, "dot", 8, 8, C.goldLight)
emblemDot:SetPoint("CENTER", emblem, "CENTER", 0, 0)
local emblemL = tex(frame, "dot", 3, 3, C.goldDark)
emblemL:SetPoint("CENTER", emblem, "CENTER", -20, 0)
local emblemR = tex(frame, "dot", 3, 3, C.goldDark)
emblemR:SetPoint("CENTER", emblem, "CENTER", 20, 0)

local title = frame:CreateFontString(nil, "OVERLAY")
title:SetFont(FONT, 22, "")
title:SetTextColor(C.goldLight.r, C.goldLight.g, C.goldLight.b, 1)
title:SetText("WoWFA")
title:SetPoint("TOP", frame, "TOP", 0, -32)

local versionLine = fs(frame, 11, C.muted, "CENTER")
versionLine:SetText("v" .. M.version)
versionLine:SetPoint("TOP", frame, "TOP", 0, -62)

local statusLine = fs(frame, 11, C.muted, "CENTER")
statusLine:SetWidth(PANEL_W - 2 * MARGIN)
statusLine:SetPoint("TOP", frame, "TOP", 0, -78)

-- rows / chips pools (rebuilt on refresh so modules registered later appear)
local moduleRows = {}
local function get_row(id)
        if not moduleRows[id] then
                local row = CreateFrame("Button", nil, frame)
                row:SetHeight(38)
                row:EnableMouse(true)
                row:RegisterForClicks("LeftButtonUp")
                local d = make_diamond(row, 15)
                d.frame:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                local name = fs(row, 13, C.text)
                local desc = fs(row, 10, C.muted)
                moduleRows[id] = { frame = row, diamond = d, name = name, desc = desc }
        end
        return moduleRows[id]
end

local chipButtons = {}

-- ------------------------------------------------------------ build layout
local y = -104

section(frame, "بخش‌ها", y)
y = y - 26

local rowY = y
local function place_row(row, yOff)
        row.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -MARGIN, yOff)
        row.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, yOff)
end

local MODES = {
        { mode = 1, desc = "پیش‌فرض — حروف چسبانده می‌شوند و چیدن سطرها را خود بازی انجام می‌دهد" },
        { mode = 2, desc = "متن خام — شکل و ترتیب حروف کاملاً به خود بازی سپرده می‌شود" },
        { mode = 3, desc = "دستی — چسباندن حروف و چیدن سطرها هر دو با خود افزونه" },
}

local function refresh()
        -- header
        local parts = {}
        for _, m in ipairs(M:ModuleList()) do
                parts[#parts + 1] = m.nameFa .. " " .. (m.enabled and "روشن" or "خاموش")
        end
        if not M:IsRegistered("quests") then
                parts[#parts + 1] = "کوئست‌ها: نصب نشده"
        end
        set_fa(statusLine, "بخش‌ها: " .. table.concat(parts, " · "))

        -- module rows (registered first, then the quests placeholder, then the
        -- minimap option - the option row lives with the toggles, same look)
        local rows = {}
        for _, m in ipairs(M:ModuleList()) do
                rows[#rows + 1] = m
        end
        local questsShown = false
        for _, r in ipairs(rows) do
                if r.id == "quests" then
                        questsShown = true
                end
        end
        if not questsShown then
                rows[#rows + 1] = {
                        id = "quests",
                        nameFa = "کوئست‌ها",
                        descFa = "به‌زودی / نصب نشده — با افزونهٔ WoWFarsi_Quests فعال می‌شود",
                        enabled = false,
                        registered = false,
                }
        end
        rows[#rows + 1] = {
                id = "__minimap",
                nameFa = "نمایش دکمهٔ مینی‌مپ",
                descFa = "دکمهٔ گرد دور نقشهٔ کوچک",
                enabled = M:IsMinimapVisible(),
                registered = true,
        }

        local ry = rowY
        for _, m in ipairs(rows) do
                local row = get_row(m.id)
                row.name:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT", -24, -2)
                row.desc:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT", -24, -18)
                set_fa(row.name, m.nameFa)
                set_fa(row.desc, m.descFa)
                if m.id == "__minimap" then
                        row.diamond.set_state(m.enabled, true)
                        row.name:SetTextColor(C.text.r, C.text.g, C.text.b)
                        row.frame:SetScript("OnClick", function()
                                M:SetMinimapVisible(not M:IsMinimapVisible())
                                refresh()
                        end)
                elseif m.registered then
                        row.diamond.set_state(m.enabled, true)
                        row.name:SetTextColor(C.text.r, C.text.g, C.text.b)
                        row.frame:SetScript("OnClick", function()
                                M:SetEnabled(m.id, not M:IsEnabled(m.id))
                                refresh()
                        end)
                else
                        -- not installed: grayed, does not react to clicks
                        row.diamond.set_state(false, false)
                        row.name:SetTextColor(C.off.r, C.off.g, C.off.b)
                        row.frame:SetScript("OnClick", nil)
                end
                row.frame:Show()
                place_row(row, ry)
                ry = ry - 38
        end

        -- display-mode chips: active = light gold + diamond above
        local mode = M:GetMode()
        for _, chip in ipairs(chipButtons) do
                local active = chip.mode == mode
                chip.lineT:SetVertexColor(active and C.goldLight.r or C.off.r, active and C.goldLight.g or C.off.g, active and C.goldLight.b or C.off.b, active and 1 or 0.6)
                chip.lineB:SetVertexColor(active and C.goldLight.r or C.off.r, active and C.goldLight.g or C.off.g, active and C.goldLight.b or C.off.b, active and 1 or 0.6)
                chip.label:SetTextColor(active and C.goldLight.r or C.muted.r, active and C.goldLight.g or C.muted.g, active and C.goldLight.b or C.muted.b)
                chip.diamond:SetShown(active)
                chip.desc:SetTextColor(active and C.muted.r or C.off.r, active and C.muted.g or C.off.g, active and C.muted.b or C.off.b)
        end
end

-- rows are built in refresh(); chips + lower sections are static
y = rowY - 38 * 3 - 6 -- talents + quests + minimap rows

-- «نحوهٔ نمایش» + chips
section(frame, "نحوهٔ نمایش", y)
y = y - 20

local chipY = y
for i, m in ipairs(MODES) do
        local chip = CreateFrame("Button", nil, frame)
        chip:SetSize(88, 26)
        chip:EnableMouse(true)
        chip:RegisterForClicks("LeftButtonUp")
        chip.mode = m.mode
        local lineT = chip:CreateTexture(nil, "OVERLAY")
        lineT:SetTexture(MEDIA .. "line_h")
        lineT:SetSize(72, 1)
        lineT:SetPoint("TOP", chip, "TOP", 0, -2)
        local lineB = chip:CreateTexture(nil, "OVERLAY")
        lineB:SetTexture(MEDIA .. "line_h")
        lineB:SetSize(72, 1)
        lineB:SetPoint("BOTTOM", chip, "BOTTOM", 0, 2)
        local label = fs(chip, 12, C.muted, "CENTER")
        set_fa(label, "حالت " .. m.mode)
        label:SetPoint("CENTER", chip, "CENTER", 0, -1)
        local diamond = tex(chip, "diamond", 7, 7, C.goldLight)
        diamond:SetPoint("BOTTOM", lineT, "TOP", 0, 3)
        diamond:SetShown(false)
        chip:SetScript("OnClick", function()
                M:SetMode(m.mode)
                refresh()
        end)
        -- RTL: mode 1 sits on the right
        chip:SetPoint("TOP", frame, "TOP", (2 - i) * 98, chipY)
        chipButtons[#chipButtons + 1] = {
                mode = m.mode, lineT = lineT, lineB = lineB, label = label, diamond = diamond,
        }
        -- one-line description per mode, under the chips row
        local d = fs(frame, 10, C.off)
        d:SetWidth(PANEL_W - 2 * MARGIN - 8)
        set_fa(d, m.mode .. ". " .. m.desc)
        d:SetPoint("TOP", frame, "TOP", 0, chipY - 30 - (i - 1) * 15)
        chipButtons[i].desc = d
end

y = chipY - 30 - 3 * 15 - 8

-- «چه چیزی تازه است»
section(frame, "چه چیزی تازه است", y)
y = y - 20

local cl = (type(WoWFA_Changelog) == "table" and WoWFA_Changelog[1]) or { version = M.version, lines = {} }
local clVersion = fs(frame, 11, C.goldLight)
clVersion:SetText("نسخهٔ " .. cl.version)
clVersion:SetPoint("TOP", frame, "TOP", 0, y)
y = y - 17
for i = 1, math.min(4, #cl.lines) do
        local ln = fs(frame, 11, C.text)
        ln:SetWidth(PANEL_W - 2 * MARGIN - 8)
        set_fa(ln, cl.lines[i])
        ln:SetPoint("TOP", frame, "TOP", 0, y)
        y = y - 16
end
y = y - 6

-- «نسخهٔ جدید؟» - static text only, no online check
section(frame, "نسخهٔ جدید؟", y)
y = y - 20

local updateHint = fs(frame, 11, C.muted)
updateHint:SetWidth(PANEL_W - 2 * MARGIN - 8)
set_fa(updateHint, "برای مطلع‌شدن از به‌روزرسانی‌ها، بررسی کنید که آخرین نسخه را دارید.")
updateHint:SetPoint("TOP", frame, "TOP", 0, y)
y = y - 34

local yourVersion = fs(frame, 11, C.text)
yourVersion:SetText("نسخهٔ شما: " .. M.version)
yourVersion:SetPoint("TOP", frame, "TOP", 0, y)
y = y - 18

if CURSEFORGE_URL then
        local url = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        url:SetSize(PANEL_W - 2 * MARGIN, 24)
        url:SetPoint("TOP", frame, "TOP", 0, y)
        url:SetText(CURSEFORGE_URL)
        url:SetAutoFocus(false)
        url:HighlightText()
        url:SetScript("OnEscapePressed", function(self)
                self:ClearFocus()
        end)
        y = y - 30
end

-- close sigil + bottom diamond
local closeBtn = sigil_button(frame, "بستن", function()
        M:ClosePanel()
end, false)
closeBtn:EnableMouse(true)
closeBtn:RegisterForClicks("LeftButtonUp")
closeBtn:SetPoint("TOP", frame, "TOP", 0, y - 14)
y = y - 56

local bottomDiamond = tex(frame, "diamond", 10, 10, C.goldDark)
bottomDiamond:SetPoint("TOP", frame, "TOP", 0, y + 2)
y = y - 18

frame:SetHeight(-y + 8)

-- --------------------------------------------------------------- animation
local fade = frame:CreateAnimationGroup()
local fadeAlpha = fade:CreateAnimation("Alpha")
fadeAlpha:SetFromAlpha(0)
fadeAlpha:SetToAlpha(1)
fadeAlpha:SetDuration(0.2)
fadeAlpha:SetSmoothing("OUT")

-- -------------------------------------------------------------------- API
function M:OpenPanel()
        -- nothing here is protected: opening in combat works like any window
        refresh()
        if not frame:IsShown() then
                frame:Show()
                frame:SetAlpha(0)
                if fade:IsPlaying() then
                        fade:Stop()
                end
                fade:Play()
        end
end

function M:ClosePanel()
        frame:Hide()
end

function M:TogglePanel()
        if frame:IsShown() then
                M:ClosePanel()
        else
                M:OpenPanel()
        end
end

-- keep the panel live when modules/modes change from anywhere
M.OnModuleChanged = function(_, _)
        if frame:IsShown() then
                refresh()
        end
end
M.OnModeChanged = function(_, _)
        if frame:IsShown() then
                refresh()
        end
end
M.OnModuleRegistered = function(_, _)
        if frame:IsShown() then
                refresh()
        end
end

-- re-shape every Persian label on refresh (mode may have changed)
local _refresh = refresh
refresh = function()
        _refresh()
        for f, text in pairs(shaped) do
                f:SetText(M:ShapeText(text))
        end
end

-- ------------------------------------------------------ Settings + compartment
local function register_settings()
        if not Settings or not Settings.RegisterCategory then
                return
        end
        pcall(function()
                local category = Settings.RegisterCategory("WOWFA", "GAMEPLAY")
                Settings.RegisterAddOnCategory(category)
                local setting = Settings.RegisterAddOnSetting(category, "WOWFA_OPEN_PANEL", false, nil,
                        Settings.VarType.Boolean, "باز کردن پنل WoWFA", false)
                if Settings.CreateButton then
                        Settings.CreateButton(category, setting, "پنل فارسی WoWFA را باز می‌کند",
                                "باز کردن پنل WoWFA", function()
                                        M:OpenPanel()
                                end)
                else
                        -- fallback for patches without a button widget: a checkbox
                        -- that opens the panel when turned on
                        Settings.CreateCheckbox(category, setting, "پنل فارسی WoWFA را باز می‌کند")
                        Settings.SetOnValueChangedCallback("WOWFA_OPEN_PANEL", function(_, value)
                                if value then
                                        M:OpenPanel()
                                end
                        end)
                end
        end)
end
register_settings()

function WoWFA_CompartmentOnClick(_, _)
        M:TogglePanel()
end

function WoWFA_CompartmentOnEnter(_, _)
        if GameTooltip then
                GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
                GameTooltip:ClearLines()
                GameTooltip:AddLine("WoWFA " .. M.version, C.goldLight.r, C.goldLight.g, C.goldLight.b)
                GameTooltip:AddLine(M:ShapeText("نمایش یا پنهان‌کردن پنل فارسی"), C.muted.r, C.muted.g, C.muted.b, true)
                GameTooltip:Show()
        end
end

function WoWFA_CompartmentOnLeave(_, _)
        if GameTooltip then
                GameTooltip:Hide()
        end
end
