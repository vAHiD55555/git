#!/bin/sh

test_description='test status when slow untracked files'

. ./test-lib.sh

DATA="$TEST_DIRECTORY/t7065"

GIT_TEST_UF_DELAY_WARNING=1
export GIT_TEST_UF_DELAY_WARNING

test_expect_success setup '
	git checkout -b test
'

test_expect_success 'when core.untrackedCache and fsmonitor are unset' '
	test_must_fail git config --get core.untrackedCache &&
	test_must_fail git config --get core.fsmonitor &&
    git status | sed "s/[0-9]\.[0-9][0-9]/X/g" >../actual &&
    test_cmp "$DATA/no_untrackedcache_no_fsmonitor" ../actual &&
    rm -fr ../actual
'

test_expect_success 'when core.untrackedCache true, but not fsmonitor' '
    git config core.untrackedCache true &&
	test_must_fail git config --get core.fsmonitor &&
    git status | sed "s/[0-9]\.[0-9][0-9]/X/g" >../actual &&
    test_cmp "$DATA/with_untrackedcache_no_fsmonitor" ../actual &&
    rm -fr ../actual
'

test_expect_success 'when core.untrackedCache true, and fsmonitor' '
    git config core.untrackedCache true &&
	git config core.fsmonitor true &&
    git status | sed "s/[0-9]\.[0-9][0-9]/X/g" >../actual &&
    test_cmp "$DATA/with_untrackedcache_with_fsmonitor" ../actual &&
    rm -fr ../actual
'

test_done
