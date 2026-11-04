-- WoWFA Forever - quests: a Persian pane docked next to the quest window and
-- the quest log. We never rewrite Blizzard's own font strings, so a changed
-- quest UI can not break the game: if a frame is missing the pane just floats.

local F = WoWFAF
local L = F.L
local T = F.T
local UI = F.UI
local C = F.C
local SEP = "\031"
local PW, PH = 340, 440
local BODY_W = PW - 44

local M = { id = "quests", order = 2, risk = "low", nameKey = "m_quests", descKey = "m_quests_d", watchMiss = true }

function M.data()
    return F.D.quests
end

function M.api()
    return GetQuestID ~= nil and (QuestFrame ~= nil or QuestLogFrame ~= nil)
end

local function get(id)
    local raw = id and F.D.quests[id]
    if type(raw) ~= "string" then
        return nil
    end
    local p = F.Split(raw, SEP)
    return { en = p[1] or "", t = p[2] or "", obj = p[3] or "", details = p[4] or "", progress = p[5] or "", completion = p[6] or "", desc = p[7] or "" }
end

local function simple(s)
    return (string.gsub(string.lower(tostring(s or "")), "[^%w]", ""))
end

-- ------------------------------------------------------------------ pane
local pane, tab
local shownId, shownCtx, closedId

local function save_pos()
    local point, _, _, x, y = pane:GetPoint(1)
    if point then
        F.db.questPos = { point, x, y }
    end
end

local function build()
    pane = CreateFrame("Frame", "WoWFAF_QuestPane", UIParent)
    pane:SetSize(PW, PH)
    pane:SetFrameStrata("MEDIUM")
    pane:SetToplevel(true)
    pane:SetClampedToScreen(true)
    pane:EnableMouse(true)
    pane:SetMovable(true)
    pane:RegisterForDrag("LeftButton")
    pane:SetScript("OnDragStart", function(self)
        if F.db.questDock == 3 then
            self:StartMoving()
        end
    end)
    pane:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if F.db.questDock == 3 then
            save_pos()
        end
    end)
    UI.Glass(pane)
    pane.title = UI.Text(pane, 15, C.gold)
    pane.title:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -16, -14)
    pane.title:SetWidth(PW - 60)
    pane.banner = UI.Text(pane, 10, C.orange)
    pane.banner:SetPoint("TOPRIGHT", pane.title, "BOTTOMRIGHT", 0, -4)
    pane.banner:SetWidth(PW - 40)
    local close = CreateFrame("Button", nil, pane, "UIPanelCloseButton")
    close:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    close:SetScript("OnClick", function()
        closedId = shownId
        pane:Hide()
    end)
    pane.scroll = UI.ScrollPage(pane, PW - 28, PH - 80)
    pane.scroll:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -14, -66)
    pane.sec = {}
    for i = 1, 3 do
        local h = UI.Text(pane.scroll.child, 13, C.gold)
        local b = UI.Text(pane.scroll.child)
        b:SetTextColor(C.text[1], C.text[2], C.text[3])
        pane.sec[i] = { h = h, b = b }
    end
    pane:Hide()

    tab = CreateFrame("Button", "WoWFAF_QuestTab", UIParent)
    tab:SetSize(120, 26)
    tab:SetFrameStrata("MEDIUM")
    UI.Glass(tab, 0.9)
    tab.label = UI.Text(tab, 12, C.goldLight, "CENTER")
    tab.label:SetPoint("CENTER")
    tab.label:SetFa(L.m_quests, 110)
    tab:SetScript("OnClick", function()
        tab:Hide()
        closedId = nil
        if pane.entry then
            pane:Show()
        end
    end)
    tab:Hide()
end

