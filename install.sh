#!/bin/bash

ROUTER_IP=$1

scp {firewall.sh,proxy} root@$ROUTER_IP:/www/cgi-bin/
