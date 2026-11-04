-- WoWFA Forever - user-facing strings.
-- Persian strings are drawn only with our own font (Vazirmatn). The chat
-- frame of an English client has no Persian glyphs, so every chat line uses
-- the English table L.en instead.

local L = {}
WoWFAF_L = L

L.subtitle = "ترجمهٔ فارسی WoW Forever"
L.master = "WoWFA روشن باشه"
L.master_d = "کلید اصلی. وقتی خاموشه هیچ متن فارسی‌ای به بازی اضافه نمی‌شه."

L.tab_mods = "بخش‌ها"
L.tab_names = "نام‌ها"
L.tab_display = "نمایش"
L.tab_health = "وضعیت"
L.tab_about = "درباره"

L.m_items = "آیتم‌ها"
L.m_items_d = "نام و توضیح فارسی زیر تولتیپ آیتم‌ها."
L.m_quests = "کوئست‌ها"
L.m_quests_d = "متن کامل کوئست کنار پنجرهٔ کوئست و دفترچهٔ کوئست."
L.m_dungeons = "دانجن و مناطق"
L.m_dungeons_d = "نام فارسی منطقه و دانجن موقع ورود و روی نقشهٔ کوچک."
L.m_npc = "NPC و اشیا"
L.m_npc_d = "نام فارسی NPCها، باس‌ها و اشیای دنیا روی تولتیپ."
L.m_spellbook = "اسپل‌بوک"
L.m_spellbook_d = "نام و توضیح فارسی اسپل‌ها در تولتیپ."
L.m_talents = "تلنت‌ها"
L.m_talents_d = "نام و توضیح فارسی تلنت‌ها در تولتیپ."

L.st_ok = "سالم"
L.st_warn = "هشدار"
L.st_off = "خاموش"
L.st_master = "کلید اصلی خاموشه"
L.st_nodata = "داده نداره"
L.st_schema = "داده ناسازگاره"
L.st_noapi = "خودکار خاموش شد"
L.st_update = "متوقف: آپدیت بازی"
L.st_fault = "خودکار خاموش شد: خطا"

L.why_nodata = "ترجمهٔ این بخش هنوز توی این نسخه نیست."
L.why_schema = "فرمت داده با این نسخهٔ اددان جور نیست. اددان رو کامل آپدیت کن."
L.why_noapi = "بازی این بخش رو عوض کرده و اددان دیگه پیداش نمی‌کنه. برای جلوگیری از خرابی خاموش شد؛ آپدیت جدید رو از سایت بگیر."
L.why_update = "بازی بعد از ساخت این ترجمه آپدیت شده و این بخش حساسه، پس موقتاً متوقفه. آپدیت اددان رو چک کن، یا اگه مشکلی نمی‌بینی روشنش کن."
L.why_warn_build = "بازی جدیدتر از داده‌های ترجمه‌ست؛ شاید بعضی متن‌ها قدیمی باشن."
L.why_warn_miss = "بیشتر متن‌های این بخش پیدا نشدن؛ احتمالاً بازی آپدیت شده. آپدیت اددان رو چک کن."
L.why_fault = "این بخش چند بار پشت هم خطا داد و برای اینکه بازیت به مشکل نخوره خاموش شد."
L.btn_resume = "با همین نسخه روشن کن"
L.btn_retry = "دوباره امتحان کن"

L.names_head = "مثل سایت: هر دسته‌ای که خاموش باشه، اون نام‌ها توی متن ترجمه انگلیسی می‌مونن."
L.n_npc = "NPCها"
L.n_zn = "مناطق"
L.n_it = "آیتم‌ها"
L.n_sp = "اسپل و مهارت"
L.n_ob = "اشیا"
L.n_qs = "عنوان کوئست‌ها"
L.n_cls = "کلاس‌ها"
L.n_tm = "اصطلاحات بازی"
L.all_on = "همه روشن"
L.all_off = "همه خاموش"

L.d_mode = "کدوم خط درست و خوانا دیده می‌شه؟ همون رو انتخاب کن."
L.d_sample = "شانس ضربهٔ بحرانی Fireball تا ۱۰٪ بیشتر می‌شه."
L.d_size = "اندازهٔ فونت"
L.d_item = "جزئیات آیتم"
L.opt_item = { "فقط نام", "نام و جلوه‌ها", "کامل" }
L.d_dock = "جای پنل کوئست"
L.opt_dock = { "سمت راست پنجره", "سمت چپ پنجره", "آزاد، جابه‌جاش کن" }
L.d_qauto = "پنل کوئست خودکار باز بشه"
L.d_zone = "اعلان نام منطقه"
L.opt_zone = { "همهٔ مناطق", "فقط دانجن و ریید", "خاموش" }
L.d_update = "وقتی بازی آپدیت شد"
L.opt_update = { "فقط هشدار بده", "بخش‌های حساس رو متوقف کن", "همه رو متوقف کن" }
L.d_digits = "عددهای زنده فارسی باشن"
L.d_minimap = "دکمهٔ کنار نقشهٔ کوچک"
L.d_toast = "پیام‌های اددان روی صفحه"
L.d_share = "خبر نسخهٔ جدید از هم‌گروهی‌ها"

