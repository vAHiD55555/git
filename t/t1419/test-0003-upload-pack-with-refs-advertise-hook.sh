test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup refs-advertise hook which handle no command" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
		test-tool refs-advertise
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): mirror clone while refs-advertise hook handle no command" '
	rm -rf local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION clone --mirror "$BAREREPO_URL" local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C local.git show-ref -d >out 2>&1 &&
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup refs-advertise hook which advertise all refs" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
	test-tool refs-advertise \
		--can-upload-pack \
		--can-ls-refs \
		-r "ref refs/heads/dev $A" \
		-r "obj $A" \
		-r "ref refs/heads/main $B" \
		-r "obj $B" \
		-r "ref refs/pull-requests/1/head $C" \
		-r "obj $C" \
		-r "ref refs/tags/v123 $TAG" \
		-r "obj $TAG" \
		-r "obj $D"
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): mirror clone all refs" '
	rm -rf local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION clone --mirror "$BAREREPO_URL" local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C local.git show-ref -d >out 2>&1 &&
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup refs-advertise hook which advertise branches" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
	test-tool refs-advertise \
		--can-upload-pack \
		--can-ls-refs \
		-r "ref refs/heads/dev $A" \
		-r "obj $A" \
		-r "ref refs/heads/main $B" \
		-r "obj $B"
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): mirror clone branches" '
	rm -rf local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION clone --mirror "$BAREREPO_URL" local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C local.git show-ref -d >out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-A> refs/heads/dev
		<COMMIT-B> refs/heads/main
	EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup refs-advertise hook which advertise branches" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
	test-tool refs-advertise \
		--can-upload-pack \
		--can-ls-refs \
		-r "ref refs/heads/dev $A" \
		-r "obj $A" \
		-r "ref refs/heads/main $B" \
		-r "obj $B"
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): fetch a not advertised commit" '
	rm -rf local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION init local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C local.git remote add origin "$BAREREPO_URL" &&
	test_must_fail git -C local.git fetch "$BAREREPO_URL" $D
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup refs-advertise hook which advertise pull refs and tags" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
	test-tool refs-advertise \
		--can-upload-pack \
		--can-ls-refs \
		-r "ref refs/pull-requests/1/head $C" \
		-r "obj $C" \
		-r "ref refs/tags/v123 $TAG" \
		-r "obj $TAG" \
		-r "obj $D"
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): mirror clone pull refs and tags" '
	rm -rf local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION clone --mirror "$BAREREPO_URL" local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C local.git show-ref -d >out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-C> refs/pull-requests/1/head
		<COMMIT-TAG-v123> refs/tags/v123
		<COMMIT-D> refs/tags/v123^{}
	EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): clone a not advertised branch" '
	rm -rf local.git &&
	test_must_fail git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION clone "$BAREREPO_URL" local.git -b main &&
	test ! -d local.git
'
