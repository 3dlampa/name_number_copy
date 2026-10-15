// Test-only executable: records real Windows argv and serves mock loopback CDP.
package main

import (
	"encoding/json"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--fixture-wait-only" {
		time.Sleep(20 * time.Second)
		return
	}
	port, profile := "", ""
	for _, arg := range os.Args[1:] {
		if strings.HasPrefix(arg, "--remote-debugging-port=") {
			port = strings.TrimPrefix(arg, "--remote-debugging-port=")
		}
		if strings.HasPrefix(arg, "--user-data-dir=") {
			profile = strings.TrimPrefix(arg, "--user-data-dir=")
		}
	}
	if port == "" || profile == "" {
		os.Exit(2)
	}
	data, _ := json.Marshal(os.Args[1:])
	if os.WriteFile(filepath.Join(profile, "test-browser-argv.json"), data, 0600) != nil {
		os.Exit(3)
	}
	listener, err := net.Listen("tcp", "127.0.0.1:"+port)
	if err != nil {
		os.Exit(4)
	}
	server := &http.Server{ReadHeaderTimeout: time.Second}
	server.Handler = http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/json/version" {
			_, _ = w.Write([]byte(`{"Browser":"Chromium/test","webSocketDebuggerUrl":"ws://127.0.0.1:` + port + `/test"}`))
		} else if r.URL.Path == "/shutdown" {
			_, _ = w.Write([]byte("done"))
			go func() { time.Sleep(100 * time.Millisecond); _ = server.Close() }()
		} else {
			_, _ = w.Write([]byte("[]"))
		}
	})
	go func() { time.Sleep(30 * time.Second); _ = server.Close() }()
	_ = server.Serve(listener)
}
