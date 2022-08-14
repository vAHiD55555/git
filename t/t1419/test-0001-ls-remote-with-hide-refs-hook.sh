test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup hide-refs hook which hide no refs" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
		test-tool hide-refs
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): ls-remote while hide-refs hook hide no refs" '
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION ls-remote "$BAREREPO_URL" >out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-B>	HEAD
		<COMMIT-A>	refs/heads/dev
		<COMMIT-B>	refs/heads/main
		<COMMIT-C>	refs/pull-requests/1/head
		<COMMIT-TAG-v123>	refs/tags/v123
		<COMMIT-D>	refs/tags/v123^{}
	EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup hide-refs hook which hide all refs" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
	test-tool hide-refs \
		-r "HEAD" \
		-r "refs/heads/dev" \
		-r "refs/heads/main" \
		-r "refs/pull-requests/1/head" \
		-r "refs/tags/v123"
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): ls-remote while hide-refs hook hide all refs" '
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION ls-remote "$BAREREPO_URL" >out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
	EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup hide-refs hook which hide branches" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
	test-tool hide-refs \
		-r "HEAD" \
		-r "refs/heads/dev" \
		-r "refs/heads/main"
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): ls-remote while hide-refs hook hide branches" '
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION ls-remote "$BAREREPO_URL" >out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-C>	refs/pull-requests/1/head
		<COMMIT-TAG-v123>	refs/tags/v123
		<COMMIT-D>	refs/tags/v123^{}
	EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup hide-refs hook which hide pull refs and tags" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
	test-tool hide-refs \
		-r "refs/pull-requests/1/head" \
		-r "refs/tags/v123"
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): ls-remote while hide-refs hook hide pull refs and tags" '
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION ls-remote "$BAREREPO_URL" >out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-B>	HEAD
		<COMMIT-A>	refs/heads/dev
		<COMMIT-B>	refs/heads/main
	EOF
	test_cmp expect actual
'
