#!/bin/sh

test_description='Ref iteration performance tests'
. ./perf-lib.sh

test_perf_large_repo

# Optimize ref backend store
test_expect_success 'setup' '
	git pack-refs
'

for pattern in "refs/heads/" "refs/tags/" "refs/remotes"
do
	test_perf "count $pattern: git for-each-ref | wc -l" "
		git for-each-ref $pattern | wc -l
	"

	test_perf "count $pattern: git for-each-ref --count-match" "
		git for-each-ref --count-matches $pattern
	"
done

test_perf "count all patterns: git for-each-ref | wc -l" "
	git for-each-ref refs/heads/ | wc -l &&
	git for-each-ref refs/tags/ | wc -l &&
	git for-each-ref refs/remotes/ | wc -l
"

test_perf "count all patterns: git for-each-ref --count-match" "
	git for-each-ref --count-matches \
		refs/heads/ refs/tags/ refs/remotes/
"

test_done
