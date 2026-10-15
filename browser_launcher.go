package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type browserSettings struct {
	Primary          string
	BraveProfileMode string
	Browsers         map[string]struct {
		Exe  string
		Port int
	}
}

type browserIdentity struct {
	PID     uint32
	Created uint64
}
type browserLaunchRecord struct {
	Profile  string
	Identity browserIdentity
}

func selectedBrowserProfile(localData, name, mode string) (string, bool, error) {
	if name != "Brave" || mode == "" || mode == "Isolated" {
		return browserProfile(localData, name), false, nil
	}
	if mode != "Existing" {
		return "", false, errors.New("ismeretlen Brave-profilmód")
	}
	profile := filepath.Join(localData, "BraveSoftware", "Brave-Browser", "User Data")
	if info, err := os.Stat(profile); err != nil || !info.IsDir() {
		return "", false, errors.New("nincs meglévő normál Brave-profil ennél a Windows-felhasználónál; indítsd el egyszer a normál Brave-et, vagy válaszd a külön OpenCart-profilt")
	}
	return profile, true, nil
}

func browserRecordPath(localData string) string {
	return filepath.Join(localData, "NameNumberCopy", "BrowserProfiles", "brave-launch.json")
}

func recordedBrowserMatches(localData, profile string, identity browserIdentity) bool {
	data, err := os.ReadFile(browserRecordPath(localData))
	if err != nil || len(data) > 4096 {
		return false
	}
	var record browserLaunchRecord
	return json.Unmarshal(data, &record) == nil && strings.EqualFold(filepath.Clean(record.Profile), filepath.Clean(profile)) && record.Identity == identity
}

func recordBrowserLaunch(localData, profile string, identity browserIdentity) error {
	path := browserRecordPath(localData)
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return err
	}
	data, err := json.Marshal(browserLaunchRecord{profile, identity})
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0600)
}

var browserSubpaths = map[string]string{
	"Brave":  `BraveSoftware\Brave-Browser\Application\brave.exe`,
	"Chrome": `Google\Chrome\Application\chrome.exe`,
	"Edge":   `Microsoft\Edge\Application\msedge.exe`,
}

func browserPort(name string) int {
	if name == "Chrome" {
		return 9223
	}
	return 9222
}

func browserProfile(localData, name string) string {
	legacyName := map[string]string{"Brave": "OpenCartBraveDebug", "Chrome": "OpenCartChromeDebug", "Edge": "OpenCartEdgeDebug"}[name]
	legacy := filepath.Join(localData, legacyName, "User Data")
	if info, err := os.Stat(legacy); err == nil && info.IsDir() {
		return legacy
	}
	return filepath.Join(localData, "NameNumberCopy", "BrowserProfiles", name)
}

func resolveBrowser(name string, config browserSettings, useInstalledBrowsers bool) string {
	if useInstalledBrowsers {
		if path := findLocalBrowser(name); path != "" {
			return path
		}
	}
	path := config.Browsers[name].Exe
	if info, err := os.Stat(path); err == nil && !info.IsDir() {
		return path
	}
	return ""
}

// Both endpoints must be usable. Never claim installation success based only on shortcuts.
func healthyBrowserCDP(ctx context.Context, client *http.Client, port int) bool {
	get := func(endpoint string, value any) bool {
		request, err := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("http://127.0.0.1:%d/json/%s", port, endpoint), nil)
		if err != nil {
			return false
		}
		response, err := client.Do(request)
		if err != nil {
			return false
		}
		defer response.Body.Close()
		return response.StatusCode == http.StatusOK && json.NewDecoder(io.LimitReader(response.Body, maxCDPMessageSize)).Decode(value) == nil
	}
	var version struct {
		Browser              string
		WebSocketDebuggerURL string
	}
	var tabs []json.RawMessage
	return get("version", &version) && version.Browser != "" && version.WebSocketDebuggerURL != "" && get("list", &tabs) && tabs != nil
}

