#!/bin/sh

test_description='verify discovery.bare checks'

. ./test-lib.sh

pwd="$(pwd)"

expect_rejected () {
	test_must_fail git rev-parse --git-dir 2>err &&
	grep "discovery.bare" err
}

test_expect_success 'setup bare repo in worktree' '
	git init outer-repo &&
	git init --bare outer-repo/bare-repo
'

test_expect_success 'discovery.bare unset' '
	(
		cd outer-repo/bare-repo &&
		git rev-parse --git-dir
	)
'

test_expect_success 'discovery.bare=always' '
	git config --global discovery.bare always &&
	(
		cd outer-repo/bare-repo &&
		git rev-parse --git-dir
	)
'

test_expect_success 'discovery.bare=never' '
	git config --global discovery.bare never &&
	(
		cd outer-repo/bare-repo &&
		expect_rejected
	)
'

test_expect_success 'discovery.bare in the repository' '
	(
		cd outer-repo/bare-repo &&
		# Temporarily set discovery.bare=always, otherwise git
		# config fails with "fatal: not in a git directory"
		# (like safe.directory)
		git config --global discovery.bare always &&
		git config discovery.bare always &&
		git config --global discovery.bare never &&
		expect_rejected
	)
'

test_expect_success 'discovery.bare on the command line' '
	git config --global discovery.bare never &&
	(
		cd outer-repo/bare-repo &&
		git -c discovery.bare=always rev-parse --git-dir
	)
'

test_done
