# Intel Mac

本分支为 Intel Mac 提供完整本地 Linux 工作台的构建路径。需要 macOS 15.5 或更新版本，以及可用的 Apple Virtualization.framework 硬件虚拟化。客机为同架构的 Debian 13 或 Ubuntu 22.04 x86_64，无需 Docker、QEMU 或 Rosetta。

macOS 15.5 的最低要求来自 Intel VZ 对 Linux 6.12+ 的兼容性；项目内置 Lima 驱动也提示这一限制。没有自动切换到软件模拟或其他虚拟机驱动的回退。

## 构建与启动

准备 Xcode Command Line Tools（或 Xcode）、Go（版本要求见根目录 `go.mod`）、Node.js 24+、npm 和 uv，并确保它们位于 PATH。首次构建会下载锁定依赖、代理核心和相关构建材料。

在项目根目录执行：

```sh
bash scripts/build-app.sh
bash scripts/test-macos-intel.sh
open _output/Cage.app
```

构建脚本生成本机 x86_64 架构的 `_output/Cage.app`，使用本地开发签名，不安装或替换已有应用。应用内含 Linux 客机代理、终端、浏览器、编辑器及独立代理核心所需的主机组件。首次创建客机仍需下载 Linux 镜像和客机工具。

初始化时选择 Debian 13 或 Ubuntu 22.04，设置存储位置与自己的代理。Intel 主机不提供“自动匹配本机系统版本”或 macOS 客机安装；已有 Ubuntu 安装可以续传，架构不匹配的镜像会被拒绝。运行后继续使用原有的代理出口限制、网络检查及按项目授权的文件共享。

## 测试

测试额外需要 Python 3.11+（推荐 3.13），且 `python3` 必须指向该版本。macOS 上旧的 Python 3.7 缺少现有测试使用的 `zoneinfo`、`str.removesuffix` 等功能，不适合作为测试解释器。可以用 uv 安装独立版本并为测试命令设置 PATH，无需替换系统 Python。

```sh
make test-go
npm --prefix ui test
npm --prefix ui run lint
bash scripts/test-app-updates.sh
bash scripts/test-macos-intel.sh
```

`test-macos-intel.sh` 检查真实应用包的架构、签名、系统版本要求、主机检测和独立临时配置下的离线工作台操作，不创建客机、不使用代理。完整运行验收还需在应用内完成一次 Debian/Ubuntu 安装，检查终端、项目读写、浏览器、编辑器、断网保护，以及停止后重新启动；离线测试不能代替这一步。

macOS 客机沿用项目的 Apple Virtualization/Lima 实现，该实现仅支持 Apple Silicon。Intel macOS 客机需要另接虚拟机后端，本分支未实现。

## 发行包

Intel 正式包命名为 `Cage-<版本>-macos-amd64.dmg`，Apple Silicon 仍使用 `macos-arm64.dmg`。应用更新只选择当前架构的包，并验证包内可执行文件的架构及原有签名要求。开发签名构建使用手动替换，不具备正式发布者身份。

具备 Developer ID 和公证配置时，沿用 `scripts/package-macos.sh` 在对应架构 Mac 上打包；Intel 包不包含 Apple Silicon macOS 客机组件或其对应源码归档。`scripts/verify-macos-release.sh` 校验的目录应只包含一个架构的 DMG。

上游下载区是否提供 Intel 预编译安装包，仍取决于实际发行附件；本分支的源码支持不代表上游已经发布。
