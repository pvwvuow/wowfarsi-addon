# WoWFarsi — ادآن فارسی تلنت‌های World of Warcraft

نمایش توضیح فارسی تلنت‌ها زیر tooltip اسپل‌ها (پنجرهٔ تلنت، اسپل‌بک، اکشن‌بار) برای همهٔ ۱۳ کلاس در **World of Warcraft Retail (Midnight 12.1.5)**.

سایت رسمی: https://wowfarsi.ir

> نسخهٔ آزمایشی — هنوز داخل بازی تست نشده است. اگر مشکلی دیدی، لطفاً در [Issues](../../issues) گزارش بده.

## نصب

1. از بخش [Releases](../../releases) فایل `WoWFA-*.zip` را بگیر.
2. زیپ را باز کن و پوشهٔ `WoWFA` را داخل این مسیر بگذار:
   `World of Warcraft\_retail_\Interface\AddOns\`
   (باید مسیر `AddOns\WoWFA\WoWFA.toc` وجود داشته باشد).
3. در صفحهٔ انتخاب کاراکتر، AddOns را بزن و WoWFA را تیک بزن. اگر «out of date» نشان داد، *Load out of date AddOns* را فعال کن.
4. وارد بازی شو. در چت باید ببینی: `WoWFA loaded: N Persian talents`.

## تست

- پنجرهٔ تلنت (`N`) را باز کن و روی تلنت‌ها hover کن. زیر متن انگلیسی باید متن فارسی بیاید.
- برای دیدن خطاها: `/run WoWFA_DEBUG=true` و `/console scriptErrors 1`.
- موارد مهم برای تست: حروف چسبیده، جهت راست‌به‌چپ، پر شدن عددها (مثلاً «۵ ثانیه» نه `$s1`)، نزدن متن از عرض tooltip.
- گزارش مشکل: اسکرین‌شات tooltip + متن خطا + کلاس/اسپک + نام تلنت.

## مجوز

All Rights Reserved با ذکر نام پروژه — جزئیات در [LICENSE](LICENSE). فونت Vazirmatn تحت مجوز SIL OFL 1.1 است.

## WoWFA Forever

نسخهٔ کلاینت **Forever (1.15.x)** هم در همین مخزن نگه‌داری می‌شود (سورس؛ دادهٔ تولیدشده فقط داخل زیپ Release است):

1. از بخش [Releases](../../releases) فایل `WoWFA-forever-<ver>.zip` را بگیر.
2. زیپ را باز کن تا پوشهٔ `WoWFA` در مسیر `Interface\AddOns\WoWFA` کلاینت Forever قرار بگیرد (نباید `WoWFA-main` باشد).
3. وارد بازی شو و `/wowfa` را بزن.

انتشار داده‌های Forever طبق قانون ساخت Add-On — بدون تبلیغ و بدون درخواست حمایت مالی — انجام می‌شود.

## اعتبارها

- داده‌ها از ForeverDB.net (https://foreverdb.net)
- فونت Vazirmatn (SIL OFL 1.1)

World of Warcraft is a trademark of Blizzard Entertainment, Inc. This is a fan-made Persian translation, not affiliated with or endorsed by Blizzard.
