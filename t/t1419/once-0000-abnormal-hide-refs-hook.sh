test_expect_success "builtin protocol (protocol: 1): setup hide-refs hook which die when read version" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
		test-tool hide-refs \
			--die-read-version \
			-r refs/heads/main
	EOF
'

test_expect_success "builtin protocol (protocol: 1): upload-pack --advertise-refs while hide-refs hook die when read version" '
	test_must_fail git -c protocol.version=1 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-read-version option
		fatal: can not read version message from hook hide-refs
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 1): setup hide-refs hook which die when write version" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
		test-tool hide-refs --die-write-version
	EOF
'

test_expect_success "builtin protocol (protocol: 1): upload-pack --advertise-refs while hide-refs hook die when write version" '
	test_must_fail git -c protocol.version=1 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-write-version option
		fatal: can not read version message from hook hide-refs
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 1): setup hide-refs hook which die when read first filter request" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
		test-tool hide-refs --die-read-first-ref
	EOF
'

test_expect_success "builtin protocol (protocol: 1): upload-pack --advertise-refs while hide-refs hook die when read first filter request" '
	test_must_fail git -c protocol.version=1 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-read-first-ref option
		fatal: hook hide-refs died abnormally
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 1): setup hide-refs hook which die when read second filter request" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
		test-tool hide-refs --die-read-second-ref
	EOF
'

test_expect_success "builtin protocol (protocol: 1): upload-pack --advertise-refs while hide-refs hook die when read second filter request" '
	test_must_fail git -c protocol.version=1 upload-pack --advertise-refs "$BAREREPO_URL"  >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-read-second-ref option
		fatal: hook hide-refs died abnormally
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 1): setup hide-refs hook which die while filtring refs" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
		test-tool hide-refs --die-after-proc-refs
	EOF
'

test_expect_success "builtin protocol (protocol: 1): upload-pack --advertise-refs while hide-refs hook die while filtring refs" '
	test_must_fail git -c protocol.version=1 upload-pack --advertise-refs "$BAREREPO_URL"  >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-after-proc-refs option
		fatal: hook hide-refs died abnormally
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 2): setup hide-refs hook which die when read version" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
		test-tool hide-refs --die-read-version
	EOF
'

test_expect_success "builtin protocol (protocol: 2): upload-pack --advertise-refs while hide-refs hook die when read version" '
	test_must_fail git -c protocol.version=2 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-read-version option
		fatal: can not read version message from hook hide-refs
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 2): setup hide-refs hook which die when write version" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
		test-tool hide-refs --die-write-version
	EOF
'

test_expect_success "builtin protocol (protocol: 2): upload-pack --advertise-refs while hide-refs hook die when write version" '
	test_must_fail git -c protocol.version=2 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-write-version option
		fatal: can not read version message from hook hide-refs
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 2): setup hide-refs hook which die when read first filter request" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
		test-tool hide-refs --die-read-first-ref
	EOF
'

test_expect_success "builtin protocol (protocol: 2): upload-pack --advertise-refs while hide-refs hook die when read first filter request" '
	test_must_fail git -c protocol.version=2 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-read-first-ref option
		fatal: hook hide-refs died abnormally
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 2): setup hide-refs hook which die when read second filter request" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
		test-tool hide-refs --die-read-second-ref
	EOF
'

test_expect_success "builtin protocol (protocol: 2): upload-pack --advertise-refs while hide-refs hook die when read second filter request" '
	test_must_fail git -c protocol.version=2 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-read-second-ref option
		fatal: hook hide-refs died abnormally
	EOF
	test_cmp expect actual
'

test_expect_success "builtin protocol (protocol: 2): setup hide-refs hook which die while filtring refs" '
	write_script "$BAREREPO_GIT_DIR/hooks/hide-refs" <<-EOF
		test-tool hide-refs --die-after-proc-refs
	EOF
'

test_expect_success "builtin protocol (protocol: 2): upload-pack --advertise-refs while hide-refs hook die while filtring refs" '
	test_must_fail git -c protocol.version=2 upload-pack --advertise-refs "$BAREREPO_URL" >out 2>&1 &&
	cat out | grep "fatal: " | make_user_friendly_and_stable_output >actual &&
	format_and_save_expect <<-EOF &&
		fatal: die with the --die-after-proc-refs option
		fatal: hook hide-refs died abnormally
	EOF
	test_cmp expect actual
'
