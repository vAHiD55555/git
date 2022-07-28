test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): push to main" '
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

test_expect_success "$PROTOCOL (protocol: $GIT_TEST_PROTOCOL_VERSION): push to delete ref" '
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
