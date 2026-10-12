//go:build !windows

package main

import "fmt"

func getForegroundWindow() uintptr       { return 0 }
func restoreForeground(uintptr)          {}
func openChoiceConsole() error           { return fmt.Errorf("csak Windowson fut") }
func closeChoiceConsole()                {}
func writeChoiceConsole(string)          {}
func readChoiceConsole(int) (int, error) { return -1, fmt.Errorf("csak Windowson fut") }
func copyClipboard(string) error         { return fmt.Errorf("csak Windowson fut") }