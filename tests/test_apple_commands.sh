#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/apple-command-tests.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
BIN=$TMP/bin; HOME=$TMP/home; WORK=$TMP/work; FIXTURES=$TMP/fixtures
mkdir -p "$BIN" "$HOME/.config/apple-dev" "$WORK"
export HOME PATH=$BIN:/usr/bin:/bin APPLE_DEV_WORK_ROOT=$WORK
PASS=0 FAIL=0 SKIP=0 CASE=0
fail() { printf 'assertion failed: %s\n' "$*" >&2; return 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected <$2>, got <$1>"; }
assert_file() { [ -f "$1" ] || fail "missing file $1"; }
assert_no_jobs() { [ -z "$(printf '%s\n' "$1"/job.* 2>/dev/null | while IFS= read -r p; do [ -d "$p" ] && printf '%s\n' "$p"; done)" ]; }
run_case() {
    local name=$1 expected=$2; shift 2; CASE=$((CASE + 1))
    set +e
    ( set -e; "$@" >"$TMP/$name.out" 2>"$TMP/$name.err" )
    local status=$?
    set -e
    if [ "$status" -eq "$expected" ]; then PASS=$((PASS + 1)); printf 'PASS: %s\n' "$name"
    else FAIL=$((FAIL + 1)); printf 'FAIL: %s (got %s expected %s)\n' "$name" "$status" "$expected" >&2; cat "$TMP/$name.err" >&2; fi
}
skip_case() { CASE=$((CASE + 1)); SKIP=$((SKIP + 1)); printf 'SKIP: %s: %s\n' "$1" "$2"; }

failfast_probe() { false; true; }
run_case harness-failfast-self-test 1 failfast_probe
harness_sabotage() {
    local sabotaged=$TMP/sabotaged-test-apple-commands.sh
    python3 - "$ROOT/tests/test_apple_commands.sh" "$sabotaged" <<'PY'
import sys
source = open(sys.argv[1], encoding="utf-8").read()
needle = 'assert_eq "$(cat "$MOCK_SSH_COUNT")" 1;'
replacement = 'assert_eq "$(cat "$MOCK_SSH_COUNT")" 999;'
if needle not in source:
    raise SystemExit("existing assertion was not found")
open(sys.argv[2], "w", encoding="utf-8").write(source.replace(needle, replacement, 1))
PY
    if APPLE_TEST_SABOTAGE_MODE=1 APPLE_TEST_EXPECTED_CASES=48 bash "$sabotaged" >"$TMP/sabotaged.out" 2>"$TMP/sabotaged.err"; then
        printf 'sabotaged suite unexpectedly passed\n' >&2
        return 1
    fi
}
if [ "${APPLE_TEST_SABOTAGE_MODE:-0}" -ne 1 ]; then
    run_case harness-sabotage-propagates 0 harness_sabotage
fi
EXPECTED_CASES=${APPLE_TEST_EXPECTED_CASES:-49}
cat >"$BIN/ssh" <<'SH'
#!/bin/bash
set -u
count=$(cat "${MOCK_SSH_COUNT}" 2>/dev/null || printf 0); printf '%s\n' $((count + 1)) >"$MOCK_SSH_COUNT"
python3 - "$MOCK_SSH_ARGV" "$@" <<'PY'
import sys
with open(sys.argv[1], 'ab') as f:
    for arg in sys.argv[2:]: f.write(arg.encode() + b'\0')
    f.write(b'\n')
PY
if [ "$#" -eq 2 ] && [ "$2" = apple-build-worker ]; then
    if [ -n "${MOCK_SSH_STATUS:-}" ]; then
        [ -z "${MOCK_SSH_STDOUT_FILE:-}" ] || cat "$MOCK_SSH_STDOUT_FILE"
        [ -z "${MOCK_SSH_STDOUT:-}" ] || printf '%s' "$MOCK_SSH_STDOUT"
        exit "$MOCK_SSH_STATUS"
    fi
    exec "$MOCK_WORKER"
fi
if [ "$#" -gt 2 ]; then cat "$MOCK_HEALTH_OUTPUT"; exit "${MOCK_SSH_STATUS:-0}"; fi
exit 90
SH
cat >"$BIN/xcodebuild" <<'SH'
#!/bin/bash
set -u
printf 'cwd=%s\n' "$PWD" >"$MOCK_XCODEBUILD_RECORD"
printf 'detached=%s\n' "$(git symbolic-ref --quiet --short HEAD >/dev/null 2>&1 && printf no || printf yes)" >>"$MOCK_XCODEBUILD_RECORD"
printf 'sha=%s\n' "$(git rev-parse HEAD)" >>"$MOCK_XCODEBUILD_RECORD"
python3 - "$MOCK_XCODEBUILD_ARGV" "$@" <<'PY'
import sys
with open(sys.argv[1], 'wb') as f:
    for arg in sys.argv[2:]: f.write(arg.encode() + b'\0')
PY
while [ "$#" -gt 0 ]; do case "$1" in -resultBundlePath) result=$2; shift 2;; *) shift;; esac; done
if [ -n "${MOCK_XCODEBUILD_OUTPUT_BYTES:-}" ]; then
    python3 -c 'import sys; sys.stdout.write("x" * int(sys.argv[1]))' "$MOCK_XCODEBUILD_OUTPUT_BYTES"
