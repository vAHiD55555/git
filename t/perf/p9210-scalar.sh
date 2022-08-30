#!/bin/sh

test_description='test scalar performance'
. ./perf-lib.sh

test_perf_large_repo "$TRASH_DIRECTORY/to-clone"

test_expect_success 'enable server-side partial clone' '
	git -C to-clone config uploadpack.allowFilter true &&
	git -C to-clone config uploadpack.allowAnySHA1InWant true
'

test_perf 'scalar clone' '
	rm -rf scalar-clone &&
	scalar clone "file://$(pwd)/to-clone" scalar-clone
'

test_perf 'git clone' '
	rm -rf git-clone &&
	git clone "file://$(pwd)/to-clone" git-clone
'

test_compare_perf () {
	command="$@"
	test_perf "$command (scalar)" "
		(
			cd scalar-clone/src &&
			$command
		)
	"

	test_perf "$command (non-scalar)" "
		(
			cd git-clone &&
			$command
		)
	"
}

test_compare_perf git status
test_compare_perf test_commit --append --no-tag A

test_done
