# Copyright (c) 2001-2004, Roger Dingledine
# Copyright (c) 2004-2006, Roger Dingledine, Nick Mathewson
# Copyright (c) 2007-2019, The Tor Project, Inc.
# See LICENSE for licensing information

ACLOCAL_AMFLAGS = -I m4

noinst_LIBRARIES=
EXTRA_DIST=
noinst_HEADERS=
bin_PROGRAMS=
EXTRA_PROGRAMS=
CLEANFILES=
TESTS=
noinst_PROGRAMS=
DISTCLEANFILES=
MOSTLYCLEANFILES=
bin_SCRIPTS=
AM_CPPFLAGS=\
	-I$(top_srcdir)/src \
	-I$(top_srcdir)/src/ext \
	-I$(top_srcdir)/src/ext/trunnel \
	-I$(top_srcdir)/src/trunnel

AM_CFLAGS=					\
	@TOR_SYSTEMD_CFLAGS@			\
	@CFLAGS_BUGTRAP@			\
	@TOR_LZMA_CFLAGS@			\
	@TOR_ZSTD_CFLAGS@

SHELL=@SHELL@

if COVERAGE_ENABLED
TESTING_TOR_BINARY=$(top_builddir)/src/app/anon-cov$(EXEEXT)
else
TESTING_TOR_BINARY=$(top_builddir)/src/app/anon$(EXEEXT)
endif

# "Common" libraries used to link anon's utility code.
TOR_UTIL_LIBS = \
        src/lib/libanon-geoip.a \
	src/lib/libanon-process.a \
        src/lib/libanon-buf.a \
	src/lib/libanon-confmgt.a \
	src/lib/libanon-pubsub.a \
	src/lib/libanon-dispatch.a \
	src/lib/libanon-time.a \
	src/lib/libanon-fs.a \
	src/lib/libanon-encoding.a \
	src/lib/libanon-sandbox.a \
	src/lib/libanon-container.a \
	src/lib/libanon-net.a \
	src/lib/libanon-thread.a \
	src/lib/libanon-memarea.a \
	src/lib/libanon-math.a \
	src/lib/libanon-meminfo.a \
	src/lib/libanon-osinfo.a \
	src/lib/libanon-log.a \
	src/lib/libanon-lock.a \
	src/lib/libanon-fdio.a \
	src/lib/libanon-string.a \
	src/lib/libanon-term.a \
	src/lib/libanon-smartlist-core.a \
	src/lib/libanon-malloc.a \
	src/lib/libanon-wallclock.a \
	src/lib/libanon-err.a \
	src/lib/libanon-version.a \
	src/lib/libanon-llharden.a \
	src/lib/libanon-intmath.a \
	src/lib/libanon-ctime.a \
	src/lib/libanon-metrics.a

# Variants of the above for linking the testing variant of tor (for coverage
# and tests)
if UNITTESTS_ENABLED
TOR_UTIL_TESTING_LIBS = \
        src/lib/libanon-geoip-testing.a \
	src/lib/libanon-process-testing.a \
        src/lib/libanon-buf-testing.a \
	src/lib/libanon-confmgt-testing.a \
	src/lib/libanon-pubsub-testing.a \
	src/lib/libanon-dispatch-testing.a \
	src/lib/libanon-time-testing.a \
	src/lib/libanon-fs-testing.a \
	src/lib/libanon-encoding-testing.a \
	src/lib/libanon-sandbox-testing.a \
	src/lib/libanon-container-testing.a \
	src/lib/libanon-net-testing.a \
	src/lib/libanon-thread-testing.a \
	src/lib/libanon-memarea-testing.a \
	src/lib/libanon-math-testing.a \
	src/lib/libanon-meminfo-testing.a \
	src/lib/libanon-osinfo-testing.a \
	src/lib/libanon-term-testing.a \
	src/lib/libanon-log-testing.a \
	src/lib/libanon-lock-testing.a \
	src/lib/libanon-fdio-testing.a \
	src/lib/libanon-string-testing.a \
	src/lib/libanon-smartlist-core-testing.a \
	src/lib/libanon-malloc-testing.a \
	src/lib/libanon-wallclock-testing.a \
	src/lib/libanon-err-testing.a \
	src/lib/libanon-version-testing.a \
	src/lib/libanon-llharden-testing.a \
	src/lib/libanon-intmath.a \
	src/lib/libanon-ctime-testing.a \
	src/lib/libanon-metrics-testing.a