else
    printf 'fake-xcodebuild-output\n'
fi
mkdir -p "$result"; printf 'fixture xcresult\n' >"$result/Info.json"
python3 - "$result" <<'PY'
import os
from pathlib import Path
import sys
root = Path(sys.argv[1])
if os.environ.get("MOCK_RESULT_MEMBER_BYTES"):
    (root / "large").write_bytes(b"x" * int(os.environ["MOCK_RESULT_MEMBER_BYTES"]))
if os.environ.get("MOCK_RESULT_MEMBER_COUNT"):
    for index in range(int(os.environ["MOCK_RESULT_MEMBER_COUNT"])):
        (root / ("member-%s" % index)).write_bytes(b"x")
PY
[ "${MOCK_BUILD_STATUS:-0}" -eq 0 ] || exit "$MOCK_BUILD_STATUS"
SH
chmod +x "$BIN/ssh" "$BIN/xcodebuild"
export MOCK_WORKER=$ROOT/dot_local/bin/executable_apple-build-worker MOCK_SSH_COUNT=$TMP/ssh.count MOCK_SSH_ARGV=$TMP/ssh.argv MOCK_HEALTH_OUTPUT=$TMP/health.out MOCK_XCODEBUILD_RECORD=$TMP/xcodebuild.record MOCK_XCODEBUILD_ARGV=$TMP/xcodebuild.argv
python3 "$ROOT/tests/helpers/apple_request_fixture.py" prepare "$FIXTURES"
SHA=$(python3 "$ROOT/tests/helpers/apple_request_fixture.py" value "$FIXTURES" sha)
REPO=$(python3 "$ROOT/tests/helpers/apple_request_fixture.py" value "$FIXTURES" repo)
DESTINATION=$(python3 "$ROOT/tests/helpers/apple_request_fixture.py" value "$FIXTURES" destination)
request() { printf '%s/%s.tar.gz' "$FIXTURES/requests" "$1"; }
controller() { "$ROOT/dot_local/bin/executable_apple-build" --host host.invalid --repository "$REPO" --scheme 'Fixture Scheme ; $() `quoted`' --action build --project App.xcodeproj --destination "$DESTINATION" --configuration 'Debug Fixture' --artifacts "$1"; }
reset_ssh() { : >"$MOCK_SSH_ARGV"; printf 0 >"$MOCK_SSH_COUNT"; }
worker_request() { set -o pipefail; cat "$(request "$1")" | "$MOCK_WORKER"; }

