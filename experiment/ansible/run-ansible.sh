#!/bin/bash

set -e

if ! (which ansible-playbook) >/dev/null 2>&1; then
    apt-get install -y ansible
fi

ansible-playbook --verbose --connection=local book.yml

