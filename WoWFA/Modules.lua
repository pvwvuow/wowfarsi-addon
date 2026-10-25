-- WoWFA Modules.lua - addon namespace + module registry + shared text helper.
-- A "module" is a feature that can be toggled per user (talents today; the
-- WoWFarsi_Quests addon registers "quests" itself, see docs/ADDON.md).
-- State persists across sessions in WoWFA_DB.modules (SavedVariable).
--
-- Module addons must set `## Dependencies: WoWFA` in their toc so WoWFA (this
-- file) loads first, then call WoWFA:RegisterModule{...} once at load time.

WoWFA = WoWFA or {}

local M = WoWFA

M.version = "0.4.0"
M.FONT = "Interface\\AddOns\\WoWFA\\Fonts\\Vazirmatn.ttf"
M.MEDIA = "Interface\\AddOns\\WoWFA\\Media\\"

-- site palette (pvwvuow.github.io/wow - "fantasy minimal, smoked glass")
M.C = {
        gold      = { r = 0.941, g = 0.780, b = 0.369 }, -- #f0c75e
        goldLight = { r = 0.965, g = 0.878, b = 0.639 }, -- #f6e0a3
        goldDark  = { r = 0.788, g = 0.635, b = 0.196 }, -- #c9a232
        text      = { r = 0.910, g = 0.890, b = 0.839 }, -- #e8e3d6
        muted     = { r = 0.659, g = 0.635, b = 0.580 }, -- #a8a294
        off       = { r = 0.522, g = 0.498, b = 0.435 }, -- #857f6f
        bg1       = { r = 0.016, g = 0.024, b = 0.043 }, -- #04060b
        bg2       = { r = 0.043, g = 0.059, b = 0.102 }, -- #0b0f1a
        blue      = { r = 0.561, g = 0.706, b = 0.910 }, -- #8fb4e8
        green     = { r = 0.561, g = 0.831, b = 0.643 }, -- #8fd4a4
}

local ORDER = {} -- registration order (pairs() order is not stable)
local DEFS = {}

local function modules_db()
        WoWFA_DB = WoWFA_DB or {}
        WoWFA_DB.modules = WoWFA_DB.modules or {}
        return WoWFA_DB.modules
end

-- Register a module. First registration wins for ordering; re-registering an
-- existing id only refreshes its display texts and never resets the user's
-- on/off choice.
function M:RegisterModule(def)
        if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then
                return false
        end
        local fresh = not DEFS[def.id]
        if fresh then
                ORDER[#ORDER + 1] = def.id
        end
        DEFS[def.id] = {
                id = def.id,
                nameFa = def.nameFa or def.id,
                descFa = def.descFa or "",
                defaultEnabled = def.defaultEnabled and true or false,
        }
        -- freeze the default on first sight so the panel never flips states
        if modules_db()[def.id] == nil then
                modules_db()[def.id] = DEFS[def.id].defaultEnabled
        end
        if M.OnModuleRegistered then
                M:OnModuleRegistered(def.id, fresh)
        end
        return true
end

function M:IsRegistered(id)
        return DEFS[id] ~= nil
end

-- Unknown / not-yet-registered ids read as disabled: a module that has not
-- registered yet must not have any effect.
function M:IsEnabled(id)
        local v = modules_db()[id]
        if v == nil then
                local d = DEFS[id]
                v = d and d.defaultEnabled or false
        end
        return v and true or false
end

function M:SetEnabled(id, on)
        if not DEFS[id] then
                return false
        end
        modules_db()[id] = on and true or false
        if M.OnModuleChanged then
                M:OnModuleChanged(id, M:IsEnabled(id))
        end
        return true
end

-- snapshot for the panel / minimap tooltip, in registration order
function M:ModuleList()
        local out = {}
        for i = 1, #ORDER do
                local d = DEFS[ORDER[i]]
                out[#out + 1] = {
                        id = d.id,
                        nameFa = d.nameFa,
                        descFa = d.descFa,
                        enabled = M:IsEnabled(d.id),
                        registered = true,
                }
        end
        return out
end

-- Persian text for our own UI, same semantics as the tooltip pipeline per
-- /wowfa mode (1: reshape + RLM, client orders; 2: raw logical; 3: full manual)
local RLM = "\226\128\143" -- U+200F RIGHT-TO-LEFT MARK

function M:GetMode()
        local m = WoWFA_DB and WoWFA_DB.mode
        if m == 1 or m == 2 or m == 3 then
                return m
        end
        return 1
end

function M:SetMode(mode)
        if mode == 1 or mode == 2 or mode == 3 then
                WoWFA_DB = WoWFA_DB or {}
                WoWFA_DB.mode = mode
                if M.OnModeChanged then
                        M:OnModeChanged(mode)
                end
                return true
        end
        return false
end

function M:ShapeText(text)
        if not text or text == "" then
                return text
        end
        local Shape = WoWFA_Shape
        if not Shape then
                return text
        end
        local mode = M:GetMode()
        if mode == 3 then
                return Shape.line(text)
        elseif mode == 1 then
                return RLM .. Shape.shape_only(text)
        end
        return RLM .. text
end

-- this addon's own feature - registered here so the panel always has it
M:RegisterModule({
        id = "talents",
        nameFa = "تلنت‌ها",
        descFa = "نمایش توضیح فارسی زیر متن تلنت‌ها",
        defaultEnabled = true,
})
