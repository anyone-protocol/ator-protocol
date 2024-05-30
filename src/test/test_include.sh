#!/bin/sh

umask 077
set -e
set -x

# emulate realpath(), in case coreutils or equivalent is not installed.
abspath() {
    f="$*"
    if [ -d "$f" ]; then
        dir="$f"
        base=""
    else
        dir="$(dirname "$f")"
        base="/$(basename "$f")"
    fi
    dir="$(cd "$dir" && pwd)"
    echo "$dir$base"
}

UNAME_OS=$(uname -s | cut -d_ -f1)
if test "$UNAME_OS" = 'CYGWIN' || \
   test "$UNAME_OS" = 'MSYS' || \
   test "$UNAME_OS" = 'MINGW' || \
   test "$UNAME_OS" = 'MINGW32' || \
   test "$UNAME_OS" = 'MINGW64'; then
  if test "$APPVEYOR" = 'True'; then
    echo "This test is disabled on Windows CI, as it requires firewall exemptions. Skipping." >&2
    exit 77
  fi
fi

# find the tor binary
if [ $# -ge 1 ]; then
  TOR_BINARY="${1}"
  shift
else
  TOR_BINARY="${TESTING_TOR_BINARY:-./src/app/anon}"
fi

TOR_BINARY="$(abspath "$TOR_BINARY")"

echo "ANON BINARY IS ${TOR_BINARY}"

if "${TOR_BINARY}" --list-modules | grep -q "relay: no"; then
  echo "This test requires the relay module. Skipping." >&2
  exit 77
fi

tmpdir=
# For some reasons, shellcheck is not seeing that we can call this
# function from the trap below.
# shellcheck disable=SC2317
clean () {
  if [ -n "$tmpdir" ] && [ -d "$tmpdir" ]; then
    rm -rf "$tmpdir"
  fi
}

trap clean EXIT HUP INT TERM

tmpdir="$(mktemp -d -t tor_include_test.XXXXXX)"
if [ -z "$tmpdir" ]; then
  echo >&2 mktemp failed
  exit 2
elif [ ! -d "$tmpdir" ]; then
  echo >&2 mktemp failed to make a directory
  exit 3
fi

datadir="$tmpdir/data"
mkdir "$datadir"

configdir="$tmpdir/config"
mkdir "$configdir"

# translate paths to windows format
if test "$UNAME_OS" = 'CYGWIN' || \
   test "$UNAME_OS" = 'MSYS' || \
   test "$UNAME_OS" = 'MINGW' || \
   test "$UNAME_OS" = 'MINGW32' || \
   test "$UNAME_OS" = 'MINGW64'; then
    datadir=$(cygpath --windows "$datadir")
    configdir=$(cygpath --windows "$configdir")
fi

# create test folder structure in configdir
anonrcd="$configdir/anonrc.d"
mkdir "$anonrcd"
mkdir "$anonrcd/folder"
mkdir "$anonrcd/empty_folder"
echo "NodeFamily 1" > "$anonrcd/01_one.conf"
echo "NodeFamily 2" > "$anonrcd/02_two.conf"
echo "NodeFamily 3" > "$anonrcd/aa_three.conf"
echo "NodeFamily 42" > "$anonrcd/.hidden.conf"
echo "NodeFamily 6" > "$anonrcd/foo"
touch "$anonrcd/empty.conf"
echo "# comment" > "$anonrcd/comment.conf"
echo "NodeFamily 4" > "$anonrcd/folder/04_four.conf"
echo "NodeFamily 5" > "$anonrcd/folder/05_five.conf"
anonrc="$configdir/anonrc"
echo "Sandbox 1" > "$anonrc"
echo "
%include $anonrcd/*.conf
%include $anonrcd/f*
%include $anonrcd/*/*
%include $anonrcd/empty_folder
%include $anonrcd/empty.conf
%include $anonrcd/comment.conf
" >> "$anonrc"

"${PYTHON:-python}" "${abs_top_srcdir:-.}/src/test/test_include.py" "${TOR_BINARY}" "$datadir" "$configdir"

exit $?
