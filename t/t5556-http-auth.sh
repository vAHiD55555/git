#!/bin/sh

test_description='test http auth header and credential helper interop'

. ./test-lib.sh

test_set_port GIT_TEST_HTTP_PROTOCOL_PORT

# Setup a repository
#
REPO_DIR="$(pwd)"/repo

# Setup some lookback URLs where test-http-server will be listening.
# We will spawn it directly inside the repo directory, so we avoid
# any need to configure directory mappings etc - we only serve this
# repository from the root '/' of the server.
#
HOST_PORT=127.0.0.1:$GIT_TEST_HTTP_PROTOCOL_PORT
ORIGIN_URL=http://$HOST_PORT/

# The pid-file is created by test-http-server when it starts.
# The server will shutdown if/when we delete it (this is easier than
# killing it by PID).
#
PID_FILE="$(pwd)"/pid-file.pid
SERVER_LOG="$(pwd)"/OUT.server.log

PATH="$GIT_BUILD_DIR/t/helper/:$PATH" && export PATH

test_expect_success 'setup repos' '
	test_create_repo "$REPO_DIR" &&
	git -C "$REPO_DIR" branch -M main
'

stop_http_server () {
	if ! test -f "$PID_FILE"
	then
		return 0
	fi
	#
	# The server will shutdown automatically when we delete the pid-file.
	#
	rm -f "$PID_FILE"
	#
	# Give it a few seconds to shutdown (mainly to completely release the
	# port before the next test start another instance and it attempts to
	# bind to it).
	#
	for k in 0 1 2 3 4
	do
		if grep -q "Starting graceful shutdown" "$SERVER_LOG"
		then
			return 0
		fi
		sleep 1
	done

	echo "stop_http_server: timeout waiting for server shutdown"
	return 1
}

start_http_server () {
	#
	# Launch our server into the background in repo_dir.
	#
	(
		cd "$REPO_DIR"
		test-http-server --verbose \
			--listen=127.0.0.1 \
			--port=$GIT_TEST_HTTP_PROTOCOL_PORT \
			--reuseaddr \
			--pid-file="$PID_FILE" \
			"$@" \
			2>"$SERVER_LOG" &
	)
	#
	# Give it a few seconds to get started.
	#
	for k in 0 1 2 3 4
	do
		if test -f "$PID_FILE"
		then
			return 0
		fi
		sleep 1
	done

	echo "start_http_server: timeout waiting for server startup"
	return 1
}

per_test_cleanup () {
	stop_http_server &&
	rm -f OUT.*
}

test_expect_success 'http auth anonymous no challenge' '
	test_when_finished "per_test_cleanup" &&
	start_http_server --allow-anonymous &&

	# Attempt to read from a protected repository
	git ls-remote $ORIGIN_URL
'

test_done
