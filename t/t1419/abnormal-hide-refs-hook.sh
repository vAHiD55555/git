#!/bin/sh

# Upstream repository (bare_repo.git) contains the configurations:
#
#	[transfer]
#		hiderefs = hook:HEAD
#		hiderefs = hook:refs
#
# During refs advertise phase the hide-refs hook will be invoked and each ref will be checked by it,
# we should make sure Git works correctly in some speicail cases

# If hide-refs not exists, Git should not invoke it and continue advertise all the refs
test_expect_success "protocol $GIT_TEST_PROTOCOL_VERSION: advertise-refs while hide-refs hook not exists" '
	rm -f "$BAREREPO_GIT_DIR/hooks/hide-refs" &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION upload-pack --advertise-refs "$BAREREPO_GIT_DIR" >out 2>&1 &&
	cat out | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-A> HEAD
		<COMMIT-B> refs/heads/dev
		<COMMIT-A> refs/heads/main
		<COMMIT-C> refs/pull-requests/1/head
		<COMMIT-TAG-v123> refs/tags/v123
		<COMMIT-D> refs/tags/v123^{}
	EOF
	test_cmp expect actual
'

# If hide-refs hook run with incompatible version, Git should not invoke it and continue to advertise all the refs
test_expect_success "protocol $GIT_TEST_PROTOCOL_VERSION: advertise-refs while hide-refs hook run with incompatible version" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF &&
		test-tool hide-refs --version=2
	EOF
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION upload-pack --advertise-refs "$BAREREPO_GIT_DIR" >out 2>&1 &&
	cat out | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-A> HEAD
		<COMMIT-B> refs/heads/dev
		<COMMIT-A> refs/heads/main
		<COMMIT-C> refs/pull-requests/1/head
		<COMMIT-TAG-v123> refs/tags/v123
		<COMMIT-D> refs/tags/v123^{}
	EOF
	test_cmp expect actual
'

# If hide-refs hook exit before processing any refs, Git should not die and continue to advertise all the refs
test_expect_success "protocol $GIT_TEST_PROTOCOL_VERSION: advertise-refs while hide-refs hook die before read ref" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF &&
		test-tool hide-refs --die-before-read-ref
	EOF
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION upload-pack --advertise-refs "$BAREREPO_GIT_DIR" >out 2>&1 &&
	cat out | make_user_friendly_and_stable_output | grep -v "^error:" >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-before-read-ref option
		<COMMIT-A> HEAD
		<COMMIT-B> refs/heads/dev
		<COMMIT-A> refs/heads/main
		<COMMIT-C> refs/pull-requests/1/head
		<COMMIT-TAG-v123> refs/tags/v123
		<COMMIT-D> refs/tags/v123^{}
	EOF
	test_cmp expect actual
'

# If hide-refs hook exit abnormally, Git should not die and continue to advertise left refs
test_expect_success "protocol $GIT_TEST_PROTOCOL_VERSION: advertise-refs while hide-refs hook die after proc ref" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF &&
		test-tool hide-refs --die-after-proc-refs
	EOF
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION upload-pack --advertise-refs "$BAREREPO_GIT_DIR" >out 2>&1 &&
	cat out | make_user_friendly_and_stable_output | grep -v "^error:" >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-after-proc-refs option
		<COMMIT-A> HEAD
		<COMMIT-B> refs/heads/dev
		<COMMIT-A> refs/heads/main
		<COMMIT-C> refs/pull-requests/1/head
		<COMMIT-TAG-v123> refs/tags/v123
		<COMMIT-D> refs/tags/v123^{}
	EOF
	test_cmp expect actual
'
