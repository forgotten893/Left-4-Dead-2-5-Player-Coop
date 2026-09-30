# [L4D2] Vocalize Spam

L4D1 let you spam voice lines from the vocalize menu. L4D2 ignores a new line while your survivor is
still talking. This plugin brings the spam back.

- **Stack** (default): a new line plays on top of the one that's still playing. The first line is a
  normal scene (mouth moves, subtitles); lines stacked on top are audio only.
- **Cut off** (`l4d2_vocalize_spam_stack 0`): a new line stops the current one and plays right away.
- **Key binds work**: `bind v "vocalize PlayerLaugh"`. L4D2 normally ignores `vocalize` typed in the
  console or bound to a key, because it lacks the menu's time token.
- **Say one exact line**: `sm_vline laughter12`, or `bind b "sm_vline laughter12"`.
  `sm_vlines laugh` lists your survivor's lines whose name or description contains "laugh".

The voice follows the survivor's **model** (e.g. Nick wearing Bill's model laughs like Bill), matching
[l4d2_vocalizebasedmodel](https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d2_vocalizebasedmodel).
Lines the game triggers on its own ("Reloading!") are left alone.

## How it works

- Which lines exist is read from the game's talker scripts (`scripts/talker/<survivor>.txt` and the
  `_dlc` files) when the plugin loads, one file per frame. The main files win over the `_dlc` files,
  which contain outdated copies of some rules.
- A scene `scenes/<survivor>/<name>.vcd` always has its audio at
  `sound/player/survivor/voice/<survivor>/<name>.wav`, which is what stacked lines play.

## Commands and settings

| | |
|---|---|
| `sm_vline <line>` | Say one specific line of your survivor |
| `sm_vlines <word>` | List your survivor's lines containing `<word>` (in the console) |
| `l4d2_vocalize_spam_enable` `1` | 0 = plugin off |
| `l4d2_vocalize_spam_interval` `0.1` | Minimum seconds between one player's lines (0 = no limit) |
| `l4d2_vocalize_spam_stack` `1` | 1 = new lines stack on top, 0 = new lines cut off the current one |
| `l4d2_vocalize_spam_binds` `1` | 1 = key binds / console `vocalize <line>` work |
| `l4d2_vocalize_spam_debug` `0` | 1 = log voice lines to the server console |

Config: `cfg/sourcemod/l4d2_vocalize_spam.cfg`

## Credits

- [Scene Processor](https://forums.alliedmods.net/showthread.php?t=241585) by Buster "Mr. Zero" Nielsen:
  how survivor voice lines are `instanced_scripted_scene` entities, and cancelling them safely
  (`Cancel` only once a scene has started, otherwise remove it).
