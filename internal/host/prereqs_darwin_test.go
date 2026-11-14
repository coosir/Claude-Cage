package host

import (
	"errors"
	"testing"
)

func TestIntelMacVZPrereqs(t *testing.T) {
	for _, tc := range []struct {
		version string
		hv      uint32
		err     error
		ready   bool
	}{
		{"15.5", 1, nil, true}, {"15.8", 1, nil, true}, {"26.0.1", 1, nil, true},
		{"14.7.1", 1, nil, false}, {"15.4.1", 1, nil, false}, {"invalid", 1, nil, false},
		{"15.8", 0, nil, false}, {"15.8", 1, errors.New("denied"), false},
	} {
		if err := intelMacVZPrereqs(tc.version, tc.hv, tc.err); (err == nil) != tc.ready {
			t.Errorf("%+v: %v", tc, err)
		}
	}
}
