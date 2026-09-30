# [L4D2] Last Chapter Results

The end-of-chapter screen only has room for 4 survivors. This plugin reads the game's own per-player
chapter stats (the `m_checkpoint*` netprops the end screen is built from) for every survivor, bots
included, keeps them when the chapter ends, and shows them to anyone who asks.

- Highlights (Tank Slayer, Witch Hunter, Team Medic, ...) for all survivors
- A stats line per survivor in chat, and a full table in the console

## Commands and settings

| | |
|---|---|
| `!lastresults` / `!slr` | Every survivor's stats from the previous chapter |
| `!results` / `!sr` | Every survivor's stats for the current chapter so far |
| `l4d2_lastresults_announce` `1` | Remind players about `!lastresults` after a new chapter loads (0 = off) |

Config: `cfg/sourcemod/l4d2_lastresults.cfg`

No other plugins needed.
