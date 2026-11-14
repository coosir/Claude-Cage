package guestos

import (
	"runtime"
	"testing"
)

func TestIntelMacInspectionUsesLinuxGuest(t *testing.T) {
	if runtime.GOARCH != "amd64" {
		t.Skip("Intel macOS host")
	}
	r := Inspect(t.Context())
	if r.Guest != Debian13 || r.Restore != nil || r.Detail == "" {
		t.Fatalf("Intel Mac was probed as a macOS guest host: %+v", r)
	}
	if r.HostCheckPassed && r.WorkbenchSupport != "supported" {
		t.Fatalf("ready Intel host has no Linux workbench: %+v", r)
	}
}