local function dock(f, anchor)
    f:ClearAllPoints()
    local d = F.db.questDock
    local okA = anchor and anchor.IsShown and anchor:IsShown() and anchor:GetRight() ~= nil
    if d == 3 or not okA then
        local p = F.db.questPos
        if type(p) == "table" and type(p[1]) == "string" and tonumber(p[2]) and tonumber(p[3]) then
            f:SetPoint(p[1], UIParent, p[1], p[2], p[3])
        else
            f:SetPoint("CENTER", UIParent, "CENTER", 320, 40)
        end
        return
    end
    -- the classic quest frames carry ~30px of transparent art on the edges
    local inset = (anchor:GetWidth() or 0) >= 380 and 30 or 0
    if d == 2 then
        f:SetPoint("TOPRIGHT", anchor, "TOPLEFT", inset > 0 and 10 or -4, -inset * 0.5)
    else
        f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", -inset + 4, -inset * 0.5)
    end
end

local SECTIONS = {
    detail = { { "q_details", "details" }, { "q_obj", "obj" } },
    progress = { { "q_progress", "progress" } },
    complete = { { "q_complete", "completion" } },
    log = { { "q_obj", "obj" }, { "q_details", "details" } },
}

local function layout(entry, ctx)
    pane.title:SetFa(T.Prepare(entry.t ~= "" and entry.t or "?"), PW - 60)
    local y = 0
    local used = 0
    for i, s in ipairs(SECTIONS[ctx] or SECTIONS.log) do
        local text = entry[s[2]]
        if (not text or text == "") and s[2] == "obj" then
            text = entry.desc
        end
        local sec = pane.sec[i]
        if text and text ~= "" then
            used = used + 1
            sec.h:ClearAllPoints()
            sec.h:SetPoint("TOPRIGHT", pane.scroll.child, "TOPRIGHT", -4, -y)
            sec.h:SetWidth(BODY_W)
            sec.h:SetFa(L[s[1]], BODY_W)
            y = y + 22
            sec.b:ClearAllPoints()
            sec.b:SetPoint("TOPRIGHT", pane.scroll.child, "TOPRIGHT", -4, -y)
            sec.b:SetWidth(BODY_W)
            sec.b:SetFa(T.Prepare(text), BODY_W)
            y = y + (sec.b:GetStringHeight() or 40) + 14
            sec.h:Show()
            sec.b:Show()
        end
    end
    for i = 1, 3 do
        if i > used then
            pane.sec[i].h:Hide()
            pane.sec[i].b:Hide()
        end
    end
    pane.scroll.child:SetHeight(math.max(y, 10))
    pane.scroll:SetVerticalScroll(0)
    pane.scroll:UpdateBar()
end

local function show(id, enTitle, ctx, anchor)
    if not pane then
        build()
    end
    local entry = get(id)
    if not entry then
        F:Track("quests", false)
        pane:Hide()
        tab:Hide()
        return
    end
    local stale = F.Usable(enTitle) and entry.en ~= "" and simple(enTitle) ~= "" and simple(enTitle) ~= simple(entry.en)
    if shownId ~= id or shownCtx ~= ctx then
        F:Track("quests", true, stale)
    end
    pane.entry, pane.ctx, pane.anchor = entry, ctx, anchor
    shownId, shownCtx = id, ctx
    layout(entry, ctx)
    if stale then
        pane.banner:SetFa(L.stale_quest, PW - 40)
        pane.banner:Show()
        pane.scroll:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -14, -84)
    else
        pane.banner:Hide()
        pane.scroll:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -14, -66)
    end
    dock(pane, anchor)
    dock(tab, anchor)
    if closedId == id then
        pane:Hide()
        tab:Show()
    elseif F.db.questAuto then
        tab:Hide()
        pane:Show()
    else
        pane:Hide()
        tab:Show()
    end
end

local function hide(ctxFilter)
    if pane and (not ctxFilter or pane.src == ctxFilter) then
        pane:Hide()
        tab:Hide()
        shownId, shownCtx = nil, nil
    end
end

