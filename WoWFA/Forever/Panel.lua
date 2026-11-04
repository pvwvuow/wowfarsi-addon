-- WoWFA Forever - main panel (minimap button / compartment / /wowfa).
-- Pages: modules (master switch + sub-switches), names (site-style family
-- switches), display, status (health + error log) and about.
-- The welcome page runs on first login: pick the display mode that reads
-- correctly, then choose the parts to translate.

local F = WoWFAF
local L = F.L
local T = F.T
local UI = F.UI
local C = F.C

local W, H = 620, 520
local CW = W - 48 -- content width
local panel, pages, tabs, current = nil, {}, {}, nil

local STATE_COLOR = {
    ok = C.green, warn = C.orange, off = C.off, master = C.off, nodata = C.muted,
    schema = C.red, noapi = C.red, update = C.orange, fault = C.red,
}
local WHY = {
    nodata = "why_nodata", schema = "why_schema", noapi = "why_noapi", update = "why_update", fault = "why_fault",
}

local function why_text(m)
    if m.state == "warn" then
        return m.why == "miss" and L.why_warn_miss or L.why_warn_build
    end
    return WHY[m.state] and L[WHY[m.state]] or nil
end

-- ------------------------------------------------------------ modules page
local function build_modules(page)
    local c = page.child
    local y = -4
    local master = UI.Toggle(c, CW - 10, L.master, L.master_d, function()
        return F.db.enabled
    end, function(v)
        F:SetEnabled(v)
    end)
    master:SetPoint("TOPRIGHT", c, "TOPRIGHT", -2, y)
    master.label:SetFont(F.FONT, 14, "")
    page.master = master
    y = y - 50
    page.rows = {}
    for _, m in ipairs(F.order) do
        local row = CreateFrame("Frame", nil, c)
        row:SetSize(CW - 30, 64)
        row:SetPoint("TOPRIGHT", c, "TOPRIGHT", -24, y)
        local branch = UI.Line(row, true, 0.3)
        branch:SetPoint("TOPRIGHT", row, "TOPRIGHT", 12, 4)
        branch:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 12, 4)
        row.toggle = UI.Toggle(row, CW - 30, L[m.nameKey], L[m.descKey], function()
            return F.db.mods[m.id]
        end, function(v)
            F:SetModule(m.id, v)
        end)
        row.toggle:SetPoint("TOPRIGHT")
        row.badge = UI.Text(row, 10, C.green, "LEFT")
        row.badge:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -6)
        row.badge:SetWidth(128)
        row.why = UI.Text(row, 10, C.orange)
        row.why:SetPoint("TOPRIGHT", row, "TOPRIGHT", -26, -42)
        row.why:SetWidth(CW - 200)
        row.action = UI.Button(row, L.btn_resume, 128, 20, function()
            if m.state == "update" or m.state == "warn" then
                F:Resume(m.id)
            else
                F:SetModule(m.id, true)
            end
        end)
        row.action:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -24)
        row.action:SetFrameLevel(row.toggle:GetFrameLevel() + 3)
        row.m = m
        page.rows[#page.rows + 1] = row
        y = y - 68
    end
    c:SetHeight(-y + 10)
    page.Update = function()
        page.master:Update()
        for _, row in ipairs(page.rows) do
            local m = row.m
            row.toggle.dimmed = not F.db.enabled
            row.toggle:Update()
            local col = STATE_COLOR[m.state] or C.muted
            row.badge:SetTextColor(col[1], col[2], col[3])
            row.badge:SetFa(L["st_" .. m.state] or m.state, 128)
            local w = why_text(m)
            if w then
                row.why:SetFa(w, CW - 200)
                row.why:Show()
            else
                row.why:Hide()
            end
            if m.state == "update" or m.state == "warn" then
                row.action:SetLabel(L.btn_resume)
                row.action:SetShown(m.state == "update" or m.why == "miss")
            elseif m.state == "fault" or m.state == "noapi" then
                row.action:SetLabel(L.btn_retry)
                row.action:Show()
            else
                row.action:Hide()
            end
        end
        page:UpdateBar()
    end
end

-- -------------------------------------------------------------- names page
local function build_names(page)
    local c = page.child
    local head = UI.Text(c, 11, C.muted)
    head:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -4)
    head:SetWidth(CW - 10)
    head:SetFa(L.names_head, CW - 10)
    page.rows = {}
    local colW = math.floor((CW - 20) / 2)
    for i, fam in ipairs(T.FAMILIES) do
        local col = (i - 1) % 2
        local line = math.floor((i - 1) / 2)
        local t = UI.Toggle(c, colW, L["n_" .. fam], nil, function()
            return F.db.names[fam] ~= false
        end, function(v)
            F.db.names[fam] = v
            F:Fire("names")
        end)
        t:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4 - col * (colW + 10), -48 - line * 32)
        page.rows[#page.rows + 1] = t
    end
    local function all(v)
        for _, fam in ipairs(T.FAMILIES) do
            F.db.names[fam] = v
        end
        F:Fire("names")
        page.Update()
    end
    local on = UI.Button(c, L.all_on, 120, 24, function()
        all(true)
    end)
    on:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -48 - 4 * 32 - 12)
    local off = UI.Button(c, L.all_off, 120, 24, function()
        all(false)
    end)
    off:SetPoint("RIGHT", on, "LEFT", -10, 0)
    c:SetHeight(48 + 4 * 32 + 60)
    page.Update = function()
        for _, r in ipairs(page.rows) do
            r:Update()
        end
        page:UpdateBar()
    end
