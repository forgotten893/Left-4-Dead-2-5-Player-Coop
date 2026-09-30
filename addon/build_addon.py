"""
Builds l4d2_survivorset.vpk: the L4D1 campaigns switched to the L4D2 survivor set.

The mission files are Valve's, so they are not stored in this repository. This script reads them
from your own Left 4 Dead 2 install, changes "survivor_set" "1" to "2", and packs them with
addoninfo.txt into a VPK (version 1, the format L4D2 addons use).

Usage:
    pip install vpk
    python build_addon.py "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Left 4 Dead 2"

Output: l4d2_survivorset.vpk next to this script.
"""

import os
import re
import sys
import shutil
import tempfile

import vpk

# campaignN.txt -> name. These are the campaigns with "survivor_set" "1".
CAMPAIGNS = {
    7: "The Sacrifice",
    8: "No Mercy",
    9: "Crash Course",
    10: "Death Toll",
    11: "Dead Air",
    12: "Blood Harvest",
    14: "The Last Stand",
}

# Later entries are only used if a file is missing from the earlier ones (update wins).
PAK_DIRS = ["update", "left4dead2_dlc3", "left4dead2_dlc2", "left4dead2_dlc1", "left4dead2"]

SURVIVOR_SET = re.compile(rb'("survivor_set"\s+")1(")', re.IGNORECASE)


def read_mission(game_dir, path):
    for pak_dir in PAK_DIRS:
        pak = os.path.join(game_dir, pak_dir, "pak01_dir.vpk")
        if not os.path.exists(pak):
            continue
        archive = vpk.open(pak, path_enc="latin1")
        if path in archive:
            return archive[path].read()
    raise FileNotFoundError(f"{path} not found in any pak01_dir.vpk under {game_dir}")


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)

    game_dir = sys.argv[1]
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "l4d2_survivorset.vpk")

    work = tempfile.mkdtemp()
    try:
        os.makedirs(os.path.join(work, "missions"))
        shutil.copy(os.path.join(here, "addoninfo.txt"), os.path.join(work, "addoninfo.txt"))

        for number, name in CAMPAIGNS.items():
            path = f"missions/campaign{number}.txt"
            text, count = SURVIVOR_SET.subn(rb"\g<1>2\g<2>", read_mission(game_dir, path))
            if count != 1:
                raise RuntimeError(f"{path} ({name}): expected one \"survivor_set\" \"1\", found {count}")
            with open(os.path.join(work, "missions", f"campaign{number}.txt"), "wb") as f:
                f.write(text)
            print(f"{path:28} {name}: survivor_set 1 -> 2")

        pak = vpk.new(work)
        pak.version = 1
        pak.save(out)
    finally:
        shutil.rmtree(work)

    print(f"\nWrote {out}")


if __name__ == "__main__":
    main()
