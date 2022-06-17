#!/bin/sh

test_description='git remote porcelain-ish'

. ./test-lib.sh

setup_repository () {
	mkdir "$1" && (
	cd "$1" &&
	git init -b main &&
	>file &&
	git add file &&
	test_tick &&
	git commit -m "Initial" &&
	git checkout -b side &&
	>elif &&
	git add elif &&
	test_tick &&
	git commit -m "Second" &&
	git checkout main
	)
}

tokens_match () {
	echo "$1" | tr ' ' '\012' | sort | sed -e '/^$/d' >expect &&
	echo "$2" | tr ' ' '\012' | sort | sed -e '/^$/d' >actual &&
	test_cmp expect actual
}

check_remote_track () {
	local config_dir=
	if test "$1" = -C
	then
		shift
		config_dir=$1
		shift
	fi
	actual=$(git ${config_dir:+-C "$config_dir"} remote show "$1" | sed -ne 's|^    \(.*\) tracked$|\1|p')
	shift &&
	tokens_match "$*" "$actual"
}

check_tracking_branch () {
	local config_dir=
	if test "$1" = -C
	then
		shift
		config_dir=$1
		shift
	fi
	f="" &&
	r=$(git ${config_dir:+-C "$config_dir"} for-each-ref "--format=%(refname)" |
		sed -ne "s|^refs/remotes/$1/||p") &&
	shift &&
	tokens_match "$*" "$r"
}

test_expect_success setup '
	setup_repository one &&
	setup_repository two &&
	git -C two branch another &&
	git clone one test
'

test_expect_success 'add remote whose URL agrees with url.<...>.insteadOf' '
	test_config url.git@host.com:team/repo.git.insteadOf myremote &&
	git remote add myremote git@host.com:team/repo.git
'

test_expect_success 'remote information for the origin' '
	tokens_match origin "$(git -C test remote)" &&
	check_remote_track -C test origin main side &&
	check_tracking_branch -C test origin HEAD main side
'

test_expect_success 'add another remote' '
	git -C test remote add -f second ../two &&
	tokens_match "origin second" "$(git -C test remote)" &&
	check_tracking_branch -C test second main side another &&
	git -C test for-each-ref "--format=%(refname)" refs/remotes |
	sed -e "/^refs\/remotes\/origin\//d" \
		-e "/^refs\/remotes\/second\//d" >actual &&
	test_must_be_empty actual
'

test_expect_success 'setup bare clone for server' '
	git clone --bare "file://$(pwd)/one" srv.bare &&
	git -C srv.bare config --local uploadpack.allowfilter 1 &&
	git -C srv.bare config --local uploadpack.allowanysha1inwant 1
'

test_expect_success 'filters for promisor remotes are listed by git remote -v' '
	test_when_finished "rm -rf pc" &&
	git clone --filter=blob:none "file://$(pwd)/srv.bare" pc &&
	git -C pc remote -v >out &&
	grep "srv.bare (fetch) \[blob:none\]" out &&

	git -C pc config remote.origin.partialCloneFilter object:type=commit &&
	git -C pc remote -v >out &&
	grep "srv.bare (fetch) \[object:type=commit\]" out
'

test_expect_success 'filters should not be listed for non promisor remotes (remote -v)' '
	test_when_finished "rm -rf pc" &&
	git clone one pc &&
	git -C pc remote -v >out &&
	! grep "(fetch) \[.*\]" out
'

test_expect_success 'filters are listed by git remote -v only' '
	test_when_finished "rm -rf pc" &&
	git clone --filter=blob:none "file://$(pwd)/srv.bare" pc &&
	git -C pc remote >out &&
	! grep "\[blob:none\]" out &&

	git -C pc remote show >out &&
	! grep "\[blob:none\]" out
'

test_expect_success 'check remote-tracking' '
	check_remote_track -C test origin main side &&
	check_remote_track -C test second main side another
'

test_expect_success 'remote forces tracking branches' '
	case $(git -C test config remote.second.fetch) in
	+*) true ;;
	 *) false ;;
	esac
'

test_expect_success 'remove remote' '
	git -C test symbolic-ref refs/remotes/second/HEAD refs/remotes/second/main &&
	git -C test remote rm second
'

test_expect_success 'remove remote' '
	tokens_match origin "$(git -C test remote)" &&
	check_remote_track -C test origin main side &&
	git -C test for-each-ref "--format=%(refname)" refs/remotes |
	sed -e "/^refs\/remotes\/origin\//d" >actual &&
	test_must_be_empty actual
'

test_expect_success 'remove remote protects local branches' '
	cat >expect1 <<-\EOF &&
	Note: A branch outside the refs/remotes/ hierarchy was not removed;
	to delete it, use:
	  git branch -d main
	EOF
	cat >expect2 <<-\EOF &&
	Note: Some branches outside the refs/remotes/ hierarchy were not removed;
	to delete them, use:
	  git branch -d foobranch
	  git branch -d main
	EOF
	git -C test tag footag &&
	git -C test config --add remote.oops.fetch "+refs/*:refs/*" &&
	git -C test remote remove oops 2>actual1 &&
	git -C test branch foobranch &&
	git -C test config --add remote.oops.fetch "+refs/*:refs/*" &&
	git -C test remote rm oops 2>actual2 &&
	git -C test branch -d foobranch &&
	git -C test tag -d footag &&
	test_cmp expect1 actual1 &&
	test_cmp expect2 actual2
