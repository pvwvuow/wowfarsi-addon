-- WoWFA Forever - dungeons and zones: Persian zone / dungeon name under the
-- game's own zone text when you arrive, and on the minimap zone tooltip.

local F = WoWFAF
local L = F.L
local T = F.T
local UI = F.UI
local C = F.C

local M = { id = "dungeons", order = 3, risk = "low", nameKey = "m_dungeons", descKey = "m_dungeons_d" }

function M.data()
    return F.D.names and F.D.names.zone
end

function M.api()
    return GetRealZoneText ~= nil and GetSubZoneText ~= nil
end

local function fa(name)
    if not F.Usable(name) or type(name) ~= "string" or name == "" then
        return nil
    end
    return F.D.names.zone[string.lower(name)]
end

local frame
local function build()
    frame = CreateFrame("Frame", "WoWFAF_ZoneText", UIParent)
    frame:SetSize(520, 80)
    frame:SetFrameStrata("LOW")
    frame:EnableMouse(false)
    if SubZoneTextString then
        frame:SetPoint("TOP", SubZoneTextString, "BOTTOM", 0, -8)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -330)
    end
    frame.kind = UI.Text(frame, 11, C.muted, "CENTER")
    frame.kind:SetPoint("TOP", frame, "TOP", 0, 0)
    frame.main = UI.Text(frame, 22, C.gold, "CENTER")
    frame.main:SetPoint("TOP", frame.kind, "BOTTOM", 0, -2)
    frame.sub = UI.Text(frame, 15, C.text, "CENTER")
    frame.sub:SetPoint("TOP", frame.main, "BOTTOM", 0, -4)
    frame:SetScript("OnUpdate", function(self, el)
        self.t = (self.t or 0) + el
        if self.t < 0.4 then
            self:SetAlpha(self.t / 0.4)
        elseif self.t > 5 then
            local a = 1 - (self.t - 5) / 1.2
            if a <= 0 then
                self:Hide()
            else
                self:SetAlpha(a)
            end
        else
            self:SetAlpha(1)
        end
    end)
    frame:Hide()
end

local function toast(main, sub, kind)
    if not main and not sub then
        return
    end
    if not frame then
        build()
    end
    frame.kind:SetFa(kind or "", 500)
    frame.kind:SetShown(kind ~= nil)
    frame.main:SetFa(main or sub, 500)
    if main and sub then
        frame.sub:SetFa(sub, 500)
        frame.sub:Show()
    else
        frame.sub:Hide()
    end
    frame.t = 0
    frame:SetAlpha(0)
    frame:Show()
end

local lastZone, lastSub
local function update()
    local zone, sub = GetRealZoneText(), GetSubZoneText()
    if not F.Usable(zone) or not F.Usable(sub) then
        return
    end
    local mode = F.db.zoneToast
    local inInst, itype = IsInInstance()
    if not F.Usable(inInst) then
        inInst = false
    end
    local dungeon = inInst and (itype == "party" or itype == "raid")
    local kind = dungeon and (itype == "raid" and L.zone_raid or L.zone_dungeon) or nil
    if zone ~= lastZone then
        lastZone, lastSub = zone, sub
        local zfa = fa(zone)
        F:Track("dungeons", zfa ~= nil)
        if mode == 1 or (mode == 2 and dungeon) then
            toast(zfa, sub ~= "" and sub ~= zone and fa(sub) or nil, zfa and kind or nil)
        end
    elseif sub ~= lastSub then
        lastSub = sub
        if mode == 1 and sub ~= "" then
            toast(fa(sub), nil, nil)
        end
    end
end

function M.install()
    F:On("ZONE_CHANGED_NEW_AREA", "dungeons", update)
    F:On("ZONE_CHANGED", "dungeons", update)
    F:On("ZONE_CHANGED_INDOORS", "dungeons", update)
    F:On("PLAYER_ENTERING_WORLD", "dungeons", function()
        lastZone = nil
        F.After(1, F:Wrap("dungeons", update))
    end)
    if MinimapZoneTextButton and MinimapZoneTextButton.HookScript then
        MinimapZoneTextButton:HookScript("OnEnter", F:Wrap("dungeons", function()
            if not GameTooltip:IsShown() then
                return
            end
            local z, s = fa(GetRealZoneText()), fa(GetSubZoneText())
            if z then
                T.TipLine(GameTooltip, z, C.gold)
            end
            if s and s ~= z then
                T.TipLine(GameTooltip, s, C.text)
            end
            if z or s then
                GameTooltip:Show()
            end
        end))
    end
end

function M.onState(_, active)
    if not active and frame then
        frame:Hide()
    end
end

F:RegisterModule(M)
