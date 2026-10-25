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
-- Views (/wowfq view fa|en|both, saved in WoWFQ_DB.view, default fa):
--   fa    only the Persian text is shown; the English text is set aside.
--   en    only the original English text - restored byte-exact, no additions.
--   both  the 0.2.x "below" look: Persian under the English text.
-- /wowfq mode below|replace (0.2.x command) still works: below -> both,
-- replace -> fa. /wowfq mode with no argument toggles fa <-> en.
-- WoWFQ.GetView() / WoWFQ.SetView(v) are a small API for other UI (the WoWFA
-- panel can later offer a "default view" option through them).
--
-- The toggle button: a small gold button above the quest text (NPC dialog and
-- the quest log details) that switches fa <-> en. It only appears when a
-- Persian record (WoWFQ[questID]) exists for the open quest; the click applies
-- to the open quest immediately without closing anything. It reuses the WoWFA
-- design language (smoked glass, 1px fading gold lines, hover diamond) and the
-- public WoWFA pieces (C palette, MEDIA textures, FONT, ShapeText) without
-- touching the WoWFA addon itself.
--
-- Panel module (docs/ADDON.md "Modules API"): at load time this file registers
-- itself as the WoWFA module "quests" (WoWFA:RegisterModule, defaultEnabled
-- true). The panel row is then a working toggle, and WoWFA:IsEnabled("quests")
-- gates every text change below: when the module is off, Display adds no text
-- at all - no QuestInfo fields, no quest-log / tracker titles, no toggle
-- button - and it does not even LoadAddOn the zone data. Hooks stay installed
-- (same cheap-gate pattern as the "talents" hook in WoWFA/Core.lua), so
-- re-enabling needs no reload.
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

local VERSION = "0.2.2"
local ADDON_NAME = ...
local Shape = WoWFA_Shape
local WoWFA = WoWFA -- module system (0.4.0); may be absent under test stubs

local FONT = "Interface\\AddOns\\WoWFA\\Fonts\\Vazirmatn.ttf"
local MEDIA = (WoWFA and WoWFA.MEDIA) or "Interface\\AddOns\\WoWFA\\Media\\"
local RLM = "\226\128\143" -- U+200F RIGHT-TO-LEFT MARK: base direction RTL
local FA_COLOR = "|cffd9deeb" -- same palette as WoWFA/Core.lua (0.85, 0.87, 0.92)
local OBJ_LABEL = "اهداف:" -- header above the objective lines in the detail view
local WHITE8X8 = "Interface\\Buttons\\WHITE8X8"

-- site palette (same values as WoWFA/Modules.lua; read live when available)
local C = (WoWFA and WoWFA.C) or {}
local GOLD = C.gold or { r = 0.941, g = 0.780, b = 0.369 } -- #f0c75e
local GOLD_LIGHT = C.goldLight or { r = 0.965, g = 0.878, b = 0.639 } -- #f6e0a3

local VIEWS = { fa = true, en = true, both = true }

WoWFQ = WoWFQ or {} -- global: quest data (zone addons) + GetView/SetView API

local mode_loaded = {} -- zone addons we already tried to load
local hooked = {} -- guards so one hook is never installed twice

-- cross references (button <-> view <-> rendering), assigned below
local render_open, toggle_view, set_button_label

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

-- ---------------------------------------------------------------- view state
local function get_view()
        local db = WoWFQ_DB
        if db then
                if VIEWS[db.view] then
                        return db.view
                end
                -- 0.2.x saved choice, mapped to the new names
                if db.mode == "replace" then
                        return "fa"
                elseif db.mode == "below" then
                        return "both"
                end
        end
        return "fa"
end

local function set_view(v)
        if not VIEWS[v] then
                return false
        end
        WoWFQ_DB = WoWFQ_DB or {}
        WoWFQ_DB.view = v
        return true
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

-- one FontString payload: fill tokens, then one shared-pipeline call per
-- paragraph (shape=false keeps logical text; used by the test harness).
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

