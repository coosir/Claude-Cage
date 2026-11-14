//go:build !darwin

package host

import "io"

func MacOSPrereqs(io.Writer) bool { return true }
