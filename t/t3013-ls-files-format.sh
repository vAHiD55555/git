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

test_expect_success 'git ls-files --format tag' '
	printf "H \nH \n" >expect &&
	git ls-files --format="%(tag)" -t >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format objectmode' '
	cat >expect <<-EOF &&
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
	cat >expect <<-EOF &&
	o1
	o2
	EOF
	git ls-files --format="%(path)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format ctime' '
	git ls-files --debug | grep ctime >expect &&
	git ls-files --format="  %(ctime)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format mtime' '
	git ls-files --debug | grep mtime >expect &&
	git ls-files --format="  %(mtime)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format dev and ino' '
	git ls-files --debug | grep dev >expect &&
	git ls-files --format="  %(dev)%x09%(ino)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format uid and gid' '
	git ls-files --debug | grep uid >expect &&
	git ls-files --format="  %(uid)%x09%(gid)" >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format with -m' '
	echo change >o1 &&
	cat >expect <<-EOF &&
	o1
	EOF
	git ls-files --format="%(path)" -m >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format with -d' '
	rm o1 &&
	test_when_finished "git restore o1" &&
	cat >expect <<-EOF &&
	o1
	EOF
	git ls-files --format="%(path)" -d >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --format size and flags' '
	git ls-files --debug | grep size >expect &&
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

test_expect_success 'git ls-files --format with -s must fail' '
	test_must_fail git ls-files --format="%(objectname)" -s
'

test_expect_success 'git ls-files --format with -o must fail' '
	test_must_fail git ls-files --format="%(objectname)" -o
'

test_expect_success 'git ls-files --format with -k must fail' '
	test_must_fail git ls-files --format="%(objectname)" -k
'

test_expect_success 'git ls-files --format with --resolve-undo must fail' '
	test_must_fail git ls-files --format="%(objectname)" --resolve-undo
'

test_expect_success 'git ls-files --format with --deduplicate must fail' '
	test_must_fail git ls-files --format="%(objectname)" --deduplicate
'

test_expect_success 'git ls-files --format with --debug must fail' '
	test_must_fail git ls-files --format="%(objectname)" --debug
'

test_expect_success 'git ls-files --object-only equal to --format=%(objectname)' '
	git ls-files --format="%(objectname)" >expect &&
	git ls-files --object-only >actual &&
	test_cmp expect actual
'

test_expect_success 'git ls-files --object-only with --format must fail' '
	test_must_fail git ls-files --format="%(path)" --object-only
'

test_expect_success 'git ls-files --object-only with -s must fail' '
	test_must_fail git ls-files --object-only -s
'

test_expect_success 'git ls-files --object-only with -o must fail' '
	test_must_fail git ls-files --object-only -o
'

test_expect_success 'git ls-files --object-only with -k must fail' '
	test_must_fail git ls-files --object-only -k
'

test_expect_success 'git ls-files --object-only with --resolve-undo must fail' '
	test_must_fail git ls-files --object-only --resolve-undo
'

test_expect_success 'git ls-files --object-only with --deduplicate must fail' '
	test_must_fail git ls-files --object-only --deduplicate
'

test_expect_success 'git ls-files --object-only with --debug must fail' '
	test_must_fail git ls-files --object-only --debug
'

test_done
