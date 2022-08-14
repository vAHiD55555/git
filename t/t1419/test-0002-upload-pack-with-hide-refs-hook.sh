test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup hide-refs hook which hide no refs" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
		test-tool hide-refs
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): mirror clone while hide-refs hook hide no refs" '
	rm -rf local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION clone --mirror "$BAREREPO_URL" local.git &&
	git -C local.git show-ref -d >out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-A> refs/heads/dev
		<COMMIT-B> refs/heads/main
		<COMMIT-C> refs/pull-requests/1/head
		<COMMIT-TAG-v123> refs/tags/v123
		<COMMIT-D> refs/tags/v123^{}
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): mirror clone while hide-refs hide all refs" '
	rm -rf local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION clone --mirror "$BAREREPO_URL" local.git &&
	test_must_fail git -C local.git show-ref -d >out 2>&1 &&
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): mirror clone branches" '
	rm -rf local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION clone --mirror "$BAREREPO_URL" local.git &&
	git -C local.git show-ref -d >out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-C> refs/pull-requests/1/head
		<COMMIT-TAG-v123> refs/tags/v123
		<COMMIT-D> refs/tags/v123^{}
	EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup hide-refs hook which some branches" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
	test-tool hide-refs \
		-r "HEAD" \
		-r "refs/heads/dev"
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): fetch a tip commit which is not hidden" '
	rm -rf local.git &&
	git init local.git &&
	git -C local.git remote add origin "$BAREREPO_URL" &&
	git -C local.git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION fetch "$BAREREPO_URL" $B
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): config allowAnySHA1InWant to true" '
	git -C "$BAREREPO_GIT_DIR" config uploadpack.allowTipSHA1InWant true &&
	git -C "$BAREREPO_GIT_DIR" config uploadpack.allowReachableSHA1InWant true
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): fetch a non-tip commit which is not hidden" '
	rm -rf local.git &&
	git init local.git &&
	git -C local.git remote add origin "$BAREREPO_URL" &&
	git -C local.git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION fetch "$BAREREPO_URL" $A
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup hide-refs hook which hide pull refs and tags" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
	test-tool hide-refs \
		-r "refs/pull-requests/1/head" \
		-r "refs/tags/v123"
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): mirror clone while hide-refs hook hide pull refs and tags" '
	rm -rf local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION clone --mirror "$BAREREPO_URL" local.git &&
	git -C local.git show-ref -d >out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-A> refs/heads/dev
		<COMMIT-B> refs/heads/main
	EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): config allowAnySHA1InWant to true" '
	git -C "$BAREREPO_GIT_DIR" config uploadpack.allowTipSHA1InWant true &&
	git -C "$BAREREPO_GIT_DIR" config uploadpack.allowReachableSHA1InWant true
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): fetch a non-tip commit which is hidden" '
	rm -rf local.git &&
	git init local.git &&
	git -C local.git remote add origin "$BAREREPO_URL" &&
	test_must_fail git -C local.git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION fetch "$BAREREPO_URL" $C
'
