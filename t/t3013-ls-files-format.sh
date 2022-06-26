#!/bin/sh

test_description='git ls-files --format test'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

for flag in -s -o -k -t --resolve-undo --deduplicate --eol
do
	test_expect_success "usage: --format is incompatible with $flag" '
		test_expect_code 129 git ls-files --format="%(objectname)" $flag
	'
done

test_expect_success 'setup' '
	echo o1 >o1 &&
	echo o2 >o2 &&
	git add o1 o2 &&
	git add --chmod +x o1 &&
	git commit -m base
'

test_expect_success 'git ls-files --format objectmode' '
	cat >expect <<-\EOF &&
	100755
	100644
	EOF
	git ls-files --format="%(objectmode)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format objectname' '
	oid1=$(git hash-object o1) &&
	oid2=$(git hash-object o2) &&
	cat >expect <<-EOF &&
	$oid1
	$oid2
	EOF
	git ls-files --format="%(objectname)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format eolinfo:index' '
	cat >expect <<-\EOF &&
	lf
	lf
	EOF
	git ls-files --format="%(eolinfo:index)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format eolinfo:worktree' '
	cat >expect <<-\EOF &&
	lf
	lf
	EOF
	git ls-files --format="%(eolinfo:worktree)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format eolattr' '
	printf "\n\n" >expect &&
	git ls-files --format="%(eolattr)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format path' '
	cat >expect <<-\EOF &&
	o1
	o2
	EOF
	git ls-files --format="%(path)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format with -m' '
	echo change >o1 &&
	cat >expect <<-\EOF &&
	o1
	EOF
	git ls-files --format="%(path)" -m >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format with -d' '
	echo o3 >o3 &&
	git add o3 &&
	rm o3 &&
	cat >expect <<-\EOF &&
	o3
	EOF
	git ls-files --format="%(path)" -d >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format imitate --stage' '
	git ls-files --stage >expect &&
	git ls-files --format="%(objectmode) %(objectname) %(stage)%x09%(path)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format with --debug' '
	git ls-files --debug >expect &&
	git ls-files --format="%(path)" --debug >actual &&
	test_cmp expect actual
'

test_done
