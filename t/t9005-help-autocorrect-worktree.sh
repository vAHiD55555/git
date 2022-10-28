#!/bin/sh

test_description='test autocorrect in work tree based on bare repository'
. ./test-lib.sh

test_expect_success 'setup non-bare' '
	echo one >file &&
	git add file &&
	git commit -m one &&
	echo two >file &&
	git commit -a -m two
'

test_expect_success 'setup bare' '
	git clone --bare . bare.git &&
	cd bare.git
'

test_expect_success 'setup worktree from bare' '
	git worktree add ../bare-wt &&
	cd ../bare-wt
'

test_expect_success 'autocorrect works in work tree created from bare repo' '
	git config help.autocorrect immediate &&
	git stauts
'

test_done
