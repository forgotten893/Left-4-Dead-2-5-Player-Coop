# [L4D2] Survivor Set

On the L4D1 campaigns the team HUD has no portraits for Nick, Rochelle, Coach and Ellis. Pick Nick with
`!csm` on No Mercy and you look and sound like Nick, but the HUD still shows an L4D1 survivor.

The HUD portrait comes from the character number, and on these campaigns (survivor set 1) the numbers
only mean Bill, Zoey, Louis and Francis. In the L4D2 set (set 2) numbers 0-7 are all 8 survivors:

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Nick | Rochelle | Coach | Ellis | Bill | Zoey | Francis | Louis |

**Each game client reads the survivor set from its own copy of the campaign's mission file**, so the
server cannot change it alone. The fix has two parts:

1. The [addon](../../addon) switches the L4D1 campaigns to set 2. **The server and every player** install it.
2. This plugin: with set 2, the game spawns the bots as the L4D2 cast. On the L4D1 campaigns, a bot
   that spawns as an L4D2 survivor is turned into its L4D1 counterpart:
   Nick -> Bill, Rochelle -> Zoey, Coach -> Louis, Ellis -> Francis.

Players' numbers follow their model through [l4d2_unique_survivors](../l4d2_unique_survivors), so the
HUD shows whoever they picked.

Campaigns: The Sacrifice, No Mercy, Crash Course, Death Toll, Dead Air, Blood Harvest, The Last Stand
(map prefixes `c7m` - `c12m`, `c14m`). Cold Stream already uses the L4D2 set.

Character number 5 (Zoey) crashes Windows servers. On Windows keep `l4d2_survivor_set_zoey5 0`: the
Zoey bot then keeps Rochelle's number and shows Rochelle's portrait.

## Requirements

- [Left4DHooks](https://forums.alliedmods.net/showthread.php?t=321696)
- The addon on the server (`left4dead2/addons/l4d2_survivorset.vpk`) and on every player's game
- Recommended: [l4d2_unique_survivors](../l4d2_unique_survivors),
  [l4d2_vocalizebasedmodel](https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d2_vocalizebasedmodel),
  [l4d2_trigger_flow_fix](https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d2_trigger_flow_fix)

## Commands and settings

| | |
|---|---|
| `sm_survivorset` (root admin) | Show the survivor set in use and every survivor's number and model |
| `l4d2_survivor_set_maps` | Map name prefixes of the L4D1 campaigns (default `c7m,c8m,c9m,c10m,c11m,c12m,c14m`) |
| `l4d2_survivor_set_zoey5` `0` | 1 = the Zoey bot gets number 5. **Linux only.** |
| `l4d2_survivor_set_override` `0` | 1 = also switch the set server-side through Left4DHooks. Not needed with the addon; does **not** change players' HUDs on its own. |
| `l4d2_survivor_set_debug` `0` | 1 = log bot changes to the server console |

Config: `cfg/sourcemod/l4d2_survivor_set.cfg`

## Credits

- Dropping and re-equipping weapons after a model change follows the approach in
  [Survivor Chat Select 2](https://forums.alliedmods.net/showpost.php?p=2714846&postcount=807).
- The survivor set hooks are provided by [Left4DHooks](https://forums.alliedmods.net/showthread.php?t=321696) (Silvers).