-- ------------------------------------------------- originals (exact English)
-- The English text of every FontString is captured BEFORE we touch it (never
-- re-read after writing), so view "en" can restore it byte-exact and toggling
-- twice can never capture our own output as the "original". A widget the game
-- rewrote since our last write is detected by the FA_COLOR marker and
-- re-captured fresh.
local orig_text = {} -- fs -> English text as the game wrote it
local orig_font = {} -- fs -> { path, size, flags } captured with it
local ours = {} -- fs -> true while the text on it is ours (carries FA_COLOR)

local function sync_original(fs)
        local ok, t = pcall(fs.GetText, fs)
        if not ok then
                return nil
        end
        t = t or ""
        if ours[fs] and string.find(t, FA_COLOR, 1, true) then
                return orig_text[fs] -- still our output; the original stands
        end
        -- fresh game text (or first sight of this widget): capture it
        orig_text[fs] = t
        local okf, path, size, flags = pcall(fs.GetFont, fs)
        orig_font[fs] = okf and { path = path, size = size, flags = flags } or nil
        ours[fs] = nil
        return t
end

local function restore(fs)
        local t = orig_text[fs]
        if t == nil then
                return
        end
        fs:SetText(t)
        local f = orig_font[fs]
        if f and f.path then
                pcall(fs.SetFont, fs, f.path, f.size or 12, f.flags or "")
        end
        ours[fs] = nil
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

-- one widget, one render pass, view-aware and idempotent (always recomposed
-- from the captured original, never from the text already on screen)
local function render_fs(fs, fa_text)
        if not fs or type(fs.SetText) ~= "function" then
                return
        end
        local en = sync_original(fs)
        local view = get_view()
        if view == "en" or not fa_text or fa_text == "" then
                -- nothing Persian for this field: the English text stands
                if ours[fs] then
                        restore(fs)
                end
                return
        end
        if view == "both" then
                show(fs, (en or "") .. "\n\n" .. fa_text)
        else
                show(fs, fa_text)
        end
        ours[fs] = true
end

-- quest log / tracker titles, same three views, same originals rule
local function render_title(fs, fa_title, ctx)
        if not fs or type(fs.SetText) ~= "function" then
                return
        end
        local en = sync_original(fs)
        local view = get_view()
        local fa = (fa_title and fa_title ~= "") and persian_text(fa_title, ctx, true) or nil
        if view == "en" or not fa then
                if ours[fs] then
                        restore(fs)
                end
                return
        end
        if view == "both" then
                show(fs, fa .. " " .. (en or ""))
        else
                show(fs, fa)
        end
        ours[fs] = true
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

-- ---------------------------------------------------------- toggle button
-- Design language of the WoWFA panel / the wowfarsi site: no box, smoked
-- glass, 1px gold lines that fade at both ends, a small diamond on hover.
-- The panel's own helpers are file-local, so this builds small independent
-- ones from the public pieces: WoWFA.C colors, WoWFA.MEDIA textures, FONT.
local toggle_buttons = {} -- parent frame -> button

local function hide_buttons()
        for _, b in pairs(toggle_buttons) do
                b:Hide()
        end
end

local function shape_label(text)
        -- the shared pipeline (docs/ADDON.md): every Persian string outside
        -- the tooltip goes through WoWFA:ShapeText; plain shape_only fallback
        if WoWFA and WoWFA.ShapeText then
                local ok, s = pcall(WoWFA.ShapeText, WoWFA, text)
                if ok and type(s) == "string" then
                        return s
                end
        end
        return RLM .. Shape.shape_only(text)
end

set_button_label = function(b)
        if not b or not b.wq then
                return
        end
        -- the label is always what a click switches TO
        if get_view() == "fa" then
                b.wq.label:SetText("English")
        else
                b.wq.label:SetText(shape_label("فارسی"))
        end
end