end

-- ----------------------------------------------------- display mode picker
local function mode_picker(parent, width, onPick)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(width, 3 * 40)
    box.rows = {}
    for i = 1, 3 do
        local b = CreateFrame("Button", nil, box)
        b:SetSize(width, 36)
        b:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -(i - 1) * 40)
        local bg = UI.Tex(b, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(C.bg2[1], C.bg2[2], C.bg2[3], 0.8)
        local hl = UI.Tex(b, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.08)
        b.dot = UI.Tex(b, "ARTWORK", "diamond_hollow")
        b.dot:SetSize(14, 14)
        b.dot:SetPoint("RIGHT", b, "RIGHT", -8, 0)
        b.fill = UI.Tex(b, "OVERLAY", "diamond")
        b.fill:SetSize(8, 8)
        b.fill:SetPoint("CENTER", b.dot, "CENTER")
        b.num = UI.Latin(b, 14, C.gold, "LEFT")
        b.num:SetPoint("LEFT", b, "LEFT", 10, 0)
        b.num:SetText(tostring(i))
        b.sample = UI.Text(b, 13, C.text)
        b.sample.wfaMode = i
        b.sample:SetPoint("RIGHT", b.dot, "LEFT", -10, 0)
        b.sample:SetWidth(width - 70)
        b.sample:SetFa(L.d_sample, width - 70)
        b:SetScript("OnClick", function()
            F.db.mode = i
            T.RefreshAll()
            box:Update()
            if onPick then
                onPick(i)
            end
        end)
        box.rows[i] = b
    end
    box.Update = function()
        for i, b in ipairs(box.rows) do
            local on = F.db.mode == i
            b.fill:SetShown(on)
            local c = on and C.gold or C.off
            b.dot:SetVertexColor(c[1], c[2], c[3])
        end
    end
    box:Update()
    return box
end

-- ------------------------------------------------------------ display page
local function build_display(page)
    local c = page.child
    local y = -4
    local function place(f, h)
        f:SetPoint("TOPRIGHT", c, "TOPRIGHT", -2, y)
        y = y - (h or f:GetHeight()) - 6
        return f
    end
    local q = UI.Text(c, 12, C.gold)
    q:SetWidth(CW - 10)
    q:SetFa(L.d_mode, CW - 10)
    place(q, 20)
    page.picker = place(mode_picker(c, CW - 10))

    -- font size
    local size = CreateFrame("Frame", nil, c)
    size:SetSize(CW - 10, 28)
    size.label = UI.Text(size, 12, C.text)
    size.label:SetPoint("RIGHT", size, "RIGHT", -4, 0)
    size.label:SetFa(L.d_size, 200)
    size.val = UI.Latin(size, 13, C.goldLight, "CENTER")
    size.val:SetPoint("LEFT", size, "LEFT", 40, 0)
    size.val:SetWidth(40)
    local minus = UI.Button(size, "-", 30, 22, function()
        F.db.fontSize = math.max(9, F.db.fontSize - 1)
        T.RefreshAll()
        page.Update()
    end)
    minus:SetPoint("LEFT", size, "LEFT", 0, 0)
    local plus = UI.Button(size, "+", 30, 22, function()
        F.db.fontSize = math.min(20, F.db.fontSize + 1)
        T.RefreshAll()
        page.Update()
    end)
    plus:SetPoint("LEFT", size.val, "RIGHT", 4, 0)
    place(size)
    page.size = size

    page.rows = {}
    local function cyc(label, opts, key)
        local r = UI.Cycler(c, CW - 10, label, opts, function()
            return F.db[key]
        end, function(v)
            F.db[key] = v
            F:Fire("options", key)
            F:Refresh()
        end)
        page.rows[#page.rows + 1] = place(r)
    end
    local function tog(label, key, after)
        local r = UI.Toggle(c, CW - 10, label, nil, function()
            if key == "minimap" then
                return not F.db.minimap.hide
            end
            return F.db[key]
        end, function(v)
            if key == "minimap" then
                F.db.minimap.hide = not v
                F:Fire("minimap")
            else
                F.db[key] = v
                F:Fire("options", key)
            end
            if after then
                after()
            end
        end)
        page.rows[#page.rows + 1] = place(r)
    end
    cyc(L.d_item, L.opt_item, "itemDetail")
    cyc(L.d_dock, L.opt_dock, "questDock")
    tog(L.d_qauto, "questAuto")
    cyc(L.d_zone, L.opt_zone, "zoneToast")
    cyc(L.d_update, L.opt_update, "onUpdate")
    tog(L.d_digits, "faDigits")
    tog(L.d_minimap, "minimap")
    tog(L.d_toast, "toast")
    tog(L.d_share, "share")
    c:SetHeight(-y + 10)
    page.Update = function()
        page.picker:Update()
        page.size.val:SetText(tostring(F.db.fontSize))
        for _, r in ipairs(page.rows) do
            r:Update()
        end
        page:UpdateBar()
    end
end

-- ------------------------------------------------------------- status page
local function build_health(page)
    local c = page.child
    local info = {}
    local keys = { "h_addon", "h_client", "h_data", "h_mem" }
    for i, k in ipairs(keys) do
        local lab = UI.Text(c, 12, C.muted)
        lab:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -4 - (i - 1) * 22)
        lab:SetFa(L[k], 220)
        local val = UI.Latin(c, 12, C.text, "LEFT")
        val:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -6 - (i - 1) * 22)
        val:SetWidth(CW - 240)
        info[k] = val
    end
    local y = -4 - #keys * 22 - 8
    local list = UI.Latin(c, 11, C.text, "LEFT")
    list:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
    list:SetWidth(CW - 10)
    list:SetJustifyV("TOP")
    page.list = list
    local errHead = UI.Header(c, L.h_errors, CW - 10)
    errHead:SetPoint("TOPRIGHT", c, "TOPRIGHT", -2, y - 120)
    local eb = CreateFrame("EditBox", nil, c)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFont(F.FONT, 10, "")
    eb:SetTextColor(C.text[1], C.text[2], C.text[3])
    eb:SetWidth(CW - 20)
    eb:SetHeight(150)
    eb:SetPoint("TOPLEFT", c, "TOPLEFT", 6, y - 152)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnTextChanged", function(self, user)
        if user then
            self:SetText(self.wfaText or "")
        end
    end)
    local ebg = UI.Tex(eb, "BACKGROUND")
    ebg:SetPoint("TOPLEFT", -4, 4)
    ebg:SetPoint("BOTTOMRIGHT", 4, -4)
    ebg:SetColorTexture(0, 0, 0, 0.35)
    page.eb = eb
    local by = y - 152 - 160
    local recheck = UI.Button(c, L.btn_recheck, 130, 24, function()
        for _, m in ipairs(F.order) do
            m.health, m.hit, m.miss, m.stale, m.seen = nil, 0, 0, 0, 0
        end
        F:Refresh()
    end)
    recheck:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, by)
    local clear = UI.Button(c, L.btn_clear, 130, 24, function()
        wipe(F.db.errors)
        page.Update()
    end)
    clear:SetPoint("RIGHT", recheck, "LEFT", -8, 0)
    local sel = UI.Button(c, L.btn_select, 130, 24, function()
        eb:SetFocus()
        eb:HighlightText()
    end)
    sel:SetPoint("RIGHT", clear, "LEFT", -8, 0)
    c:SetHeight(-by + 40)
    page.Update = function()
        info.h_addon:SetText(F.VERSION)
        local warnBuild = F.buildNewer or F.patchNewer
        info.h_client:SetText(tostring(F.clientVersion) .. "." .. tostring(F.clientBuildText) .. "  (interface " .. tostring(F.interface or "?") .. ")" .. (warnBuild and "  |cffff9e40newer than data|r" or ""))
        info.h_data:SetText(tostring(F.dataBuildText) .. "  " .. tostring(F.D and F.D.meta and F.D.meta.date or ""))
        local kb
        if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
            pcall(UpdateAddOnMemoryUsage)
            local ok, v = pcall(GetAddOnMemoryUsage, F.ADDON)
            kb = ok and v or nil
        end
        info.h_mem:SetText(kb and string.format("%.1f MB", kb / 1024) or "-")
        local lines = {}
        for _, m in ipairs(F.order) do
            lines[#lines + 1] = string.format("%-16s %-8s hits %d  miss %d  stale %d  errors %d",
                L.en[m.nameKey] or m.id, tostring(m.state), m.hit or 0, m.miss or 0, m.stale or 0, m.faults or 0)
        end
        if F.newerVersion then
            lines[#lines + 1] = "|cffff9e40newer addon version seen: " .. F.newerVersion .. "|r"
        end
        list:SetText(table.concat(lines, "\n"))
        local out = {}
        for i, e in ipairs(F.db.errors) do
            if i > 8 then
                break
            end
            out[#out + 1] = string.format("[%s] x%d v%s b%s: %s", tostring(e.m), e.n or 1, tostring(e.v), tostring(e.b), tostring(e.e))
        end
        local text = #out > 0 and (F.StatusLine() .. "\n" .. table.concat(out, "\n")) or ""
        eb.wfaText = text
        eb:SetText(text)
        if #out == 0 then
            eb:SetText("")
            eb.wfaText = ""
        end
        page:UpdateBar()
    end
end

-- -------------------------------------------------------------- about page
local function build_about(page)
    local c = page.child
    local y = -4
    local title = UI.Latin(c, 18, C.gold, "RIGHT")
    title:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, y)
    title:SetText("WoWFA " .. F.VERSION)
    y = y - 30
    local site = UI.Text(c, 12, C.muted)
    site:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, y)
    site:SetFa(L.a_site, 200)
    local eb = CreateFrame("EditBox", nil, c)
    eb:SetAutoFocus(false)
    eb:SetFont(F.FONT, 12, "")
    eb:SetTextColor(C.blue[1], C.blue[2], C.blue[3])
    eb:SetSize(240, 20)
    eb:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
    eb:SetText(F.SITE)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEditFocusGained", eb.HighlightText)
    eb:SetScript("OnTextChanged", function(self, user)
        if user then
            self:SetText(F.SITE)
            self:HighlightText()
        end
    end)
    y = y - 26
    local credit = UI.Latin(c, 11, C.muted, "LEFT")
    credit:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
    credit:SetText("Data from ForeverDB.net  |  Persian font: Vazirmatn (OFL)")
    y = y - 26
    -- ForeverDB credit link (addon policy: visible wherever the data is shown).
    -- Same pattern as the site EditBox above: read-only in effect (resets on
    -- user edit), select-all on focus, so the URL is copyable.
    local fdbUrl = CreateFrame("EditBox", nil, c)
    fdbUrl:SetAutoFocus(false)
    fdbUrl:SetFont(F.FONT, 12, "")
    fdbUrl:SetTextColor(C.blue[1], C.blue[2], C.blue[3])
    fdbUrl:SetSize(240, 20)
    fdbUrl:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
    fdbUrl:SetText("https://foreverdb.net")
    fdbUrl:SetScript("OnEscapePressed", fdbUrl.ClearFocus)
    fdbUrl:SetScript("OnEditFocusGained", fdbUrl.HighlightText)
    fdbUrl:SetScript("OnTextChanged", function(self, user)
        if user then
            self:SetText("https://foreverdb.net")
            self:HighlightText()
        end
    end)
    y = y - 26
    local cmds = UI.Text(c, 11, C.text)
    cmds:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, y)
    cmds:SetWidth(CW - 10)
    cmds:SetFa(L.a_cmds, CW - 10)
    y = y - 36
    local nh = UI.Header(c, L.a_new, CW - 10)
    nh:SetPoint("TOPRIGHT", c, "TOPRIGHT", -2, y)
    y = y - 30
    for _, line in ipairs(L.changelog) do
        local t = UI.Text(c, 11, C.text)
        t:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, y)
        t:SetWidth(CW - 10)
        t:SetFa(line, CW - 10)
        y = y - 34
    end
    y = y - 10
    local welcome = UI.Button(c, L.btn_welcome, 170, 24, function()
        F.OpenPanel("welcome")
    end)
    welcome:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, y)
    local reset
    reset = UI.Button(c, L.btn_reset, 170, 24, function(self)
        if self.armed and GetTime() - self.armed < 4 then
            self.armed = nil
            F:ResetDB()
            F.Chat(L.en.reset)
            self:SetLabel(L.btn_reset)
            if panel then
                panel:UpdateAll()
            end
        else
            self.armed = GetTime()
            self:SetLabel(L.btn_reset_sure)
            F.After(4, function()
                if reset.armed and GetTime() - reset.armed >= 3.9 then
                    reset.armed = nil
                    reset:SetLabel(L.btn_reset)
                end
            end)
        end
    end)
    reset:SetPoint("RIGHT", welcome, "LEFT", -10, 0)
    c:SetHeight(-y + 40)
    page.Update = function()
        page:UpdateBar()
    end