success_case() { reset_ssh; controller "$TMP/artifacts"; assert_eq "$(cat "$MOCK_SSH_COUNT")" 1; python3 - "$MOCK_SSH_ARGV" <<'PY'
import sys
raw=open(sys.argv[1],'rb').read().splitlines(); assert len(raw)==1
assert raw[0].split(b'\0')[:-1] == [b'host.invalid', b'apple-build-worker']
PY
archive=$TMP/artifacts/apple-build-$SHA.tar.gz; assert_file "$archive"; python3 "$ROOT/tests/helpers/apple_request_fixture.py" assert-result "$archive" "$(request valid)" "$SHA" 0; grep -Fqx "sha=$SHA" "$MOCK_XCODEBUILD_RECORD"; grep -Fqx 'detached=yes' "$MOCK_XCODEBUILD_RECORD"; [ ! -e "$FIXTURES/injection-sentinel" ]; assert_no_jobs "$WORK"; }
run_case published-commit-success 0 success_case
exact_detached_case() { controller "$TMP/exact-detached" >/dev/null; grep -Fqx "sha=$SHA" "$MOCK_XCODEBUILD_RECORD"; grep -Fqx 'detached=yes' "$MOCK_XCODEBUILD_RECORD"; }
run_case exact-detached-sha 0 exact_detached_case
run_case result-manifest-metadata-log-xcresult 0 python3 "$ROOT/tests/helpers/apple_request_fixture.py" assert-result "$TMP/artifacts/apple-build-$SHA.tar.gz" "$(request valid)" "$SHA" 0
failed_case() { reset_ssh; export MOCK_BUILD_STATUS=65; set +e; controller "$TMP/failure-artifacts" >/dev/null; local status=$?; set -e; unset MOCK_BUILD_STATUS; assert_eq "$status" 65; python3 "$ROOT/tests/helpers/apple_request_fixture.py" assert-result "$TMP/failure-artifacts/apple-build-$SHA.tar.gz" "$(request valid)" "$SHA" 65; assert_no_jobs "$WORK"; }
run_case failed-build-valid-artifact 0 failed_case
reserved_xcode_status_case() {
    local build_status artifact_dir controller_status
    for build_status in 125 129 130 143; do
        artifact_dir=$TMP/reserved-xcode-status-$build_status
        reset_ssh
        export MOCK_BUILD_STATUS=$build_status
        set +e
        controller "$artifact_dir" >/dev/null 2>"$artifact_dir.stderr"
        controller_status=$?
        set -e
        unset MOCK_BUILD_STATUS
        assert_eq "$controller_status" 65
        python3 "$ROOT/tests/helpers/apple_request_fixture.py" assert-result "$artifact_dir/apple-build-$SHA.tar.gz" "$(request valid)" "$SHA" "$build_status"
        assert_file "$artifact_dir/apple-build-$SHA.transport.log"
        ! grep -Fq 'transport/protocol error' "$artifact_dir.stderr"
        assert_no_jobs "$WORK"
    done
}
run_case reserved-xcode-statuses-remap-with-artifacts 0 reserved_xcode_status_case
run_case work-root-empty-success 0 assert_no_jobs "$WORK"
run_case work-root-empty-build-failure 0 assert_no_jobs "$WORK"