endif

# Internal crypto libraries used in Tor
TOR_CRYPTO_LIBS = \
	src/lib/libanon-tls.a \
	src/lib/libanon-crypt-ops.a \
	$(LIBKECCAK_TINY) \
	$(LIBDONNA)

if BUILD_MODULE_POW
TOR_CRYPTO_LIBS += $(EQUIX_LIBS)
endif

# Variants of the above for linking the testing variant of tor (for coverage
# and tests)
if UNITTESTS_ENABLED
TOR_CRYPTO_TESTING_LIBS = \
	src/lib/libanon-tls-testing.a \
	src/lib/libanon-crypt-ops-testing.a \
	$(LIBKECCAK_TINY) \
	$(LIBDONNA) \
	$(EQUIX_LIBS)
endif

# All static libraries used to link tor.
TOR_INTERNAL_LIBS = \
	src/core/libanon-app.a \
	src/lib/libanon-compress.a \
	src/lib/libanon-evloop.a \
	$(TOR_CRYPTO_LIBS) \
	$(TOR_UTIL_LIBS) \
	src/trunnel/libor-trunnel.a \
	src/lib/libanon-trace.a

libanon.a: $(TOR_INTERNAL_LIBS)
	$(AM_V_AR) export AR="$(AR)"; \
	export ARFLAGS="$(ARFLAGS)"; \
	export RANLIB="$(RANLIB)"; \
	$(top_srcdir)/scripts/build/combine_libs libanon.a $(TOR_INTERNAL_LIBS)

MOSTLYCLEANFILES += libanon.a

# Variants of the above for linking the testing variant of tor (for coverage
# and tests)
if UNITTESTS_ENABLED
TOR_INTERNAL_TESTING_LIBS = \
	src/core/libanon-app-testing.a \
	src/lib/libanon-compress-testing.a \
	src/lib/libanon-evloop-testing.a \
	$(TOR_CRYPTO_TESTING_LIBS) \
	$(TOR_UTIL_TESTING_LIBS) \
	src/trunnel/libor-trunnel-testing.a \
	src/lib/libanon-trace.a

src/test/libanon-testing.a: $(TOR_INTERNAL_TESTING_LIBS)
	$(AM_V_AR) export AR="$(AR)"; \
	export ARFLAGS="$(ARFLAGS)"; \
	export RANLIB="$(RANLIB)"; \
	$(top_srcdir)/scripts/build/combine_libs src/test/libanon-testing.a $(TOR_INTERNAL_TESTING_LIBS)

MOSTLYCLEANFILES += src/test/libanon-testing.a
endif

TOR_LDFLAGS_CRYPTLIB=@TOR_LDFLAGS_openssl@
TOR_LIBS_CRYPTLIB=@TOR_OPENSSL_LIBS@
TOR_CFLAGS_CRYPTLIB=
if USE_NSS
TOR_CFLAGS_CRYPTLIB+=@NSS_CFLAGS@
TOR_LIBS_CRYPTLIB+=@NSS_LIBS@
endif

# All libraries used to link tor-cov

include src/include.am
include doc/include.am
include contrib/include.am

manpages: $(nodist_man1_MANS)

