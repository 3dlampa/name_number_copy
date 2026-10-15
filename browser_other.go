//go:build !windows

package main

import (
	"errors"
	"os/exec"
)

func findLocalBrowser(string) string    { return "" }
func configureBrowserProcess(*exec.Cmd) {}
func showBrowserStartError(error)       {}
func browserEndpointIdentity(int) (browserIdentity, error) {
	return browserIdentity{}, errors.New("Windows szükséges")
}
func browserProcessRunning(string) (bool, error) { return false, errors.New("Windows szükséges") }
