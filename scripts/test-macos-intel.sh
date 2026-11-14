#!/usr/bin/env bash
# Inspect the actual Intel App and exercise its offline controller in a new profile.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin && "$(uname -m)" == x86_64 ]] || { echo 'Run on Intel macOS.' >&2; exit 1; }
bundle="${1:-$PWD/_output/Cage.app}"
[[ "$bundle" == /*.app ]] || { echo 'Pass an absolute Cage.app path.' >&2; exit 2; }
codesign --verify --deep --strict "$bundle"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$bundle/Contents/Info.plist")" == 15.5 ]]
for executable in Contents/MacOS/Cage Contents/Resources/cage Contents/Resources/mihomo Contents/Resources/CageUpdateInstaller; do
  test -x "$bundle/$executable"
  lipo "$bundle/$executable" -verify_arch x86_64
done
binary="$bundle/Contents/Resources/cage"
"$binary" verify-web-assets
"$bundle/Contents/Resources/mihomo" -v
"$binary" agent host.inspect | node --input-type=module -e '
  import assert from "node:assert/strict";
  let input = "";
  for await (const chunk of process.stdin) input += chunk;
  const report = JSON.parse(input).data;
  assert.equal(report.guest, "debian-13");
  assert.equal(report.hostCheckPassed, true, report.detail);
  assert.equal(report.workbenchSupport, "supported");
  assert.equal(report.restore, undefined);
  console.log("PASS: Intel VZ Linux host is ready; macOS restore is not offered.");
'
node scripts/agent-cli-smoke.mjs "$binary"
echo 'PASS: Intel macOS App architecture, signatures, assets and offline workbench.'
