#!/bin/sh

test_description='diff sparse-checkout scope'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh


test_expect_success 'setup' '
	git init temp &&
	(
		cd temp &&
		mkdir sub1 &&
		mkdir sub2 &&
		echo sub1/file1 >sub1/file1 &&
		echo sub2/file2 >sub2/file2 &&
		echo file1 >file1 &&
		echo file2 >file2 &&
		git add --all &&
		git commit -m init &&
		echo sub1/file1 >>sub1/file1 &&
		echo sub1/file2 >>sub1/file2 &&
		echo sub2/file1 >>sub2/file1 &&
		echo sub2/file2 >>sub2/file2 &&
		echo file1 >>file1 &&
		echo file2 >>file2 &&
		git add --all &&
		git commit -m change1 &&
		echo sub1/file1 >>sub1/file1 &&
		echo sub1/file2 >>sub1/file2 &&
		echo sub2/file1 >>sub2/file1 &&
		echo sub2/file2 >>sub2/file2 &&
		echo file1 >>file1 &&
		echo file2 >>file2 &&
		git add --all &&
		git commit -m change2
	)
'

reset_repo () {
	rm -rf repo &&
	git clone --no-checkout temp repo
}

reset_with_sparse_checkout() {
	reset_repo &&
	git -C repo sparse-checkout set $1 sub1 &&
	git -C repo checkout
}

change_worktree_and_index() {
	(
		cd repo &&
		mkdir sub2 sub3 &&
		echo sub1/file3 >sub1/file3 &&
		echo sub2/file3 >sub2/file3 &&
		echo sub3/file3 >sub3/file3 &&
		echo file3 >file3 &&
		git add --all --sparse &&
		echo sub1/file3 >>sub1/file3 &&
		echo sub2/file3 >>sub2/file3 &&
		echo sub3/file3 >>sub3/file3 &&
		echo file3 >>file3
	)
}

diff_scope() {
	title=$1
	need_change_worktree_and_index=$2
	sparse_checkout_option=$3
	scope_option=$4
	expect=$5
	shift 5
	args=("$@")

	test_expect_success "$title $sparse_checkout_option $scope_option" "
		reset_with_sparse_checkout $sparse_checkout_option &&
		if test \"$need_change_worktree_and_index\" = \"true\" ; then
			change_worktree_and_index
		fi &&
		git -C repo diff $scope_option ${args[*]} >actual &&
		if test -z \"$expect\" ; then
			>expect
		else
			cat > expect <<-EOF
$expect
			EOF
		fi &&
		test_cmp expect actual
	"
}

args=("--name-only" "HEAD" "HEAD~")
diff_scope builtin_diff_tree false "--no-cone" "--scope=sparse" \
"sub1/file1
sub1/file2" "${args[@]}"

diff_scope builtin_diff_tree false "--no-cone" "--scope=all" \
"file1
file2
sub1/file1
sub1/file2
sub2/file1
sub2/file2" "${args[@]}"

diff_scope builtin_diff_tree false "--no-cone" "--no-scope" \
"file1
file2
sub1/file1
sub1/file2
sub2/file1
sub2/file2" "${args[@]}"

diff_scope builtin_diff_tree false "--cone" "--scope=sparse" \
"file1
file2
sub1/file1
sub1/file2" "${args[@]}"

diff_scope builtin_diff_tree false "--cone" "--scope=all" \
"file1
file2
sub1/file1
sub1/file2
sub2/file1
sub2/file2" "${args[@]}"

diff_scope builtin_diff_tree false "--cone" "--no-scope" \
"file1
file2
sub1/file1
sub1/file2
sub2/file1
sub2/file2" "${args[@]}"

args=("--name-only" "HEAD~")
diff_scope builtin_diff_index true "--no-cone" "--scope=sparse" \
"sub1/file1
sub1/file2
sub1/file3" "${args[@]}"

diff_scope builtin_diff_index true "--no-cone" "--scope=all" \
"file1
file2
file3
sub1/file1
sub1/file2
sub1/file3
sub2/file1
sub2/file2
sub2/file3
sub3/file3" "${args[@]}"

diff_scope builtin_diff_index true "--no-cone" "--no-scope" \
"file1
file2
file3
sub1/file1
sub1/file2
sub1/file3
sub2/file1
sub2/file2
sub2/file3
sub3/file3" "${args[@]}"

diff_scope builtin_diff_index true "--cone" "--scope=sparse" \
"file1
file2
file3
sub1/file1
sub1/file2
sub1/file3" "${args[@]}"

