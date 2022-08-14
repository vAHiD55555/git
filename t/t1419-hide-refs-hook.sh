#!/bin/sh
#
# Copyright (c) 2022 Sun Chao
#

test_description='Test hide-refs hook'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

. "$TEST_DIRECTORY"/t1419/common-functions.sh

setup_bare_repo_and_work_repo () {
	# Refs of bare_repo : main(A)
	# Refs of work_repo: main(A)  tags/v123
	test_expect_success "setup bare_repo and work_repo" '
		rm -rf bare_repo.git bare_repo.git.dump &&
		rm -rf work_repo work_repo.dump &&
		git init --bare bare_repo.git &&
		git init work_repo &&
		create_commits_in work_repo A B C D &&
		(
			cd work_repo &&
			git config --local core.abbrev 7 &&
			git remote add origin ../bare_repo.git &&
			git update-ref refs/heads/dev $A &&
			git update-ref refs/heads/main $B &&
			git update-ref refs/pull-requests/1/head $C &&
			git tag -m "v123" v123 $D &&
			git push origin +refs/heads/*:refs/heads/* &&
			git push origin +refs/tags/*:refs/tags/* &&
			git push origin +refs/pull-requests/*:refs/pull-requests/*
		) &&
		TAG=$(git -C work_repo rev-parse v123) &&

		# setup pre-receive hook
		write_script bare_repo.git/hooks/pre-receive <<-\EOF &&
		exec >&2
		echo "# pre-receive hook"
		while read old new ref
		do
			echo "pre-receive< $old $new $ref"
		done
		EOF

		# setup update hook
		write_script bare_repo.git/hooks/update <<-\EOF &&
		exec >&2
		echo "# update hook"
		echo "update< $@"
		EOF

		# setup post-receive hook
		write_script bare_repo.git/hooks/post-receive <<-\EOF
		exec >&2
		echo "# post-receive hook"
		while read old new ref
		do
			echo "post-receive< $old $new $ref"
		done
		EOF
	'
}

run_hide_refs_hook_tests() {
	case $1 in
		http)
			PROTOCOL="HTTP protocol"
			BAREREPO_GIT_DIR="$HTTPD_DOCUMENT_ROOT_PATH/bare_repo.git"
			BAREREPO_PREFIX="$HTTPD_URL"/smart
			;;
		local)
			PROTOCOL="builtin protocol"
			BAREREPO_GIT_DIR="$(pwd)/bare_repo.git"
			BAREREPO_PREFIX="$(pwd)"
			;;
	esac

	BAREREPO_URL="$BAREREPO_PREFIX/bare_repo.git"

	GIT_TEST_PROTOCOL_VERSION=$2

	# Run test cases for 'hide-refs' hook
	for t in  "$TEST_DIRECTORY"/t1419/test-*.sh
	do
		# Initialize the bare_repo repository and work_repo
		setup_bare_repo_and_work_repo
		git -C work_repo remote set-url origin "$BAREREPO_URL"
		cp -rf work_repo work_repo.dump

		git -C bare_repo.git config --local http.receivepack true
		git -C bare_repo.git config --add transfer.hiderefs force:HEAD
		git -C bare_repo.git config --add transfer.hiderefs force:refs
		cp -rf bare_repo.git bare_repo.git.dump

		if test "$1" = "http"; then
			setup_askpass_helper
			rm -rf "$HTTPD_DOCUMENT_ROOT_PATH/bare_repo.git"
			mv bare_repo.git "$HTTPD_DOCUMENT_ROOT_PATH/bare_repo.git"
		fi

		. "$t"
	done
}


setup_bare_repo_and_work_repo
BAREREPO_GIT_DIR="$(pwd)/bare_repo.git"
BAREREPO_PREFIX="$(pwd)"
BAREREPO_URL="$BAREREPO_PREFIX/bare_repo.git"

# Load test cases that only need to be executed once.
for t in  "$TEST_DIRECTORY"/t1419/once-*.sh
do
	git -C "$BAREREPO_GIT_DIR" config --add transfer.hiderefs force:HEAD
	git -C "$BAREREPO_GIT_DIR" config --add transfer.hiderefs force:refs
	. "$t"
done

for protocol in 1 2
do
	# Run test cases for 'hide-refs' hook on local file protocol.
	run_hide_refs_hook_tests local $protocol
done

ROOT_PATH="$PWD"
. "$TEST_DIRECTORY"/lib-gpg.sh
. "$TEST_DIRECTORY"/lib-httpd.sh
. "$TEST_DIRECTORY"/lib-terminal.sh

start_httpd
set_askpass user@host pass@host

# Run test cases for 'hide-refs' hook on HTTP protocol.
for protocol in 1 2
do
	run_hide_refs_hook_tests http $protocol
done

test_done