end

-- ------------------------------------------------------------ welcome page
local function build_welcome(page)
    local c = page.child
    local title = UI.Latin(c, 18, C.gold, "CENTER")
    title:SetPoint("TOP", c, "TOP", 0, -4)
    title:SetText("WoWFA")
    local hint = UI.Latin(c, 12, C.goldLight, "CENTER")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
    hint:SetText(L.w_step1)
    local step2 = CreateFrame("Frame", nil, c)
    local picker = mode_picker(c, CW - 10, function()
        step2:Show()
        page.Update()
    end)
    picker:SetPoint("TOPRIGHT", c, "TOPRIGHT", -2, -52)
    step2:SetSize(CW - 10, 360)
    step2:SetPoint("TOPRIGHT", picker, "BOTTOMRIGHT", 0, -12)
    local wt = UI.Text(step2, 15, C.gold, "CENTER")
    wt:SetPoint("TOP", step2, "TOP", 0, 0)
    wt:SetFa(L.w_title, CW - 20)
    local s2 = UI.Text(step2, 11, C.muted)
    s2:SetPoint("TOPRIGHT", step2, "TOPRIGHT", -4, -26)
    s2:SetWidth(CW - 20)
    s2:SetFa(L.w_step2, CW - 20)
    page.rows = {}
    local master = UI.Toggle(step2, CW - 20, L.master, nil, function()
        return F.db.enabled
    end, function(v)
        F:SetEnabled(v)
        page.Update()
    end)
    master:SetPoint("TOPRIGHT", step2, "TOPRIGHT", -2, -62)
    page.rows[1] = master
    local colW = math.floor((CW - 50) / 2)
    for i, m in ipairs(F.order) do
        local col = (i - 1) % 2
        local line = math.floor((i - 1) / 2)
        local t = UI.Toggle(step2, colW, L[m.nameKey], nil, function()
            return F.db.mods[m.id]
        end, function(v)
            F:SetModule(m.id, v)
        end)
        t:SetPoint("TOPRIGHT", step2, "TOPRIGHT", -26 - col * (colW + 8), -94 - line * 30)
        page.rows[#page.rows + 1] = t
    end
    local start = UI.Button(step2, L.w_start, 150, 28, function()
        F.db.welcomed = true
        F:Refresh()
        F.OpenPanel("mods")
    end)
    start:SetPoint("TOPRIGHT", step2, "TOPRIGHT", -26, -94 - 3 * 30 - 14)
    local later = UI.Button(step2, L.w_later, 110, 28, function()
        F.db.welcomed = true
        panel:Hide()
    end)
    later:SetPoint("RIGHT", start, "LEFT", -10, 0)
    step2:SetHeight(94 + 3 * 30 + 50)
    c:SetHeight(52 + 120 + 12 + step2:GetHeight() + 10)
    page.OnOpen = function()
        if F.db.welcomed then
            step2:Show()
        else
            step2:Hide()
        end
    end
    page.Update = function()
        picker:Update()
        for i, r in ipairs(page.rows) do
            r.dimmed = i > 1 and not F.db.enabled
            r:Update()
        end
        page:UpdateBar()
    end
end

-- ---------------------------------------------------------------- frame
local TABS = {
    { id = "mods", key = "tab_mods", build = build_modules },
    { id = "names", key = "tab_names", build = build_names },
    { id = "display", key = "tab_display", build = build_display },
    { id = "health", key = "tab_health", build = build_health },
    { id = "about", key = "tab_about", build = build_about },
}

local function show_page(id)
    current = id
    for pid, p in pairs(pages) do
        p:SetShown(pid == id)
    end
    for _, t in ipairs(tabs) do
        local on = t.id == id
        local col = on and C.gold or C.muted
        t.label:SetTextColor(col[1], col[2], col[3])
        t.under:SetShown(on)
        t:SetShown(id ~= "welcome")
    end
    local p = pages[id]
    if p then
        if p.OnOpen then
            p.OnOpen()
        end
        p:SetVerticalScroll(0)
        p.Update()
    end
end

local function build()
    panel = CreateFrame("Frame", "WoWFAF_Panel", UIParent)
    panel:SetSize(W, H)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("HIGH")
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    UI.Glass(panel)
    tinsert(UISpecialFrames, "WoWFAF_Panel")

    local icon = UI.Tex(panel, "ARTWORK", "icon")
    icon:SetSize(34, 34)
    icon:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -14)
    local title = UI.Latin(panel, 20, C.gold, "RIGHT")
    title:SetPoint("TOPRIGHT", icon, "TOPLEFT", -10, -1)
    title:SetText("WoWFA")
    local sub = UI.Text(panel, 11, C.muted)
    sub:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -2)
    sub:SetFa(L.subtitle, 300)
    local ver = UI.Latin(panel, 10, C.muted, "LEFT")
    ver:SetPoint("TOPLEFT", panel, "TOPLEFT", 40, -18)
    ver:SetText("v" .. F.VERSION)
    panel.ver = ver
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -2)
    close:SetScript("OnClick", function()
        panel:Hide()
    end)

    -- tabs, right to left
    local x = -20
    for _, def in ipairs(TABS) do
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(100, 26)
        b:SetPoint("TOPRIGHT", panel, "TOPRIGHT", x, -62)
        b.label = UI.Text(b, 13, C.muted, "CENTER")
        b.label:SetPoint("CENTER")
        b.label:SetFa(L[def.key], 96)
        b.under = UI.Line(b, false, 0.9)
        b.under:SetPoint("BOTTOMLEFT", 8, 0)
        b.under:SetPoint("BOTTOMRIGHT", -8, 0)
        b.id = def.id
        b:SetScript("OnClick", function()
            show_page(def.id)
        end)
        tabs[#tabs + 1] = b
        x = x - 104
    end
    local sep = UI.Line(panel, false, 0.3)
    sep:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -90)
    sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -90)

    local function page_frame()
        local p = UI.ScrollPage(panel, CW, H - 100 - 40)
        p:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -100)
        p:Hide()
        return p
    end
    for _, def in ipairs(TABS) do
        local p = page_frame()
        def.build(p)
        pages[def.id] = p
    end
    local wp = page_frame()
    wp:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -64)
    wp:SetHeight(H - 64 - 40)
    build_welcome(wp)
    pages.welcome = wp

    -- footer: builds + warning
    local foot = UI.Latin(panel, 10, C.muted, "LEFT")
    foot:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 12)
    foot:SetWidth(W - 32)
    panel.foot = foot

    panel.UpdateAll = function()
        local warn = F.buildNewer or F.patchNewer
        foot:SetText(string.format("game %s  |  data %s%s%s", tostring(F.clientVersion or "") .. "." .. tostring(F.clientBuildText or "?"), tostring(F.dataBuildText or "-"),
            warn and "  |cffff9e40(game is newer)|r" or "", F.newerVersion and ("  |cffff9e40new addon " .. F.newerVersion .. "|r") or ""))
        local p = pages[current]
        if p and p:IsShown() then
            p.Update()
        end
    end
    panel:SetScript("OnShow", function()
        panel.UpdateAll()
    end)
    panel:Hide()
end

function F.OpenPanel(page)
    if not F.db then
        return
    end
    if not panel then
        local ok, err = pcall(build)
        if not ok then
            F:LogError("ui", err)
            F.Chat("WoWFA: panel failed to build: " .. tostring(err))
            panel = nil
            return
        end
    end
    if page == nil and panel:IsShown() then
        panel:Hide()
        return
    end
    if not F.db.welcomed then
        page = "welcome"
    end
    panel:Show()
    show_page(page or (current ~= "welcome" and current) or "mods")
    panel.UpdateAll()
end

function F.TogglePanel()
    F.OpenPanel(nil)
end

local function refresh()
    if panel and panel:IsShown() then
        panel.UpdateAll()
    end
end
F:Listen("state", refresh)
F:Listen("errors", refresh)
F:Listen("text", refresh)

-- first login: welcome page (out of combat, after the loading screen)
F:Listen("login", function()
    if F.db.welcomed then
        return
    end
    local function open()
        if InCombatLockdown and InCombatLockdown() then
            F.After(5, open)
            return
        end
        F.OpenPanel("welcome")
    end
    F.After(4, open)
end)
