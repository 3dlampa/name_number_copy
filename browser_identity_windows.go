//go:build windows

package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"os"
	"strings"
	"syscall"
	"unsafe"
)

var procGetExtendedTCPTable = syscall.NewLazyDLL("iphlpapi.dll").NewProc("GetExtendedTcpTable")
var procProcessIDToSessionID = syscall.NewLazyDLL("kernel32.dll").NewProc("ProcessIdToSessionId")

func processBrowserIdentity(pid uint32) (browserIdentity, error) {
	handle, err := syscall.OpenProcess(0x1000, false, pid)
	if err != nil {
		return browserIdentity{}, err
	}
	defer syscall.CloseHandle(handle)
	current, err := syscall.GetCurrentProcess()
	if err != nil {
		return browserIdentity{}, err
	}
	owner := func(process syscall.Handle) (string, error) {
		var token syscall.Token
		if err := syscall.OpenProcessToken(process, syscall.TOKEN_QUERY, &token); err != nil {
			return "", err
		}
		defer token.Close()
		user, err := token.GetTokenUser()
		if err != nil {
			return "", err
		}
		return user.User.Sid.String()
	}
	want, err := owner(current)
	if err != nil {
		return browserIdentity{}, err
	}
	got, err := owner(handle)
	if err != nil || got != want {
		return browserIdentity{}, errors.New("a böngésző másik Windows-fiókhoz tartozik")
	}
	var thisSession, otherSession uint32
	first, _, e1 := procProcessIDToSessionID.Call(uintptr(os.Getpid()), uintptr(unsafe.Pointer(&thisSession)))
	second, _, e2 := procProcessIDToSessionID.Call(uintptr(pid), uintptr(unsafe.Pointer(&otherSession)))
	if first == 0 {
		return browserIdentity{}, e1
	}
	if second == 0 {
		return browserIdentity{}, e2
	}
	if thisSession != otherSession {
		return browserIdentity{}, errors.New("a böngésző másik Windows-munkamenetben fut")
	}
	var created, exit, kernel, user syscall.Filetime
	if err := syscall.GetProcessTimes(handle, &created, &exit, &kernel, &user); err != nil {
		return browserIdentity{}, err
	}
	return browserIdentity{pid, uint64(created.HighDateTime)<<32 | uint64(created.LowDateTime)}, nil
}

func browserEndpointIdentity(port int) (browserIdentity, error) {
	var size uint32
	code, _, _ := procGetExtendedTCPTable.Call(0, uintptr(unsafe.Pointer(&size)), 0, 2, 3, 0) // IPv4, OWNER_PID_LISTENER.
	for attempt := 0; attempt < 3; attempt++ {
		if code != 122 || size < 4 || size > 16<<20 {
			return browserIdentity{}, fmt.Errorf("TCP tulajdonos nem olvasható: %d", code)
		}
		buffer := make([]byte, size)
		code, _, _ = procGetExtendedTCPTable.Call(uintptr(unsafe.Pointer(&buffer[0])), uintptr(unsafe.Pointer(&size)), 0, 2, 3, 0)
		if code == 122 {
			continue
		}
		if code != 0 {
			return browserIdentity{}, fmt.Errorf("TCP tábla hiba: %d", code)
		}
		count := int(binary.LittleEndian.Uint32(buffer[:4]))
		if count > (len(buffer)-4)/24 {
			return browserIdentity{}, errors.New("érvénytelen TCP tábla")
		}
		for i := 0; i < count; i++ {
			row := buffer[4+i*24 : 4+(i+1)*24]
			if int(binary.BigEndian.Uint16(row[8:10])) == port && row[4] == 127 && row[5] == 0 && row[6] == 0 && row[7] == 1 {
				return processBrowserIdentity(binary.LittleEndian.Uint32(row[20:24]))
			}
		}
		return browserIdentity{}, errors.New("nem található helyi CDP-listener")
	}
	return browserIdentity{}, errors.New("a TCP tábla folyamatosan változik")
}

func browserProcessRunning(exe string) (bool, error) {
	snapshot, err := syscall.CreateToolhelp32Snapshot(syscall.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return false, err
	}
	defer syscall.CloseHandle(snapshot)
	entry := syscall.ProcessEntry32{Size: uint32(unsafe.Sizeof(syscall.ProcessEntry32{}))}
	err = syscall.Process32First(snapshot, &entry)
	for err == nil {
		if strings.EqualFold(syscall.UTF16ToString(entry.ExeFile[:]), exe) {
			if _, checkErr := processBrowserIdentity(entry.ProcessID); checkErr == nil {
				return true, nil
			}
		}
		err = syscall.Process32Next(snapshot, &entry)
	}
	if err != syscall.ERROR_NO_MORE_FILES {
		return false, err
	}
	return false, nil
}
