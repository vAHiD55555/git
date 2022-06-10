#!/bin/sh

test_description='git ls-files --format test'

. ./test-lib.sh

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
	git ls-files --format="%(objectmode)" -t >actual &&
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

test_expect_success 'git ls-files --format eol' '
	printf "i/lf    w/lf    attr/                 \t\n" >expect &&
	printf "i/lf    w/lf    attr/                 \t\n" >>expect &&
	git ls-files --format="%(eol)" --eol >actual &&
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

test_expect_success 'git ls-files --format ctime' '
	git ls-files --debug >out &&
	grep ctime out >expect &&
	git ls-files --format="  %(ctime)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format mtime' '
	git ls-files --debug >out &&
	grep mtime out >expect &&
	git ls-files --format="  %(mtime)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format dev and ino' '
	git ls-files --debug >out &&
	grep dev out >expect &&
	git ls-files --format="  %(dev)%x09%(ino)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format uid and gid' '
	git ls-files --debug >out &&
	grep uid out >expect &&
	git ls-files --format="  %(uid)%x09%(gid)" >actual &&
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

test_expect_success 'git ls-files --format size and flags' '
	git ls-files --debug >out &&
	grep size out >expect &&
	git ls-files --format="  %(size)%x09%(flags)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format imitate --stage' '
	git ls-files --stage >expect &&
	git ls-files --format="%(objectmode) %(objectname) %(stage)%x09%(path)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format imitate --debug' '
	git ls-files --debug >expect &&
	git ls-files --format="%(path)%x0a  %(ctime)%x0a  %(mtime)%x0a  %(dev)%x09%(ino)%x0a  %(uid)%x09%(gid)%x0a  %(size)%x09%(flags)" >actual &&
	test_cmp expect actual
'

for flag in -s -o -k --resolve-undo --deduplicate --debug
do
	test_expect_success "git ls-files --format is incompatible with $flag" '
		test_must_fail git ls-files --format="%(objectname)" $flag
	'
done
test_done