func runBrowserLauncher(args []string) error {
	name, localData, checkOnly := "Auto", os.Getenv("LOCALAPPDATA"), false
	useInstalledBrowsers := true
	if len(args) > 0 {
		name = args[0]
		args = args[1:]
	}
	if name != "Auto" && browserSubpaths[name] == "" {
		return errors.New("ismeretlen böngésző")
	}
	for len(args) > 0 {
		switch args[0] {
		case "--autostart": // The optional Startup shortcut uses the same launcher.
		case "--check-only":
			checkOnly = true
		case "--test-user-root":
			if len(args) < 2 {
				return errors.New("hiányzó tesztprofil")
			}
			localData = args[1]
			useInstalledBrowsers = false // Explicit fixture root must never launch the host's browser.
			args = args[1:]
		default:
			return fmt.Errorf("ismeretlen indítási opció: %s", args[0])
		}
		args = args[1:]
	}
	executable, err := os.Executable()
	if err != nil {
		return err
	}
	data, err := os.ReadFile(filepath.Join(filepath.Dir(executable), "opencart_browser_config.json"))
	if err != nil {
		return err
	}
	var config browserSettings
	if err := json.Unmarshal(data, &config); err != nil {
		return err
	}
	if name == "Auto" {
		for _, candidate := range []string{config.Primary, "Brave", "Chrome", "Edge"} {
			if browserSubpaths[candidate] != "" && resolveBrowser(candidate, config, useInstalledBrowsers) != "" {
				name = candidate
				break
			}
		}
	}
	path := resolveBrowser(name, config, useInstalledBrowsers)
	if path == "" {
		return errors.New("nem található Brave, Chrome vagy Edge")
	}
	if localData == "" {
		return errors.New("nem érhető el a LOCALAPPDATA mappa")
	}
	profile, existingProfile, err := selectedBrowserProfile(localData, name, config.BraveProfileMode)
	if err != nil {
		return err
	}
	// No proxy or redirect: CDP stays on the explicitly selected loopback endpoint.
	client := &http.Client{Timeout: 3 * time.Second, Transport: &http.Transport{Proxy: nil}, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	defer client.CloseIdleConnections()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	port := browserPort(name)
	// Explicit fixture roots use their own local port and never disturb a live host browser.
	if !useInstalledBrowsers && config.Browsers[name].Port > 0 && config.Browsers[name].Port <= 65535 {
		port = config.Browsers[name].Port
	}
	logBrowserMessage(fmt.Sprintf("INFO: verzio=%s; bongeszo=%s; port=%d; CDP ellenorzes", appVersion, name, port))
	if healthyBrowserCDP(ctx, client, port) {
		if existingProfile {
			identity, err := browserEndpointIdentity(port)
			if err != nil || !recordedBrowserMatches(localData, profile, identity) {
				return errors.New("a CDP-porton már másik vagy korábban indított böngésző fut; zárd be a Brave ablakait, majd indítsd az OpenCart - Brave ikont a normál profilhoz")
			}
		}
		logBrowserMessage("OK: CDP mar elerheto")
		return nil
	}
	if checkOnly {
		return fmt.Errorf("a %s CDP %d portja nem érhető el", name, port)
	}
	if existingProfile {
		running, err := browserProcessRunning(filepath.Base(path))
		if err != nil {
			return err
		}
		if running {
			return errors.New("a Brave már fut hibakereső kapcsolat nélkül; zárd be az összes Brave-ablakot és a háttérben futó Brave-et, majd indítsd az OpenCart - Brave ikont; a bejelentkezéseid megmaradnak")
		}
	}
	if err := os.MkdirAll(profile, 0700); err != nil {
		return err
	}
	command := exec.Command(path, "--remote-debugging-address=127.0.0.1", fmt.Sprintf("--remote-debugging-port=%d", port), "--user-data-dir="+profile, "--no-first-run")
	configureBrowserProcess(command)
	logBrowserMessage(fmt.Sprintf("INFO: bongeszoinditas; exe=%s; profil=%s", path, profile))
	if err := command.Start(); err != nil {
		return err
	}
	go func() { _ = command.Wait() }()
	for ctx.Err() == nil {
		if healthyBrowserCDP(ctx, client, port) {
			if existingProfile {
				identity, err := browserEndpointIdentity(port)
				if err != nil || identity.PID != uint32(command.Process.Pid) {
					return errors.New("a CDP nem a most indított Brave-folyamathoz tartozik; a korábbi böngésző nem kerül használatba")
				}
				if err := recordBrowserLaunch(localData, profile, identity); err != nil {
					return err
				}
			}
			logBrowserMessage("OK: bongeszo elindult, mindket CDP vegpont elerheto")
			return nil
		}
		select {
		case <-ctx.Done():
		case <-time.After(500 * time.Millisecond):
		}
	}
	return fmt.Errorf("a %s elindult, de a CDP %d port 20 másodpercen belül nem vált elérhetővé", name, port)
}

func logBrowserError(err error) {
	logBrowserMessage("HIBA: " + strings.TrimSpace(err.Error()))
}

func logBrowserMessage(message string) {
	file, openErr := os.OpenFile(filepath.Join(os.TempDir(), "name_number_copy_browser.log"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if openErr == nil {
		defer file.Close()
		fmt.Fprintf(file, "%s | %s\n", time.Now().Format(time.RFC3339), message)
	}
}
