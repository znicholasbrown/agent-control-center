#!/usr/bin/env bash
# Tests for bin/branch-status git-fallback path.
# Builds a sandbox center with a local bare remote (gh cannot treat it
# as a GitHub repo, so the git heuristics run) and BRANCH_STATUS_NO_GH=1
# for determinism. Checks the status token for merged/unmerged/gone.
# Run: tests/branch-status.test.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$ROOT/.tmp/branch-status-test.$$"
CENTER="$TMP/center"
export BRANCH_STATUS_NO_GH=1
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$CENTER/bin" "$CENTER/projects/demo/code"
cp "$ROOT/bin/branch-status" "$CENTER/bin/branch-status"
: >"$CENTER/projects/demo/PROJECT.md"

git init -q --bare -b main "$TMP/remote.git"
git init -q -b main "$TMP/seed"
(cd "$TMP/seed"
 git config user.name t; git config user.email t@t
 echo a >f; git add f; git commit -qm A
 git push -q "$TMP/remote.git" main
 git branch merged-b            # merged-b points at A
 git push -q "$TMP/remote.git" merged-b
 echo b >>f; git commit -qam B  # main advances to B; A is ancestor
 git push -q "$TMP/remote.git" main
 git checkout -q -b unmerged-b  # from B, add C not on main
 echo c >>f; git commit -qam C
 git push -q "$TMP/remote.git" unmerged-b)
git clone -q "$TMP/remote.git" "$CENTER/projects/demo/code/repo/main"

BS="$CENTER/bin/branch-status"
fail=0
check() {  # expected-status name branch
  local want="$1" name="$2" branch="$3" got
  got="$("$BS" repo "$branch" --project demo 2>/dev/null | awk '{print $1}')"
  if [ "$got" = "$want" ]; then echo "  ok      $name"
  else echo "  FAIL    $name (expected $want, got '$got')"; fail=1; fi
}

check merged   "ancestor branch is merged"        merged-b
check unmerged "remote branch not merged"         unmerged-b
check gone     "no remote branch is gone"         never-pushed-b

exit $fail
