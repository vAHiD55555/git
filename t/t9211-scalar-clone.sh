#!/bin/sh

test_description='test the `scalar clone` subcommand'

. ./test-lib.sh

GIT_TEST_MAINT_SCHEDULER="crontab:test-tool crontab cron.txt,launchctl:true,schtasks:true"
export GIT_TEST_MAINT_SCHEDULER

test_expect_success 'set up repository to clone' '
	rm -rf .git &&
	git init to-clone &&
	(
		cd to-clone &&
		git branch -m base &&

		test_commit first &&
		test_commit second &&
		test_commit third &&

		git switch -c parallel first &&
		mkdir -p 1/2 &&
		test_commit 1/2/3 &&

		git switch base &&

		# By default, permit
		git config uploadpack.allowfilter true &&
		git config uploadpack.allowanysha1inwant true
	)
'

cleanup_clone () {
	rm -rf "$1"
}

test_expect_success 'creates content in enlistment root' '
	test_when_finished cleanup_clone cloned &&

	scalar clone "file://$(pwd)/to-clone" cloned &&
	ls -A cloned >enlistment-root &&
	test_line_count = 1 enlistment-root &&
	test_path_is_dir cloned/src &&
	test_path_is_dir cloned/src/.git
'

test_expect_success 'with spaces' '
	test_when_finished cleanup_clone "cloned with space" &&

	scalar clone "file://$(pwd)/to-clone" "cloned with space" &&
	test_path_is_dir "cloned with space" &&
	test_path_is_dir "cloned with space/src" &&
	test_path_is_dir "cloned with space/src/.git"
'

test_expect_success 'partial clone if supported by server' '
	test_when_finished cleanup_clone cloned &&

	scalar clone "file://$(pwd)/to-clone" cloned &&

	(
		cd cloned/src &&

		# Two promisor packs: one for refs, the other for blobs
		ls .git/objects/pack/pack-*.promisor >promisorlist &&
		test_line_count = 2 promisorlist
	)
'

test_expect_success 'fall back on full clone if partial unsupported' '
	test_when_finished cleanup_clone cloned &&

	test_config -C to-clone uploadpack.allowfilter false &&
	test_config -C to-clone uploadpack.allowanysha1inwant false &&

	scalar clone "file://$(pwd)/to-clone" cloned 2>err &&
	grep "filtering not recognized by server, ignoring" err &&

	(
		cd cloned/src &&

		# Still get a refs promisor file, but none for blobs
		ls .git/objects/pack/pack-*.promisor >promisorlist &&
		test_line_count = 1 promisorlist
	)
'

test_expect_success 'initializes sparse-checkout by default' '
	test_when_finished cleanup_clone cloned &&

	scalar clone "file://$(pwd)/to-clone" cloned &&
	(
		cd cloned/src &&
		test_cmp_config true core.sparseCheckout &&
		test_cmp_config true core.sparseCheckoutCone
	)
'

test_expect_success '--full-clone does not create sparse-checkout' '
	test_when_finished cleanup_clone cloned &&

	scalar clone --full-clone "file://$(pwd)/to-clone" cloned &&
	(
		cd cloned/src &&
		test_cmp_config "" --default "" core.sparseCheckout &&
		test_cmp_config "" --default "" core.sparseCheckoutCone
	)
'

test_expect_success '--single-branch clones HEAD only' '
	test_when_finished cleanup_clone cloned &&

	scalar clone --single-branch "file://$(pwd)/to-clone" cloned &&
	(
		cd cloned/src &&
		git for-each-ref refs/remotes/origin >out &&
		test_line_count = 1 out &&
		grep "refs/remotes/origin/base" out
	)
'

test_expect_success '--no-single-branch clones all branches' '
	test_when_finished cleanup_clone cloned &&

	scalar clone --no-single-branch "file://$(pwd)/to-clone" cloned &&
	(
		cd cloned/src &&
		git for-each-ref refs/remotes/origin >out &&
		test_line_count = 2 out &&
		grep "refs/remotes/origin/base" out &&
		grep "refs/remotes/origin/parallel" out
	)
'

test_done
