package host

import (
	"fmt"
	"io"
	"os/exec"
	"runtime"
	"strings"

	"golang.org/x/mod/semver"
	"golang.org/x/sys/unix"
)

// MacOSPrereqs checks the Intel VZ host before downloading or booting a
// Linux guest. Linux 6.12+ needs the VZ fixes shipped in macOS 15.5.
func MacOSPrereqs(w io.Writer) bool {
	if runtime.GOARCH != "amd64" {
		return true
	}
	version, err := exec.Command("/usr/bin/sw_vers", "-productVersion").Output()
	if err != nil {
		fmt.Fprintf(w, "无法读取 macOS 版本：%v\n", err)
		return false
	}
	hv, err := unix.SysctlUint32("kern.hv_support")
	if err := intelMacVZPrereqs(strings.TrimSpace(string(version)), hv, err); err != nil {
		fmt.Fprintln(w, err)
		return false
	}
	return true
}

func intelMacVZPrereqs(version string, hv uint32, probeErr error) error {
	if !semver.IsValid("v"+version) || semver.Compare("v"+version, "v15.5.0") < 0 {
		return fmt.Errorf("Intel Mac 的 Linux 工作台需要 macOS 15.5 或更新版本（当前 %s），以支持 Linux 6.12+ 的 VZ 启动", version)
	}
	if probeErr != nil {
		return fmt.Errorf("无法检测 Intel Mac 硬件虚拟化能力：%w", probeErr)
	}
	if hv != 1 {
		return fmt.Errorf("Intel Mac 的硬件虚拟化不可用；请在支持 Virtualization.framework 的实体 Mac 上运行")
	}
	return nil
}
