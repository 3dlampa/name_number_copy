package main

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"testing"
	"time"
)

func TestBrowserProfilesRetainLegacyAndRemainSeparate(t *testing.T) {
	root := t.TempDir()
	for _, name := range []string{"Brave", "Chrome", "Edge"} {
		want := filepath.Join(root, "NameNumberCopy", "BrowserProfiles", name)
		if got := browserProfile(root, name); got != want {
			t.Fatalf("%s: %s != %s", name, got, want)
		}
	}
	legacy := filepath.Join(root, "OpenCartChromeDebug", "User Data")
	if err := os.MkdirAll(legacy, 0700); err != nil {
		t.Fatal(err)
	}
	if got := browserProfile(root, "Chrome"); got != legacy {
		t.Fatal("existing login profile lost")
	}
	if browserPort("Chrome") != 9223 || browserPort("Brave") != 9222 || browserPort("Edge") != 9222 {
		t.Fatal("CDP ports changed")
	}
}

func TestBrowserCDPRequiresBothValidEndpoints(t *testing.T) {
	for _, tc := range []struct {
		name, version, list string
		ok                  bool
	}{
		{"healthy", `{"Browser":"Chromium/test","webSocketDebuggerUrl":"ws://127.0.0.1/x"}`, `[]`, true},
		{"missing-version", `{}`, `[]`, false},
		{"invalid-list", `{"Browser":"Chromium/test","webSocketDebuggerUrl":"ws://127.0.0.1/x"}`, `{"error":"blocked"}`, false},
		{"missing-list", `{"Browser":"Chromium/test","webSocketDebuggerUrl":"ws://127.0.0.1/x"}`, `null`, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path == "/json/version" {
					_, _ = w.Write([]byte(tc.version))
				} else {
					_, _ = w.Write([]byte(tc.list))
				}
			}))
			defer server.Close()
			_, p, _ := net.SplitHostPort(server.Listener.Addr().String())
			port, _ := strconv.Atoi(p)
			if got := healthyBrowserCDP(context.Background(), &http.Client{Timeout: time.Second}, port); got != tc.ok {
				t.Fatalf("got %v want %v", got, tc.ok)
			}
		})
	}
}

func TestBrowserCDPHonorsOverallDeadline(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { <-r.Context().Done() }))
	defer server.Close()
	_, p, _ := net.SplitHostPort(server.Listener.Addr().String())
	port, _ := strconv.Atoi(p)
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()
	started := time.Now()
	if healthyBrowserCDP(ctx, &http.Client{Timeout: time.Second}, port) {
		t.Fatal("stalled endpoint accepted")
	}
	if time.Since(started) > 500*time.Millisecond {
		t.Fatal("overall deadline ignored")
	}
}
