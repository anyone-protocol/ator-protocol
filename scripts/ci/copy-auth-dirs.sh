#!/bin/bash

# copy desired environment auth dirs before build

set -e
set -x

pkg_env="$1"; shift

auth_dirs_env="stage"
if [ "$pkg_env" = "dev" ] || [ "$pkg_env" = "unstable-dev" ]; then
  auth_dirs_env="dev"
fi

cp "src/app/config/auth_dirs_${auth_dirs_env}.inc" src/app/config/auth_dirs.inc
