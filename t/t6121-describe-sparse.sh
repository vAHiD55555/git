#!/bin/sh

test_description='git describe in sparse checked out trees'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

check_describe () {
	indir= &&
	while test $# != 0
	do
		case "$1" in
		-C)
			indir="$2"
			shift
			;;
		*)
			break
			;;
		esac
		shift
	done &&
	indir=${indir:+"$indir"/} &&
	expect="$1"
	shift
	describe_opts="$@"
	test_expect_success "describe $describe_opts" '
		git ${indir:+ -C "$indir"} describe $describe_opts >actual &&
		echo "$expect" >expect &&
		test_cmp expect actual
	'
}

test_expect_success setup '
	test_commit initial file one &&
	test_commit --annotate A file A &&

	test_tick &&

	git sparse-checkout init --cone
'

check_describe A HEAD

test_expect_success 'describe --dirty with --work-tree' '
	(
		cd "$TEST_DIRECTORY" &&
		git --git-dir "$TRASH_DIRECTORY/.git" --work-tree "$TRASH_DIRECTORY" describe --dirty >"$TRASH_DIRECTORY/out"
	) &&
	grep "A" out
'

test_expect_success 'set-up dirty work tree' '
	echo >>file
'

test_expect_success 'describe --dirty with --work-tree (dirty)' '
	git describe --dirty >expected &&
	(
		cd "$TEST_DIRECTORY" &&
		git --git-dir "$TRASH_DIRECTORY/.git" --work-tree "$TRASH_DIRECTORY" describe --dirty >"$TRASH_DIRECTORY/out"
	) &&
	test_cmp expected out
'
test_done