EXTRA_DIST+= \
	ChangeLog							\
	CONTRIBUTING							\
	CODE_OF_CONDUCT							\
	INSTALL								\
	LICENSE								\
	README.md								\
	ReleaseNotes							\
	scripts/build/combine_libs					\
	scripts/maint/checkIncludes.py					\
	scripts/maint/checkSpace.pl					\
	scripts/maint/checkSpaceTest.sh					\
	scripts/maint/checkspace_tests/dubious.c			\
	scripts/maint/checkspace_tests/dubious.h			\
	scripts/maint/checkspace_tests/expected.txt			\
	scripts/maint/checkspace_tests/good_guard.h			\
	scripts/maint/checkspace_tests/same_guard.h			\
	scripts/maint/checkspace_tests/subdir/dubious.c			\
	scripts/maint/checkShellScripts.sh				\
	scripts/maint/practracker/README				\
	scripts/maint/practracker/exceptions.txt			\
	scripts/maint/practracker/includes.py				\
	scripts/maint/practracker/metrics.py				\
	scripts/maint/practracker/practracker.py			\
	scripts/maint/practracker/practracker_tests.py			\
	scripts/maint/practracker/problem.py				\
	scripts/maint/practracker/testdata/.may_include			\
	scripts/maint/practracker/testdata/a.c				\
	scripts/maint/practracker/testdata/b.c				\
	scripts/maint/practracker/testdata/ex0-expected.txt		\
	scripts/maint/practracker/testdata/ex0.txt			\
	scripts/maint/practracker/testdata/ex1-expected.txt		\
	scripts/maint/practracker/testdata/ex1.txt			\
	scripts/maint/practracker/testdata/ex1-overbroad-expected.txt	\
	scripts/maint/practracker/testdata/ex1-regen-expected.txt	\
	scripts/maint/practracker/testdata/ex1-regen-overbroad-expected.txt \
	scripts/maint/practracker/testdata/ex.txt			\
	scripts/maint/practracker/testdata/header.h			\
	scripts/maint/practracker/testdata/not_c_file			\
	scripts/maint/practracker/test_practracker.sh			\
	scripts/maint/practracker/util.py				\
	scripts/coccinelle/apply.sh					\
	scripts/coccinelle/check_cocci_parse.sh				\
	scripts/coccinelle/exceptions.txt				\
	scripts/coccinelle/test-operator-cleanup			\
	scripts/coccinelle/tor-coccinelle.h				\
	scripts/coccinelle/try_parse.sh

## This tells etags how to find mockable function definitions.
AM_ETAGSFLAGS=--regex='{c}/MOCK_IMPL([^,]+,\W*\([a-zA-Z0-9_]+\)\W*,/\1/s'

if COVERAGE_ENABLED
TEST_CFLAGS=-fno-inline -fprofile-arcs -ftest-coverage
if DISABLE_ASSERTS_IN_UNIT_TESTS
TEST_CPPFLAGS=-DTOR_UNIT_TESTS -DTOR_COVERAGE -DDISABLE_ASSERTS_IN_UNIT_TESTS @TOR_MODULES_ALL_ENABLED@
else
TEST_CPPFLAGS=-DTOR_UNIT_TESTS -DTOR_COVERAGE @TOR_MODULES_ALL_ENABLED@
endif
TEST_NETWORK_FLAGS=--coverage --hs-multi-client 1
else
TEST_CFLAGS=
TEST_CPPFLAGS=-DTOR_UNIT_TESTS @TOR_MODULES_ALL_ENABLED@
TEST_NETWORK_FLAGS=--hs-multi-client 1
endif
TEST_NETWORK_SHOW_WARNINGS_FOR_LAST_RUN_FLAGS=--quiet --only-warnings

if LIBFUZZER_ENABLED
TEST_CFLAGS += -fsanitize=fuzzer-no-link
# not "edge"
endif

TEST_NETWORK_ALL_LOG_DIR=$(top_builddir)/test_network_log
TEST_NETWORK_ALL_DRIVER_FLAGS=--color-tests yes

#install-data-local:
#	$(INSTALL) -m 755 -d $(LOCALSTATEDIR)/lib/anon

# Allows to override rpmbuild with rpmbuild-md5 from fedora-packager so that
# building for EL5 won't fail on https://bugzilla.redhat.com/show_bug.cgi?id=490613
RPMBUILD ?= rpmbuild

