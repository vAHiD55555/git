#!/bin/sh

test_description='basic tests of rev-list --disk-usage'
. ./test-lib.sh

# we want a mix of reachable and unreachable, as well as
# objects in the bitmapped pack and some outside of it
test_expect_success 'set up repository' '
	test_commit --no-tag one &&
	test_commit --no-tag two &&
	git repack -adb &&
	git reset --hard HEAD^ &&
	test_commit --no-tag three &&
	test_commit --no-tag four &&
	git reset --hard HEAD^
'

# We don't want to hardcode sizes, because they depend on the exact details of
# packing, zlib, etc. We'll assume that the regular rev-list and cat-file
# machinery works and compare the --disk-usage output to that.
disk_usage_slow () {
	git rev-list --no-object-names "$@" |
	git cat-file --batch-check="%(objectsize:disk)" |
	perl -lne '$total += $_; END { print $total}'
}

# check behavior with given rev-list options; note that
# whitespace is not preserved in args
check_du () {
	args=$*

	test_expect_success "generate expected size ($args)" "
		disk_usage_slow $args >expect
	"

	test_expect_success "rev-list --disk-usage without bitmaps ($args)" "
		git rev-list --disk-usage $args >actual &&
		test_cmp expect actual
	"

	test_expect_success "rev-list --disk-usage with bitmaps ($args)" "
		git rev-list --disk-usage --use-bitmap-index $args >actual &&
		test_cmp expect actual
	"
}

check_du HEAD
check_du --objects HEAD
check_du --objects HEAD^..HEAD


test_expect_success 'rev-list --disk-usage with --human-readable' '
	git rev-list --objects HEAD --disk-usage --human-readable >actual &&
	test_i18ngrep -e "446 bytes" actual
'

test_expect_success 'rev-list --disk-usage with bitmap and --human-readable' '
	git rev-list --objects HEAD --use-bitmap-index --disk-usage -H >actual &&
	test_i18ngrep -e "446 bytes" actual
'

test_expect_success 'rev-list use --human-readable without --disk-usage' '
	test_must_fail git rev-list --objects HEAD --human-readable 2> err &&
	echo "fatal: option '\''--human-readable/-H'\'' should be used with" \
	"'\''--disk-usage'\'' together" >expect &&
	test_cmp err expect
'

test_done
