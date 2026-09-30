# Left 4 Dead 2 5+ Player Coop

A Left 4 Dead 2 dedicated server setup for **co-op with more than 4 players**, built on SourceMod,
plus four SourceMod plugins and a small addon written for it.

**Note: anything that recommends disabling the Zoey options (e.g. `l4d_scs_zoey 0`, "Zoey crashes
Windows servers") can be safely ignored. Valve patched the bug by 2023, and Zoey can now be used on
Windows servers as well as Linux servers without issue.** See [About Zoey on Windows](#about-zoey-on-windows).

**Set up for 5 players by default, and can go up to 8** - see [Up to 8 players](#up-to-8-players).

Tested on a Windows dedicated server and on Linux (LinuxGSM), SourceMod 1.12, L4D2 2.2.4.3.

## Features

- **5 survivors every round** (default, up to 8) - empty spots are filled with bots, extra survivors start with a pistol
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
| [addon](addon) | `l4d2_survivorset.vpk` - switches the L4D1 campaigns to the L4D2 survivor set. Server **and** every player need it. Players: [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3810937801). |

Compiled plugins, the addon (for the server) and the server configs are in the
[Releases](../../releases). The source code is in this repository.

## Installing a server

1. **Install the dedicated server** (app 222860) with SteamCMD:
   ```
   steamcmd +force_install_dir <server folder> +login anonymous +app_update 222860 validate +quit
   ```
   On Linux, [LinuxGSM](https://linuxgsm.com/servers/l4d2server/) works too.

   > **Linux / LinuxGSM - known SteamCMD bug:** the L4D2 dedicated server often won't download on
   > Linux directly. The workaround is to download the **Windows** version first, then validate
   > **without** forcing the platform, which replaces it with the Linux binaries:
   >
   > 1. Force the Windows download:
   >    ```
   >    steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir <server folder> +login anonymous +app_update 222860 validate +quit
   >    ```
   > 2. Remove the force and validate. The same command without `+@sSteamCmdForcePlatformType windows`:
   >    ```
   >    steamcmd +force_install_dir <server folder> +login anonymous +app_update 222860 validate +quit
   >    ```
   >    With LinuxGSM, run `./l4d2server validate` instead. `<server folder>` is LinuxGSM's
   >    `serverfiles` folder, e.g. `/home/l4d2server/serverfiles`.
   >
   > Afterwards `srcds_run` and the `.so` files should be in the server folder.
2. **Install the third-party mods** listed in [THIRD_PARTY.md](THIRD_PARTY.md), from their own pages:
   Metamod:Source, SourceMod, L4DToolZ, the extensions and the plugins.
3. **Download the release** and copy its `left4dead2` folder into the server's `left4dead2` folder
   (merge / overwrite). It has the same layout as the server, so it drops straight in.
4. **Make yourself admin**: add a line with your Steam ID to SourceMod's
   `left4dead2/addons/sourcemod/configs/admins_simple.ini` (the `status` console command shows it):
   ```
   "[U:1:12345678]"	"99:z"		// you - full admin
   ```
5. **Start it** with `start_l4d2_server.sh` (Linux) or `Start L4D2 Server.bat` (Windows), from the
   `server-config` folder, placed next to `srcds_run` / `srcds.exe`. Set `SERVER_IP` in the script first.
   Open port 27015 UDP + TCP. Players join with `connect <ip>:27015`.

`server.cfg` is set for 5 players (`sv_maxplayers 5`) and has an empty `sv_password` - set one to keep
strangers out.

## Up to 8 players

Out of the box the server allows **5 players** and every round has **5 survivors** (bots fill empty
spots). To go up to 8, change three settings and restart the server:

1. `left4dead2/cfg/server.cfg` - how many players can join:
   ```
   sv_maxplayers 8
   ```
2. `left4dead2/cfg/sourcemod/l4dmultislots.cfg` - the most survivors there can be:
   ```
   l4d_multislots_max_survivors "8"
   ```
3. Same file - how many survivors every round starts with (bots fill the empty spots):
   ```
   l4d_multislots_min_survivors "8"
   ```
   Keep this at `"5"` (or `"4"`) if you'd rather not have extra bots when fewer people are playing -
   players who join later still get their own survivor, up to the maximum.

The start scripts already reserve enough slots (`-maxplayers 31 +sv_setmax 31`), so they don't need to
change. The team HUD keeps showing your 4 nearest teammates.

With 8 survivors, all 8 characters are in use and every one of them is unique - on Windows and Linux.

Anything between 5 and 8 works the same way - use the same number in all three places (or a lower
`min_survivors`).

This setup has been played and tested with 5 players. The plugins it uses are made for 5+ survivors
(l4dmultislots supports up to 18), but 6-8 players haven't been tested here yet.

## For players

Everything works without installing anything, **except the HUD portraits of Nick, Rochelle, Coach and
Ellis on the L4D1 campaigns**, which need the addon:
**[subscribe to L4D2 Survivor Portraits on L4D1 Campaigns on the Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3810937801)**
and restart the game.

Commands (chat with `!`, console with `sm_`):

| Command | |
|---|---|
| `!csm` / `!model` | Pick your survivor (all 8) |
| `!lastresults` / `!slr` | Everyone's stats from the last chapter |
| `!results` / `!sr` | Everyone's stats for this chapter so far |
| `sm_vlines <word>` | List your survivor's voice lines containing a word (console) |
| `sm_vline <line>` | Say one exact line, e.g. `sm_vline laughter12` |
| `bind v "vocalize PlayerLaugh"` | Voice lines work as key binds |

## About Zoey on Windows

Older guides and plugins (including Survivor Chat Select's `l4d_scs_zoey` option) say Zoey's character
number, 5, crashes Windows servers, and use Rochelle's number for her instead. Valve has fixed that bug
([Real Zoey Unlock](https://forums.alliedmods.net/showthread.php?t=308483) was withdrawn by its author
for this reason), and it was confirmed on a Windows dedicated server here: Zoey as a player, as a bot,
and on the L4D1 campaigns with the addon - no crashes. So Zoey is enabled everywhere by default
(`l4d_scs_zoey "1"`, `l4d2_unique_survivors_zoey5 "1"`, `l4d2_survivor_set_zoey5 "1"`). If a server
ever does crash with her, set those three to `0`.

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
