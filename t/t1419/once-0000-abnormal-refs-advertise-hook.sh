test_expect_success "builtin protocol (protocol: 1): setup refs-advertise hook which die when read version" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
		test-tool refs-advertise \
			--can-upload-pack \
			--can-receive-pack \
			--can-ls-refs \
			--die-read-version
	EOF
'

test_expect_success "builtin protocol (protocol: 1): upload-pack --advertise-refs while refs-advertise hook die when read version" '
	test_must_fail git -c protocol.version=1 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-read-version option
		fatal: can not read version message from hook refs-advertise
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 1): setup refs-advertise hook which die when write version" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
		test-tool refs-advertise \
			--can-upload-pack \
			--can-receive-pack \
			--can-ls-refs \
			--die-write-version
	EOF
'

test_expect_success "builtin protocol (protocol: 1): upload-pack --advertise-refs while refs-advertise hook die when write version" '
	test_must_fail git -c protocol.version=1 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-write-version option
		fatal: can not read version message from hook refs-advertise
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 1): setup refs-advertise hook which die when read first filter request" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
		test-tool refs-advertise \
			--can-upload-pack \
			--can-receive-pack \
			--can-ls-refs \
			--die-read-first-ref
	EOF
'

test_expect_success "builtin protocol (protocol: 1): upload-pack --advertise-refs while refs-advertise hook die when read first filter request" '
	test_must_fail git -c protocol.version=1 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-read-first-ref option
		fatal: hook refs-advertise died abnormally
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 1): setup refs-advertise hook which die when read second filter request" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
		test-tool refs-advertise \
			--can-upload-pack \
			--can-receive-pack \
			--can-ls-refs \
			--die-read-second-ref
	EOF
'

test_expect_success "builtin protocol (protocol: 1): upload-pack --advertise-refs while refs-advertise hook die when read second filter request" '
	test_must_fail git -c protocol.version=1 upload-pack --advertise-refs "$BAREREPO_URL"  >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-read-second-ref option
		fatal: hook refs-advertise died abnormally
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 1): setup refs-advertise hook which die while filtring refs" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
		test-tool refs-advertise \
			--can-upload-pack \
			--can-receive-pack \
			--can-ls-refs \
			--die-filter-refs
	EOF
'

test_expect_success "builtin protocol (protocol: 1): upload-pack --advertise-refs while refs-advertise hook die while filtring refs" '
	test_must_fail git -c protocol.version=1 upload-pack --advertise-refs "$BAREREPO_URL"  >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-filter-refs option
		fatal: hook refs-advertise died abnormally
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 2): setup refs-advertise hook which die when read version" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
		test-tool refs-advertise \
			--can-upload-pack \
			--can-receive-pack \
			--can-ls-refs \
			--die-read-version
	EOF
'

test_expect_success "builtin protocol (protocol: 2): upload-pack --advertise-refs while refs-advertise hook die when read version" '
	test_must_fail git -c protocol.version=2 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-read-version option
		fatal: can not read version message from hook refs-advertise
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 2): setup refs-advertise hook which die when write version" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
		test-tool refs-advertise \
			--can-upload-pack \
			--can-receive-pack \
			--can-ls-refs \
			--die-write-version
	EOF
'

test_expect_success "builtin protocol (protocol: 2): upload-pack --advertise-refs while refs-advertise hook die when write version" '
	test_must_fail git -c protocol.version=2 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-write-version option
		fatal: can not read version message from hook refs-advertise
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 2): setup refs-advertise hook which die when read first filter request" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
		test-tool refs-advertise \
			--can-upload-pack \
			--can-receive-pack \
			--can-ls-refs \
			--die-read-first-ref
	EOF
'

test_expect_success "builtin protocol (protocol: 2): upload-pack --advertise-refs while refs-advertise hook die when read first filter request" '
	test_must_fail git -c protocol.version=2 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-read-first-ref option
		fatal: hook refs-advertise died abnormally
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 2): setup refs-advertise hook which die when read second filter request" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
		test-tool refs-advertise \
			--can-upload-pack \
			--can-receive-pack \
			--can-ls-refs \
			--die-read-second-ref
	EOF
'

test_expect_success "builtin protocol (protocol: 2): upload-pack --advertise-refs while refs-advertise hook die when read second filter request" '
	test_must_fail git -c protocol.version=2 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-read-second-ref option
		fatal: hook refs-advertise died abnormally
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 2): setup refs-advertise hook which die while filtring refs" '
	write_script "$BAREREPO_GIT_DIR/hooks/refs-advertise" <<-EOF
		test-tool refs-advertise \
			--can-upload-pack \
			--can-receive-pack \
			--can-ls-refs \
			--die-filter-refs
	EOF
'

test_expect_success "builtin protocol (protocol: 2): upload-pack --advertise-refs while refs-advertise hook die while filtring refs" '
	test_must_fail git -c protocol.version=2 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-filter-refs option
		fatal: hook refs-advertise died abnormally
	EOF
	test_cmp expect actual
'
