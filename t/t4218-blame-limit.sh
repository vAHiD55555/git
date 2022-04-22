#!/bin/sh

test_description='git blame with filter options limiting the output'

. ./test-lib.sh

test_expect_success 'setup test' '
	git init &&
	echo a >file &&
	git add file &&
	GIT_AUTHOR_DATE="2020-01-01 00:00" GIT_COMMITTER_DATE="2020-01-01 00:00" git commit -m init &&
	echo a >>file &&
	git add file &&
	GIT_AUTHOR_DATE="2020-02-01 00:00" GIT_COMMITTER_DATE="2020-02-01 00:00" git commit -m first &&
	echo a >>file &&
	git add file &&
	GIT_AUTHOR_DATE="2020-03-01 00:00" GIT_COMMITTER_DATE="2020-03-01 00:00" git commit -m second &&
	echo a >>file &&
	git add file &&
	GIT_AUTHOR_DATE="2020-04-01 00:00" GIT_COMMITTER_DATE="2020-04-01 00:00" git commit -m third
'

test_expect_success 'git blame --since=...' '
	git blame --since="2020-02-15" file >actual &&
	cat >expect <<-\EOF &&
	^c7bc5ce (A U Thor 2020-02-01 00:00:00 +0000 1) a
	^c7bc5ce (A U Thor 2020-02-01 00:00:00 +0000 2) a
	33fc0d13 (A U Thor 2020-03-01 00:00:00 +0000 3) a
	ec76e003 (A U Thor 2020-04-01 00:00:00 +0000 4) a
	EOF
	test_cmp expect actual
'

test_done
