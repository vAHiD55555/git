#!/bin/sh

test_description="Tests performance of cache tree operations"

. ./perf-lib.sh

test_perf_large_repo
test_checkout_worktree

count=200
test_perf "prime_cache_tree, clean" "
	test-tool cache-tree --count $count prime
"

test_perf "cache_tree_update, clean" "
	test-tool cache-tree --count $count update
"

test_perf "prime_cache_tree, invalid" "
	test-tool cache-tree --count $count --fresh prime
"

test_perf "cache_tree_update, invalid" "
	test-tool cache-tree --count $count --fresh update
"

test_done
