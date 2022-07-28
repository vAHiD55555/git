test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): mirror clone" '
	rm -rf local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION clone --mirror "$BAREREPO_URL" local.git &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C local.git show-ref -d >out 2>&1 &&
	refs_num=$(cat out | wc -l) &&
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): ls-remote" '
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION ls-remote "$BAREREPO_URL" >out 2>&1 &&
	refs_num=$(cat out | wc -l) &&
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): upload-pack" '
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION upload-pack --advertise-refs "$BAREREPO_GIT_DIR" >out 2>&1 &&
	filter_out_refs_advertise_output <out >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-B> HEAD
		<COMMIT-A> refs/heads/dev
		<COMMIT-B> refs/heads/main
		<COMMIT-C> refs/pull-requests/1/head
		<COMMIT-TAG-v123> refs/tags/v123
		<COMMIT-D> refs/tags/v123^{}
	EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): receive-pack" '
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION receive-pack --advertise-refs "$BAREREPO_GIT_DIR" >out 2>&1 &&
	filter_out_refs_advertise_output <out >actual &&
	format_and_save_expect <<-EOF &&
		<COMMIT-A> refs/heads/dev
		<COMMIT-B> refs/heads/main
		<COMMIT-C> refs/pull-requests/1/head
		<COMMIT-TAG-v123> refs/tags/v123
	EOF
	test_cmp expect actual
'
