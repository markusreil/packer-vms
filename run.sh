#!/usr/bin/env bash

if [ -z "$1" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

PACKER_LOG=1 packer build -var-file ~/.config/packer/secrets.pkrvars.hcl $1
