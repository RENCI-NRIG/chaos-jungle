#!/bin/bash

if [[ "$USER" != "root" ]]; then
  echo "script must run as root"
  exit 1
fi

set -eux

dnf install -y git gcc ncurses-devel elfutils-libelf-devel bc openssl-devel libcap-devel clang llvm bison flex glibc-devel.i686 ntp man-pages
dnf install -y bcc-tools kernel-devel-$(uname -r) kernel-headers-$(uname -r) libbcc-examples python-pyroute2
systemctl enable --now ntpd
