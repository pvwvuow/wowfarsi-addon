# WoWFarsi_Quests (collector + display)

Tiny add-on that saves the English text of quests as you open them, so the
project has real source text to translate. Nothing is uploaded.

The display half shows the Persian quest text inside the game (requires the
`WoWFA` addon). `/wowfq mode below|replace` picks whether the Persian text is
appended under the English text (below, default) or replaces it. How the
Persian letters are drawn follows the WoWFA panel display mode
(`/wowfa mode 1|2|3`), and the whole feature can be switched off in the WoWFA
panel: the «کوئست‌ها» row toggles it, and with it off no text is added
anywhere.

Part of the WoWFarsi add-on family.

Install: copy this folder to `World of Warcraft/_retail_/Interface/AddOns/`.

Use: play normally and open quests (accept, hand in, click quests you already
hold). `/wowfaq scan` saves the text of every quest in your log in one go.
`/wowfaq` shows how many were saved.

Send the file `WTF/Account/<ACCOUNT>/SavedVariables/WoWFarsi_Quests.lua` (after
`/reload` or logging out). Then:

```
python tools/quests.py import-sv WoWFarsi_Quests.lua
python tools/quests.py lint
```

The text is not yet tested in the real client: if `/wowfaq` prints nothing, set
`WoWFAQ_DEBUG = true` in the chat (`/run WoWFAQ_DEBUG=true`) and report the error.