local function make_button(parent)
        local b = CreateFrame("Button", nil, parent)
        b:SetHeight(28)
        b:EnableMouse(true)
        b:RegisterForClicks("LeftButtonUp")
        -- smoked glass: layered dark gradient, like the panel background
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(WHITE8X8)
        if bg.SetGradient then
                bg:SetGradient("VERTICAL",
                        CreateColor(0.016, 0.024, 0.043, 0.85),
                        CreateColor(0.043, 0.059, 0.102, 0.72))
        end
        -- 1px gold lines top + bottom, fading at both ends (WoWFA media art)
        local top = b:CreateTexture(nil, "OVERLAY")
        top:SetTexture(MEDIA .. "line_h")
        top:SetHeight(1)
        top:SetPoint("TOPLEFT", b, "TOPLEFT", 8, 0)
        top:SetPoint("TOPRIGHT", b, "TOPRIGHT", -8, 0)
        local bottom = b:CreateTexture(nil, "OVERLAY")
        bottom:SetTexture(MEDIA .. "line_h")
        bottom:SetHeight(1)
        bottom:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 8, 0)
        bottom:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 0)
        local label = b:CreateFontString(nil, "OVERLAY")
        label:SetFont(FONT, 12, "")
        label:SetPoint("CENTER", b, "CENTER", 0, 0)
        local diamond = b:CreateTexture(nil, "OVERLAY")
        diamond:SetTexture(MEDIA .. "diamond")
        diamond:SetSize(7, 7)
        diamond:SetPoint("BOTTOM", top, "TOP", 0, 3)
        diamond:SetAlpha(0)
        b.wq = { label = label, top = top, bottom = bottom, diamond = diamond }
        b:SetScript("OnEnter", function()
                label:SetTextColor(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b)
                top:SetVertexColor(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 1)
                bottom:SetVertexColor(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 0.9)
                diamond:SetAlpha(1)
        end)
        b:SetScript("OnLeave", function()
                label:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
                top:SetVertexColor(GOLD.r, GOLD.g, GOLD.b, 0.85)
                bottom:SetVertexColor(GOLD.r, GOLD.g, GOLD.b, 0.85)
                diamond:SetAlpha(0)
        end)
        b:SetScript("OnClick", function()
                pcall(toggle_view)
        end)
        if b.SetFrameLevel and parent and parent.GetFrameLevel then
                pcall(b.SetFrameLevel, b, (parent:GetFrameLevel() or 0) + 4)
        end
        set_button_label(b)
        return b
end

-- anchor the button above the first shown quest-text widget; visible only
-- when a Persian record exists for the open quest - and never while the
-- "quests" module is switched off in the panel
local function update_button(anchor_fs, has_record)
        hide_buttons()
        if not quests_enabled() then
                return -- panel switch off: the button never shows
        end
        if not has_record or not anchor_fs or not anchor_fs.GetParent then
                return
        end
        local ok, parent = pcall(anchor_fs.GetParent, anchor_fs)
        if not ok or not parent then
                return
        end
        local b = toggle_buttons[parent]
        if not b then
                local okb, made = pcall(make_button, parent)
                if not okb then
                        return
                end
                b = made
                toggle_buttons[parent] = b
        end
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", anchor_fs, "TOPLEFT", 0, 6)
        b:SetPoint("BOTTOMRIGHT", anchor_fs, "TOPRIGHT", 0, 6)
        set_button_label(b)
        b:Show()
end

-- ----------------------------------------------------------------- display
local last_quest_id = 0

-- detail view payload, or nil when the record has no description/objectives
local function detail_payload(field, ctx)
        if not field then
                return nil
        end
        local fa = persian_block(field, ctx)
        if fa == FA_COLOR .. "|r" then
                return nil
        end
        return fa
end

