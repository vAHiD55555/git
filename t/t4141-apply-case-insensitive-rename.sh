#!/bin/sh

test_description='git apply should handle case-only renames on case-insensitive filesystems'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# Please note, this test assumes that core.ignorecase is set appropriately for the filesystem,
# as tested in t0050. Case-only rename conflicts are only tested in case-sensitive filesystems.

if ! test_have_prereq CASE_INSENSITIVE_FS
then
	test_set_prereq CASE_SENSITIVE_FS
	echo nuts
fi

test_expect_success setup '
	echo "This is some content in the file." > file1 &&
	echo "A completely different file." > file2 &&
	git update-index --add file1 &&
	git update-index --add file2 &&
	cat >case_only_rename_patch <<-\EOF
	diff --git a/file1 b/File1
	similarity index 100%
	rename from file1
	rename to File1
	EOF
'

test_expect_success 'refuse to apply rename patch with conflict' '
	cat >conflict_patch <<-\EOF &&
	diff --git a/file1 b/file2
	similarity index 100%
	rename from file1
	rename to file2
	EOF
	test_must_fail git apply --index conflict_patch
'

test_expect_success CASE_SENSITIVE_FS 'refuse to apply case-only rename patch with conflict, in case-sensitive FS' '
	test_when_finished "git mv File1 file2" &&
	git mv file2 File1 &&
	test_must_fail git apply --index case_only_rename_patch
'

test_expect_success 'apply case-only rename patch without conflict' '
	git apply --index case_only_rename_patch
'

test_done
