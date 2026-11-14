#!/usr/bin/env bash
# Build, notarize, and package a Developer ID distribution. No installation.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo 'Build macOS releases on macOS.' >&2; exit 1; }
case "$(uname -m)" in
  arm64) architecture=arm64 ;;
  x86_64) architecture=amd64 ;;
  *) echo 'Unsupported macOS architecture.' >&2; exit 1 ;;
esac
case "${1:-}" in ''|--from-notarized-app) ;; *) echo 'Usage: scripts/package-macos.sh [--from-notarized-app]' >&2; exit 2 ;; esac
: "${CAGE_SIGNING_IDENTITY:?Set CAGE_SIGNING_IDENTITY to your Developer ID Application identity.}"
: "${CAGE_NOTARY_PROFILE:?Set CAGE_NOTARY_PROFILE to a notarytool keychain profile.}"
notary_credentials=(--keychain-profile "$CAGE_NOTARY_PROFILE")
if [[ -n "${CAGE_NOTARY_KEYCHAIN:-}" ]]; then
  notary_credentials+=(--keychain "$CAGE_NOTARY_KEYCHAIN")
fi
if [[ "$CAGE_SIGNING_IDENTITY" == - ]]; then echo 'Release packages require a Developer ID identity.' >&2; exit 1; fi
version="$(tr -d '\n\r' < VERSION)"
release="$PWD/_output/releases/$version"
bundle="$PWD/_output/Cage.app"
mkdir -p "$release"
if [[ "${1:-}" != --from-notarized-app ]]; then
  bash scripts/build-app.sh
  ditto -c -k --keepParent "$bundle" "$release/Cage-notarization.zip"
  xcrun notarytool submit "$release/Cage-notarization.zip" \
    "${notary_credentials[@]}" --wait --timeout 20m \
    --output-format json > "$release/app-notarization.json"
  node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1])); if(r.status!=="Accepted") throw new Error(`Apple notarization: ${r.status}; submission ${r.id}`)' "$release/app-notarization.json"
  xcrun stapler staple "$bundle"
fi
actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CageVersion' "$bundle/Contents/Info.plist")"
if [[ "$actual_version" != "$version" ]]; then echo 'App version differs from VERSION; rebuild before packaging.' >&2; exit 1; fi
codesign --verify --deep --strict --verbose=2 "$bundle"
xcrun stapler validate "$bundle"
spctl --assess --type execute --verbose=2 "$bundle"
guest_source="cage-macos-guest-$version-source.tar.gz"
guest_materials="$bundle/Contents/Resources/guest-os/sources/$guest_source"
if [[ "$architecture" == arm64 ]]; then
  node scripts/guest-os/collect-macos-sshfs-sources.mjs verify "$guest_materials" \
    "$bundle/Contents/Resources/guest-os/project/cage-sshfs" "$version"
  # Copy only the source frozen by this App build, including the final signed
  # helper hash. Packaging must not substitute newer Homebrew source material.
  cp "$guest_materials" "$release/$guest_source"
fi
for executable in Contents/MacOS/Cage Contents/Resources/cage Contents/Resources/mihomo Contents/Resources/CageUpdateInstaller; do
  lipo "$bundle/$executable" -verify_arch "$(uname -m)"
done

stage="$(mktemp -d "$PWD/_output/dmg-stage.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
ditto "$bundle" "$stage/Cage.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/安装说明 - Read Me.txt" <<'EOF'
Cage — 本机隔离编码工作区

1. 将 Cage.app 拖入 Applications（应用程序）。
2. 从应用程序打开 Cage，设置本地账户，并按首次引导选择客机系统、存储位置和代理。
3. 添加自己的 Clash/Mihomo YAML 订阅或配置并选择节点，创建和启动环境。首次需下载系统镜像和工具，请保持网络连接。
4. 打开项目或新建终端，输入 claude，并在 Cage 浏览器内登录自己的 Claude 账户。

Apple Silicon Mac 需要 macOS 14+；Intel Mac 需要 macOS 15.5+，仅支持 x86_64 Linux 客机。
请选择与处理器架构对应的安装包。无需安装 Go、Node.js 或 Clash。
代理服务与 Claude 账户需自行准备。具体版本与发布状态以发行说明为准。
共享项目中的文件修改会直接写回 Mac；请备份重要项目。
升级前请退出 Cage 并停止环境，再替换应用程序；配置与项目文件会保留。

Drag Cage.app into Applications, then open it from Applications.
Complete the local account and environment setup, add your own Clash/Mihomo
YAML subscription or configuration, select a node, and start the environment.
Initial setup downloads the selected guest system and developer tools.
Requires macOS 14+ on Apple Silicon, or macOS 15.5+ on Intel (Linux guests only).
Use the installer matching your CPU. Your own proxy and Claude account are required.

入门 / Getting started:
https://github.com/Lee-xeo/Claude-Cage/blob/main/docs/getting-started.md
问题反馈 / Issues:
https://github.com/Lee-xeo/Claude-Cage/issues
EOF
artifact="Cage-$version-macos-$architecture.dmg"
hdiutil create -volname Cage -srcfolder "$stage" -ov -format UDZO "$release/$artifact"
codesign --force --sign "$CAGE_SIGNING_IDENTITY" --timestamp "$release/$artifact"
xcrun notarytool submit "$release/$artifact" "${notary_credentials[@]}" \
  --wait --timeout 20m --output-format json > "$release/dmg-notarization.json"
node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1])); if(r.status!=="Accepted") throw new Error(`Apple notarization: ${r.status}; submission ${r.id}`)' "$release/dmg-notarization.json"
xcrun stapler staple "$release/$artifact"
xcrun stapler validate "$release/$artifact"
spctl --assess --type open --context context:primary-signature --verbose=2 "$release/$artifact"

# Distribute the corresponding unmodified Mihomo source beside its executable.
core_version="$(sed -n 's/^version=//p' scripts/fetch-proxy-core.sh)"
core_source="mihomo-$core_version-source.tar.gz"
curl --fail --location --retry 2 --connect-timeout 15 --max-time 180 \
  "https://github.com/MetaCubeX/mihomo/archive/refs/tags/$core_version.tar.gz" \
  -o "$release/$core_source.part"
mv "$release/$core_source.part" "$release/$core_source"
tar -tzf "$release/$core_source" > /dev/null
release_files=("$artifact" "$core_source")
if [[ "$architecture" == arm64 ]]; then release_files+=("$guest_source"); fi
(cd "$release" && shasum -a 256 "${release_files[@]}" > SHA256SUMS)
node scripts/cleanup-apps.mjs --keep "$bundle" --root "$PWD/_output"
printf 'Verified release artifacts: %s/%s (see %s/SHA256SUMS)\n' "$release" "$artifact" "$release"
