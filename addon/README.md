# l4d2_survivorset.vpk - L4D2 survivor set on the L4D1 campaigns

Switches these campaigns to the L4D2 survivor set, so the HUD can show portraits for all 8 survivors
(see [l4d2_survivor_set](../plugins/l4d2_survivor_set)):

The Sacrifice, No Mercy, Crash Course, Death Toll, Dead Air, Blood Harvest, The Last Stand

It contains only those seven mission files (`missions/campaignN.txt`) with `"survivor_set" "1"`
changed to `"2"`, plus `addoninfo.txt`. No models, sounds or scripts.

## Install

- **Players**: [subscribe on the Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3810937801)
  and restart the game. It shows up under Extras -> Add-ons.
- **Server**: dedicated servers can't subscribe to Workshop items, so the server zip in the
  [Releases](../../../releases) includes the `.vpk` at `left4dead2/addons/l4d2_survivorset.vpk`.
  Restart the server after copying it. The server also needs the
  [l4d2_survivor_set](../plugins/l4d2_survivor_set) plugin, otherwise the bots on these campaigns
  are the L4D2 cast.

## Build it yourself

The mission files are Valve's, so they aren't in this repository. `build_addon.py` takes them from
your own game install and makes the change:

```
pip install vpk
python build_addon.py "C:\Program Files (x86)\Steam\steamapps\common\Left 4 Dead 2"
```

It writes `l4d2_survivorset.vpk` next to the script. L4D2 has no `vpk.exe` of its own, so the script
uses the [vpk](https://pypi.org/project/vpk/) Python package to write a version 1 VPK.
