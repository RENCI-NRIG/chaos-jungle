#!/bin/bash

if [[ "$USER" != "root" ]]; then
  echo "script must run as root"
  exit 1
fi

set -eux

dnf config-manager --add-repo=http://alt.fedoraproject.org/pub/alt/rawhide-kernel-nodebug/fedora-rawhide-kernel-nodebug.repo
echo -e '[iovisor]\nbaseurl=https://repo.iovisor.org/yum/nightly/f25/$basearch\nenabled=1\ngpgcheck=0' | sudo tee /etc/yum.repos.d/iovisor.repo
dnf -y update