dirty_case() { printf dirty >>"$REPO/App.xcodeproj/project.pbxproj"; reset_ssh; set +e; "$ROOT/dot_local/bin/executable_apple-build" --host host.invalid --repository "$REPO" --scheme Scheme --action build --project App.xcodeproj; local status=$?; set -e; assert_eq "$status" 1; assert_eq "$(cat "$MOCK_SSH_COUNT")" 0; git -C "$REPO" checkout -q -- .; }
run_case dirty-rejects-before-ssh 0 dirty_case
run_case unpublished-commit-rejects-before-ssh 0 bash -c "printf unpublished >'$REPO/unpublished'; git -C '$REPO' add .; git -C '$REPO' commit -qm unpublished; set +e; '$ROOT/dot_local/bin/executable_apple-build' --host host.invalid --repository '$REPO' --scheme Scheme --action build --project App.xcodeproj; s=\$?; set -e; git -C '$REPO' reset -q --hard HEAD~1; test \$s -eq 1; test \$(cat '$MOCK_SSH_COUNT') -eq 0"
exact_ssh_case() { reset_ssh; controller "$TMP/exact-ssh" >/dev/null; assert_eq "$(cat "$MOCK_SSH_COUNT")" 1; }
run_case exactly-one-ssh-host-worker 0 exact_ssh_case
adversarial_case() { reset_ssh; controller "$TMP/adversarial" >/dev/null; [ ! -e "$FIXTURES/injection-sentinel" ]; python3 - "$MOCK_XCODEBUILD_ARGV" "$DESTINATION" <<'PY'
import sys
args=open(sys.argv[1],'rb').read().split(b'\0')[:-1]
assert b'Fixture Scheme ; $() ' + bytes([96]) + b'quoted' + bytes([96]) in args
assert sys.argv[2].encode() in args
PY
}
worker_log_bound_case() {
    local archive=$TMP/worker-log-bound.tar.gz status
    set +e
    APPLE_BUILD_TEST_MAX_LOG_BYTES=8 MOCK_XCODEBUILD_OUTPUT_BYTES=256 MOCK_BUILD_STATUS=65 worker_request valid >"$archive"
    status=$?
    set -e
    assert_eq "$status" 65
    python3 - "$archive" <<'PY'
import json, sys, tarfile
with tarfile.open(sys.argv[1], "r:gz") as archive:
    metadata = json.load(archive.extractfile("metadata.json"))
    log = archive.extractfile("xcodebuild.log").read()
assert metadata["xcodebuild_exit_status"] == 65
assert len(log) == 8
PY
    assert_no_jobs "$WORK"
}
run_case worker-log-capture-bounded-preserves-status 0 worker_log_bound_case
worker_archive_limit_case() {
    local archive=$TMP/worker-archive-limit.tar.gz status
    set +e
    APPLE_BUILD_TEST_MAX_ARCHIVE_BYTES=100 worker_request valid >"$archive"
    status=$?
    set -e
    assert_eq "$status" 125
    [ ! -s "$archive" ]
    assert_no_jobs "$WORK"
}
run_case worker-compressed-result-limit 0 worker_archive_limit_case
worker_member_limit_case() {
    local archive=$TMP/worker-member-limit.tar.gz status
    set +e
    APPLE_BUILD_TEST_MAX_MEMBERS=4 MOCK_RESULT_MEMBER_COUNT=2 worker_request valid >"$archive"
    status=$?
    set -e
    assert_eq "$status" 125
    [ ! -s "$archive" ]
    assert_no_jobs "$WORK"
}
run_case worker-result-member-count-limit 0 worker_member_limit_case
worker_expanded_limit_case() {
    local archive=$TMP/worker-expanded-limit.tar.gz status
    set +e
    APPLE_BUILD_TEST_MAX_EXPANDED_BYTES=1 worker_request valid >"$archive"
    status=$?
    set -e
    assert_eq "$status" 125
    [ ! -s "$archive" ]
    assert_no_jobs "$WORK"
}
run_case worker-expanded-result-limit 0 worker_expanded_limit_case
worker_individual_limit_case() {
    local archive=$TMP/worker-individual-limit.tar.gz status
    set +e
    APPLE_BUILD_TEST_MAX_MEMBER_BYTES=8 worker_request valid >"$archive"
    status=$?
    set -e
    assert_eq "$status" 125
    [ ! -s "$archive" ]
    assert_no_jobs "$WORK"
}
run_case worker-individual-member-limit 0 worker_individual_limit_case
worker_limit_raise_case() {
    set +e
    APPLE_BUILD_TEST_MAX_ARCHIVE_BYTES=4294967297 worker_request valid >/dev/null
    local status=$?
    set -e
    assert_eq "$status" 125
    assert_no_jobs "$WORK"
}
run_case production-limits-cannot-be-raised 0 worker_limit_raise_case
stale_cleanup_case() {
    local dead=$WORK/job.dead live=$WORK/job.live nested=$WORK/nested/job.nested status
    mkdir -p "$dead" "$live" "$nested"
    printf '99999999\n' >"$dead/.apple-build-worker.pid"
    printf '%s\n' "$$" >"$live/.apple-build-worker.pid"
    printf nested >"$nested/file"
    touch -t 200001010000 "$dead" "$live" "$nested"
    set +e
    worker_request valid >/dev/null
    status=$?
    set -e
    assert_eq "$status" 0
    [ ! -e "$dead" ]
    [ -d "$live" ]
    [ -f "$nested/file" ]
    rm -rf "$live" "$nested"
}
run_case stale-dead-removed-live-preserved 0 stale_cleanup_case
make_result() { python3 "$ROOT/tests/helpers/apple_request_fixture.py" make-result "$FIXTURES" "$TMP/$1.tar.gz" "$1"; }
controller_compressed_limit_case() {
    local result=$TMP/valid.tar.gz status
    make_result valid
    reset_ssh
    set +e
    APPLE_BUILD_TEST_MAX_ARCHIVE_BYTES=1 MOCK_SSH_STATUS=0 MOCK_SSH_STDOUT_FILE="$result" controller "$TMP/controller-compressed-limit" >/dev/null
    status=$?
    set -e
    assert_eq "$status" 125
}
run_case controller-compressed-result-limit 0 controller_compressed_limit_case
controller_member_limit_case() {
    local result=$TMP/result-member-count.tar.gz status
    make_result result-member-count
    reset_ssh
    set +e
    APPLE_BUILD_TEST_MAX_MEMBERS=4 MOCK_SSH_STATUS=0 MOCK_SSH_STDOUT_FILE="$result" controller "$TMP/controller-member-limit" >/dev/null
    status=$?
    set -e
    assert_eq "$status" 125
}
run_case controller-result-member-count-limit 0 controller_member_limit_case
controller_expanded_limit_case() {
    local result=$TMP/result-expanded.tar.gz status
    make_result result-expanded
    reset_ssh
    set +e
    APPLE_BUILD_TEST_MAX_EXPANDED_BYTES=1 MOCK_SSH_STATUS=0 MOCK_SSH_STDOUT_FILE="$result" controller "$TMP/controller-expanded-limit" >/dev/null
    status=$?
    set -e
    assert_eq "$status" 125
}
run_case controller-expanded-result-limit 0 controller_expanded_limit_case
controller_individual_limit_case() {
    local result=$TMP/result-large-member.tar.gz status
    make_result result-large-member
    reset_ssh
    set +e
    APPLE_BUILD_TEST_MAX_MEMBER_BYTES=8 MOCK_SSH_STATUS=0 MOCK_SSH_STDOUT_FILE="$result" controller "$TMP/controller-individual-limit" >/dev/null
    status=$?
    set -e
    assert_eq "$status" 125
}
run_case controller-individual-member-limit 0 controller_individual_limit_case
run_case adversarial-argv-no-sentinel 0 adversarial_case
invalid_case() { local variant=$1; set +e; cat "$(request "$variant")" | "$MOCK_WORKER"; local status=${PIPESTATUS[1]}; set -e; assert_eq "$status" 125; assert_no_jobs "$WORK"; }
for variant in extra-member duplicate-member traversal-member nonregular-member; do
    run_case "$variant-fail-closed" 0 invalid_case "$variant"
