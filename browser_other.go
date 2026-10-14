//go:build !windows

package main

import "os/exec"

func findLocalBrowser(string) string    { return "" }
func configureBrowserProcess(*exec.Cmd) {}
