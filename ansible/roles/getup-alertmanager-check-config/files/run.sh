#!/bin/bash

trap exit SIGINT

RESPONSE_OK="HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n${2:-"OK"}\r\n"
RESPONSE_ER="HTTP/1.1 400 Config Not Found\r\nConnection: close\r\n\r\n${2:-"Config Not Found"}\r\n"

which ncat && NC=ncat || NC=nc

while true; do
    $NC -l 8080 --sh-exec "grep 'name: pager_duty' -A 4 /config/alertmanager.yml | grep 'service_key: .\+' -q && echo -ne '${RESPONSE_OK}' || echo -ne '${RESPONSE_ER}'"
done

