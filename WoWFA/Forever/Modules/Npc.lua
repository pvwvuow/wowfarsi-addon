-- WoWFA Forever - NPCs, bosses and world objects: Persian name on the tooltip.
-- Names are looked up by their English name, so new or moved NPCs that keep
-- their name still work after a game update. Secret values (combat-restricted
-- unit data) are never compared or stored.

local F = WoWFAF
local T = F.T
local C = F.C

local M = { id = "npc", order = 4, risk = "low", nameKey = "m_npc", descKey = "m_npc_d" }

function M.data()
    return F.D.names and F.D.names.npc
end

local function tdp(kind)
    return TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
        and Enum.TooltipDataType[kind] ~= nil
end

function M.api()
    if not UnitName then
        return false
    end
    return tdp("Unit") or (GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetUnit"))
end

local function lookup(name)
    local n = F.D.names
    local key = string.lower(name)
    return (n.boss and n.boss[key]) or (n.npc and n.npc[key])
end

local function on_unit(tt)
    if not tt or (tt.IsForbidden and tt:IsForbidden()) or not tt.GetUnit then
        return
    end
    local _, unit = tt:GetUnit()
    if not F.Usable(unit) or not unit then
        return
    end
    local isPlayer = UnitIsPlayer(unit)
    if not F.Usable(isPlayer) or isPlayer then
        return
    end
    local name = UnitName(unit)
    if not F.Usable(name) or type(name) ~= "string" or name == "" then
        return
    end
    local fa = lookup(name)
    if not fa then
        return
    end
    if not T.Once(tt, "u" .. name) then
        return
    end
    T.TipLine(tt, fa, C.gold)
    T.Done(tt)
    tt:Show()
end

local function on_object(tt, data)
    if not tt or (tt.IsForbidden and tt:IsForbidden()) then
        return
    end
    local first = data and type(data.lines) == "table" and data.lines[1]
    local name = first and first.leftText
    if not F.Usable(name) or type(name) ~= "string" or name == "" then
        return
    end
    local n = F.D.names
    local fa = n.obj and n.obj[string.lower(name)]
    if not fa or not T.Once(tt, "o" .. name) then
        return
    end
    T.TipLine(tt, fa, C.gold)
    T.Done(tt)
    tt:Show()
end

function M.install()
    if tdp("Unit") then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, F:Wrap("npc", on_unit))
    else
        GameTooltip:HookScript("OnTooltipSetUnit", F:Wrap("npc", on_unit))
    end
    if tdp("Object") then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, F:Wrap("npc", on_object))
    end
end

F:RegisterModule(M)
