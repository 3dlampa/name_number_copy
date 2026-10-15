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

func TestExistingBraveProfilePreservesSameDirectoryAndExplicitMode(t *testing.T) {
	root := t.TempDir()
	normal := filepath.Join(root, "BraveSoftware", "Brave-Browser", "User Data")
	if _, _, err := selectedBrowserProfile(root, "Brave", "Existing"); err == nil {
		t.Fatal("missing existing profile silently replaced")
	}
	if err := os.MkdirAll(normal, 0700); err != nil {
		t.Fatal(err)
	}
	login := filepath.Join(normal, "existing-login.txt")
	if err := os.WriteFile(login, []byte("keep"), 0600); err != nil {
		t.Fatal(err)
	}
	profile, existing, err := selectedBrowserProfile(root, "Brave", "Existing")
	if err != nil || profile != normal || !existing {
		t.Fatalf("normal profile not reused: %s / %v", profile, err)
	}
	if data, _ := os.ReadFile(login); string(data) != "keep" {
		t.Fatal("existing data changed")
	}
	for _, name := range []string{"Brave", "Chrome", "Edge"} {
		mode := "Isolated"
		if name != "Brave" {
			mode = "Existing"
		}
		got, ordinary, err := selectedBrowserProfile(root, name, mode)
		if err != nil || ordinary || got != browserProfile(root, name) {
			t.Fatal("isolated/Chrome/Edge compatibility lost")
		}
	}
	if _, _, err := selectedBrowserProfile(root, "Brave", "typo"); err == nil {
		t.Fatal("unknown profile mode accepted")
	}
	identity := browserIdentity{123, 456}
	if err := recordBrowserLaunch(root, normal, identity); err != nil {
		t.Fatal(err)
	}
	if !recordedBrowserMatches(root, normal, identity) {
		t.Fatal("own launch not recognized")
	}
	if recordedBrowserMatches(root, filepath.Join(root, "other"), identity) || recordedBrowserMatches(root, normal, browserIdentity{123, 789}) {
		t.Fatal("different profile or reused PID accepted")
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
