#!/usr/bin/env bash
# Terminal checks for omarchy-bridge: one real KERN round trip, then every
# refusal path. Uses a throwaway state dir so real request ids are untouched.
set -euo pipefail

b="$(dirname "${BASH_SOURCE[0]}")/omarchy-bridge"
export XDG_STATE_HOME; XDG_STATE_HOME="$(mktemp -d)"; trap 'rm -rf "$XDG_STATE_HOME"' EXIT
env() { printf '<omarchy-action>%s</omarchy-action>' "$1"; }
expect() { # name, input, substring the reply must contain
  local out; out="$("$b" action "$2")"
  [[ "$out" == *"$3"* ]] || { echo "FAIL $1: $out" >&2; exit 1; }
  echo "ok   $1"
}
ok='{"v":1,"id":"t1","tool":"system.service_status","arguments":{"service":"bluetooth"}}'

"$b" tools | grep -q kern_asp && echo "ok   tools lists KERN"
expect "read round trip"   "$(env "$ok")"  "$(systemctl show -p ActiveState --value bluetooth.service)"
expect "duplicate id"      "$(env "$ok")"  '"ignore": "duplicate id"'
expect "prose"             "Sure, I can check bluetooth." '"ignore": "prose"'
expect "envelope in prose" "Here: $(env "$ok") done" 'not an action envelope'
expect "malformed JSON"    "$(env '{"v":1,"id":"m1",')" 'not an action envelope'
expect "unknown tool"      "$(env '{"v":1,"id":"u1","tool":"system.shell","arguments":{"cmd":"id"}}')" 'unknown tool'
expect "bad argument"      "$(env '{"v":1,"id":"a1","tool":"system.service_status","arguments":{"service":"sshd"}}')" 'must be one of'
expect "wrong version"     "$(env '{"v":2,"id":"w1","tool":"system.service_status","arguments":{"service":"bluetooth"}}')" 'unsupported version'
echo "omarchy-bridge checks passed."
