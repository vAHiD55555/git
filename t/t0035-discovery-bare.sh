#!/bin/sh

test_description='verify discovery.bare checks'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

pwd="$(pwd)"

expect_accepted () {
	git "$@" rev-parse --git-dir
}

expect_rejected () {
	test_must_fail git "$@" rev-parse --git-dir 2>err &&
	grep -F "cannot use bare repository" err
}

test_expect_success 'setup bare repo in worktree' '
	git init outer-repo &&
	git init --bare outer-repo/bare-repo
'

test_expect_success 'discovery.bare unset' '
	expect_accepted -C outer-repo/bare-repo
'

test_expect_success 'discovery.bare=always' '
	test_config_global discovery.bare always &&
	expect_accepted -C outer-repo/bare-repo
'

test_expect_success 'discovery.bare=never' '
	test_config_global discovery.bare never &&
	expect_rejected -C outer-repo/bare-repo
'

test_expect_success 'discovery.bare in the repository' '
	# discovery.bare must not be "never", otherwise git config fails
	# with "fatal: not in a git directory" (like safe.directory)
	test_config -C outer-repo/bare-repo discovery.bare always &&
	test_config_global discovery.bare never &&
	expect_rejected -C outer-repo/bare-repo
'

test_expect_success 'discovery.bare on the command line' '
	test_config_global discovery.bare never &&
	expect_accepted -C outer-repo/bare-repo \
		-c discovery.bare=always
'

test_done
