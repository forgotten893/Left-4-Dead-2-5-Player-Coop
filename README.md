# Left 4 Dead 2 5+ Player Coop

A Left 4 Dead 2 dedicated server setup for **co-op with 5 (or more) players**, built on SourceMod,
plus four SourceMod plugins and a small addon written for it.

Tested on a Windows dedicated server and on Linux (LinuxGSM), SourceMod 1.12, L4D2 2.2.4.3.

## Features

- **5 survivors every round** - empty spots are filled with bots, extra survivors start with a pistol
- **Fixes for 5+ survivors** - identity, defib, charger, witch, transitions, finales and more
  (third-party plugins, see [THIRD_PARTY.md](THIRD_PARTY.md))
- **Team HUD shows your 4 nearest teammates**
- **Pick any of the 8 survivors** with `!csm` - on every campaign, and the HUD portrait follows
- **No duplicate survivors** - an extra bot never shows up as a second copy of someone
- **Spammable, stackable voice lines** like in L4D1, key binds for voice lines, and `sm_vline` to say one exact line
- **End-of-chapter stats for everyone** - the stock screen only has room for 4 survivors
- **Admin menu** - change difficulty and campaign without a vote

## The plugins in this repository

| Plugin | What it does |
|---|---|
| [l4d2_unique_survivors](plugins/l4d2_unique_survivors) | Bots never duplicate another survivor. Everyone's name and HUD portrait follow their model after `!csm` / `!csc`. |
| [l4d2_vocalize_spam](plugins/l4d2_vocalize_spam) | L4D1-style voice line spam: new lines cut in or stack on top, key binds work, `sm_vline` / `sm_vlines`. |
| [l4d2_survivor_set](plugins/l4d2_survivor_set) | With the addon below: HUD portraits for all 8 survivors on the L4D1 campaigns. |
| [l4d2_lastresults](plugins/l4d2_lastresults) | `!lastresults` / `!results`: every survivor's chapter stats, not just 4. |
| [addon](addon) | `l4d2_survivorset.vpk` - switches the L4D1 campaigns to the L4D2 survivor set. Server **and** every player need it. |

Compiled plugins, the addon and the server configs are in the
[Releases](../../releases). The source code is in this repository.

## Installing a server

1. **Install the dedicated server** (app 222860) with SteamCMD:
   ```
   steamcmd +force_install_dir <server folder> +login anonymous +app_update 222860 validate +quit
   ```
   Add `+@sSteamCmdForcePlatformType windows` or `linux` before `+app_update` if needed.
   On Linux, [LinuxGSM](https://linuxgsm.com/servers/l4d2server/) works too.
2. **Install the third-party mods** listed in [THIRD_PARTY.md](THIRD_PARTY.md), from their own pages:
   Metamod:Source, SourceMod, L4DToolZ, the extensions and the plugins.
3. **Download the release** and copy its `left4dead2` folder into the server's `left4dead2` folder
   (merge / overwrite). It has the same layout as the server, so it drops straight in.
4. **Make yourself admin**: add a line with your Steam ID to SourceMod's
   `left4dead2/addons/sourcemod/configs/admins_simple.ini` (the `status` console command shows it):
   ```
   "[U:1:12345678]"	"99:z"		// you - full admin
   ```
5. **Windows servers only**: Zoey's character number (5) crashes Windows servers. Set these to `0`:
   - `cfg/sourcemod/l4dscs.cfg`: `l4d_scs_zoey "0"`
   - `cfg/sourcemod/l4d2_unique_survivors.cfg`: `l4d2_unique_survivors_zoey5 "0"`
   - `cfg/sourcemod/l4d2_survivor_set.cfg`: `l4d2_survivor_set_zoey5 "0"`
6. **Start it** with `start_l4d2_server.sh` (Linux) or `Start L4D2 Server.bat` (Windows), from the
   `server-config` folder, placed next to `srcds_run` / `srcds.exe`. Set `SERVER_IP` in the script first.
   Open port 27015 UDP + TCP. Players join with `connect <ip>:27015`.

`server.cfg` is set for 5 players (`sv_maxplayers 5`) and has an empty `sv_password` - set one to keep
strangers out.

## For players

Everything works without installing anything, **except the HUD portraits of Nick, Rochelle, Coach and
Ellis on the L4D1 campaigns**, which need the addon: put `l4d2_survivorset.vpk` from the release into
`Left 4 Dead 2/left4dead2/addons/` and restart the game.

Commands (chat with `!`, console with `sm_`):

| Command | |
|---|---|
| `!csm` / `!model` | Pick your survivor (all 8) |
| `!lastresults` / `!slr` | Everyone's stats from the last chapter |
| `!results` / `!sr` | Everyone's stats for this chapter so far |
| `sm_vlines <word>` | List your survivor's voice lines containing a word (console) |
| `sm_vline <line>` | Say one exact line, e.g. `sm_vline laughter12` |
| `bind v "vocalize PlayerLaugh"` | Voice lines work as key binds |

## Credits

The server is mostly built from other people's work - every mod and plugin used is listed with its
author, version and link in **[THIRD_PARTY.md](THIRD_PARTY.md)**. None of them are modified; get them
from their original pages.

The four plugins and the addon in this repository are by forgotten893, written with the help of
Claude (Anthropic). Ideas and techniques borrowed from other plugins are credited in each plugin's README.

## License

The plugins are licensed under the [GNU General Public License v3](LICENSE), like SourceMod itself.
The addon's mission files are Valve's; this repository only contains the script that builds the addon
from your own copy of the game.
