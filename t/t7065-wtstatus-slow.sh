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
	cat >../expected <<-EOF &&
On branch test

No commits yet


It took X seconds to enumerate untracked files.
See '"'"'git help status'"'"' for information on how to improve this.

nothing to commit (create/copy files and use "git add" to track)
	EOF
	test_cmp ../expected ../actual &&
	rm -fr ../actual ../expected
'

test_expect_success 'when core.untrackedCache true, but not fsmonitor' '
	git config core.untrackedCache true &&
	test_must_fail git config --get core.fsmonitor &&
	git status | sed "s/[0-9]\.[0-9][0-9]/X/g" >../actual &&
	cat >../expected <<-EOF &&
On branch test

No commits yet


It took X seconds to enumerate untracked files.
See '"'"'git help status'"'"' for information on how to improve this.

nothing to commit (create/copy files and use "git add" to track)
	EOF
	test_cmp ../expected ../actual &&
	rm -fr ../actual ../expected
'

test_expect_success 'when core.untrackedCache true, and fsmonitor' '
	git config core.untrackedCache true &&
	git config core.fsmonitor true &&
	git status | sed "s/[0-9]\.[0-9][0-9]/X/g" >../actual &&
	cat >../expected <<-EOF &&
On branch test

No commits yet


It took X seconds to enumerate untracked files,
but this is currently being cached.
See '"'"'git help status'"'"' for information on how to improve this.

nothing to commit (create/copy files and use "git add" to track)
	EOF
	test_cmp ../expected ../actual &&
	rm -fr ../actual ../expected
'

test_done