'

test_expect_success 'remove errors out early when deleting non-existent branch' '
	echo "error: No such remote: '\''foo'\''" >expect &&
	test_expect_code 2 git -C test remote rm foo 2>actual &&
	test_cmp expect actual
'

test_expect_success 'remove remote with a branch without configured merge' '
	test_when_finished "(
		git -C test checkout main;
		git -C test branch -D two;
		git -C test config --remove-section remote.two;
		git -C test config --remove-section branch.second;
		true
	)" &&
	git -C test remote add two ../two &&
	git -C test fetch two &&
	git -C test checkout -b second two/main^0 &&
	git -C test config branch.second.remote two &&
	git -C test checkout main &&
	git -C test remote rm two
'

test_expect_success 'rename errors out early when deleting non-existent branch' '
	echo "error: No such remote: '\''foo'\''" >expect &&
	test_expect_code 2 git -C test remote rename foo bar 2>actual &&
	test_cmp expect actual
'

test_expect_success 'rename errors out early when new name is invalid' '
	test_config remote.foo.vcs bar &&
	echo "fatal: '\''invalid...name'\'' is not a valid remote name" >expect &&
	test_must_fail git remote rename foo invalid...name 2>actual &&
	test_cmp expect actual
'

test_expect_success 'add existing foreign_vcs remote' '
	test_config remote.foo.vcs bar &&
	echo "error: remote foo already exists." >expect &&
	test_expect_code 3 git remote add foo bar 2>actual &&
	test_cmp expect actual
'

test_expect_success 'add existing foreign_vcs remote' '
	test_config remote.foo.vcs bar &&
	test_config remote.bar.vcs bar &&
	echo "error: remote bar already exists." >expect &&
	test_expect_code 3 git remote rename foo bar 2>actual &&
	test_cmp expect actual
'

test_expect_success 'add invalid foreign_vcs remote' '
	echo "fatal: '\''invalid...name'\'' is not a valid remote name" >expect &&
	test_must_fail git remote add invalid...name bar 2>actual &&
	test_cmp expect actual
'

cat >expect <<EOF
* remote origin
  Fetch URL: $(pwd)/one
  Push  URL: $(pwd)/one
  HEAD branch: main
  Remote branches:
    main new (next fetch will store in remotes/origin)
    side tracked
  Local branches configured for 'git pull':
    ahead    merges with remote main
    main     merges with remote main
    octopus  merges with remote topic-a
                and with remote topic-b
                and with remote topic-c
    rebase  rebases onto remote main
  Local refs configured for 'git push':
    main pushes to main     (local out of date)
    main pushes to upstream (create)
* remote two
  Fetch URL: ../two
  Push  URL: ../three
  HEAD branch: main
  Local refs configured for 'git push':
    ahead forces to main    (fast-forwardable)
    main  pushes to another (up to date)
EOF

test_expect_success 'show' '
	git -C test config --add remote.origin.fetch refs/heads/main:refs/heads/upstream &&
	git -C test fetch &&
	git -C test checkout -b ahead origin/main &&
	echo 1 >>test/file &&
	test_tick &&
	git -C test commit -m update file &&
	git -C test checkout main &&
	git -C test branch --track octopus origin/main &&
	git -C test branch --track rebase origin/main &&
	git -C test branch -d -r origin/main &&
	git -C test config --add remote.two.url ../two &&
	git -C test config --add remote.two.pushurl ../three &&
	git -C test config branch.rebase.rebase true &&
	git -C test config branch.octopus.merge "topic-a topic-b topic-c" &&
	echo 1 >one/file &&
	test_tick &&
	git -C one commit -m update file &&
	git -C test config --add remote.origin.push : &&
	git -C test config --add remote.origin.push refs/heads/main:refs/heads/upstream &&
	git -C test config --add remote.origin.push +refs/tags/lastbackup &&
	git -C test config --add remote.two.push +refs/heads/ahead:refs/heads/main &&
	git -C test config --add remote.two.push refs/heads/main:refs/heads/another &&
	git -C test remote show origin two >output &&
	git -C test branch -d rebase octopus &&
	test_cmp expect output
'

cat >expect <<EOF
* remote origin
  Fetch URL: $(pwd)/one
  Push  URL: $(pwd)/one
  HEAD branch: main
  Remote branches:
    main skipped
    side tracked
  Local branches configured for 'git pull':
    ahead merges with remote main
    main  merges with remote main
  Local refs configured for 'git push':
    main pushes to main     (local out of date)
    main pushes to upstream (create)
EOF

test_expect_success 'show with negative refspecs' '
	test_when_finished "git -C test config --unset-all --fixed-value remote.origin.fetch ^refs/heads/main" &&
	git -C test config --add remote.origin.fetch ^refs/heads/main &&
	git -C test remote show origin >output &&
	test_cmp expect output
'

cat >expect <<EOF
* remote origin
  Fetch URL: $(pwd)/one
  Push  URL: $(pwd)/one
  HEAD branch: main
  Remote branches:
    main new (next fetch will store in remotes/origin)
    side stale (use 'git remote prune' to remove)
  Local branches configured for 'git pull':
    ahead merges with remote main
    main  merges with remote main
  Local refs configured for 'git push':
    main pushes to main     (local out of date)
    main pushes to upstream (create)
