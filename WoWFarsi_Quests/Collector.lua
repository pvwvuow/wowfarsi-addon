-- WoWFarsi_Quests Collector.lua
-- Saves the English text of quests you open into the SavedVariables table
-- WoWFAQuestDB, keyed by questID. Nothing is sent anywhere. Import the file
-- with:  python tools/quests.py import-sv <WoWFarsi_Quests.lua>
--
-- Record: { title, summary, desc, obj = {...}, progress, complete, build }
--   title    quest title                       (QUEST_DETAIL / PROGRESS / COMPLETE)
--   summary  the "objective" paragraph         (QUEST_DETAIL)
--   desc     the story text                    (QUEST_DETAIL)
--   obj      quest-log objective lines, counters removed (after accepting)
--   progress text shown when you are not done  (QUEST_PROGRESS)
--   complete text shown on turn-in             (QUEST_COMPLETE)
-- Your character name is stored as $n. Class / race / gender words stay as the
-- game printed them; the import tool reports conflicts between captures.
--
-- Commands: /wowfaq status | scan | reset confirm

local VERSION = "0.1.0"
local db
local seenThisSession = {}

local function build_string()
        local version, build = GetBuildInfo()
        return tostring(version) .. "." .. tostring(build)
end

local function esc_pattern(s)
        return (string.gsub(s, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function clean(text)
        if type(text) ~= "string" or text == "" then
                return ""
        end
        local name = UnitName("player")
        if name and name ~= "" then
                if string.find(name, "^%a+$") then
                        text = string.gsub(text, "%f[%a]" .. esc_pattern(name) .. "%f[%A]", "$n")
                else
                        text = string.gsub(text, esc_pattern(name), "$n")
                end
        end
        text = string.gsub(text, "^%s+", "")
        text = string.gsub(text, "%s+$", "")
        return text
end

local function clean_objective(text)
        text = clean(text)
        text = string.gsub(text, ":%s*%d+/%d+$", "")
        text = string.gsub(text, "^%d+/%d+%s+", "")
        text = string.gsub(text, "%s*%(%d+%%%)$", "")
        return text
end

local function record(questID)
        if not questID or questID == 0 then
                return nil
        end
        local key = tostring(questID)
        local rec = db[key]
        if not rec then
                rec = { title = "", summary = "", desc = "", obj = {}, progress = "", complete = "" }
                db[key] = rec
        end
        rec.build = build_string()
        return rec
end

local function set(rec, field, value)
        value = clean(value)
        if value ~= "" and rec[field] ~= value then
                rec[field] = value
                return true
        end
        return false
end

local function read_objectives(questID)
        local rec = record(questID)
        if not rec or not C_QuestLog or not C_QuestLog.GetQuestObjectives then
                return
        end
        local ok, list = pcall(C_QuestLog.GetQuestObjectives, questID)
        if not ok or type(list) ~= "table" then
                return
        end
        local out = {}
        for _, o in ipairs(list) do
                local t = clean_objective(o.text)
                if t ~= "" then
                        out[#out + 1] = t
                end
        end
        if #out > 0 then
                rec.obj = out
        end
end

local function on_detail()
        local rec = record(GetQuestID())
        if rec then
                set(rec, "title", GetTitleText())
                set(rec, "desc", GetQuestText())
                set(rec, "summary", GetObjectiveText())
        end
end

local function on_progress()
        local rec = record(GetQuestID())
        if rec then
                set(rec, "title", GetTitleText())
                set(rec, "progress", GetProgressText())
        end
end

local function on_complete()
        local rec = record(GetQuestID())
        if rec then
                set(rec, "title", GetTitleText())
                set(rec, "complete", GetRewardText())
        end
end

local function scan_log()
        if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then
                return 0
        end
        local n = 0
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
                local info = C_QuestLog.GetInfo(i)
                if info and not info.isHeader and info.questID then
                        local rec = record(info.questID)
                        set(rec, "title", info.title)
                        if GetQuestLogQuestText then
                                local ok, desc, summary = pcall(GetQuestLogQuestText, i)
                                if ok then
                                        set(rec, "desc", desc)
                                        set(rec, "summary", summary)
                                end
                        end
                        read_objectives(info.questID)
                        n = n + 1
                end
        end
        return n
end

local function count()
        local n, full = 0, 0
        for _, rec in pairs(db) do
                n = n + 1
                if rec.desc ~= "" and rec.progress ~= "" and rec.complete ~= "" then
                        full = full + 1
                end
        end
        return n, full
end

local function say(msg)
        print("|cffffd100WoWFAQ|r " .. msg)
end

SLASH_WOWFAQ1 = "/wowfaq"
SlashCmdList["WOWFAQ"] = function(arg)
        arg = string.lower(arg or "")
        if arg == "scan" then
                say("scanned " .. scan_log() .. " quests from your quest log")
        elseif arg == "reset confirm" then
                for k in pairs(db) do
                        db[k] = nil
                end
                say("collected quests cleared")
        elseif arg == "reset" then
                say("type /wowfaq reset confirm to delete everything collected")
        else
                local n, full = count()
                say("v" .. VERSION .. ": " .. n .. " quests saved, " .. full .. " with description + progress + completion")
                say("/wowfaq scan   save text of quests in your log")
                say("Then /reload or log out, and give WTF/Account/<account>/SavedVariables/WoWFarsi_Quests.lua to the project.")
        end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
                if arg1 == "WoWFarsi_Quests" then
                        WoWFAQuestDB = WoWFAQuestDB or {}
                        db = WoWFAQuestDB
                        local n = count()
                        say("v" .. VERSION .. " ready, " .. n .. " quests saved. /wowfaq for help.")
                end
                return
        end
        if not db then
                return
        end
        local ok, err = pcall(function()
                if event == "QUEST_DETAIL" then
                        on_detail()
                elseif event == "QUEST_PROGRESS" then
                        on_progress()
                elseif event == "QUEST_COMPLETE" then
                        on_complete()
                elseif event == "QUEST_ACCEPTED" then
                        local questID = arg1
                        if C_Timer and C_Timer.After then
                                C_Timer.After(1, function()
                                        read_objectives(questID)
                                end)
                        else
                                read_objectives(questID)
                        end
                end
        end)
        if not ok and WoWFAQ_DEBUG then
                say("error in " .. event .. ": " .. tostring(err))
        end
end)
