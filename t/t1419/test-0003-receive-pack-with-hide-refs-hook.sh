test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup hide-refs hook which hide no refs" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
		test-tool hide-refs
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): push to main while hide-refs hook hide no refs" '
	create_commits_in work_repo E &&
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C work_repo push origin HEAD:main >out 2>&1 &&
	make_user_friendly_and_stable_output <out >out.tmp &&
	sed "s/$(get_abbrev_oid $E)[0-9a-f]*/<COMMIT-E>/g" <out.tmp >actual &&
	format_and_save_expect <<-EOF &&
		remote: # pre-receive hook        Z
		remote: pre-receive< <COMMIT-B> <COMMIT-E> refs/heads/main        Z
		remote: # update hook        Z
		remote: update< refs/heads/main <COMMIT-B> <COMMIT-E>        Z
		remote: # post-receive hook        Z
		remote: post-receive< <COMMIT-B> <COMMIT-E> refs/heads/main        Z
		To <URL/of/bare_repo.git>
		   <COMMIT-B>..<COMMIT-E>  HEAD -> main
	EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): create ref while hide-refs hook hide no refs" '
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C work_repo push origin HEAD:new >out 2>&1 &&
	make_user_friendly_and_stable_output <out >out.tmp &&
	sed "s/$(get_abbrev_oid $E)[0-9a-f]*/<COMMIT-E>/g" <out.tmp >actual &&
	format_and_save_expect <<-EOF &&
		remote: # pre-receive hook        Z
		remote: pre-receive< <ZERO-OID> <COMMIT-E> refs/heads/new        Z
		remote: # update hook        Z
		remote: update< refs/heads/new <ZERO-OID> <COMMIT-E>        Z
		remote: # post-receive hook        Z
		remote: post-receive< <ZERO-OID> <COMMIT-E> refs/heads/new        Z
		To <URL/of/bare_repo.git>
		 * [new branch]      HEAD -> new
		EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): push to delete ref while hide-refs hook hide no refs" '
	git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C work_repo push origin :dev >out 2>&1 &&
	make_user_friendly_and_stable_output <out >out.tmp &&
	sed "s/$(get_abbrev_oid $E)[0-9a-f]*/<COMMIT-E>/g" <out.tmp >actual &&
	format_and_save_expect <<-EOF &&
		remote: # pre-receive hook        Z
		remote: pre-receive< <COMMIT-A> <ZERO-OID> refs/heads/dev        Z
		remote: # update hook        Z
		remote: update< refs/heads/dev <COMMIT-A> <ZERO-OID>        Z
		remote: # post-receive hook        Z
		remote: post-receive< <COMMIT-A> <ZERO-OID> refs/heads/dev        Z
		To <URL/of/bare_repo.git>
		 - [deleted]         dev
	EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup hide-refs hook which hide all refs" '
	rm -rf work_repo &&
	cp -rf work_repo.dump work_repo &&
	rm -rf "$BAREREPO_GIT_DIR" &&
	cp -rf bare_repo.git.dump "$BAREREPO_GIT_DIR" &&
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
	test-tool hide-refs \
		-r "HEAD" \
		-r "refs/heads/dev" \
		-r "refs/heads/main" \
		-r "refs/pull-requests/1/head" \
		-r "refs/tags/v123"
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): push to main while hide-refs hook hide all refs" '
	create_commits_in work_repo E &&
	test_must_fail git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C work_repo push origin HEAD:main >out 2>&1 &&
	make_user_friendly_and_stable_output <out >out.tmp &&
	sed "s/$(get_abbrev_oid $E)[0-9a-f]*/<COMMIT-E>/g" <out.tmp >actual &&
	format_and_save_expect <<-EOF &&
		remote: # pre-receive hook        Z
		remote: pre-receive< <ZERO-OID> <COMMIT-E> refs/heads/main        Z
		To <URL/of/bare_repo.git>
		 ! [remote rejected] HEAD -> main (deny updating a hidden ref)
		error: failed to push some refs to "<URL/of/bare_repo.git>"
	EOF
	test_cmp expect actual
'