EOF

test_expect_failure 'show stale with negative refspecs' '
	test_when_finished "git -C test config --unset-all --fixed-value remote.origin.fetch ^refs/heads/side" &&
	git -C test config --add remote.origin.fetch ^refs/heads/side &&
	git -C test remote show origin >output &&
	test_cmp expect output
'

cat >expect <<EOF
* remote origin
  Fetch URL: $(pwd)/one
  Push  URL: $(pwd)/one
  HEAD branch: (not queried)
  Remote branches: (status not queried)
    main
    side
  Local branches configured for 'git pull':
    ahead merges with remote main
    main  merges with remote main
  Local refs configured for 'git push' (status not queried):
    (matching)           pushes to (matching)
    refs/heads/main      pushes to refs/heads/upstream
    refs/tags/lastbackup forces to refs/tags/lastbackup
EOF

test_expect_success 'show -n' '
	mv one one.unreachable &&
	git -C test remote show -n origin >output &&
	mv one.unreachable one &&
	test_cmp expect output
'

test_expect_success 'prune' '
	git -C one branch -m side side2 &&
	git -C test fetch origin &&
	git -C test remote prune origin &&
	git -C test rev-parse refs/remotes/origin/side2 &&
	test_must_fail git -C test rev-parse refs/remotes/origin/side
'

test_expect_success 'set-head --delete' '
	git -C test symbolic-ref refs/remotes/origin/HEAD &&
	git -C test remote set-head --delete origin &&
	test_must_fail git -C test symbolic-ref refs/remotes/origin/HEAD
'

test_expect_success 'set-head --auto' '
	git -C test remote set-head --auto origin &&
	echo refs/remotes/origin/main >expect &&
	git -C test symbolic-ref refs/remotes/origin/HEAD >output &&
	test_cmp expect output
'

test_expect_success 'set-head --auto has no problem w/multiple HEADs' '
	git -C test fetch two "refs/heads/*:refs/remotes/two/*" &&
	git -C test remote set-head --auto two >output 2>&1 &&
	echo "two/HEAD set to main" >expect &&
	test_cmp expect output
'

cat >expect <<\EOF
refs/remotes/origin/side2
EOF

test_expect_success 'set-head explicit' '
	git -C test remote set-head origin side2 &&
	git -C test symbolic-ref refs/remotes/origin/HEAD >output &&
	git -C test remote set-head origin main &&
	test_cmp expect output
'

cat >expect <<EOF
Pruning origin
URL: $(pwd)/one
 * [would prune] origin/side2
EOF

test_expect_success 'prune --dry-run' '
	git -C one branch -m side2 side &&
	test_when_finished "git -C one branch -m side side2" &&
	git -C test remote prune --dry-run origin >output &&
	git -C test rev-parse refs/remotes/origin/side2 &&
	test_must_fail git -C test rev-parse refs/remotes/origin/side &&
	test_cmp expect output
'

test_expect_success 'add --mirror && prune' '
	mkdir mirror &&
	git -C mirror init --bare &&
	git -C mirror remote add --mirror -f origin ../one &&
	git -C one branch -m side2 side &&
	git -C mirror rev-parse --verify refs/heads/side2 &&
	test_must_fail git -C mirror rev-parse --verify refs/heads/side &&
	git -C mirror fetch origin &&
	git -C mirror remote prune origin &&
	test_must_fail git -C mirror rev-parse --verify refs/heads/side2 &&
	git -C mirror rev-parse --verify refs/heads/side
'

test_expect_success 'add --mirror=fetch' '
	mkdir mirror-fetch &&
	git init -b main mirror-fetch/parent &&
	test_commit -C mirror-fetch/parent one &&
	git init --bare mirror-fetch/child &&
	git -C mirror-fetch/child remote add --mirror=fetch -f parent ../parent
'

test_expect_success 'fetch mirrors act as mirrors during fetch' '
	git -C mirror-fetch/parent branch new &&
	git -C mirror-fetch/parent branch -m main renamed &&
	git -C mirror-fetch/child fetch parent &&
	git -C mirror-fetch/child rev-parse --verify refs/heads/new &&
	git -C mirror-fetch/child rev-parse --verify refs/heads/renamed
'

test_expect_success 'fetch mirrors can prune' '
	git -C mirror-fetch/child remote prune parent &&
	test_must_fail git -C mirror-fetch/child rev-parse --verify refs/heads/main
'

test_expect_success 'fetch mirrors do not act as mirrors during push' '
	git -C mirror-fetch/parent checkout HEAD^0 &&
	git -C mirror-fetch/child branch -m renamed renamed2 &&
	git -C mirror-fetch/child push parent : &&
	git -C mirror-fetch/parent rev-parse --verify renamed &&
	test_must_fail git -C mirror-fetch/parent rev-parse --verify refs/heads/renamed2
'

test_expect_success 'add fetch mirror with specific branches' '
	git init --bare mirror-fetch/track &&
	git -C mirror-fetch/track remote add --mirror=fetch -t heads/new parent ../parent
'

test_expect_success 'fetch mirror respects specific branches' '
	git -C mirror-fetch/track fetch parent &&
	git -C mirror-fetch/track rev-parse --verify refs/heads/new &&
	test_must_fail git -C mirror-fetch/track rev-parse --verify refs/heads/renamed
