#!/bin/bash -e

wget -qO /dev/null --keep-session-cookies --save-cookies cookie --post-data="UserName=$WRC_USERNAME&Password=$WRC_PASSWORD" 'https://login.intersystems.com/login/SSO.UI.Login.cls?referrer=https%253A//wrc.intersystems.com/wrc/login.csp' 
wget --secure-protocol=TLSv1_2 -O $kit --load-cookies cookie "https://wrc.intersystems.com/wrc/WRC.StreamServer.cls?FILE=/wrc/Live/ServerKits/$kit"
exit