diff_scope builtin_diff_index true "--cone" "--scope=all" \
"file1
file2
file3
sub1/file1
sub1/file2
sub1/file3
sub2/file1
sub2/file2
sub2/file3
sub3/file3" "${args[@]}"

diff_scope builtin_diff_index true "--cone" "--no-scope" \
"file1
file2
file3
sub1/file1
sub1/file2
sub1/file3
sub2/file1
sub2/file2
sub2/file3
sub3/file3" "${args[@]}"

args=("--name-only" "file3" "sub1/" "sub2/")

diff_scope builtin_diff_files true "--no-cone" "--scope=sparse" \
"sub1/file3" "${args[@]}"

diff_scope builtin_diff_files true "--no-cone" "--scope=all" \
"file3
sub1/file3
sub2/file1
sub2/file2
sub2/file3" "${args[@]}"

diff_scope builtin_diff_files true "--no-cone" "--no-scope" \
"file3
sub1/file3
sub2/file3" "${args[@]}"

diff_scope builtin_diff_files true "--cone" "--scope=sparse" \
"file3
sub1/file3" "${args[@]}"

diff_scope builtin_diff_files true "--cone" "--scope=all" \
"file3
sub1/file3
sub2/file1
sub2/file2
sub2/file3" "${args[@]}"

diff_scope builtin_diff_files true "--cone" "--no-scope" \
"file3
sub1/file3
sub2/file3" "${args[@]}"


args=("--name-only" "HEAD~:sub2/file2" "sub1/file2")

diff_scope builtin_diff_b_f true "--no-cone" "--scope=sparse" \
"" "${args[@]}"

diff_scope builtin_diff_b_f true "--no-cone" "--scope=all" \
"sub1/file2" "${args[@]}"

diff_scope builtin_diff_b_f true "--no-cone" "--no-scope" \
"sub1/file2" "${args[@]}"

args=("--name-only" "HEAD~:sub1/file1" "file3")

diff_scope builtin_diff_b_f true "--cone" "--scope=sparse" \
"file3" "${args[@]}"

diff_scope builtin_diff_b_f true "--cone" "--scope=all" \
"file3" "${args[@]}"

diff_scope builtin_diff_b_f true "--cone" "--no-scope" \
"file3" "${args[@]}"

args=("--name-only" HEAD~:sub2/file2 HEAD:sub1/file2)

diff_scope builtin_diff_blobs true "--no-cone" "--scope=sparse" \
"" "${args[@]}"

diff_scope builtin_diff_blobs true "--no-cone" "--scope=all" \
"sub1/file2" "${args[@]}"

diff_scope builtin_diff_blobs true "--no-cone" "--no-scope" \
"sub1/file2" "${args[@]}"

args=("--name-only" HEAD~:sub1/file1 HEAD:file2)

diff_scope builtin_diff_blobs false "--cone" "--scope=sparse" \
"file2" "${args[@]}"

diff_scope builtin_diff_blobs false "--cone" "--scope=all" \
"file2" "${args[@]}"

diff_scope builtin_diff_blobs false "--cone" "--no-scope" \
"file2" "${args[@]}"

args=("--name-only" HEAD~2 HEAD~ HEAD)

diff_scope builtin_diff_combined false "--no-cone" "--scope=sparse" \
"sub1/file1
sub1/file2" "${args[@]}"

diff_scope builtin_diff_combined false "--no-cone" "--scope=all" \
"file1
file2
sub1/file1
sub1/file2
sub2/file1
sub2/file2" "${args[@]}"

diff_scope builtin_diff_combined false "--no-cone" "--no-scope" \
"file1
file2
sub1/file1
sub1/file2
sub2/file1
sub2/file2" "${args[@]}"

diff_scope builtin_diff_combined false "--cone" "--scope=sparse" \
"file1
file2
sub1/file1
sub1/file2" "${args[@]}"

diff_scope builtin_diff_combined false "--cone" "--scope=all" \
"file1
file2
sub1/file1
sub1/file2
sub2/file1
sub2/file2" "${args[@]}"

diff_scope builtin_diff_combined false "--cone" "--no-scope" \
"file1
file2
sub1/file1
sub1/file2
sub2/file1
sub2/file2" "${args[@]}"

test_expect_success 'diff_no_index --no-cone, --scope=sparse' '
	reset_with_sparse_checkout --no-cone &&
	(
		cd repo &&
		mkdir sub3 &&
		echo sub3/file3 >sub3/file3
	) &&
	test_expect_code 1 git -C repo diff --no-index --name-only --scope=sparse sub1/file1 sub1/file2 >actual &&
	cat > expect <<-EOF &&
