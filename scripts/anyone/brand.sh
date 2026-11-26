#!/usr/bin/env bash
# Apply the Anon product branding to an unbranded tree (upstream tor plus the
# Anyone patch series).  The result is committed as the last commit of the
# series and regenerated after every upstream rebase.
#
# Usage: scripts/anyone/brand.sh [tree]      (default: current directory)
#
# Branded: installed program, library and man page names, the configuration
# file name and default directories, user-visible log, help and error text.
# Never branded: anything another program parses (wire and controller
# protocol strings, signature and KDF labels, the relay platform line, the
# version parser, the syslog identity, file headers tor recognizes on read).
# Anyone-owned files (packaging, deploy, Anyone docs) are left alone.
set -euo pipefail
ROOT=${1:-.}
cd "$ROOT"

MAP=$(mktemp)
trap 'rm -f "$MAP"' EXIT
PRUNE='-path ./.git -o -path ./src/ext -o -path ./src/trunnel -o -path ./debian -o -path ./docker -o -path ./.github -o -path ./operations -o -path ./scripts/anyone -o -path ./changes -o -path ./doc/release'

# Phase 1: file renames (basename only).
find . -depth \( $PRUNE \) -prune -o -print | while IFS= read -r p; do
  [ "$p" = "." ] && continue
  case "$p" in
    ./contrib/operator-tools/tor.logrotate.in|./doc/contrib/tor-rpm-creation.txt|./doc/tor-doxygen.css|./scripts/coccinelle/tor-coccinelle.h) continue ;;
  esac
  d=$(dirname "$p"); b=$(basename "$p")
  nb=$(printf '%s' "$b" | sed -E 's/torrc/anonrc/g; s/torify/anonify/g; s/^tor([-.@]|$)/anon\1/')
  [ "$p" = ./src/app/main/tor_main.c ] && nb=anon_main.c
  if [ "$nb" != "$b" ]; then mv "$p" "$d/$nb"; printf '%s %s\n' "${p#./}" "${d#./}/$nb" >> "$MAP"; fi
done

textfiles() {
  find . \( $PRUNE \) -prune -o -type f \
    ! -name ChangeLog ! -name ReleaseNotes ! -name geoip ! -name geoip6 \
    ! -name '*.png' ! -name '*.ico' ! -name '*.gz' ! -name '*.pem' \
    ! -name '*.a' ! -name '*.o' ! -name 'auth_dirs.inc' ! -name 'fallback_dirs.inc' \
    ! -path './scripts/ci/update-env.sh' ! -path './README.md' ! -path './doc/anyone_hosts_format.txt' \
    -print
}
pick() { grep -E "$1" || true; }
subst() { xargs -r -d '\n' perl -pi -e "$1"; }

