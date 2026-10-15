//go:build windows

package main

import (
	"net"
	"os"
	"strconv"
	"testing"
)

func TestNativeCDPListenerIdentityUsesActualWindowsOwner(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	_, raw, _ := net.SplitHostPort(listener.Addr().String())
	port, _ := strconv.Atoi(raw)
	identity, err := browserEndpointIdentity(port)
	if err != nil {
		t.Fatal(err)
	}
	if identity.PID != uint32(os.Getpid()) || identity.Created == 0 {
		t.Fatalf("wrong native owner: %+v", identity)
	}
	again, err := processBrowserIdentity(uint32(os.Getpid()))
	if err != nil || again != identity {
		t.Fatalf("unstable process identity: %+v / %v", again, err)
	}
}