'

test_expect_success 'add --mirror=push' '
	mkdir mirror-push &&
	git init --bare mirror-push/public &&
	git init -b main mirror-push/private &&
	test_commit -C mirror-push/private one &&
	git -C mirror-push/private remote add --mirror=push public ../public
'

test_expect_success 'push mirrors act as mirrors during push' '
	git -C mirror-push/private branch new &&
	git -C mirror-push/private branch -m main renamed &&
	git -C mirror-push/private push public &&
	git -C mirror-push/private rev-parse --verify refs/heads/new &&
	git -C mirror-push/private rev-parse --verify refs/heads/renamed &&
	test_must_fail git -C mirror-push/private rev-parse --verify refs/heads/main
'

test_expect_success 'push mirrors do not act as mirrors during fetch' '
	git -C mirror-push/public branch -m renamed renamed2 &&
	git -C mirror-push/public symbolic-ref HEAD refs/heads/renamed2 &&
	git -C mirror-push/private fetch public &&
	git -C mirror-push/private rev-parse --verify refs/heads/renamed &&
	test_must_fail git -C mirror-push/private rev-parse --verify refs/heads/renamed2
'

test_expect_success 'push mirrors do not allow you to specify refs' '
	git init mirror-push/track &&
	test_must_fail git -C mirror-push/track remote add --mirror=push -t new public ../public
'

test_expect_success 'add alt && prune' '
	mkdir alttst &&
	git -C alttst init &&
	git -C alttst remote add -f origin ../one &&
	git -C alttst config remote.alt.url ../one &&
	git -C alttst config remote.alt.fetch "+refs/heads/*:refs/remotes/origin/*" &&
	git -C one branch -m side side2 &&
	git -C alttst rev-parse --verify refs/remotes/origin/side &&
	test_must_fail git -C alttst rev-parse --verify refs/remotes/origin/side2 &&
	git -C alttst fetch alt &&
	git -C alttst remote prune alt &&
	test_must_fail git -C alttst rev-parse --verify refs/remotes/origin/side &&
	git -C alttst rev-parse --verify refs/remotes/origin/side2
'

cat >expect <<\EOF
some-tag
EOF

test_expect_success 'add with reachable tags (default)' '
	>one/foobar &&
	git -C one add foobar &&
	git -C one commit -m "Foobar" &&
	git -C one tag -a -m "Foobar tag" foobar-tag &&
	git -C one reset --hard HEAD~1 &&
	git -C one tag -a -m "Some tag" some-tag &&
	mkdir add-tags &&
	git -C add-tags init &&
	git -C add-tags remote add -f origin ../one &&
	git -C add-tags tag -l some-tag >output &&
	git -C add-tags tag -l foobar-tag >>output &&
	test_must_fail git -C add-tags config remote.origin.tagopt &&
	test_cmp expect output
'

cat >expect <<\EOF
some-tag
foobar-tag
--tags
EOF

test_expect_success 'add --tags' '
	rm -rf add-tags &&
	mkdir add-tags &&
	git -C add-tags init &&
	git -C add-tags remote add -f --tags origin ../one &&
	git -C add-tags tag -l some-tag >output &&
	git -C add-tags tag -l foobar-tag >>output &&
	git -C add-tags config remote.origin.tagopt >>output &&
	test_cmp expect output
'

cat >expect <<\EOF
--no-tags
EOF

test_expect_success 'add --no-tags' '
	rm -rf add-tags &&
	mkdir add-no-tags &&
	git -C add-no-tags init &&
	git -C add-no-tags remote add -f --no-tags origin ../one &&
	grep tagOpt add-no-tags/.git/config &&
	git -C add-no-tags tag -l some-tag >output &&
	git -C add-no-tags tag -l foobar-tag >output &&
	git -C add-no-tags config remote.origin.tagopt >>output &&
	git -C one tag -d some-tag foobar-tag &&
	test_cmp expect output
'

test_expect_success 'reject --no-no-tags' '
	test_must_fail git -C add-no-tags remote add -f --no-no-tags neworigin ../one
'

cat >expect <<\EOF
  apis/main
  apis/side
  drosophila/another
  drosophila/main
  drosophila/side
EOF

test_expect_success 'update' '
	git -C one remote add drosophila ../two &&
	git -C one remote add apis ../mirror &&
	git -C one remote update &&
	git -C one branch -r >output &&
	test_cmp expect output
'

cat >expect <<\EOF
  drosophila/another
  drosophila/main
  drosophila/side
  manduca/main
  manduca/side
  megaloprepus/main
  megaloprepus/side
EOF

test_expect_success 'update with arguments' '
	for b in $(git -C one branch -r)
	do
	git -C one branch -r -d $b || exit 1
	done &&
	git -C one remote add manduca ../mirror &&
	git -C one remote add megaloprepus ../mirror &&
	git -C one config remotes.phobaeticus "drosophila megaloprepus" &&
	git -C one config remotes.titanus manduca &&
	git -C one remote update phobaeticus titanus &&
	git -C one branch -r >output &&
	test_cmp expect output
'

