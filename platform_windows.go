//go:build windows

package main

import (
	"errors"
	"fmt"
	"runtime"
	"syscall"
	"time"
	"unicode/utf16"
	"unsafe"
)

var (
	kernel32                = syscall.NewLazyDLL("kernel32.dll")
	user32                  = syscall.NewLazyDLL("user32.dll")
	procAllocConsole        = kernel32.NewProc("AllocConsole")
	procFreeConsole         = kernel32.NewProc("FreeConsole")
	procGetStdHandle        = kernel32.NewProc("GetStdHandle")
	procSetConsoleTitleW    = kernel32.NewProc("SetConsoleTitleW")
	procGetConsoleMode      = kernel32.NewProc("GetConsoleMode")
	procSetConsoleMode      = kernel32.NewProc("SetConsoleMode")
	procReadConsoleW        = kernel32.NewProc("ReadConsoleW")
	procWriteConsoleW       = kernel32.NewProc("WriteConsoleW")
	procGetConsoleWindow    = kernel32.NewProc("GetConsoleWindow")
	procGetForegroundWindow = user32.NewProc("GetForegroundWindow")
	procSetForegroundWindow = user32.NewProc("SetForegroundWindow")
	procGetWindowThreadID   = user32.NewProc("GetWindowThreadProcessId")
	procGetCurrentThreadID  = kernel32.NewProc("GetCurrentThreadId")
	procAttachThreadInput   = user32.NewProc("AttachThreadInput")
	procBringWindowToTop    = user32.NewProc("BringWindowToTop")
	procIsWindow            = user32.NewProc("IsWindow")
	procShowWindow          = user32.NewProc("ShowWindow")
	procOpenClipboard       = user32.NewProc("OpenClipboard")
	procCloseClipboard      = user32.NewProc("CloseClipboard")
	procEmptyClipboard      = user32.NewProc("EmptyClipboard")
	procSetClipboardData    = user32.NewProc("SetClipboardData")
	procGlobalAlloc         = kernel32.NewProc("GlobalAlloc")
	procGlobalLock          = kernel32.NewProc("GlobalLock")
	procGlobalUnlock        = kernel32.NewProc("GlobalUnlock")
	procGlobalFree          = kernel32.NewProc("GlobalFree")
	procCreateWindowExW     = user32.NewProc("CreateWindowExW")
	procDestroyWindow       = user32.NewProc("DestroyWindow")
)

const (
	stdInputHandle  = ^uintptr(9)
	stdOutputHandle = ^uintptr(10)
	cfUnicodeText   = 13
	gmemMoveable    = 2
)

var consoleIn uintptr
var consoleOut uintptr

func getForegroundWindow() uintptr { h, _, _ := procGetForegroundWindow.Call(); return h }

