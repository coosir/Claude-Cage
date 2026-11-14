package guestos

import (
	"bytes"
	"context"
	"runtime"
	"strings"

	"github.com/sylvinus/agent-vm/internal/host"
)

func Inspect(ctx context.Context) Inspection {
	if runtime.GOARCH == "amd64" {
		var details bytes.Buffer
		ready := host.MacOSPrereqs(&details)
		r := Inspection{Guest: Debian13, HostCheckPassed: ready, WorkbenchSupport: "host-not-ready", Detail: strings.TrimSpace(details.String())}
		if ready {
			r.WorkbenchSupport = "supported"
			r.Detail = "Intel Mac 可使用 VZ 硬件虚拟化运行 x86_64 Debian 或 Ubuntu 工作台；macOS 客机需要 Apple Silicon。"
		}
		return r
	}
	r := Inspection{Guest: MacOS, WorkbenchSupport: nativeWorkbenchSupport(MacOS, false)}
	image, err := probeMacHost(ctx)
	if err != nil {
		r.Detail = "无法查询本机兼容的 Apple 恢复镜像：" + err.Error()
		return r
	}
	r.HostCheckPassed = true
	r.WorkbenchSupport = nativeWorkbenchSupport(MacOS, true)
	r.Restore = &image
	r.Detail = "Apple 提供与此主机兼容的 macOS 恢复镜像。"
	return r
}
