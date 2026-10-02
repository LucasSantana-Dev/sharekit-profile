#!/usr/bin/env bats
# scripts/doctor.sh: dependency preflight lists missing tools, never fails by default.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  EMPTY="$BATS_TEST_TMPDIR/empty"
  FULL="$BATS_TEST_TMPDIR/full"
  mkdir -p "$EMPTY" "$FULL"
  for t in jq gh sqlite3 node python3 rtk graphify; do
    printf '#!/bin/sh\nexit 0\n' > "$FULL/$t"
    chmod +x "$FULL/$t"
  done
}

@test "missing tools are listed and exit is 0 (non-fatal)" {
  run env SHAREKIT_DOCTOR_PATH="$EMPTY" /bin/bash "$REPO_ROOT/scripts/doctor.sh"
  [ "$status" -eq 0 ]
  for t in jq gh sqlite3 node python rtk graphify; do
    [[ "$output" == *"$t"* ]]
  done
  [[ "$output" == *"MISSING  jq"* ]]
  [[ "$output" == *"winget install jqlang.jq"* ]]
}

@test "--strict fails when a required tool is missing" {
  run env SHAREKIT_DOCTOR_PATH="$EMPTY" /bin/bash "$REPO_ROOT/scripts/doctor.sh" --strict
  [ "$status" -eq 1 ]
}

@test "all tools present reports clean" {
  run env SHAREKIT_DOCTOR_PATH="$FULL" /bin/bash "$REPO_ROOT/scripts/doctor.sh" --strict
  [ "$status" -eq 0 ]
  [[ "$output" == *"all tools present."* ]]
  [[ "$output" != *"MISSING"* ]]
}
