//go:build windows

package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"unsafe"
)

func findLocalBrowser(name string) string {
	subpath := browserSubpaths[name]
	if subpath == "" {
		return ""
	}
	var paths []string
	for _, hive := range []syscall.Handle{syscall.HKEY_CURRENT_USER, syscall.HKEY_LOCAL_MACHINE} {
		for _, keyRoot := range []string{`SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\`, `SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\`} {
			keyName, _ := syscall.UTF16PtrFromString(keyRoot + filepath.Base(subpath))
			var key syscall.Handle
			if syscall.RegOpenKeyEx(hive, keyName, 0, syscall.KEY_READ, &key) != nil {
				continue
			}
			var kind, size uint32
			if syscall.RegQueryValueEx(key, nil, nil, &kind, nil, &size) == nil && size > 0 && size <= 65536 && (kind == syscall.REG_SZ || kind == syscall.REG_EXPAND_SZ) {
				buffer := make([]uint16, (size+1)/2)
				if syscall.RegQueryValueEx(key, nil, nil, &kind, (*byte)(unsafe.Pointer(&buffer[0])), &size) == nil {
					value := strings.Trim(syscall.UTF16ToString(buffer), `"`)
					if kind == syscall.REG_EXPAND_SZ {
						value = expandWindowsEnvironment(value)
					}
					paths = append(paths, value)
				}
			}
			syscall.RegCloseKey(key)
		}
	}
	for _, variable := range []string{"LOCALAPPDATA", "ProgramFiles", "ProgramFiles(x86)"} {
		if root := os.Getenv(variable); root != "" {
			paths = append(paths, filepath.Join(root, subpath))
		}
	}
	for _, path := range paths {
		if info, err := os.Stat(path); err == nil && !info.IsDir() {
			return path
		}
	}
	return ""
}

func expandWindowsEnvironment(value string) string {
	// Windows registry values use %NAME%, not Go's $NAME expansion.
	var result strings.Builder
	for len(value) > 0 {
		start := strings.IndexByte(value, '%')
		if start < 0 {
			result.WriteString(value)
			break
		}
		result.WriteString(value[:start])
		value = value[start:]
		end := strings.IndexByte(value[1:], '%')
		if end < 0 {
			result.WriteString(value)
			break
		}
		end++
		token := value[:end+1]
		name := value[1:end]
		if replacement, ok := os.LookupEnv(name); ok {
			result.WriteString(replacement)
		} else {
			result.WriteString(token)
		}
		value = value[end+1:]
	}
	return result.String()
}

func configureBrowserProcess(command *exec.Cmd) {
	command.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
}
