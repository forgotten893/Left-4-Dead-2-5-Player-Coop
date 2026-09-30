@echo off
rem Left 4 Dead 2 dedicated server, 5 player coop.
rem Put this file in the server's root folder (next to srcds.exe).
rem
rem SERVER_IP: this machine's LAN address (run "ipconfig"). Pinning it matters on PCs with extra
rem network adapters such as Hyper-V/WSL, otherwise players get stuck on "Sending UDP connect".
rem Players join with: connect <SERVER_IP>   (or <public IP>:27015 over the internet)
set SERVER_IP=0.0.0.0
rem
rem sv_setmax/-maxplayers 31 raise the engine slot limit so extra survivor bots fit (recommended by l4dmultislots).
rem The human player cap is sv_maxplayers in left4dead2\cfg\server.cfg.
rem +z_difficulty sets the starting difficulty only (Easy / Normal / Hard = Advanced / Impossible = Expert).
rem Change it in-game any time with !admin > Server Commands > Change Difficulty.
cd /d "%~dp0"
start "L4D2 Server" srcds.exe -console -game left4dead2 +ip %SERVER_IP% -port 27015 +sv_setmax 31 -maxplayers 31 +z_difficulty Impossible +map c1m1_hotel
