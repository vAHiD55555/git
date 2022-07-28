test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup refs-advertise hook which handle no command" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
		test-tool refs-advertise
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): push to main while refs-advertise hook handle no command" '
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): create ref while refs-advertise hook handle no command" '
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): push to delete ref while refs-advertise hook handle no command" '
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup refs-advertise hook which advertise nothing" '
	rm -rf work_repo &&
	cp -rf work_repo.dump work_repo &&
	rm -rf "$BAREREPO_GIT_DIR" &&
	cp -rf bare_repo.git.dump "$BAREREPO_GIT_DIR" &&
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
	test-tool refs-advertise \
		--can-receive-pack \
		--can-ls-refs
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): push to main while refs-advertise hook advertise nothing" '
	create_commits_in work_repo E &&
	test_must_fail git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C work_repo push origin HEAD:main >out 2>&1 &&
	make_user_friendly_and_stable_output <out >out.tmp &&
	sed "s/$(get_abbrev_oid $E)[0-9a-f]*/<COMMIT-E>/g" <out.tmp >actual &&
	format_and_save_expect <<-EOF &&
		remote: # pre-receive hook        Z
		remote: pre-receive< <ZERO-OID> <COMMIT-E> refs/heads/main        Z
		remote: # update hook        Z
		remote: update< refs/heads/main <ZERO-OID> <COMMIT-E>        Z
		remote: error: cannot lock ref "refs/heads/main": reference already exists        Z
		To <URL/of/bare_repo.git>
		 ! [remote rejected] HEAD -> main (failed to update ref)
		error: failed to push some refs to "<URL/of/bare_repo.git>"
	EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): create ref while while refs-advertise hook advertise nothing" '
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): push to delete ref while while refs-advertise hook advertise nothing" '
	test_must_fail git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C work_repo push origin :dev >out 2>&1 &&
	make_user_friendly_and_stable_output <out >out.tmp &&
	sed "s/$(get_abbrev_oid $E)[0-9a-f]*/<COMMIT-E>/g" <out.tmp >actual &&
	format_and_save_expect <<-EOF &&
		error: unable to delete "dev": remote ref does not exist
		error: failed to push some refs to "<URL/of/bare_repo.git>"
	EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup refs-advertise hook which advertise all refs" '
	rm -rf work_repo &&
	cp -rf work_repo.dump work_repo &&
	rm -rf "$BAREREPO_GIT_DIR" &&
	cp -rf bare_repo.git.dump "$BAREREPO_GIT_DIR" &&
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
	test-tool refs-advertise \
		--can-receive-pack \
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): push to main while refs-advertise hook advertise all refs" '
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): create ref while while refs-advertise hook advertise all refs" '
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): push to delete ref while while refs-advertise hook advertise all refs" '
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): setup refs-advertise hook which advertise pull refs and tags" '
	rm -rf work_repo &&
	cp -rf work_repo.dump work_repo &&
	rm -rf "$BAREREPO_GIT_DIR" &&
	cp -rf bare_repo.git.dump "$BAREREPO_GIT_DIR" &&
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
	test-tool refs-advertise \
		--can-receive-pack \
		--can-ls-refs \
		-r "ref refs/pull-requests/1/head $C" \
		-r "obj $C" \
		-r "ref refs/tags/v123 $TAG" \
		-r "obj $TAG" \
		-r "obj $D"
	EOF
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): push to main while refs-advertise hook advertise pull refs and tags" '
	create_commits_in work_repo E &&
	test_must_fail git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C work_repo push origin HEAD:main >out 2>&1 &&
	make_user_friendly_and_stable_output <out >out.tmp &&
	sed "s/$(get_abbrev_oid $E)[0-9a-f]*/<COMMIT-E>/g" <out.tmp >actual &&
	format_and_save_expect <<-EOF &&
		remote: # pre-receive hook        Z
		remote: pre-receive< <ZERO-OID> <COMMIT-E> refs/heads/main        Z
		remote: # update hook        Z
		remote: update< refs/heads/main <ZERO-OID> <COMMIT-E>        Z
		remote: error: cannot lock ref "refs/heads/main": reference already exists        Z
		To <URL/of/bare_repo.git>
		 ! [remote rejected] HEAD -> main (failed to update ref)
		error: failed to push some refs to "<URL/of/bare_repo.git>"
	EOF
	test_cmp expect actual
'

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): create ref while while refs-advertise hook advertise pull refs and tags" '
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): push to delete ref while while refs-advertise hook advertise pull refs and tags" '
	test_must_fail git -c protocol.version=$GIT_TEST_PROTOCOL_VERSION -C work_repo push origin :dev >out 2>&1 &&
	make_user_friendly_and_stable_output <out >out.tmp &&
	sed "s/$(get_abbrev_oid $E)[0-9a-f]*/<COMMIT-E>/g" <out.tmp >actual &&
	format_and_save_expect <<-EOF &&
		error: unable to delete "dev": remote ref does not exist
		error: failed to push some refs to "<URL/of/bare_repo.git>"
	EOF
	test_cmp expect actual
'
