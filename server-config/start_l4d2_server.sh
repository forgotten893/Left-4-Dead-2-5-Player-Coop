#!/bin/bash
# Left 4 Dead 2 dedicated server, 5 player coop.
# Put this file in the server's root folder (next to srcds_run), then: chmod +x start_l4d2_server.sh
#
# SERVER_IP: the address to listen on. 0.0.0.0 = all interfaces, which is fine on most Linux servers.
# If players get stuck on "Sending UDP connect", set this to the machine's LAN address (ip -4 addr).
# Players join with: connect <server IP>   (or <public IP>:27015 over the internet)
SERVER_IP=0.0.0.0

# sv_setmax/-maxplayers 31 raise the engine slot limit so extra survivor bots fit (recommended by l4dmultislots).
# The human player cap is sv_maxplayers in left4dead2/cfg/server.cfg.
# +z_difficulty sets the starting difficulty only (Easy / Normal / Hard = Advanced / Impossible = Expert).
# Change it in-game any time with !admin > Server Commands > Change Difficulty.
cd "$(dirname "$0")"
./srcds_run -console -game left4dead2 +ip "$SERVER_IP" -port 27015 +sv_setmax 31 -maxplayers 31 +z_difficulty Impossible +map c1m1_hotel