# Use automake's dist-gzip target to build the tarball
dist-rpm: dist-gzip
	TIMESTAMP=$$(date +"%Y-%m-%d_%H.%M.%S"); 				\
	RPM_BUILD_DIR=$$(mktemp -d "/tmp/anon-rpm-build-$$TIMESTAMP-XXXX");	\
	mkdir -p "$$RPM_BUILD_DIR"/{BUILD,RPMS,SOURCES/"anon-$(VERSION)",SPECS,SRPMS}; \
	cp -fa "$(distdir).tar.gz" "$$RPM_BUILD_DIR"/SOURCES/;			\
	LIBS=-lrt $(RPMBUILD) -ba --define "_topdir $$RPM_BUILD_DIR" anon.spec; 	\
	cp -fa "$$RPM_BUILD_DIR"/SRPMS/* .;                           		\
	cp -fa "$$RPM_BUILD_DIR"/RPMS/* .;                            		\
	rm -rf "$$RPM_BUILD_DIR";						\
	echo "RPM build finished";						\
	#end of dist-rpm

.PHONY: doxygen
doxygen: Doxyfile
	mkdir -p doc/doxygen
	(cd "$(top_srcdir)" && doxygen "$(abs_top_builddir)/Doxyfile")

test: all
	$(top_builddir)/src/test/test

shellcheck:
	$(top_srcdir)/scripts/maint/checkShellScripts.sh

check-local:					\
	check-spaces				\
	check-changes				\
	check-includes				\
	shellcheck

# test-network requires a copy of Chutney in $CHUTNEY_PATH.
# Chutney can be cloned from https://gitlab.torproject.org/tpo/core/chutney.git .
.PHONY: need-chutney-path
need-chutney-path:
	@if test ! -d "$$CHUTNEY_PATH"; then \
		echo '$$CHUTNEY_PATH was not set.'; \
		if test -d "$(top_srcdir)/../chutney" && \
		   test -x "$(top_srcdir)/../chutney/chutney"; then \
			echo "Assuming test-network.sh will find" \
			  "$(top_srcdir)/../chutney"; \
		else \
			echo; \
			echo "To run these tests," \
			  "git clone" \
			  "https://gitlab.torproject.org/tpo/core/chutney.git ;" \
			  "export CHUTNEY_PATH=\`pwd\`/chutney"; \
			exit 1; \
		fi \
	fi

# Run some basic tests using automake's test-driver
.PHONY: test-network
# Hide directory path logs from submakes using $(MAKE) -s
test-network:
	@$(MAKE) -s test-network-mkdir
	@$(MAKE) -s test-network-clean
	@$(MAKE) -s test-network-run \
	  ipv4_flavors="$(TEST_CHUTNEY_FLAVOR_QUICK)" \
	  ipv6_flavors="$(TEST_CHUTNEY_FLAVOR_QUICK_IPV6)"
	@$(MAKE) -s test-network-results

# Run all available tests using automake's test-driver
.PHONY: test-network-all
# Hide directory path logs from submakes using $(MAKE) -s
test-network-all:
	@$(MAKE) -s test-network-mkdir
	@$(MAKE) -s test-network-clean
	@$(MAKE) -s test-network-run \
	  ipv4_flavors="$(TEST_CHUTNEY_FLAVORS)" \
	  mixed_flavors="$(TEST_CHUTNEY_FLAVORS_MIXED)" \
	  ipv6_flavors="$(TEST_CHUTNEY_FLAVORS_IPV6)" \
	  ipv6_mixed_flavors="$(TEST_CHUTNEY_FLAVORS_IPV6_MIXED)"
	@$(MAKE) -s test-network-results

# Run IPv4 and mixed tests using automake's test-driver
.PHONY: test-network-ipv4
# Hide directory path logs from submakes using $(MAKE) -s
test-network-ipv4:
	@$(MAKE) -s test-network-mkdir
	@$(MAKE) -s test-network-clean
	@$(MAKE) -s test-network-run \
	  ipv4_flavors="$(TEST_CHUTNEY_FLAVORS)" \
	  mixed_flavors="$(TEST_CHUTNEY_FLAVORS_MIXED)"
	@$(MAKE) -s test-network-results

# Run IPv6 tests using automake's test-driver
.PHONY: test-network-ipv6
# Hide directory path logs from submakes using $(MAKE) -s
test-network-ipv6:
	@$(MAKE) -s test-network-mkdir
	@$(MAKE) -s test-network-clean
	@$(MAKE) -s test-network-run \
	  ipv6_flavors="$(TEST_CHUTNEY_FLAVORS_IPV6)" \
	  ipv6_mixed_flavors="$(TEST_CHUTNEY_FLAVORS_IPV6_MIXED)"
	@$(MAKE) -s test-network-results

# Make the test network log directory, if it does not exist
.PHONY: test-network-mkdir
test-network-mkdir:
	@mkdir -p "$(TEST_NETWORK_ALL_LOG_DIR)"

# Clean the test network log directory
.PHONY: test-network-clean
# We need to remove all matching files, so we can't quote the glob part of the
# rm arguments
test-network-clean:
	rm -f "$(TEST_NETWORK_ALL_LOG_DIR)"/*.log \
	      "$(TEST_NETWORK_ALL_LOG_DIR)"/*.trs

# Run tests using automake's test-driver
# When checking if a set of test can be run, log the type of test, and the
# list of tests that will be run (or skipped).
#
# Run the IPv4 tests in $(ipv4_flavors), unconditionally
#   - tor relays and directory authorities require IPv4.
# Run the IPv6 tests in $(ipv6_flavors), if IPv6 is available
#   - only run IPv6 tests if we can ping6 or ping -6 ::1 (localhost)
#     we try the syntax for BSD ping6, Linux ping6, and Linux ping -6,
#     because they're incompatible
#   - some IPv6 tests may fail without an IPv6 DNS server
#     (see #16971 and #17011)
# Run the mixed tests in $(mixed_flavors), if a tor-stable binary is available
#   - only run mixed tests if we have a tor-stable binary
# Run the IPv6 mixed tests in $(ipv6_mixed_flavors), if IPv6 and mixed are run
#   - see above for details about IPv6 and mixed
.PHONY: test-network-run
# We need the word splitting in the "for" lines, so we can't quote
# $(skip_flavors) or $(flavors)
test-network-run: need-chutney-path test-driver $(TESTING_TOR_BINARY) src/tools/anon-gencert
	@flavors=""; \
	skip_flavors=""; \
	if test -n "$(ipv4_flavors)"; then \
		echo "Running IPv4 flavors: $(ipv4_flavors)."; \
		flavors="$$flavors $(ipv4_flavors)"; \
	fi; \
	test_network_ipv6=false; \
	if test -n "$(ipv6_flavors)" || \
	   test -n "$(ipv6_mixed_flavors)"; then \
		if ping6 -q -c 1 -o   ::1 >/dev/null 2>&1 || \
		   ping6 -q -c 1 -W 1 ::1 >/dev/null 2>&1 || \
		   ping  -6 -c 1 -W 1 ::1 >/dev/null 2>&1; then \
			test_network_ipv6=true; \
		fi; \
	fi; \
	if test -n "$(ipv6_flavors)"; then \
		if test "$$test_network_ipv6" = "true"; then \
			echo "ping6 ::1 or ping ::1 succeeded, running IPv6" \
			  "flavors: $(ipv6_flavors)."; \
			flavors="$$flavors $(ipv6_flavors)"; \
		else \
			echo "ping6 ::1 and ping ::1 failed, skipping IPv6" \
			  "flavors: $(ipv6_flavors)."; \
			skip_flavors="$$skip_flavors $(ipv6_flavors)"; \
		fi; \
	fi; \
	test_network_mixed=false; \
	if test -n "$(mixed_flavors)" || \
	   test -n "$(ipv6_mixed_flavors)"; then \
		if command -v tor-stable >/dev/null 2>&1; then \
			test_network_mixed=true; \
		fi; \
	fi; \
	if test -n "$(mixed_flavors)"; then \
		if test "$$test_network_mixed" = "true"; then \
			echo "tor-stable found, running mixed flavors:" \
			  "$(mixed_flavors)."; \
			flavors="$$flavors $(mixed_flavors)"; \
		else \
			echo "tor-stable not found, skipping mixed flavors:" \
			  "$(mixed_flavors)."; \
			skip_flavors="$$skip_flavors $(mixed_flavors)"; \
		fi; \
	fi; \
	if test -n "$(ipv6_mixed_flavors)"; then \
		if test "$$test_network_ipv6" = "true" && \
		   test "$$test_network_mixed" = "true"; then \
			echo "Running IPv6 mixed flavors:" \
			  "$(ipv6_mixed_flavors)."; \
			flavors="$$flavors $(ipv6_mixed_flavors)"; \
		else \
			echo "Skipping IPv6 mixed flavors:" \
			  "$(ipv6_mixed_flavors)."; \
			skip_flavors="$$skip_flavors $(ipv6_mixed_flavors)"; \
		fi; \
	fi; \
	for f in $$skip_flavors; do \
		echo "SKIP: $$f"; \
	done; \
	for f in $$flavors; do \
		$(SHELL) "$(top_srcdir)/test-driver" --test-name "$$f" \
		  --log-file "$(TEST_NETWORK_ALL_LOG_DIR)/$$f.log" \
		  --trs-file "$(TEST_NETWORK_ALL_LOG_DIR)/$$f.trs" \
		  $(TEST_NETWORK_ALL_DRIVER_FLAGS) \
		  "$(top_srcdir)/src/test/test-network.sh" \
		    --flavor "$$f" $(TEST_NETWORK_FLAGS); \
		"$(top_srcdir)/src/test/test-network.sh" \
		  $(TEST_NETWORK_SHOW_WARNINGS_FOR_LAST_RUN_FLAGS); \
	done

# Print the results from automake's test-driver
#   - show tor warnings on the console after each network run
#     (otherwise, warnings go to the logs, and people don't see them unless
#     there is a network failure)
.PHONY: test-network-results
# We need to grep all matching files, so we can't quote the glob part of the
# grep arguments
test-network-results:
	@echo \
	  "Log and result files are available in $(TEST_NETWORK_ALL_LOG_DIR)."
	@! grep -q FAIL "$(TEST_NETWORK_ALL_LOG_DIR)"/*.trs

need-stem-path:
	@if test ! -d "$$STEM_SOURCE_DIR"; then \
		echo '$$STEM_SOURCE_DIR was not set.'; echo; \
		echo "To run these tests, git clone https://gitlab.torproject.org/tpo/network-health/stem ; export STEM_SOURCE_DIR=\`pwd\`/stem"; \
		exit 1; \
	fi

test-stem: need-stem-path $(TESTING_TOR_BINARY)
	@$(PYTHON) "$$STEM_SOURCE_DIR"/run_tests.py --tor "$(TESTING_TOR_BINARY)" --integ --test control.controller --test control.base_controller --test process --log notice;

test-stem-full: need-stem-path $(TESTING_TOR_BINARY)
	@$(PYTHON) "$$STEM_SOURCE_DIR"/run_tests.py --tor "$(TESTING_TOR_BINARY)" --all --log notice --target RUN_ALL,ONLINE -v;

test-full:					\
	need-stem-path				\
	need-chutney-path			\
	check					\
	test-network				\
	test-stem

test-full-online:				\
	need-stem-path				\
	need-chutney-path			\
	check					\
	test-network				\
	test-stem-full

# We can't delete the gcno files, because they are created when tor is compiled
reset-gcov:
	rm -f $(top_builddir)/src/*/*.gcda $(top_builddir)/src/*/*/*.gcda \
	      $(top_builddir)/src/*/*.gcov $(top_builddir)/src/*/*/*.gcov

HTML_COVER_DIR=$(top_builddir)/coverage_html
coverage-html: all
if COVERAGE_ENABLED
	test -e "`which lcov`" || (echo "lcov must be installed. See <http://ltp.sourceforge.net/coverage/lcov.php>." && false)
	test -d "$(HTML_COVER_DIR)" || $(MKDIR_P) "$(HTML_COVER_DIR)"
	lcov --rc lcov_branch_coverage=1 --directory $(top_builddir)/src --zerocounters
	$(MAKE) reset-gcov
	$(MAKE) check
	lcov --capture --rc lcov_branch_coverage=1 --no-external --directory $(top_builddir) --base-directory $(top_srcdir) --output-file "$(HTML_COVER_DIR)/lcov.tmp"
	lcov --remove "$(HTML_COVER_DIR)/lcov.tmp" --rc lcov_branch_coverage=1 'test/*' 'ext/tinytest*' '/usr/*' --output-file "$(HTML_COVER_DIR)/lcov.info"
	genhtml --branch-coverage -o "$(HTML_COVER_DIR)" "$(HTML_COVER_DIR)/lcov.info"
else
	@printf "Not configured with --enable-coverage, run ./configure --enable-coverage\n"
endif

coverage-html-full: all
	test -e "`which lcov`" || (echo "lcov must be installed. See <http://ltp.sourceforge.net/coverage/lcov.php>." && false)
	test -d "$(HTML_COVER_DIR)" || mkdir -p "$(HTML_COVER_DIR)"
	lcov --rc lcov_branch_coverage=1 --directory ./src --zerocounters
	$(MAKE) reset-gcov
	$(MAKE) check
	$(MAKE) test-stem-full
	CHUTNEY_TOR=tor-cov CHUTNEY_ANON_GENCERT=tor-cov-gencert $(top_srcdir)/src/test/test-network.sh
	CHUTNEY_TOR=tor-cov CHUTNEY_ANON_GENCERT=tor-cov-gencert $(top_srcdir)/src/test/test-network.sh --flavor hs
	lcov --capture --rc lcov_branch_coverage=1 --no-external --directory . --output-file "$(HTML_COVER_DIR)/lcov.tmp"
	lcov --remove "$(HTML_COVER_DIR)/lcov.tmp" --rc lcov_branch_coverage=1 'test/*' 'ext/tinytest*' '/usr/*' --output-file "$(HTML_COVER_DIR)/lcov.info"
	genhtml --branch-coverage -o "$(HTML_COVER_DIR)" "$(HTML_COVER_DIR)/lcov.info"

# For scripts: avoid src/ext and src/trunnel.
# Keep these lists consistent:
#   - OWNED_TOR_C_FILES in Makefile.am
#   - CHECK_FILES in pre-commit.git-hook and pre-push.git-hook
#   - try_parse in check_cocci_parse.sh
OWNED_TOR_C_FILES=\
		$(top_srcdir)/src/lib/*/*.[ch] \
		$(top_srcdir)/src/core/*/*.[ch] \
		$(top_srcdir)/src/feature/*/*.[ch] \
		$(top_srcdir)/src/app/*/*.[ch] \
		$(top_srcdir)/src/test/*.[ch] \
		$(top_srcdir)/src/test/*/*.[ch] \
		$(top_srcdir)/src/tools/*.[ch]

check-spaces:
if USE_PERL
	$(PERL) $(top_srcdir)/scripts/maint/checkSpace.pl -C \
		$(OWNED_TOR_C_FILES)
endif

check-includes:
if USEPYTHON
	$(PYTHON) $(top_srcdir)/scripts/maint/practracker/includes.py $(top_srcdir)
endif

check-best-practices:
if USEPYTHON
	@$(PYTHON) $(top_srcdir)/scripts/maint/practracker/practracker.py $(top_srcdir) $(TOR_PRACTRACKER_OPTIONS)
endif

check-cocci:
	VERBOSE=1 $(top_srcdir)/scripts/coccinelle/check_cocci_parse.sh $(OWNED_TOR_C_FILES)

practracker-regen:
	$(PYTHON) $(top_srcdir)/scripts/maint/practracker/practracker.py --regen $(top_srcdir)

check-docs: all
	$(PERL) $(top_builddir)/scripts/maint/checkOptionDocs.pl

check-logs:
	$(top_srcdir)/scripts/maint/checkLogs.pl \
		$(top_srcdir)/src/*/*.[ch] | sort -n

