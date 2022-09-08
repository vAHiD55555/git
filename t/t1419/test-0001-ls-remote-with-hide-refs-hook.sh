#!/bin/sh

# Upstream repository (bare_repo.git) contains the configurations:
#
#	[transfer]
#		hiderefs = hook:HEAD
#		hiderefs = hook:refs
#
# During refs advertise phase the hide-refs hook will be invoked and each ref will be checked by it

# Git will not advertise the refs that are hided by hide-refs hook
test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): ls-remote while hide-refs hook hide part of refs" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF &&
	test-tool hide-refs \
		-H "refs/pull-requests/1/head" \
		-H "refs/tags/v123"
	EOF
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION ls-remote "$BAREREPO_URL" >out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-A>	HEAD
		<COMMIT-B>	refs/heads/dev
		<COMMIT-A>	refs/heads/main
	EOF
	test_cmp expect actual
'

# The hide-ref hook should not change the default effects of [transfer|uploadpack|receive].hiderefs configurations,
# if it hide no refs, the original hiderefs rules should works
test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): ls-remote while hide-refs hook hide no refs" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF &&
		test-tool hide-refs
	EOF
	git -C "$BAREREPO_GIT_DIR" config --add transfer.hiderefs refs/heads/dev &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION ls-remote "$BAREREPO_URL" >out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-A>	HEAD
		<COMMIT-A>	refs/heads/main
		<COMMIT-C>	refs/pull-requests/1/head
		<COMMIT-TAG-v123>	refs/tags/v123
		<COMMIT-D>	refs/tags/v123^{}
	EOF
	test_cmp expect actual
'
