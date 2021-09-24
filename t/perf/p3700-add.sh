#!/bin/sh
#
# This test measures the performance of adding new files to the object database
# and index. The test was originally added to measure the effect of the
# core.fsyncMethod=batch mode, which is why we are testing different values
# of that setting explicitly and creating a lot of unique objects.

test_description="Tests performance of adding things to the object database"

# Fsync is normally turned off for the test suite.
GIT_TEST_FSYNC=1
export GIT_TEST_FSYNC

. ./perf-lib.sh

. $TEST_DIRECTORY/lib-unique-files.sh

test_perf_fresh_repo
test_checkout_worktree

dir_count=10
files_per_dir=50
total_files=$((dir_count * files_per_dir))

for mode in false true batch
do
	case $mode in
	false)
		FSYNC_CONFIG='-c core.fsync=-loose-object -c core.fsyncmethod=fsync'
		;;
	true)
		FSYNC_CONFIG='-c core.fsync=loose-object -c core.fsyncmethod=fsync'
		;;
	batch)
		FSYNC_CONFIG='-c core.fsync=loose-object -c core.fsyncmethod=batch'
		;;
	esac

	test_perf "add $total_files files (object_fsyncing=$mode)" \
		--setup "
		(rm -rf .git || 1) &&
		git init &&
		test_create_unique_files $dir_count $files_per_dir files_$mode
	" "
		git $FSYNC_CONFIG add files_$mode
	"

	test_perf "stash $total_files files (object_fsyncing=$mode)" \
		--setup "
		(rm -rf .git || 1) &&
		git init &&
		test_commit first &&
		test_create_unique_files $dir_count $files_per_dir stash_files_$mode
	" "
		git $FSYNC_CONFIG stash push -u -- stash_files_$mode
	"
done

test_done