# Phase 2: build system.
textfiles | pick '(\.am$|^\./configure\.ac$|^\./\.gitignore$|^\./Doxyfile\.in$|\.nsi\.in$|^\./scripts/|^\./\.travis\.yml$|^\./\.gitlab-ci\.yml$|^\./Makefile\.nmake$|^\./src/win32/)' | subst '
  s/LIBTOR_/LIBANON_/g;
  s/libtor([-._])/libanon$1/g;
  s/libtorrunner/libanonrunner/g;
  s/BUILD_LIBTORRUNNER/BUILD_LIBANONRUNNER/g;
  s{src/app/tor(?=[-.\s/\$\"\x27\x7d]|$)}{src/app/anon}g;
  s/\bsrc_app_tor_/src_app_anon_/g;
  s{src/app/main/tor_main\.c}{src/app/main/anon_main.c}g;
  s{src/tools/tor-(resolve|gencert|print-ed-signing-cert|checkkey)}{src/tools/anon-$1}g;
  s/\bsrc_tools_tor_(resolve|gencert|print_ed_signing_cert)_/src_tools_anon_$1_/g;
  s{doc/man/tor(?=[-.\s]|$)}{doc/man/anon}g;
  s{doc/man/torify}{doc/man/anonify}g;
  s/\btorrc/anonrc/g;
  s/\bTorrc\b/Anonrc/g;
  s/\btorify\b/anonify/g;
  s/\btor-(gencert|resolve|print-ed-signing-cert)\b/anon-$1/g;
  s/\benable_system_torrc\b/enable_system_anonrc/g;
  s/AC_INIT\(\[tor\]/AC_INIT([anon]/g;
  s{\$\(sysconfdir\)/tor\b}{\$(sysconfdir)/anon}g;
  s{\$\(datadir\)/tor\b}{\$(datadir)/anon}g;
  s{\$sysconfdir/tor\b}{\$sysconfdir/anon}g;
  s{\$\(LOCALSTATEDIR\)/lib/tor\b}{\$(LOCALSTATEDIR)/lib/anon}g;
  s/tor\x27s configuration directory/anon\x27s configuration directory/g;
  s/"tor and libtor/"anon and libanon/g;
  s/link tor\x27s utility code/link anon\x27s utility code/g;
  s{src/config/sample-server-torrc}{src/config/sample-server-anonrc}g;
  s{/tmp/tor-rpm-build-}{/tmp/anon-rpm-build-}g;
  s{SOURCES/"tor-\$\(VERSION\)"}{SOURCES/"anon-\$(VERSION)"}g;
  s/\btor\.spec\b/anon.spec/g;
  s/loadTorrc/loadAnonrc/g;
  s{contrib/operator-tools/tor-exit-notice\.html}{contrib/operator-tools/anon-exit-notice.html}g;
  s{contrib/win32build/tor(-mingw\.nsi\.in|\.ico|\.nsi\.in)}{contrib/win32build/anon$1}g;
  s/AC_INIT\\\(\\\[tor\\\]/AC_INIT\\(\\[anon\\]/g;
  s/version of tor and libtor\b/version of anon and libanon/g;
'
textfiles | pick '^\./(configure\.ac|Doxyfile\.in)$' | subst '
  next if /^\s*(dnl|#)/ || /Tor Project/;
  s/\bTor\b/Anon/g;
'

# Phase 3: docs, sample configs, contrib, test fixtures and test scripts.
textfiles | pick '^\./(doc/|contrib/|src/config/|src/test/conf_examples/|src/test/conf_failures/|src/test/[^/]+\.(sh|py)$|README|INSTALL|src/lib/conf/config\.md|src/app/config/app_config\.md)' | subst '
  s/\bTorrc\b/Anonrc/g;
  s/torrc/anonrc/g;
  s/\btorify\b/anonify/g;
  s/\btor-(gencert|resolve|print-ed-signing-cert|instance-create)\b/anon-$1/g;
  s{(/var/lib|/etc|/var/log|/var/run|/run|/usr/share|/usr/(local/)?s?bin)/tor(?=[/\s"\x27.)]|$)}{$1/anon}g;
  s{~/\.tor(?=[/\s"\x27.)]|$)}{~/.anon}g;
  s{\$HOME/\.tor\b}{\$HOME/.anon}g;
  s{\@LOCALSTATEDIR\@/(log|lib|run)/tor\b}{\@LOCALSTATEDIR\@/$1/anon}g;
  s/\bdebian-tor\b/debian-anon/g;
  s/\btor\.(pid|service|socket|log|1|html|1\.in|html\.in|1\.xml)\b/anon.$1/g;
  s/\btor\@/anon\@/g;
  s{src/app/tor(?=[-.\s/\$\"\x27\x7d]|$)}{src/app/anon}g;
  s{src/tools/tor-(resolve|gencert|print-ed-signing-cert)}{src/tools/anon-$1}g;
  s{doc/man/tor(?=[-.\s]|$)}{doc/man/anon}g;
'
# Man pages: command name and product name in prose.
textfiles | pick '^\./doc/man/.*\.txt$' | subst '
  s/^= TOR(-[A-Z-]+)?\(1\)/= ANON$1(1)/;
  s/^tor(-[a-z-]+)? - /anon$1 - /;
  s/\*\*tor\*\*/**anon**/g;
  s/\*\*`tor`\*\*/**`anon`**/g;
  s/`tor (-|--)/`anon $1/g;
  s/\*\*`tor (-|--)/**`anon $1/g;
  next if /Tor Project|Tor Browser|tor-spec|torspec|spec\.torproject/;
  s/\bTor\b/Anon/g;
'
# Test scripts and expected logs match the branded log text.
textfiles | pick '^\./src/test/([^/]+\.(sh|py)|conf_examples/.*/(expected_log|error)[^/]*)$' | { grep -vE '_ref\.py$|/test_(hs_)?ntor\.sh$' || true; } | subst '
  next if /Tor Project/;
  s/\bTor\b/Anon/g;
'

# Phase 4: C and Python string literals.
read -r -d '' P4A <<'PERL' || true
BEGIN { sub strsub { my ($re,$rep)=@_; s/("(?:[^"\\]|\\.)*")/ (my $t=$1) =~ s{$re}{$rep}g; $t /ge } }
next if m{^\s*(/\*|\*(?:\s|/|$)|//)};
strsub(qr/torrc/, 'anonrc');
strsub(qr/Torrc/, 'Anonrc');
s/"__ReloadAnonrcOnSIGHUP"/"__ReloadTorrcOnSIGHUP"/;
strsub(qr/\btor-gencert\b/, 'anon-gencert');
strsub(qr/\btor-resolve\b/, 'anon-resolve');
strsub(qr/\btor-print-ed-signing-cert\b/, 'anon-print-ed-signing-cert');
strsub(qr/\btorify\b/, 'anonify');
strsub(qr{~/\.tor\b}, '~/.anon');
strsub(qr{^"/\.tor"$}, '"/.anon"');
strsub(qr{^"\\\\tor"$}, '"\\\\anon"');
strsub(qr{^"tor"$}, '"anon"') unless $ARGV =~ m{^\./src/test/};
strsub(qr/'tor (?=-)/, "'anon ");
strsub(qr/^"tor -f /, '"anon -f ');
PERL
textfiles | pick '\.(c|h|inc|py)$' | subst "$P4A"

# "Tor" -> "Anon" in C string literals, except strings another program
# parses.  versions.c is the version parser and is skipped whole.
read -r -d '' P4B <<'PERL' || true
BEGIN {
  sub brand { my $t = shift;
    return $t if $t =~ /^"Tor ?"$/;
    $t =~ s{\bTor (?=networks?\b)}{Anyone }g;
    $t =~ s{\bTor\b(?!-[A-Z]| [0-9]| Project| Browser|-spec| spec)}{Anon}g;
    return $t; }
}
next if m{^\s*(/\*|\*(?:\s|/|$)|//)};
next if /Tor %s on %s|"Tor just started"|handshaking \(Tor,|generated by Tor;/;
next if /(X-)?Tor-(Capabilities|RPC-Target|Stream-Isolation|Request-Failed)/;
next if /Tor safe cookie|Tor router descriptor signature|Tor establish-intro cell|Tor onion service descriptor sig|Tor hs intro|Tor TLS RSA\/Ed25519|Tor byte-counting layer|Tor-Process-Pipe|Tor V3 handshake TLS cross-certification/;
next if /TorVersion, "Tor %s"|"Tor-%s", syslog_identity_tag/;
s/(" may only be changed in testing )Tor "   /$1Anyone "/;
s/("(?:[^"\\]|\\.)*")/brand($1)/ge;
PERL
textfiles | pick '\.(c|h)$' | { grep -vE '^\./src/core/or/versions\.c$|^\./src/lib/tls/' || true; } | subst "$P4B"

# Phase 4c: "Anon" is one character longer than "Tor"; keep branded lines
# within 79 columns by trimming leading spaces (never significant in C).
read -r -d '' P4C <<'PERL' || true
chomp; my $over = length($_) - 79;
if ($over > 0 && /\b[Aa]non/ && /^( +)/ && length($1) > $over) { substr($_, 0, $over) = ''; }
$_ .= "\n";
PERL
textfiles | pick '^\./src/.*\.(c|h)$' | subst "$P4C"

# Phase 5: invariants.  Any failure here means a protocol string changed.
fail=0
check() { if ! eval "$1" >/dev/null 2>&1; then echo "brand.sh: FAIL: $2" >&2; fail=1; fi; }
check 'grep -q "\"Tor %s on %s\"" src/feature/relay/router.c' 'relay platform line'
check 'grep -q "strcmpstart(cp, \"Tor \")" src/core/or/versions.c' 'version parser prefix'
check 'grep -q "strcmpstart(platform, \"Tor \")" src/feature/dirauth/dirvote.c' 'dirauth platform prefix'
check 'grep -q "control_reply_append_kv(reply, \"Tor\"" src/feature/control/control_cmd.c' 'PROTOCOLINFO VERSION Tor='
check 'grep -q "\"Tor-%s\", syslog_identity_tag" src/lib/log/log.c' 'syslog identity tag'
check 'grep -q "Tor safe cookie authentication server-to-controller hash" src/feature/control/control_auth.c' 'cookie auth constants'
check 'grep -q "\"Tor router descriptor signature v1\"" src/feature/dirparse/routerparse.h' 'router descriptor sig prefix'
check 'grep -q "\"Tor onion service descriptor sig v3\"" src/feature/hs/hs_descriptor.c' 'hs descriptor sig prefix'
check 'grep -q "\"Tor establish-intro cell v1\"" src/feature/hs/hs_common.h' 'establish-intro sig prefix'
check 'grep -q "Tor hs intro v1" src/feature/hs/hs_pow.h' 'hs pow personalization'
check 'grep -q "\"Tor TLS RSA/Ed25519 cross-certificate\"" src/feature/nodelist/torcert.c' 'TLS cross-cert label'
check 'grep -q "\"# This file was generated by Tor; \"" src/app/config/config.c' 'generated-config header'
check 'grep -q "\"__ReloadTorrcOnSIGHUP\"" src/app/config/config.c' 'controller-visible __ReloadTorrcOnSIGHUP'
check '! grep -rq "Anon V3 handshake TLS" src' 'TLS cross-certification magic'
check '! grep -rqE "\"(X-)?Anon-(Capabilities|RPC-Target|Stream-Isolation|Request-Failed)" src' 'HTTP CONNECT headers'
check '! grep -rq --exclude=brand.sh "anon-\\\$1" src doc scripts' 'unexpanded anon-$1'
check '! grep -q "enable_system_torrc" configure.ac' 'system-anonrc configure option wiring'
check 'grep -q "AC_DEFINE(DISABLE_SYSTEM_TORRC" configure.ac' 'DISABLE_SYSTEM_TORRC define name (C code tests it)'
check '! grep -rqE "anon_(assert|malloc|free)\\b|ANON_UNIT_TESTS" src' 'C identifier namespace'
check '! grep -rlqE "libtor[-._]|LIBTOR_" --include="*.am" --include=configure.ac .' 'libtor build tokens remain'
while read -r old new; do
  if textfiles | pick '(\.am|configure\.ac|\.py|\.sh|Makefile\.nmake)$' | xargs -r -d '\n' grep -lqsF -- "$old"; then
    echo "brand.sh: FAIL: build files still reference renamed $old (now $new)" >&2; fail=1
  fi
done < "$MAP"
left=$(grep -rn -o -E '"[^"]*\bTor\b[^"]*"' src --include='*.c' --include='*.h' 2>/dev/null | grep -v '^src/ext/' | wc -l)
echo "brand.sh: $left \"Tor\" string literal(s) remain (protocol strings and proper nouns)"
[ "$fail" = 0 ] || { echo "brand.sh: invariant check FAILED" >&2; exit 1; }
echo "brand.sh: done"
