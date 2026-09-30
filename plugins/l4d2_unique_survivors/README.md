# [L4D2] Unique Survivors

With 5+ survivors, the extra bot is often a copy of someone who is already playing ("(1)Ellis"). The
team HUD tracks survivors by their character number, so duplicates share one HUD slot and one of them
disappears from the HUD.

- **No duplicate bots**: a bot whose character number is already in use gets an unused number, plus a
  model and name nobody else has. Human players are never given another model.
- **Name and HUD follow the model**: Survivor Chat Select's `!csm` (players) and `!csc` (admins, on bots)
  only change the model. This plugin also sets the character number to match, and renames bots, so the
  HUD portrait, the HUD name and the name above their head all show the survivor they look like.
  - A player takes the number unless another player has it; a bot holding it is moved to someone else.
  - On L4D1 campaigns only Bill, Zoey, Louis and Francis have numbers, unless the
    [survivor set addon](../../addon) is installed.
- **Teammate portraits are redrawn**: clients don't redraw a teammate's portrait when the number
  changes, so the plugin reloads HUD Player Display Manager afterwards (same as its `!resethud`).

Zoey's character number (5) used to crash Windows servers. Valve has fixed that (tested on a Windows
server), so she is handed out like everyone else. `l4d2_unique_survivors_zoey5 0` brings back the old
"never use Zoey" behaviour if you need it.

## Requirements

- [Left4DHooks](https://forums.alliedmods.net/showthread.php?t=321696)
- Optional: [HUD Player Display Manager](https://github.com/szGabu/L4D2_HudDisplayManager) (portrait refresh)

## Commands and settings

| | |
|---|---|
| `sm_uniquecheck` (root admin) | Run the duplicate check now and list every survivor's number and model |
| `l4d2_unique_survivors_enable` `1` | 0 = plugin off |
| `l4d2_unique_survivors_zoey5` `1` | 1 = Zoey is used like everyone else (number 5, her own portrait). 0 = never use Zoey's number or model. |

Config: `cfg/sourcemod/l4d2_unique_survivors.cfg`

## Credits

- Dropping and re-equipping weapons after a model change (so they attach to the new model) follows
  the approach in [Survivor Chat Select 2](https://forums.alliedmods.net/showpost.php?p=2714846&postcount=807).