sub1/file2
	EOF
	test_expect_code 1 git -C repo diff --no-index --name-only --scope=sparse sub1/file1 sub3/file3 >actual &&
	>expect &&
	test_cmp expect actual
'

test_expect_success 'diff_no_index --no-cone, --scope=all' '
	reset_with_sparse_checkout --no-cone &&
	(
		cd repo &&
		mkdir sub3 &&
		echo sub3/file3 >sub3/file3
	) &&
	test_expect_code 1 git -C repo diff --no-index --name-only --scope=all sub1/file1 sub1/file2 >actual &&
	cat > expect <<-EOF &&
sub1/file2
	EOF
	test_expect_code 1 git -C repo diff --no-index --name-only --scope=all sub1/file1 sub3/file3 >actual &&
	cat > expect <<-EOF &&
sub3/file3
	EOF
	test_cmp expect actual
'

test_expect_success 'diff_no_index --no-cone, --no-scope' '
	reset_with_sparse_checkout --no-cone &&
	(
		cd repo &&
		mkdir sub3 &&
		echo sub3/file3 >sub3/file3
	) &&
	test_expect_code 1 git -C repo diff --no-index --name-only --no-scope sub1/file1 sub1/file2 >actual &&
	cat > expect <<-EOF &&
sub1/file2
	EOF
	test_expect_code 1 git -C repo diff --no-index --name-only --no-scope sub1/file1 sub3/file3 >actual &&
	cat > expect <<-EOF &&
sub3/file3
	EOF
	test_cmp expect actual
'

test_expect_success 'diff_no_index --cone, --scope=sparse' '
	reset_with_sparse_checkout --cone &&
	(
		cd repo &&
		echo file3 >file3 &&
		mkdir sub3 &&
		echo sub3/file3 >sub3/file3
	) &&
	test_expect_code 1 git -C repo diff --no-index --name-only --scope=sparse sub1/file1 file3 >actual &&
	cat > expect <<-EOF &&
file3
	EOF
	test_expect_code 1 git -C repo diff --no-index --name-only --scope=sparse sub1/file1 sub3/file3 >actual &&
	>expect &&
	test_cmp expect actual
'

test_expect_success 'diff_no_index --cone, --scope=all' '
	reset_with_sparse_checkout --cone &&
	(
		cd repo &&
		echo file3 >file3 &&
		mkdir sub3 &&
		echo sub3/file3 >sub3/file3
	) &&
	test_expect_code 1 git -C repo diff --no-index --name-only --scope=all sub1/file1 file3 >actual &&
	cat > expect <<-EOF &&
file3
	EOF
	test_expect_code 1 git -C repo diff --no-index --name-only --scope=all sub1/file1 sub3/file3 >actual &&
	cat > expect <<-EOF &&
sub3/file3
	EOF
	test_cmp expect actual
'

test_expect_success 'diff_no_index --cone, --no-scope' '
	reset_with_sparse_checkout --cone &&
	(
		cd repo &&
		echo file3 >file3 &&
		mkdir sub3 &&
		echo sub3/file3 >sub3/file3
	) &&
	test_expect_code 1 git -C repo diff --no-index --name-only --no-scope sub1/file1 file3 >actual &&
	cat > expect <<-EOF &&
file3
	EOF
	test_expect_code 1 git -C repo diff --no-index --name-only --no-scope sub1/file1 sub3/file3 >actual &&
	cat > expect <<-EOF &&
sub3/file3
	EOF
	test_cmp expect actual
'

test_expect_success 'diff scope config sparse' '
	reset_with_sparse_checkout --cone &&
	git -C repo -c diff.scope=sparse diff --name-only HEAD~ >actual &&
	cat > expect <<-EOF &&
file1
file2
sub1/file1
sub1/file2
	EOF
	test_cmp expect actual
'

test_expect_success 'diff scope config all' '
	reset_with_sparse_checkout --cone &&
	git -C repo -c diff.scope=all diff --name-only HEAD~ >actual &&
	cat > expect <<-EOF &&
file1
file2
sub1/file1
sub1/file2
sub2/file1
sub2/file2
	EOF
	test_cmp expect actual
'

test_expect_success 'diff scope config override by option' '
	reset_with_sparse_checkout --cone &&
	git -C repo -c diff.scope=sparse diff --name-only --scope=all HEAD~ >actual &&
	cat > expect <<-EOF &&
file1
file2
sub1/file1
sub1/file2
sub2/file1
sub2/file2
	EOF
	test_cmp expect actual
'

test_done