F.QuestToggle = function()
    if not pane or not pane.entry then
        return
    end
    if pane:IsShown() then
        closedId = shownId
        pane:Hide()
        tab:Show()
    else
        closedId = nil
        tab:Hide()
        pane:Show()
    end
end

-- ------------------------------------------------------------- sources
local function frame_quest()
    local id = GetQuestID and GetQuestID()
    local title = GetTitleText and GetTitleText()
    if not F.Usable(id) or type(id) ~= "number" or id <= 0 then
        return nil
    end
    return id, title
end

local function log_quest()
    if GetQuestLogSelection and GetQuestLogTitle then
        local idx = GetQuestLogSelection()
        if F.Usable(idx) and idx and idx > 0 then
            local title, _, _, isHeader, _, _, _, qid = GetQuestLogTitle(idx)
            if not isHeader and F.Usable(qid) and type(qid) == "number" and qid > 0 then
                return qid, title
            end
        end
    end
    if C_QuestLog and C_QuestLog.GetSelectedQuest then
        local qid = C_QuestLog.GetSelectedQuest()
        if F.Usable(qid) and type(qid) == "number" and qid > 0 then
            local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)
            return qid, title
        end
    end
end

local function log_frame()
    for _, name in ipairs({ "QuestLogFrame", "QuestLogDetailFrame", "QuestMapFrame" }) do
        local f = _G[name]
        if f and f.IsShown and f:IsShown() then
            return f
        end
    end
end

local function on_frame(ctx)
    return function()
        local id, title = frame_quest()
        if id then
            show(id, title, ctx, QuestFrame)
            pane.src = "frame"
        end
    end
end

local function on_log()
    local f = log_frame()
    if not f then
        hide("log")
        return
    end
    if pane and pane.src == "frame" and pane:IsShown() and QuestFrame and QuestFrame:IsShown() then
        return -- the open quest dialog wins
    end
    local id, title = log_quest()
    if id then
        show(id, title, "log", f)
        pane.src = "log"
    end
end

function M.install()
    F:On("QUEST_DETAIL", "quests", on_frame("detail"))
    F:On("QUEST_PROGRESS", "quests", on_frame("progress"))
    F:On("QUEST_COMPLETE", "quests", on_frame("complete"))
    F:On("QUEST_FINISHED", "quests", function()
        F.After(0.1, function()
            if not (QuestFrame and QuestFrame:IsShown()) then
                hide("frame")
            end
        end)
    end)
    local throttle = 0
    F:On("QUEST_LOG_UPDATE", "quests", function()
        local now = GetTime()
        if now - throttle > 0.3 and log_frame() then
            throttle = now
            on_log()
        end
    end)
    local wrapped = F:Wrap("quests", on_log)
    for _, fn in ipairs({ "SelectQuestLogEntry", "QuestLog_SetSelection" }) do
        if type(_G[fn]) == "function" then
            hooksecurefunc(fn, wrapped)
        end
    end
    for _, name in ipairs({ "QuestLogFrame", "QuestLogDetailFrame", "QuestMapFrame" }) do
        local f = _G[name]
        if f and f.HookScript then
            f:HookScript("OnShow", wrapped)
            f:HookScript("OnHide", F:Wrap("quests", function()
                F.After(0.05, on_log)
            end))
        end
    end
    if QuestFrame and QuestFrame.HookScript then
        QuestFrame:HookScript("OnHide", function()
            hide("frame")
        end)
    end
    F:Listen("options", function(key)
        if pane and pane.entry and shownId and (key == "questDock" or key == "questAuto") then
            show(shownId, nil, shownCtx, pane.anchor)
        end
    end)
    F:Listen("names", function()
        if pane and pane:IsShown() and pane.entry then
            layout(pane.entry, pane.ctx)
        end
    end)
    F:Listen("text", function()
        if pane and pane:IsShown() and pane.entry then
            layout(pane.entry, pane.ctx)
        end
    end)
end

function M.onState(_, active)
    if not active then
        hide()
    end
end

F:RegisterModule(M)