done
for variant in malformed-json duplicate-json-key unknown-key wrong-type missing-key empty-scheme both-selectors no-selector protocol-mismatch; do
    run_case "manifest-$variant-fail-closed" 0 invalid_case "$variant"
done
run_case bundle-manifest-sha-mismatch 0 invalid_case bundle-manifest-sha-mismatch
unreachable_case() { reset_ssh; set +e; MOCK_SSH_STATUS=255 "$ROOT/dot_local/bin/executable_apple-build" --host host.invalid --repository "$REPO" --scheme Scheme --action build --project App.xcodeproj --artifacts "$TMP/unreachable" >/dev/null; local status=$?; set -e; assert_eq "$status" 125; assert_eq "$(cat "$MOCK_SSH_COUNT")" 1; [ ! -e "$TMP/unreachable/apple-build-$SHA.tar.gz" ]; }
run_case unreachable-ssh-no-artifact 0 unreachable_case
truncated_case() { reset_ssh; set +e; MOCK_SSH_STATUS=7 MOCK_SSH_STDOUT=$'\037\213truncated' "$ROOT/dot_local/bin/executable_apple-build" --host host.invalid --repository "$REPO" --scheme Scheme --action build --project App.xcodeproj --artifacts "$TMP/truncated" >/dev/null; local status=$?; set -e; assert_eq "$status" 125; assert_eq "$(cat "$MOCK_SSH_COUNT")" 1; [ ! -e "$TMP/truncated/apple-build-$SHA.tar.gz" ]; }
run_case truncated-result-no-artifact 0 truncated_case
if [ -e /dev/full ]; then output_failure() { set +e; worker_request valid >/dev/full; local status=$?; set -e; assert_eq "$status" 125; assert_no_jobs "$WORK"; }; run_case output-write-failure-cleans-job 0 output_failure; else skip_case output-write-failure-cleans-job '/dev/full unavailable'; fi
configured_root_case() { local configured=$TMP/configured-work sentinel=$TMP/default-sentinel; mkdir -p "$sentinel"; printf 'APPLE_DEV_WORK_ROOT=%s\n' "$configured" >"$HOME/.config/apple-dev/config"; unset APPLE_DEV_WORK_ROOT; set +e; worker_request valid >/dev/null; local status=$?; set -e; assert_eq "$status" 0; [ -d "$configured" ]; assert_no_jobs "$configured"; assert_no_jobs "$sentinel"; rm -f "$HOME/.config/apple-dev/config"; export APPLE_DEV_WORK_ROOT=$WORK; }
run_case configured-worker-root-honored 0 configured_root_case
health_case() { reset_ssh; "$ROOT/dot_local/bin/executable_apple-dev-health" --host host.invalid --tart-vm vm --json >"$TMP/health-pass.out"; python3 - "$TMP/health-pass.out" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['ok'] is True and x['reachable']['status']=='pass'
assert set(x) == {'ok','reachable','macos','omp','xcode','simulator_runtime','disk','hindsight','tart','stale_build_state'}
PY
assert_eq "$(cat "$MOCK_SSH_COUNT")" 1; }
printf 'macos=14.5\nomp=omp\nxcode_path=/Applications/Xcode.app\nxcode_version=Xcode\nsimulator=available\ndisk_kb=104857600\ntart_present=yes\ntart_found=yes\ntart_state=running\nhindsight=unconfigured\nstale=no\n' >"$MOCK_HEALTH_OUTPUT"
run_case health-pass-stable-json 0 health_case
health_warning() { reset_ssh; printf 'macos=14\nomp=omp\nxcode_path=x\nxcode_version=x\nsimulator=available\ndisk_kb=104857600\ntart_present=no\ntart_found=no\ntart_state=missing\nhindsight=unconfigured\nstale=yes\n' >"$MOCK_HEALTH_OUTPUT"; set +e; "$ROOT/dot_local/bin/executable_apple-dev-health" --host host.invalid --json >"$TMP/health-warning-status.out"; local s=$?; set -e; assert_eq "$s" 1; python3 - "$TMP/health-warning-status.out" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['ok'] is True and x['stale_build_state']['status']=='warning'
PY
assert_eq "$(cat "$MOCK_SSH_COUNT")" 1; }
run_case health-warning-status 0 health_warning
health_critical() { printf bad >"$MOCK_HEALTH_OUTPUT"; set +e; "$ROOT/dot_local/bin/executable_apple-dev-health" --host host.invalid --json >"$TMP/health-critical-status.out"; s=$?; set -e; [ "$s" -eq 2 ]; python3 - "$TMP/health-critical-status.out" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['ok'] is False and x['reachable']['status']=='pass' and x['macos']['status']=='critical'
PY
}
run_case health-critical-status 0 health_critical
health_unreachable() { reset_ssh; set +e; MOCK_SSH_STATUS=255 "$ROOT/dot_local/bin/executable_apple-dev-health" --host host.invalid --json >"$TMP/health-unreachable-status.out"; s=$?; set -e; [ "$s" -eq 2 ]; python3 - "$TMP/health-unreachable-status.out" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['ok'] is False and x['reachable']['status']=='critical'
PY
assert_eq "$(cat "$MOCK_SSH_COUNT")" 1; }
run_case health-unreachable-status 0 health_unreachable
malformed_bytes_case() { set +e; printf '\\377' | "$MOCK_WORKER"; local status=${PIPESTATUS[1]}; set -e; assert_eq "$status" 125; assert_no_jobs "$WORK"; }
run_case malformed-bytes-fail-closed 0 malformed_bytes_case
health_invalid() { reset_ssh; set +e; "$ROOT/dot_local/bin/executable_apple-dev-health" --stale-days 1.5 --json; s=$?; set -e; assert_eq "$s" 2; assert_eq "$(cat "$MOCK_SSH_COUNT")" 0; }
run_case health-invalid-input-status 0 health_invalid
health_one_ssh() { printf 'macos=14.5\nomp=omp\nxcode_path=/Applications/Xcode.app\nxcode_version=Xcode\nsimulator=available\ndisk_kb=104857600\ntart_present=yes\ntart_found=yes\ntart_state=running\nhindsight=unconfigured\nstale=no\n' >"$MOCK_HEALTH_OUTPUT"; reset_ssh; "$ROOT/dot_local/bin/executable_apple-dev-health" --host host.invalid --tart-vm vm --json >/dev/null; assert_eq "$(cat "$MOCK_SSH_COUNT")" 1; }
run_case health-one-ssh-probe 0 health_one_ssh
printf 'SUMMARY: %d passed, %d failed, %d skipped ( %d named cases )\n' "$PASS" "$FAIL" "$SKIP" "$CASE"
[ "$FAIL" -eq 0 ] && [ "$CASE" -eq "$EXPECTED_CASES" ]
