#!/usr/bin/env bash

if grep -q "grafana.local" /etc/hosts; then
    echo "Exists"
else
    sudo -- bash -c "echo 127.0.0.1 grafana.local >> /etc/hosts"
fi