.PHONY: check-typos
check-typos:
	@if test -x "`which misspell 2>&1;true`"; then \
		echo "Checking for Typos ..."; \
		(misspell \
			$(top_srcdir)/src/[^e]*/*.[ch] \
			$(top_srcdir)/doc \
			$(top_srcdir)/contrib \
			$(top_srcdir)/scripts \
			$(top_srcdir)/README.md \
			$(top_srcdir)/ChangeLog \
			$(top_srcdir)/INSTALL \
			$(top_srcdir)/ReleaseNotes \
			$(top_srcdir)/LICENSE); \
	else \
		echo "Tor can use misspell to check for typos."; \
		echo "It seems that you don't have misspell installed."; \
		echo "You can install the latest version of misspell here: https://github.com/client9/misspell#install"; \
	fi

.PHONY: check-changes
check-changes:
if USEPYTHON
	@if test -d "$(top_srcdir)/changes"; then \
		PACKAGE_VERSION=$(PACKAGE_VERSION) $(PYTHON) $(top_srcdir)/scripts/maint/lintChanges.py $(top_srcdir)/changes; \
		fi
endif

.PHONY: update-versions
update-versions:
	abs_top_srcdir="$(abs_top_srcdir)" $(PYTHON) $(top_srcdir)/scripts/maint/update_versions.py

.PHONY: callgraph
callgraph:
	cd $(top_builddir); $(abs_top_srcdir)/scripts/maint/run_calltool.sh

version:
	@echo "Tor @VERSION@"
	@if test -d "$(top_srcdir)/.git" && test -x "`which git 2>&1;true`"; then \
	   echo -n "git: " ;\
	   (cd "$(top_srcdir)" && git rev-parse --short=16 HEAD); \
	fi

.PHONY: autostyle-ifdefs
autostyle-ifdefs:
	$(PYTHON) $(top_srcdir)/scripts/maint/annotate_ifdef_directives.py $(OWNED_TOR_C_FILES)

.PHONY: autostyle-ifdefs
autostyle-operators:
	$(PERL) $(top_srcdir)/scripts/coccinelle/test-operator-cleanup $(OWNED_TOR_C_FILES)

.PHONY: rectify-includes
rectify-includes:
	cd $(top_srcdir); $(PYTHON) $(abs_top_srcdir)/scripts/maint/rectify_include_paths.py

.PHONY: update-copyright
update-copyright:
	$(PERL) $(top_srcdir)/scripts/maint/updateCopyright.pl $(OWNED_TOR_C_FILES)

.PHONY: autostyle
autostyle: update-versions autostyle-ifdefs rectify-includes

mostlyclean-local:
	rm -f $(top_builddir)/src/*/*.gc{da,no} $(top_builddir)/src/*/*/*.gc{da,no}
	rm -rf $(HTML_COVER_DIR)
	rm -rf $(top_builddir)/doc/doxygen
	rm -rf $(TEST_NETWORK_ALL_LOG_DIR)

# This relies on some internal details of how automake implements
# distcheck.  We check two directories because automake-1.15 changed
# from $(distdir)/_build to $(distdir)/_build/sub.
show-distdir-testlog:
	@if test -d "$(distdir)/_build/sub"; then \
	  cat $(distdir)/_build/sub/$(TEST_SUITE_LOG); \
	else \
	  cat $(distdir)/_build/$(TEST_SUITE_LOG); fi

# Similarly, this relies on automake internals to run file on an
# intermittent core file whose provenance is not known to us.  See
# ticket 26787.
show-distdir-core:
	@if test -d "$(distdir)/_build/sub"; then \
	  file $(distdir)/_build/sub/core ; \
	else \
	  file $(distdir)/_build/core; fi

show-libs:
	@echo libanon.a

show-testing-libs:
	@echo src/test/libanon-testing.a

# Note here that we hardcode this -j2 because if the user would pass too many
# cores, bear actually chockes and dies :S. For this to work, a make clean
# needs to be done else bear will miss some compile flags.
lsp:
	@if test -x "`which bear 2>&1;true`"; then \
		echo "Generating LSP compile_commands.json. Might take few minutes..."; \
		$(MAKE) clean 2>&1 >/dev/null; \
		bear >/dev/null 2>&1 -- $(MAKE) -j2 2>&1 >/dev/null; \
		echo "Generating .ccls file..."; \
		./scripts/maint/gen_ccls_file.sh \
	else \
		echo "No bear command found. On debian, apt install bear"; \
	fi

# Reproducible tarball. We change the tar options for this.
dist-reprod:
	$(MAKE) dist am__tar="$${TAR-tar} --format=gnu --owner=root --group=root --sort=name --mtime=\"`git show --no-patch --format='%ci'`\" -chof - $(distdir)"
