-- WoWFarsi_Quests Display.lua - shows the Persian quest text inside the game.
-- Data comes from the generated LoadOnDemand zone addons (WoWFQ_*: Index.lua
-- maps questID -> addon; see tools/export_quests.py). Collector.lua is the
-- separate in-game capture layer and is not touched by this file.
--
-- Display (QuestInfo frame + quest log / tracker titles):
--   QUEST_DETAIL    -> QuestInfoDescriptionText  field d (+ objectives o below it)
--   QUEST_PROGRESS  -> QuestInfoProgressText     field p
--   QUEST_COMPLETE  -> QuestInfoRewardText       field c
--   QuestLogQuests_Update / ObjectiveTracker_Update hooks -> quest titles (best
--   effort; the exact widget layout still needs a game client to verify)
--
-- Modes (/wowfq mode):
--   below (default) Persian text is appended under the English text.
--   replace         the English text is replaced by the Persian text.
--   /wowfq mode with no argument toggles between the two.
--   Where the text goes is a quest-display-only choice, saved in WoWFQ_DB
--   (this addon's SavedVariable); WoWFA/Core.lua and its /wowfa command are
--   never written to from here.
--
-- Panel module (docs/ADDON.md "Modules API"): at load time this file registers
-- itself as the WoWFA module "quests" (WoWFA:RegisterModule, defaultEnabled
-- true). The panel row is then a working toggle, and WoWFA:IsEnabled("quests")
-- gates every text change below: when the module is off, Display adds no text
-- at all - no QuestInfo fields, no quest-log / tracker titles, and it does not
-- even LoadAddOn the zone data. Hooks stay installed (same cheap-gate pattern
-- as the "talents" hook in WoWFA/Core.lua), so re-enabling needs no reload.
--
-- Persian rendering uses only the WoWFA API (## Dependencies: WoWFA):
--   WoWFA:ShapeText(text) - the shared pipeline from the panel (docs/ADDON.md):
--   the /wowfa display mode 1|2|3 owned by WoWFA/Core.lua decides how the
--   letters are drawn (1: reshape + RLM and the client orders/wraps, 2: raw
--   logical text, 3: full manual reshape + bidi). One pipeline for the whole
--   panel, read-only on WoWFA_DB. When the WoWFA namespace is unavailable
--   (very old version, test harness) the display falls back to the old
--   mode-1 behaviour: WoWFA_Shape.shape_only + RLM.
--   Every Persian paragraph keeps U+200F RLM (modes 1/2) so the base
--   direction is RTL, and the Vazirmatn font bundled with WoWFA is applied
--   to the text we write (the default UI fonts have no Arabic
--   presentation-form glyphs).

local VERSION = "0.3.0"
local ADDON_NAME = ...
local Shape = WoWFA_Shape

local FONT = "Interface\\AddOns\\WoWFA\\Fonts\\Vazirmatn.ttf"
local RLM = "\226\128\143" -- U+200F RIGHT-TO-LEFT MARK: base direction RTL
local FA_COLOR = "|cffd9deeb" -- same palette as WoWFA/Core.lua (0.85, 0.87, 0.92)
local OBJ_LABEL = "اهداف:" -- header above the objective lines in the detail view

WoWFQ = WoWFQ or {} -- global: quest data, filled by the WoWFQ_* zone addons

local mode_loaded = {} -- zone addons we already tried to load
local hooked = {} -- guards so one hook is never installed twice

-- --------------------------------------------------------- panel module
-- Register with the WoWFA panel (docs/ADDON.md). The toc has
-- ## Dependencies: WoWFA so the namespace exists; the guard keeps the display
-- usable in a WoWFA-less harness. Re-registering only refreshes the texts -
-- the user's on/off choice in WoWFA_DB.modules is never reset (Modules.lua).
if WoWFA and WoWFA.RegisterModule then
        WoWFA:RegisterModule({
                id = "quests",
                nameFa = "کوئست‌ها",
                descFa = "نمایش فارسی متن کوئست‌ها",
                defaultEnabled = true,
        })
end

-- The panel switch. Unknown / not-yet-registered ids read as disabled per
-- Modules.lua, so until the registration above ran nothing should draw anyway.
local function quests_enabled()
        if WoWFA and WoWFA.IsEnabled then
                return WoWFA:IsEnabled("quests") and true or false
        end
        return true -- no WoWFA namespace (test harness): previous behaviour
end

-- --------------------------------------------------------------- mode
local function get_mode()
        local m = WoWFQ_DB and WoWFQ_DB.mode
        if m == "below" or m == "replace" then
                return m
        end
        return "below"
end

-- ------------------------------------------------------------ player tokens
-- Runtime fill, per docs/QUESTS.md + the collector convention:
--   $n, $p, $m and <name> (any case)  -> player name
--     $p/$m appear in the source data (e.g. quest 93023 "Dey must be dealt
--     with, $m."), the collector writes $n; all are name placeholders.
--   <class>, <race> (any case)        -> localized class / race name
--   $g<male>:<female>;                -> one form, picked by UnitSex
-- A token whose context value is missing stays raw (never guessed).
local function fill_tokens(text, ctx)
        ctx = ctx or {}
        text = string.gsub(text, "<(%a+)>", function(tag)
                tag = string.lower(tag)
                if tag == "name" and ctx.name then
                        return ctx.name
                elseif tag == "class" and ctx.class then
                        return ctx.class
                elseif tag == "race" and ctx.race then
                        return ctx.race
                end
                return nil -- keep the token
        end)
        text = string.gsub(text, "%$g([^:]*):([^;]*);", function(m, f)
                if ctx.sex == 2 then
                        return f
                end
                return m -- male is the default (unknown sex included)
        end)
        text = string.gsub(text, "%$([npm])", function()
                return ctx.name -- nil keeps the token
        end)
        return text
end

-- ------------------------------------------------------------- text output
-- one paragraph through the shared pipeline (docs/ADDON.md "Shared text
-- pipeline"): the panel's /wowfa mode decides how the text is drawn, so quest
-- text follows the same display mode as the talent tooltips. shape=false keeps
-- the logical text (test harness). Without the WoWFA namespace the display
-- keeps the old mode-1 behaviour (shape_only + RLM).
local function shape_para(para, shape)
        if not shape then
                return RLM .. para
        end
        if WoWFA and WoWFA.ShapeText then
                return WoWFA:ShapeText(para)
        end
        return RLM .. Shape.shape_only(para)
end

-- one FontString payload: fill tokens, then per paragraph RLM + presentation
-- forms (shape=false keeps logical text; used by the test harness).
local function persian_text(fa, ctx, shape)
        fa = fill_tokens(fa or "", ctx)
        local parts = {}
        for para in string.gmatch(fa, "([^\n]*)\n?") do
                if para ~= "" then
                        parts[#parts + 1] = shape_para(para, shape)
                end
        end
        return FA_COLOR .. table.concat(parts, "\n") .. "|r"
end

-- detail view payload: description, then the objective lines under a header
local function persian_block(field, ctx)
        local payload = field.d or ""
        if field.o and #field.o > 0 then
                local lines = { payload, OBJ_LABEL }
                for _, o in ipairs(field.o) do
                        lines[#lines + 1] = o
                end
                payload = table.concat(lines, "\n")
        end
        return persian_text(payload, ctx, true)
end

local function already_applied(fs)
        local ok, t = pcall(fs.GetText, fs)
        return ok and string.find(t or "", FA_COLOR, 1, true) ~= nil
end

-- put Vazirmatn on the widget (keeps its own size/flags); the default fonts
-- cannot render the presentation forms the shaper emits
local function set_font(fs)
        local ok, _, size, flags = pcall(fs.GetFont, fs)
        if ok then
                pcall(fs.SetFont, fs, FONT, size or 12, flags or "")
        end
end

local function show(fs, text)
        if not fs or type(fs.SetText) ~= "function" then
                return
        end
        fs:SetText(text)
        set_font(fs)
end

-- field.p / field.c single-field widgets
local function apply_field(fs, fa, ctx)
        if not fa or fa == "" or already_applied(fs) then
                return
        end
        local fa_txt = persian_text(fa, ctx, true)
        local ok, en = pcall(fs.GetText, fs)
        if get_mode() == "replace" or not ok or en == nil or en == "" then
                show(fs, fa_txt)
        else
                show(fs, en .. "\n\n" .. fa_txt)
        end
end

-- detail view: description + objectives in one block under the English text
-- (apply_* are only called with the "quests" module enabled - the callers gate)
local function apply_detail(fs, field, ctx)
        if not field or already_applied(fs) then
                return
        end
        local fa = persian_block(field, ctx)
        if fa == FA_COLOR .. "|r" then
                return -- nothing to show (empty record)
        end
        local ok, en = pcall(fs.GetText, fs)
        if get_mode() == "replace" or not ok or en == nil or en == "" then
                show(fs, fa)
        else
                show(fs, en .. "\n\n" .. fa)
        end
end

-- -------------------------------------------------------------- zone data
local function ensure_addon(addonName)
        if not addonName or mode_loaded[addonName] then
                return
        end
        mode_loaded[addonName] = true
        local loaded = false
        if C_AddOns and C_AddOns.IsAddOnLoaded then
                loaded = C_AddOns.IsAddOnLoaded(addonName)
        elseif IsAddOnLoaded then
                loaded = IsAddOnLoaded(addonName)
        end
        if loaded then
                return
        end
        local ok, err = pcall(function()
                if C_AddOns and C_AddOns.LoadAddOn then
                        C_AddOns.LoadAddOn(addonName)
                else
                        LoadAddOn(addonName)
                end
        end)
        if not ok and WoWFQ_DEBUG then
                print("|cffffd100WoWFQ|r load " .. addonName .. " failed: " .. tostring(err))
        end
end

local function record_for(questID)
        if not questID or questID == 0 then
                return nil
        end
        ensure_addon(WoWFQ_Index and WoWFQ_Index[questID])
        return WoWFQ[questID]
end

-- --------------------------------------------------------------- player ctx
local function get_ctx()
        local ctx = {}
        if UnitName then
                local ok, v = pcall(UnitName, "player")
                if ok then
                        ctx.name = v
                end
        end
        if UnitClass then
                local ok, _, cls = pcall(UnitClass, "player")
                if ok then
                        ctx.class = cls
                end
        end
        if UnitRace then
                local ok, _, race = pcall(UnitRace, "player")
                if ok then
                        ctx.race = race
                end
        end
        if UnitSex then
                local ok, v = pcall(UnitSex, "player")
                if ok then
                        ctx.sex = v
                end
        end
        return ctx
end

-- ----------------------------------------------------------------- display
local function apply_quest(questID)
        if not quests_enabled() then
                return -- panel switch off: no text, and no LoadAddOn of zone data
        end
        local field = record_for(questID)
        if not field then
                return
        end
        local ctx = get_ctx()
        if QuestInfoDescriptionText and QuestInfoDescriptionText.IsShown
                and QuestInfoDescriptionText:IsShown() then
                apply_detail(QuestInfoDescriptionText, field, ctx)
        end
        if QuestInfoProgressText and QuestInfoProgressText.IsShown
                and QuestInfoProgressText:IsShown() then
                apply_field(QuestInfoProgressText, field.p, ctx)
        end
        if QuestInfoRewardText and QuestInfoRewardText.IsShown
                and QuestInfoRewardText:IsShown() then
                apply_field(QuestInfoRewardText, field.c, ctx)
        end
end

-- titles (quest log buttons / tracker blocks), mode-aware, best effort
local function apply_title(fs, en, fa_title, ctx)
        if not fa_title or fa_title == "" or not fs or already_applied(fs) then
                return
        end
        local fa = persian_text(fa_title, ctx, true)
        if get_mode() == "replace" then
                show(fs, fa)
        else
                show(fs, fa .. " " .. (en or ""))
        end
end

local function update_log_titles()
        if not quests_enabled() then
                return
        end
        local scroll = QuestLogQuests and QuestLogQuests.ScrollFrame
        local buttons = scroll and scroll.buttons
        if not buttons then
                return
        end
        local ctx = get_ctx()
        for _, b in ipairs(buttons) do
                local qid = b.questID
                if not qid and b.GetID then
                        qid = b:GetID()
                end
                local field = record_for(qid)
                if field and field.t and b.title then
                        apply_title(b.title, (b.title.GetText and b.title:GetText()), field.t, ctx)
                end
        end
end

local function update_tracker()
        if not quests_enabled() then
                return
        end
        if not QUEST_MODULE or not QUEST_MODULE.usedBlocks then
                return
        end
        local ctx = get_ctx()
        for id, block in pairs(QUEST_MODULE.usedBlocks) do
                local fs = block and block.header and block.header.Text
                local field = record_for(id)
                if field and field.t and fs then
                        apply_title(fs, (fs.GetText and fs:GetText()), field.t, ctx)
                end
        end
end

-- ------------------------------------------------------------------- hooks
if QuestInfo_Display and not hooked.QuestInfo_Display then
        hooked.QuestInfo_Display = true
        hooksecurefunc("QuestInfo_Display", function()
                pcall(apply_quest, GetQuestID and GetQuestID() or 0)
        end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_COMPLETE")
frame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
                if arg1 == ADDON_NAME then
                        WoWFQ_DB = WoWFQ_DB or {}
                        local n = 0
                        for _ in pairs(WoWFQ_Index or {}) do
                                n = n + 1
                        end
                        print("|cffffd100WoWFQ|r display v" .. VERSION .. ": " .. n
                                .. " Persian quests (LoadOnDemand). /wowfq mode below|replace")
                end
                return
        end
        local ok, err = pcall(apply_quest, GetQuestID and GetQuestID() or 0)
        if not ok and WoWFQ_DEBUG then
                print("|cffffd100WoWFQ|r error in " .. event .. ": " .. tostring(err))
        end
end)

-- quest log list (Midnight/Dragonflight layout); guarded, needs client check
if QuestLogQuests_Update and not hooked.QuestLogQuests_Update then
        hooked.QuestLogQuests_Update = true
        hooksecurefunc("QuestLogQuests_Update", function()
                pcall(update_log_titles)
        end)
end

-- objective tracker; guarded, needs client check
if ObjectiveTracker_Update and not hooked.ObjectiveTracker_Update then
        hooked.ObjectiveTracker_Update = true
        hooksecurefunc("ObjectiveTracker_Update", function()
                pcall(update_tracker)
        end)
end

-- ------------------------------------------------------------------- slash
SLASH_WOWFQ1 = "/wowfq"
SlashCmdList["WOWFQ"] = function(msg)
        local word1, word2 = string.match(string.lower(msg or ""), "^%s*(%S*)%s*(%S*)")
        if word1 == "mode" and (word2 == "below" or word2 == "replace") then
                WoWFQ_DB = WoWFQ_DB or {}
                WoWFQ_DB.mode = word2
                print("|cffffd100WoWFQ|r mode = " .. word2)
        elseif word1 == "mode" then
                local m = get_mode() == "below" and "replace" or "below"
                WoWFQ_DB = WoWFQ_DB or {}
                WoWFQ_DB.mode = m
                print("|cffffd100WoWFQ|r mode = " .. m .. " (open a quest to see it)")
        else
                local n = 0
                for _ in pairs(WoWFQ_Index or {}) do
                        n = n + 1
                end
                print("|cffffd100WoWFQ|r v" .. VERSION .. ", mode = " .. get_mode()
                        .. ", " .. n .. " Persian quests. Use /wowfq mode below|replace")
        end
end

-- test hook (only active when a harness pre-sets WoWFQ_TEST)
if WoWFQ_TEST then
        WoWFQ_internals = {
                fill_tokens = fill_tokens,
                persian_text = persian_text,
                persian_block = persian_block,
                get_mode = get_mode,
                quests_enabled = quests_enabled,
                shape_para = shape_para,
                apply_quest = apply_quest,
                update_log_titles = update_log_titles,
                update_tracker = update_tracker,
        }
end
