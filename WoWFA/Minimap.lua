-- WoWFA Minimap.lua - draggable minimap button, no libraries.
-- Left click toggles the panel; hover shows a short Persian tooltip with the
-- version and per-module status. The angle around the minimap persists in
-- WoWFA_DB.minimapAngle, the on/off flag in WoWFA_DB.showMinimap.

local M = WoWFA
local C = M.C

local ICON = M.MEDIA .. "icon" -- Media/icon.tga (64x64, generated with the repo's tooling)
local RADIUS = 78
local DEFAULT_ANGLE = 220

local button = CreateFrame("Button", "WoWFAMinimapButton", Minimap)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:SetSize(31, 31)
button:SetClampedToScreen(true)
button:RegisterForClicks("AnyUp")
button:RegisterForDrag("LeftButton")

local bg = button:CreateTexture(nil, "BACKGROUND")
bg:SetSize(20, 20)
bg:SetPoint("CENTER")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetSize(18, 18)
icon:SetPoint("CENTER")
icon:SetTexture(ICON)

local overlay = button:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetPoint("TOPLEFT")
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local highlight = button:CreateTexture(nil, "HIGHLIGHT")
highlight:SetSize(36, 36)
highlight:SetPoint("TOPLEFT")
highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local function place(angleDeg)
        local a = math.rad(angleDeg or DEFAULT_ANGLE)
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * RADIUS, math.sin(a) * RADIUS)
end

local function save_angle(angleDeg)
        WoWFA_DB = WoWFA_DB or {}
        WoWFA_DB.minimapAngle = angleDeg
end

button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function(self)
                local mx, my = Minimap:GetCenter()
                local px, py = GetCursorPosition()
                local scale = Minimap:GetEffectiveScale() or UIParent:GetEffectiveScale() or 1
                px, py = px / scale, py / scale
                local angle = math.deg(math.atan2(py - my, px - mx))
                if angle < 0 then
                        angle = angle + 360
                end
                place(angle)
                save_angle(angle)
        end)
end)

button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
end)

button:SetScript("OnClick", function(self)
        if WoWFA.TogglePanel then
                WoWFA:TogglePanel()
        end
end)

-- short status list for the hover tooltip: registered modules + pending ones
local function status_lines()
        local lines = {}
        local seen = {}
        for _, m in ipairs(M:ModuleList()) do
                seen[m.id] = true
                lines[#lines + 1] = {
                        m.nameFa .. ": " .. (m.enabled and "روشن" or "خاموش"),
                        m.enabled and C.green or C.muted,
                }
        end
        if not M:IsRegistered("quests") then
                lines[#lines + 1] = { "کوئست‌ها: نصب نشده", C.off }
        end
        return lines
end

button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("WoWFA " .. M.version, C.goldLight.r, C.goldLight.g, C.goldLight.b)
        for _, ln in ipairs(status_lines()) do
                GameTooltip:AddLine(M:ShapeText(ln[1]), ln[2].r, ln[2].g, ln[2].b, true)
        end
        GameTooltip:Show()
end)

button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
end)

-- API used by the panel toggle ("نمایش دکمهٔ مینی‌مپ")
function M:SetMinimapVisible(visible)
        WoWFA_DB = WoWFA_DB or {}
        WoWFA_DB.showMinimap = visible and true or false
        if visible then
                place(WoWFA_DB.minimapAngle or DEFAULT_ANGLE)
                button:Show()
        else
                button:Hide()
        end
end

function M:IsMinimapVisible()
        return (WoWFA_DB and WoWFA_DB.showMinimap ~= false) and true or false
end

-- init from saved state
if M:IsMinimapVisible() then
        place(WoWFA_DB and WoWFA_DB.minimapAngle or DEFAULT_ANGLE)
else
        button:Hide()
end