test_expect_success 'update --prune' '
	git -C one branch -m side2 side3 &&
	git -C test remote update --prune &&
	git -C one branch -m side3 side2 &&
	git -C test rev-parse refs/remotes/origin/side3 &&
	test_must_fail git -C test rev-parse refs/remotes/origin/side2
'

cat >expect <<-\EOF
  apis/main
  apis/side
  manduca/main
  manduca/side
  megaloprepus/main
  megaloprepus/side
EOF

test_expect_success 'update default' '
	for b in $(git -C one branch -r)
	do
	git -C one branch -r -d $b || exit 1
	done &&
	git -C one config remote.drosophila.skipDefaultUpdate true &&
	git -C one remote update default &&
	git -C one branch -r >output &&
	test_cmp expect output
'

cat >expect <<\EOF
  drosophila/another
  drosophila/main
  drosophila/side
EOF

test_expect_success 'update default (overridden, with funny whitespace)' '
	for b in $(git -C one branch -r)
	do
	git -C one branch -r -d $b || exit 1
	done &&
	git -C one config remotes.default "$(printf "\t drosophila  \n")" &&
	git -C one remote update default &&
	git -C one branch -r >output &&
	test_cmp expect output
'

test_expect_success 'update (with remotes.default defined)' '
	for b in $(git -C one branch -r)
	do
	git -C one branch -r -d $b || exit 1
	done &&
	git -C one config remotes.default "drosophila" &&
	git -C one remote update &&
	git -C one branch -r >output &&
	test_cmp expect output
'

test_expect_success '"remote show" does not show symbolic refs' '
	git clone one three &&
	git -C three remote show origin >output &&
	! grep "^ *HEAD$" < output &&
	! grep -i stale < output
'

test_expect_success 'reject adding remote with an invalid name' '
	test_must_fail git remote add some:url desired-name
'

# The first three test if the tracking branches are properly renamed,
# the last two ones check if the config is updated.

test_expect_success 'rename a remote' '
	test_config_global remote.pushDefault origin &&
	git clone one four &&
	git -C four config branch.main.pushRemote origin &&
	GIT_TRACE2_EVENT=$(pwd)/trace \
		git -C four remote rename --progress origin upstream &&
	test_region progress "Renaming remote references" trace &&
	grep "pushRemote" four/.git/config &&
	test -z "$(git -C four for-each-ref refs/remotes/origin)" &&
	test "$(git -C four symbolic-ref refs/remotes/upstream/HEAD)" = "refs/remotes/upstream/main" &&
	test "$(git -C four rev-parse upstream/main)" = "$(git -C four rev-parse main)" &&
	test "$(git -C four config remote.upstream.fetch)" = "+refs/heads/*:refs/remotes/upstream/*" &&
	test "$(git -C four config branch.main.remote)" = "upstream" &&
	test "$(git -C four config branch.main.pushRemote)" = "upstream" &&
	test "$(git -C four config --global remote.pushDefault)" = "origin"
'

test_expect_success 'rename a remote renames repo remote.pushDefault' '
	git clone one four.1 &&
	git -C four.1 config remote.pushDefault origin &&
	git -C four.1 remote rename origin upstream &&
	grep pushDefault four.1/.git/config &&
	test "$(git -C four.1 config --local remote.pushDefault)" = "upstream"
'

test_expect_success 'rename a remote renames repo remote.pushDefault but ignores global' '
	test_config_global remote.pushDefault other &&
	git clone one four.2 &&
	git -C four.2 config remote.pushDefault origin &&
	git -C four.2 remote rename origin upstream &&
	test "$(git -C four.2 config --global remote.pushDefault)" = "other" &&
	test "$(git -C four.2 config --local remote.pushDefault)" = "upstream"
'

test_expect_success 'rename a remote renames repo remote.pushDefault but keeps global' '
	test_config_global remote.pushDefault origin &&
	git clone one four.3 &&
	git -C four.3 config remote.pushDefault origin &&
	git -C four.3 remote rename origin upstream &&
	test "$(git -C four.3 config --global remote.pushDefault)" = "origin" &&
	test "$(git -C four.3 config --local remote.pushDefault)" = "upstream"
'

