#!/bin/sh

test_description='git archive --recurse-submodules test'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-submodule-update.sh

test_expect_success 'setup' '
	create_lib_submodule_repo &&
	git -C submodule_update_repo checkout valid_sub1 &&
	git -C submodule_update_repo submodule update
'

check_tar() {
	tarfile=$1.tar
	listfile=$1.lst
	dir=$1
	dir_with_prefix=$dir/$2

	test_expect_success ' extract tar archive' '
		(mkdir $dir && cd $dir && "$TAR" xf -) <$tarfile
	'
}

check_added() {
	dir=$1
	path_in_fs=$2
	path_in_archive=$3

	test_expect_success " validate extra file $path_in_archive" '
		test -f $dir/$path_in_archive &&
		diff -r $path_in_fs $dir/$path_in_archive
	'
}

check_not_added() {
	dir=$1
	path_in_archive=$2

	test_expect_success " validate unpresent file $path_in_archive" '
		! test -f $dir/$path_in_archive &&
		! test -d $dir/$path_in_archive
	'
}

test_expect_success 'archive without recurse, non-init' '
	reset_work_tree_to valid_sub1 &&
	git -C submodule_update archive HEAD >b.tar
'

check_tar b
check_added b submodule_update/file1 file1
check_not_added b sub1/file1

test_expect_success 'archive with recurse, non-init' '
	reset_work_tree_to valid_sub1 &&
	! git -C submodule_update archive --recurse-submodules HEAD >b2-err.tar
'

test_expect_success 'archive with recurse, init' '
	reset_work_tree_to valid_sub1 &&
	git -C submodule_update submodule update --init &&
	git -C submodule_update ls-files --recurse-submodules &&
	git -C submodule_update ls-tree HEAD &&
	git -C submodule_update archive --recurse-submodules HEAD >b2.tar
'

check_tar b2
check_added b2 submodule_update/sub1/file1 sub1/file1

test_expect_success 'archive with recurse with big files' '
	reset_work_tree_to valid_sub1 &&
	test_config core.bigfilethreshold 1 &&
	git -C submodule_update submodule update --init &&
	git -C submodule_update ls-files --recurse-submodules &&
	git -C submodule_update ls-tree HEAD &&
	git -C submodule_update archive --recurse-submodules HEAD >b3.tar
'

check_tar b3
check_added b3 submodule_update/sub1/file1 sub1/file1


test_done