// A választó előtt aktív, tetszőleges Windows-ablakot aktiváljuk újra.
// A SetForegroundWindow hívást a Windows előtér-aktiválási szabályai
// időnként letiltják. Ilyenkor rövid időre összekapcsoljuk az
// inputszálakat, majd minden kapcsolatot visszabontunk.
func restoreForeground(hwnd uintptr) {
	if hwnd == 0 {
		return
	}
	valid, _, _ := procIsWindow.Call(hwnd)
	if valid == 0 || getForegroundWindow() == hwnd {
		return
	}
	procSetForegroundWindow.Call(hwnd)
	if getForegroundWindow() == hwnd {
		return
	}

	// Ez csak a többrendeléses konzolválasztó lezárásakor fut.
	// Nem állítunk fókuszt alkalmazásnév alapján és nem aktiváljuk a böngészőt.
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	currentThread, _, _ := procGetCurrentThreadID.Call()
	targetThread, _, _ := procGetWindowThreadID.Call(hwnd, 0)
	foreground := getForegroundWindow()
	foregroundThread, _, _ := procGetWindowThreadID.Call(foreground, 0)
	attach := func(other uintptr) bool {
		if other == 0 || other == currentThread {
			return false
		}
		ok, _, _ := procAttachThreadInput.Call(currentThread, other, 1)
		return ok != 0
	}
	attachedForeground := attach(foregroundThread)
	attachedTarget := false
	if targetThread != foregroundThread {
		attachedTarget = attach(targetThread)
	}
	defer func() {
		if attachedTarget {
			procAttachThreadInput.Call(currentThread, targetThread, 0)
		}
		if attachedForeground {
			procAttachThreadInput.Call(currentThread, foregroundThread, 0)
		}
	}()
	procBringWindowToTop.Call(hwnd)
	procSetForegroundWindow.Call(hwnd)
}
func openChoiceConsole() error {
	success, _, callErr := procAllocConsole.Call()
	if success == 0 {
		return fmt.Errorf("AllocConsole: %v", callErr)
	}
	ready := false
	defer func() {
		if !ready {
			procFreeConsole.Call()
			consoleIn = 0
			consoleOut = 0
		}
	}()
	consoleIn, _, _ = procGetStdHandle.Call(stdInputHandle)
	consoleOut, _, _ = procGetStdHandle.Call(stdOutputHandle)
	if consoleIn == 0 || consoleOut == 0 || consoleIn == ^uintptr(0) || consoleOut == ^uintptr(0) {
		return errors.New("hiányzó konzol kimenet/bemenet")
	}
	title := syscall.StringToUTF16("Név és rendelésszám másoló - rendelésválasztó")
	procSetConsoleTitleW.Call(uintptr(unsafe.Pointer(&title[0])))
	// Kapcsoljuk ki a soros bevitelt és a visszhangot: egyetlen gomb lenyomása elegendő.
	const enableProcessedInput = 0x0001
	var original uint32
	r, _, _ := procGetConsoleMode.Call(consoleIn, uintptr(unsafe.Pointer(&original)))
	if r == 0 {
		return errors.New("GetConsoleMode sikertelen")
	}
	r, _, _ = procSetConsoleMode.Call(consoleIn, enableProcessedInput)
	if r == 0 {
		return errors.New("SetConsoleMode sikertelen")
	}
	window, _, _ := procGetConsoleWindow.Call()
	if window != 0 {
		procShowWindow.Call(window, 5)       // SW_SHOW
		procSetForegroundWindow.Call(window) // csak a választó kap billentyűfókuszt
	}
	ready = true
	return nil
}
func closeChoiceConsole() {
	procFreeConsole.Call()
	consoleIn = 0
	consoleOut = 0
}
func writeChoiceConsole(s string) {
	if consoleOut == 0 {
		return
	}
	u := utf16.Encode([]rune(s))
	if len(u) == 0 {
		return
	}
	var written uint32
	procWriteConsoleW.Call(consoleOut, uintptr(unsafe.Pointer(&u[0])), uintptr(len(u)), uintptr(unsafe.Pointer(&written)), 0)
}
func readChoiceConsole(count int) (int, error) {
	if count <= 0 {
		return -1, errors.New("nincs rendelés")
	}
	digits := ""
	for {
		var unit uint16
		var n uint32
		r, _, e := procReadConsoleW.Call(consoleIn, uintptr(unsafe.Pointer(&unit)), 1, uintptr(unsafe.Pointer(&n)), 0)
		if r == 0 {
			return -1, fmt.Errorf("ReadConsoleW: %v", e)
		}
		if n == 0 {
			continue
		}
		if unit == 27 {
			return -1, nil
		} // ESC
		if unit == '\b' {
			if digits != "" {
				digits = digits[:len(digits)-1]
			}
			continue
		}
		if unit >= '0' && unit <= '9' {
			// 1-9 azonnali választás, 10+ esetén: 0, sorszám, Enter.
			// Így az első kilenc sorszám több mint kilenc rendelésnél is egyetlen gomb marad.
			if digits == "" && unit >= '1' && unit <= '9' {
				idx := int(unit - '1')
				if idx < count {
					return idx, nil
				}
				continue
			}
			digits += string(rune(unit))
			if len(digits) > 5 {
				digits = ""
			}
		} else if (unit == '\r' || unit == '\n') && digits != "" {
			if digits[0] == '0' {
				value, err := strconvAtoiSafe(digits[1:])
				if err == nil && value >= 10 && value <= count {
					return value - 1, nil
				}
			}
			digits = ""
		}
	}
}
func strconvAtoiSafe(s string) (int, error) {
	if len(s) > 4 {
		return 0, errors.New("túl hosszú szám")
	}
	val := 0
	for _, r := range s {
		if r < '0' || r > '9' {
			return 0, errors.New("nem szám")
		}
		val = val*10 + int(r-'0')
	}
	return val, nil
}
func copyClipboard(value string) error {
	// A Windows csak érvényes ablakhoz társított OpenClipboard / EmptyClipboard
	// után engedi megbízhatóan a SetClipboardData műveletet. Nulla HWND hibás.
	// Egy LÁTHATATLAN HWND jön létre: nem jelenik meg ablak, nem változik a fókusz.
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	class := syscall.StringToUTF16("STATIC")
	title := syscall.StringToUTF16("name-number-copy clipboard")
	owner, _, e := procCreateWindowExW.Call(0, uintptr(unsafe.Pointer(&class[0])), uintptr(unsafe.Pointer(&title[0])), 0, 0, 0, 0, 0, 0, 0, 0, 0)
	if owner == 0 {
		return fmt.Errorf("rejtett clipboard ablak nem hozható létre: %v", e)
	}
	defer procDestroyWindow.Call(owner)

	utf := utf16.Encode([]rune(value))
	utf = append(utf, 0)
	var ok uintptr
	for retry := 0; retry < 12; retry++ {
		ok, _, _ = procOpenClipboard.Call(owner)
		if ok != 0 {
			break
		}
		time.Sleep(30 * time.Millisecond)
	}
	if ok == 0 {
		return errors.New("nem nyitható meg a Windows vágólap")
	}
	defer procCloseClipboard.Call()

	handle, _, _ := procGlobalAlloc.Call(gmemMoveable, uintptr(len(utf)*2))
	if handle == 0 {
		return errors.New("GlobalAlloc sikertelen")
	}
	ptr, _, _ := procGlobalLock.Call(handle)
	if ptr == 0 {
		procGlobalFree.Call(handle)
		return errors.New("GlobalLock sikertelen")
	}
	dst := unsafe.Slice((*uint16)(unsafe.Pointer(ptr)), len(utf))
	copy(dst, utf)
	procGlobalUnlock.Call(handle)
	ok, _, _ = procEmptyClipboard.Call()
	if ok == 0 {
		procGlobalFree.Call(handle)
		return errors.New("EmptyClipboard sikertelen")
	}
	ok, _, _ = procSetClipboardData.Call(cfUnicodeText, handle)
	if ok == 0 {
		procGlobalFree.Call(handle)
		return errors.New("SetClipboardData sikertelen")
	}
	// Siker esetén a globális memóriát a Windows birtokolja, nem szabad felszabadítani.
	return nil
}