test_expect_success 'rename does not update a non-default fetch refspec' '
	git clone one four.one &&
	git -C four.one config remote.origin.fetch +refs/heads/*:refs/heads/origin/* &&
	git -C four.one remote rename origin upstream &&
	test "$(git -C four.one config remote.upstream.fetch)" = "+refs/heads/*:refs/heads/origin/*" &&
	git -C four.one rev-parse -q origin/main
'

test_expect_success 'rename a remote with name part of fetch spec' '
	git clone one four.two &&
	git -C four.two remote rename origin remote &&
	git -C four.two remote rename remote upstream &&
	test "$(git -C four.two config remote.upstream.fetch)" = "+refs/heads/*:refs/remotes/upstream/*"
'

test_expect_success 'rename a remote with name prefix of other remote' '
	git clone one four.three &&
	git -C four.three remote add o git://example.com/repo.git &&
	git -C four.three remote rename o upstream &&
	test "$(git -C four.three rev-parse origin/main)" = "$(git -C four.three rev-parse main)"
'

test_expect_success 'rename succeeds with existing remote.<target>.prune' '
	git clone one four.four &&
	test_when_finished git config --global --unset remote.upstream.prune &&
	git config --global remote.upstream.prune true &&
	git -C four.four remote rename origin upstream
'

test_expect_success 'remove a remote' '
	test_config_global remote.pushDefault origin &&
	git clone one four.five &&
	git -C four.five config branch.main.pushRemote origin &&
	git -C four.five remote remove origin &&
	test -z "$(git -C four.five for-each-ref refs/remotes/origin)" &&
	test_must_fail git -C four.five config branch.main.remote &&
	test_must_fail git -C four.five config branch.main.pushRemote &&
	test "$(git -C four.five config --global remote.pushDefault)" = "origin"
'

test_expect_success 'remove a remote removes repo remote.pushDefault' '
	git clone one four.five.1 &&
	git -C four.five.1 config remote.pushDefault origin &&
	git -C four.five.1 remote remove origin &&
	test_must_fail git -C four.five.1 config --local remote.pushDefault
'

test_expect_success 'remove a remote removes repo remote.pushDefault but ignores global' '
	test_config_global remote.pushDefault other &&
	git clone one four.five.2 &&
	git -C four.five.2 config remote.pushDefault origin &&
	git -C four.five.2 remote remove origin &&
	test "$(git -C four.five.2 config --global remote.pushDefault)" = "other" &&
	test_must_fail git -C four.five.2 config --local remote.pushDefault
'

test_expect_success 'remove a remote removes repo remote.pushDefault but keeps global' '
	test_config_global remote.pushDefault origin &&
	git clone one four.five.3 &&
	git -C four.five.3 config remote.pushDefault origin &&
	git -C four.five.3 remote remove origin &&
	test "$(git -C four.five.3 config --global remote.pushDefault)" = "origin" &&
	test_must_fail git -C four.five.3 config --local remote.pushDefault
'

cat >remotes_origin <<EOF
URL: $(pwd)/one
Push: refs/heads/main:refs/heads/upstream
Push: refs/heads/next:refs/heads/upstream2
Pull: refs/heads/main:refs/heads/origin
Pull: refs/heads/next:refs/heads/origin2
EOF

test_expect_success 'migrate a remote from named file in $GIT_DIR/remotes' '
	git clone one five &&
	origin_url=$(pwd)/one &&
	git -C five remote remove origin &&
	mkdir -p five/.git/remotes &&
	cat remotes_origin >five/.git/remotes/origin &&
	git -C five remote rename origin origin &&
	test_path_is_missing .git/remotes/origin &&
	test "$(git -C five config remote.origin.url)" = "$origin_url" &&
	cat >push_expected <<-\EOF &&
	refs/heads/main:refs/heads/upstream
	refs/heads/next:refs/heads/upstream2
	EOF
	cat >fetch_expected <<-\EOF &&
	refs/heads/main:refs/heads/origin
	refs/heads/next:refs/heads/origin2
	EOF
	git -C five config --get-all remote.origin.push >push_actual &&
	git -C five config --get-all remote.origin.fetch >fetch_actual &&
	test_cmp push_expected push_actual &&
	test_cmp fetch_expected fetch_actual
'

test_expect_success 'migrate a remote from named file in $GIT_DIR/branches' '
	git clone one six &&
	origin_url=$(pwd)/one &&
	git -C six remote rm origin &&
	echo "$origin_url#main" >six/.git/branches/origin &&
	git -C six remote rename origin origin &&
	test_path_is_missing .git/branches/origin &&
	test "$(git -C six config remote.origin.url)" = "$origin_url" &&
	test "$(git -C six config remote.origin.fetch)" = "refs/heads/main:refs/heads/origin" &&
	test "$(git -C six config remote.origin.push)" = "HEAD:refs/heads/main"
'

test_expect_success 'migrate a remote from named file in $GIT_DIR/branches (2)' '
	git clone one seven &&
	git -C seven remote rm origin &&
	echo "quux#foom" >seven/.git/branches/origin &&
	git -C seven remote rename origin origin &&
	test_path_is_missing .git/branches/origin &&
	test "$(git -C seven config remote.origin.url)" = "quux" &&
	test "$(git -C seven config remote.origin.fetch)" = "refs/heads/foom:refs/heads/origin" &&
	test "$(git -C seven config remote.origin.push)" = "HEAD:refs/heads/foom"
'

test_expect_success 'remote prune to cause a dangling symref' '
	git clone one eight &&
	git -C one checkout side2 &&
	git -C one branch -D main &&
	git -C eight remote prune origin >err 2>&1 &&
	test_i18ngrep "has become dangling" err &&

	: And the dangling symref will not cause other annoying errors &&
	git -C eight branch -a 2>err &&
	! grep "points nowhere" err &&
	test_must_fail git -C eight branch nomore origin 2>err &&
	test_i18ngrep "dangling symref" err
'

test_expect_success 'show empty remote' '
	test_create_repo empty &&
	git clone empty empty-clone &&
	git -C empty-clone remote show origin
'

test_expect_success 'remote set-branches requires a remote' '
	test_must_fail git remote set-branches &&
	test_must_fail git remote set-branches --add
'

test_expect_success 'remote set-branches' '
	echo "+refs/heads/*:refs/remotes/scratch/*" >expect.initial &&
	sort <<-\EOF >expect.add &&
	+refs/heads/*:refs/remotes/scratch/*
	+refs/heads/other:refs/remotes/scratch/other
	EOF
	sort <<-\EOF >expect.replace &&
	+refs/heads/maint:refs/remotes/scratch/maint
	+refs/heads/main:refs/remotes/scratch/main
	+refs/heads/next:refs/remotes/scratch/next
	EOF
	sort <<-\EOF >expect.add-two &&
	+refs/heads/maint:refs/remotes/scratch/maint
	+refs/heads/main:refs/remotes/scratch/main
	+refs/heads/next:refs/remotes/scratch/next
	+refs/heads/seen:refs/remotes/scratch/seen
	+refs/heads/t/topic:refs/remotes/scratch/t/topic
	EOF
	sort <<-\EOF >expect.setup-ffonly &&
	refs/heads/main:refs/remotes/scratch/main
	+refs/heads/next:refs/remotes/scratch/next
	EOF
	sort <<-\EOF >expect.respect-ffonly &&
	refs/heads/main:refs/remotes/scratch/main
	+refs/heads/next:refs/remotes/scratch/next
	+refs/heads/seen:refs/remotes/scratch/seen
	EOF

	git clone .git/ setbranches &&
	git -C setbranches remote rename origin scratch &&
	git -C setbranches config --get-all remote.scratch.fetch >config-result &&
	sort <config-result >actual.initial &&

	git -C setbranches remote set-branches scratch --add other &&
	git -C setbranches config --get-all remote.scratch.fetch >config-result &&
	sort <config-result >actual.add &&

	git -C setbranches remote set-branches scratch maint main next &&
	git -C setbranches config --get-all remote.scratch.fetch >config-result &&
	sort <config-result >actual.replace &&

	git -C setbranches remote set-branches --add scratch seen t/topic &&
	git -C setbranches config --get-all remote.scratch.fetch >config-result &&
	sort <config-result >actual.add-two &&

	git -C setbranches config --unset-all remote.scratch.fetch &&
	git -C setbranches config remote.scratch.fetch \
		refs/heads/main:refs/remotes/scratch/main &&
	git -C setbranches config --add remote.scratch.fetch \
		+refs/heads/next:refs/remotes/scratch/next &&
	git -C setbranches config --get-all remote.scratch.fetch >config-result &&
	sort <config-result >actual.setup-ffonly &&

	git -C setbranches remote set-branches --add scratch seen &&
	git -C setbranches config --get-all remote.scratch.fetch >config-result &&
	sort <config-result >actual.respect-ffonly &&

	test_cmp expect.initial actual.initial &&
	test_cmp expect.add actual.add &&
	test_cmp expect.replace actual.replace &&
	test_cmp expect.add-two actual.add-two &&
	test_cmp expect.setup-ffonly actual.setup-ffonly &&
	test_cmp expect.respect-ffonly actual.respect-ffonly
'

test_expect_success 'remote set-branches with --mirror' '
	echo "+refs/*:refs/*" >expect.initial &&
	echo "+refs/heads/main:refs/heads/main" >expect.replace &&
	git clone --mirror .git/ setbranches-mirror &&
	git -C setbranches-mirror remote rename origin scratch &&
	git -C setbranches-mirror config --get-all remote.scratch.fetch >actual.initial &&

	git -C setbranches-mirror remote set-branches scratch heads/main &&
	git -C setbranches-mirror config --get-all remote.scratch.fetch >actual.replace &&
	test_cmp expect.initial actual.initial &&
	test_cmp expect.replace actual.replace
'

test_expect_success 'new remote' '
	git remote add someremote foo &&
	echo foo >expect &&
	git config --get-all remote.someremote.url >actual &&
	cmp expect actual
'

get_url_test () {
	cat >expect &&
	git remote get-url "$@" >actual &&
	test_cmp expect actual
}

test_expect_success 'get-url on new remote' '
	echo foo | get_url_test someremote &&
	echo foo | get_url_test --all someremote &&
	echo foo | get_url_test --push someremote &&
	echo foo | get_url_test --push --all someremote
'

test_expect_success 'remote set-url with locked config' '
	test_when_finished "rm -f .git/config.lock" &&
	git config --get-all remote.someremote.url >expect &&
	>.git/config.lock &&
	test_must_fail git remote set-url someremote baz &&
	git config --get-all remote.someremote.url >actual &&
	cmp expect actual
'

test_expect_success 'remote set-url bar' '
	git remote set-url someremote bar &&
	echo bar >expect &&
	git config --get-all remote.someremote.url >actual &&
	cmp expect actual
'

test_expect_success 'remote set-url baz bar' '
	git remote set-url someremote baz bar &&
	echo baz >expect &&
	git config --get-all remote.someremote.url >actual &&
	cmp expect actual
'

test_expect_success 'remote set-url zot bar' '
	test_must_fail git remote set-url someremote zot bar &&
	echo baz >expect &&
	git config --get-all remote.someremote.url >actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --push zot baz' '
	test_must_fail git remote set-url --push someremote zot baz &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	test_must_fail git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --push zot' '
	git remote set-url --push someremote zot &&
	echo zot >expect &&
	echo "YYY" >>expect &&
	echo baz >>expect &&
	git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'get-url with different urls' '
	echo baz | get_url_test someremote &&
	echo baz | get_url_test --all someremote &&
	echo zot | get_url_test --push someremote &&
	echo zot | get_url_test --push --all someremote
'

test_expect_success 'remote set-url --push qux zot' '
	git remote set-url --push someremote qux zot &&
	echo qux >expect &&
	echo "YYY" >>expect &&
	echo baz >>expect &&
	git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --push foo qu+x' '
	git remote set-url --push someremote foo qu+x &&
	echo foo >expect &&
	echo "YYY" >>expect &&
	echo baz >>expect &&
	git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --push --add aaa' '
	git remote set-url --push --add someremote aaa &&
	echo foo >expect &&
	echo aaa >>expect &&
	echo "YYY" >>expect &&
	echo baz >>expect &&
	git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'get-url on multi push remote' '
	echo foo | get_url_test --push someremote &&
	get_url_test --push --all someremote <<-\EOF
	foo
	aaa
	EOF
'

test_expect_success 'remote set-url --push bar aaa' '
	git remote set-url --push someremote bar aaa &&
	echo foo >expect &&
	echo bar >>expect &&
	echo "YYY" >>expect &&
	echo baz >>expect &&
	git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --push --delete bar' '
	git remote set-url --push --delete someremote bar &&
	echo foo >expect &&
	echo "YYY" >>expect &&
	echo baz >>expect &&
	git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --push --delete foo' '
	git remote set-url --push --delete someremote foo &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	test_must_fail git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --add bbb' '
	git remote set-url --add someremote bbb &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	echo bbb >>expect &&
	test_must_fail git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'get-url on multi fetch remote' '
	echo baz | get_url_test someremote &&
	get_url_test --all someremote <<-\EOF
	baz
	bbb
	EOF
'

test_expect_success 'remote set-url --delete .*' '
	test_must_fail git remote set-url --delete someremote .\* &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	echo bbb >>expect &&
	test_must_fail git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --delete bbb' '
	git remote set-url --delete someremote bbb &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	test_must_fail git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --delete baz' '
	test_must_fail git remote set-url --delete someremote baz &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	test_must_fail git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --add ccc' '
	git remote set-url --add someremote ccc &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	echo ccc >>expect &&
	test_must_fail git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --delete baz' '
	git remote set-url --delete someremote baz &&
	echo "YYY" >expect &&
	echo ccc >>expect &&
	test_must_fail git config --get-all remote.someremote.pushurl >actual &&
	echo "YYY" >>actual &&
	git config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'extra args: setup' '
	# add a dummy origin so that this does not trigger failure
	git remote add origin .
'

test_extra_arg () {
	test_expect_success "extra args: $*" "
		test_must_fail git remote $* bogus_extra_arg 2>actual &&
		test_i18ngrep '^usage:' actual
	"
}

test_extra_arg add nick url
test_extra_arg rename origin newname
test_extra_arg remove origin
test_extra_arg set-head origin main
# set-branches takes any number of args
test_extra_arg get-url origin newurl
test_extra_arg set-url origin newurl oldurl
# show takes any number of args
# prune takes any number of args
# update takes any number of args

test_expect_success 'add remote matching the "insteadOf" URL' '
	git config url.xyz@example.com.insteadOf backup &&
	git remote add backup xyz@example.com
'

test_expect_success 'unqualified <dst> refspec DWIM and advice' '
	test_when_finished "git -C test tag -d some-tag" &&
	git -C test tag -a -m "Some tag" some-tag main &&
	for type in commit tag tree blob
	do
		if test "$type" = "blob"
		then
			oid=$(git -C test rev-parse some-tag:file)
		else
			oid=$(git -C test rev-parse some-tag^{$type})
		fi &&
		test_must_fail git -C test push origin $oid:dst 2>err &&
		test_i18ngrep "error: The destination you" err &&
		test_i18ngrep "hint: Did you mean" err &&
		test_must_fail git -C test -c advice.pushUnqualifiedRefName=false \
			push origin $oid:dst 2>err &&
		test_i18ngrep "error: The destination you" err &&
		test_i18ngrep ! "hint: Did you mean" err ||
		exit 1
	done
'

test_expect_success 'refs/remotes/* <src> refspec and unqualified <dst> DWIM and advice' '
	git -C two tag -a -m "Some tag" my-tag main &&
	git -C two update-ref refs/trees/my-head-tree HEAD^{tree} &&
	git -C two update-ref refs/blobs/my-file-blob HEAD:file &&
	git -C test config --add remote.two.fetch "+refs/tags/*:refs/remotes/tags-from-two/*" &&
	git -C test config --add remote.two.fetch "+refs/trees/*:refs/remotes/trees-from-two/*" &&
	git -C test config --add remote.two.fetch "+refs/blobs/*:refs/remotes/blobs-from-two/*" &&
	git -C test fetch --no-tags two &&

	test_must_fail git -C test push origin refs/remotes/two/another:dst 2>err &&
	test_i18ngrep "error: The destination you" err &&

	test_must_fail git -C test push origin refs/remotes/tags-from-two/my-tag:dst-tag 2>err &&
	test_i18ngrep "error: The destination you" err &&

	test_must_fail git -C test push origin refs/remotes/trees-from-two/my-head-tree:dst-tree 2>err &&
	test_i18ngrep "error: The destination you" err &&

	test_must_fail git -C test push origin refs/remotes/blobs-from-two/my-file-blob:dst-blob 2>err &&
	test_i18ngrep "error: The destination you" err
'

test_done
