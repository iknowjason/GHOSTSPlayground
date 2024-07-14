#!/bin/bash

# synch npc with machines
echo "Run api /api/npcsgenerate/syncwithmachineusernames"
echo "Ensures an NPC is created for each and every machine currentusername that exists"
request2="http://127.0.0.1:5000/api/npcsgenerate/syncwithmachineusernames"
curl -X 'POST' \
  "$request2" \
  -H 'accept: application/json' \
  -d ''
echo "Request complete to api endpoint at /api/npcsgenerate/syncwithmachineusernames"
