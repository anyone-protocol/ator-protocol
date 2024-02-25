#!/bin/bash

# set the upstream version in configure.ac correctly

set -e
set -x

pkg_env="$1"; shift

if ! [ -e configure.ac ]; then
    echo >&2 "Did not find configure.ac"
    exit 1
fi

if [ "$(grep -c AC_INIT configure.ac)" != 1 ]; then
    echo >&2 "Did not find exactly one AC_INIT"
    exit 1
fi

sed_arg="/^AC_INIT(/ s/\(-dev\)\?\(-$pkg_env\)\?])/-$pkg_env])/"

if [[ "$OSTYPE" == "darwin"* ]]; then
    gsed -i -e "$sed_arg" configure.ac
else
    sed -i -e "$sed_arg" configure.ac
fi

if [ "$(grep -c "AC_INIT.*-$pkg_env" configure.ac)" != 1 ]; then
    echo >&2 "Unexpected version in configure.ac."
    exit 1
fi