L.h_client = "نسخهٔ بازی"
L.h_data = "نسخهٔ داده‌های ترجمه"
L.h_addon = "نسخهٔ اددان"
L.h_mem = "حافظه"
L.h_errors = "خطاهای اخیر؛ برای گزارش کپی کن و بفرست"
L.h_noerr = "خطایی ثبت نشده."
L.btn_recheck = "بررسی دوباره"
L.btn_clear = "پاک کردن خطاها"
L.btn_select = "انتخاب برای کپی"

L.a_site = "سایت و آپدیت‌ها"
L.a_cmds = "دستورها: /wowfa پنل، /wowfa on یا off، /wowfa status، /wowfa reset"
L.a_new = "چه خبر"
L.changelog = {
    "0.5.1: نام فارسی ۱٬۷۸۷ آیتم تازه و نام‌های کامل NPC.",
    "0.5.0: اولین نسخهٔ Forever با پنل جدید، صفحهٔ خوش‌آمد و محافظ آپدیت بازی.",
}
L.btn_welcome = "نمایش دوبارهٔ خوش‌آمد"
L.btn_reset = "بازنشانی همهٔ تنظیمات"
L.btn_reset_sure = "مطمئنی؟ دوباره بزن"

L.w_title = "به WoWFA خوش اومدی"
L.w_step1 = "Step 1: click the line that reads correctly"
L.w_step2 = "مرحلهٔ ۲: هر بخشی که می‌خوای ترجمه بشه رو روشن کن. بعداً هم از همین پنل عوض می‌شه."
L.w_start = "شروع"
L.w_later = "بعداً"

L.mm_left = "کلیک: باز کردن پنل"
L.mm_right = "راست‌کلیک: روشن یا خاموش"
L.mm_drag = "بکش تا جابه‌جا بشه"
L.mm_issue = "یک بخش نیاز به توجه داره"
L.open_panel = "باز کردن پنل WoWFA"

L.t_tripped = "بخش «%s» به خاطر خطا خودکار خاموش شد. جزئیات توی پنل، بخش وضعیت."
L.t_update = "بازی آپدیت شده. بخش‌های حساس موقتاً متوقف شدن تا آپدیت اددان رو بگیری."
L.t_newver = "نسخهٔ جدید WoWFA منتشر شده: %s. از wowfarsi.ir بگیرش."
L.t_miss = "متن‌های بخش «%s» دیگه با بازی جور نیست؛ احتمالاً آپدیت اومده."
L.t_upgraded = "WoWFA به نسخهٔ %s آپدیت شد."
L.t_nodata = "داده‌های ترجمه پیدا نشد؛ اددان رو دوباره نصب کن."
L.t_on = "WoWFA روشن شد."
L.t_off = "WoWFA خاموش شد."

L.stale_item = "(!) آمار این آیتم توی بازی عوض شده؛ فقط نام نشون داده شد."
L.stale_quest = "(!) متن این کوئست توی بازی عوض شده؛ ترجمه شاید قدیمی باشه."
L.q_obj = "هدف"
L.q_details = "شرح"
L.q_progress = "در جریان"
L.q_complete = "پایان"
L.zone_dungeon = "دانجن"
L.zone_raid = "ریید"

L.class = {
    WARRIOR = "جنگاور", PALADIN = "پالادین", HUNTER = "شکارچی", ROGUE = "راهزن", PRIEST = "روحانی",
    SHAMAN = "شمن", MAGE = "جادوگر", WARLOCK = "احضارکننده", DRUID = "دروئید",
}
L.race = {
    Human = "انسان", Dwarf = "دورف", NightElf = "نایت‌الف", Gnome = "گنوم",
    Orc = "اورک", Scourge = "آندد", Tauren = "تائورن", Troll = "ترول",
}

-- chat lines (English: the chat font has no Persian glyphs)
L.en = {
    m_items = "Items", m_quests = "Quests", m_dungeons = "Dungeons & zones", m_npc = "NPCs & objects",
    m_spellbook = "Spellbook", m_talents = "Talents",
    loaded = "WoWFA %s loaded (data build %s). Type /wowfa to open the panel.",
    tripped = "WoWFA: '%s' turned itself off after repeated errors. /wowfa > Status for details.",
    update = "WoWFA: the game was updated (build %s, translation data %s). Sensitive parts are paused until you update the addon or resume them in /wowfa.",
    build = "WoWFA: game build %s is newer than the translation data (%s). Texts may be slightly out of date; check wowfarsi.ir for an update.",
    iface = "WoWFA: the game interface (%d) is newer than this addon (%d). If something looks wrong, check wowfarsi.ir for an update.",
    newver = "WoWFA: a newer version (%s) is out. Get it from wowfarsi.ir",
    miss = "WoWFA: most '%s' texts no longer match the game. An addon update is probably needed.",
    nodata = "WoWFA: translation data not found. Please reinstall the addon.",
    schema = "WoWFA: translation data does not match this addon version. Please reinstall the addon.",
    on = "WoWFA enabled.", off = "WoWFA disabled.",
    reset = "WoWFA: all settings were reset.",
    combat = "WoWFA: will open after combat.",
    status = "WoWFA %s | game %s | data %s | %s",
}