local function apply_quest(questID)
        if not quests_enabled() then
                -- panel switch off (docs/ADDON.md "Modules API"): no text, no
                -- LoadAddOn of zone data, and the toggle button stays hidden.
                hide_buttons()
                return
        end
        last_quest_id = questID or 0
        local field = record_for(questID)
        local ctx = get_ctx()
        local anchor = nil
        local function feed(fs, fa_text)
                if not fs or not fs.IsShown or not fs:IsShown() then
                        return
                end
                anchor = anchor or fs
                render_fs(fs, fa_text)
        end
        feed(QuestInfoDescriptionText, detail_payload(field, ctx))
        if QuestInfoProgressText then
                local p = field and field.p
                feed(QuestInfoProgressText, (p and p ~= "") and persian_text(p, ctx, true) or nil)
        end
        if QuestInfoRewardText then
                local c = field and field.c
                feed(QuestInfoRewardText, (c and c ~= "") and persian_text(c, ctx, true) or nil)
        end
        update_button(anchor, field ~= nil)
end

-- titles (quest log buttons / tracker blocks), view-aware, best effort
local function update_log_titles()
        if not quests_enabled() then
                return
        end
        local scroll = QuestLogQuests and QuestLogQuests.ScrollFrame
        local list = scroll and scroll.buttons
        if not list then
                return
        end
        local ctx = get_ctx()
        for _, b in ipairs(list) do
                local qid = b.questID
                if not qid and b.GetID then
                        qid = b:GetID()
                end
                local field = record_for(qid)
                if field and field.t and b.title then
                        render_title(b.title, field.t, ctx)
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
                        render_title(fs, field.t, ctx)
                end
        end
end

-- re-render whatever is open right now (view changed): text, titles, button
render_open = function()
        pcall(apply_quest, last_quest_id)
        pcall(update_log_titles)
        pcall(update_tracker)
end

toggle_view = function()
        -- the button switches between fa and en; "both" stays reachable
        -- through /wowfq view both (and /wowfq mode below)
        local target = (get_view() == "fa") and "en" or "fa"
        if set_view(target) then
                render_open()
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
                                .. " Persian quests (LoadOnDemand). /wowfq view fa|en|both")
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
        if word1 == "view" then
                if VIEWS[word2] then
                        set_view(word2)
                        pcall(render_open)
                        print("|cffffd100WoWFQ|r view = " .. word2)
                else
                        print("|cffffd100WoWFQ|r view = " .. get_view()
                                .. "  (use /wowfq view fa|en|both)")
                end
        elseif word1 == "mode" then
                -- 0.2.x command kept working: below -> both, replace -> fa
                if word2 == "below" or word2 == "replace" then
                        set_view(word2 == "below" and "both" or "fa")
                        pcall(render_open)
                        print("|cffffd100WoWFQ|r view = " .. get_view())
                else
                        local target = (get_view() == "fa") and "en" or "fa"
                        set_view(target)
                        pcall(render_open)
                        print("|cffffd100WoWFQ|r view = " .. target .. " (open a quest to see it)")
                end
        else
                local n = 0
                for _ in pairs(WoWFQ_Index or {}) do
                        n = n + 1
                end
                print("|cffffd100WoWFQ|r v" .. VERSION .. ", view = " .. get_view()
                        .. ", " .. n .. " Persian quests. Use /wowfq view fa|en|both or /wowfq mode")
        end
end

-- small API for other UI (the WoWFA panel can read/change the default view)
function WoWFQ.GetView()
        return get_view()
end

function WoWFQ.SetView(v)
        if not set_view(v) then
                return false
        end
        pcall(render_open)
        return true
end

-- test hook (only active when a harness pre-sets WoWFQ_TEST)
if WoWFQ_TEST then
        WoWFQ_internals = {
                fill_tokens = fill_tokens,
                persian_text = persian_text,
                persian_block = persian_block,
                shape_para = shape_para,
                quests_enabled = quests_enabled,
                get_view = get_view,
                set_view = set_view,
                render_fs = render_fs,
                render_title = render_title,
                detail_payload = detail_payload,
                apply_quest = apply_quest,
                update_log_titles = update_log_titles,
                update_tracker = update_tracker,
                toggle_view = toggle_view,
                update_button = update_button,
                buttons = toggle_buttons,
        }
end
