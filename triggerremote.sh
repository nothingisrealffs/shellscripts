#!/bin/bash
command=iptables -t nat -L -n -v | awk '/Chain VSERVER/,/Chain VUPNP/ {if ($8 ~ /^134\.68\.60\.[0-9]{1,3}$/) print}'
ports=$(iptables -t nat -L -n -v | awk '/Chain VSERVER/,/Chain VUPNP/ {if ($8 ~ /^134\.68\.60\.[0-9]{1,3}$/) print $11}' | sed 's/[^0-9]*//g')
original=$($command)
for port in $ports;
do
   sc_name = "iptables -t nat -A PREROUTING -p tcp --dport $port -j DNAT --to-destination {$1}:$port"
   nvram set script_fire=$sc_name
   nvram commit
done
sleep(30)
if [$original -eq $($command)]