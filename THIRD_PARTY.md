# Third-party mods and plugins

Everything below is used **unmodified** and is **not** included in this repository or its releases.
Download each from its original page. Versions are the ones this setup was tested with.

## Server platform

| Name | Version | Author | Link |
|---|---|---|---|
| Metamod:Source | 1.12 (git1227) | AlliedModders | https://www.metamodsource.net |
| SourceMod | 1.12 (git7253) | AlliedModders | https://www.sourcemod.net |
| L4DToolZ | 2.5.1 | lakwsh (fork of ivailosp) | https://github.com/lakwsh/l4dtoolz |

## Extensions

| Name | Version | Author | Link |
|---|---|---|---|
| Actions | 3.9.2 | BHaType | https://forums.alliedmods.net/showthread.php?t=336374 |
| Source Scramble | 0.8.2 | nosoop | https://github.com/nosoop/SMExt-SourceScramble |
| SendProxy (Left4SendProxy) | 1.3.3 | szGabu (fork) | https://github.com/szGabu/Left4SendProxy |

Actions 4.x needs SourceMod 1.13; 3.9.2 is the last version for SourceMod 1.12.

## Plugins

| Plugin | Author | Link |
|---|---|---|
| Left4DHooks | Silvers (SilverShot) | https://forums.alliedmods.net/showthread.php?t=321696 |
| l4dmultislots (5+ survivors) | fbef0102 | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4dmultislots |
| l4d_CreateSurvivorBot | fbef0102 | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d_CreateSurvivorBot |
| HUD Player Display Manager 1.0.3 | gabuch2 (szGabu) | https://github.com/szGabu/L4D2_HudDisplayManager |
| Survivor Chat Select 2 (2.3.0) + fall scream fix | mi123645, DeathChaos25, Merudo, zrmdsxa, Sappykun | https://forums.alliedmods.net/showpost.php?p=2714846&postcount=807 |
| Survivor Identity Fix for 5+ Survivors 1.7b | Merudo, Shadowysn | https://forums.alliedmods.net/showthread.php?p=2403731 |
| Command and ConVar Buffer Overflow Fixer 2.11 | SilverShot, Peace-Maker | https://forums.alliedmods.net/showthread.php?t=309656 |
| Ladder Server Crash Patch Fix 1.1 | SilverShot, Peace-Maker | https://forums.alliedmods.net/showthread.php?t=336298 |
| InputKill Kick Prevention 1.0 | Shadowysn | https://forums.alliedmods.net/showthread.php?t=332860 |
| Transition Restore Fix 1.2.5 | sorallll | https://forums.alliedmods.net/showthread.php?t=336287 |
| Defib Fix 2.0.1 | Lux | https://forums.alliedmods.net/showthread.php?p=2647018 |
| Charger Collision Patch 2.0.1 | Lux | https://forums.alliedmods.net/showthread.php?p=2647017 |
| Witch Target Patch 1.4 | Lux | https://forums.alliedmods.net/showthread.php?p=2647014 |
| Survivor AFK Fix 1.0.4 | Lux | https://github.com/LuxLuma/Left-4-fix/tree/master/left%204%20fix/survivors/survivor_afk_fix |
| Fix Changelevel 1.3 | Lux, Forgetest | https://github.com/Target5150/MoYu_Server_Stupid_Plugins |
| Fix Mixed Characters 1.7.1 | Forgetest | https://github.com/Target5150/MoYu_Server_Stupid_Plugins |
| Fix Target Replace 1.2 | Forgetest | https://github.com/Target5150/MoYu_Server_Stupid_Plugins |
| l4d2_vocalizebasedmodel | fbef0102 | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d2_vocalizebasedmodel |
| l4d2_trigger_flow_fix (Survivor Set Trigger Fix) | fbef0102, original by gabuch2 | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d2_trigger_flow_fix |
| l4d2_maptankfix | fbef0102 | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d2_maptankfix |
| l4d2_rescue_vehicle_multi | fbef0102 | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d2_rescue_vehicle_multi |
| l4d2_transition_info_fix | fbef0102 | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d2_transition_info_fix |
| l4d_both_fixUpgradePack | fbef0102 | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d_both_fixUpgradePack |
| l4d_full_slot_bot_replace_fix | fbef0102 | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d_full_slot_bot_replace_fix |
| l4dafkfix_deadbot | fbef0102 | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4dafkfix_deadbot |
| spawn_infected_nolimit | fbef0102 | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/spawn_infected_nolimit |

The fbef0102 repository also has a guide for 5+ survivors in coop that this setup follows:
https://github.com/fbef0102/Game-Private_Plugin/tree/main/Tutorial_教學區/English/Game/L4D2/8%2B_Survivors_In_Coop

## Credited for ideas / techniques (not used as-is)

| Name | Author | Link | Used for |
|---|---|---|---|
| Scene Processor | Buster "Mr. Zero" Nielsen | https://forums.alliedmods.net/showthread.php?t=241585 | How survivor voice lines are `instanced_scripted_scene` entities and how to cancel them safely (l4d2_vocalize_spam) |
| Survivor Chat Select 2 | see above | see above | Dropping and re-equipping weapons after a model change (l4d2_unique_survivors, l4d2_survivor_set) |
