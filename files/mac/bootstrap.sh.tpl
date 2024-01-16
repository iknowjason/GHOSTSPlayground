#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Start bootstrap script"


echo "End of bootstrap script"
