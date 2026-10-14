package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"testing"
	"time"
)

type cdpTestFrame struct {
	opcode  byte
	final   bool
	payload []byte
}

func writeCDPTestHeader(w io.Writer, opcode byte, final bool, n uint64) error {
	var header bytes.Buffer
	if final {
		opcode |= 0x80
	}
	header.WriteByte(opcode)
	switch {
	case n <= 125:
		header.WriteByte(byte(n))
	case n <= 65535:
		header.WriteByte(126)
		_ = binary.Write(&header, binary.BigEndian, uint16(n))
	default:
		header.WriteByte(127)
		_ = binary.Write(&header, binary.BigEndian, n)
	}
	_, err := w.Write(header.Bytes())
	return err
}

func runCDPFrameTest(t *testing.T, frames []cdpTestFrame, deadline bool) (browserData, error, error) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	done := make(chan error, 1)
	go func() {
		c, err := ln.Accept()
		if err != nil {
			done <- err
			return
		}
		defer c.Close()
		_ = c.SetDeadline(time.Now().Add(3 * time.Second))
		r := bufio.NewReader(c)
		req, err := http.ReadRequest(r)
		if err != nil {
			done <- err
			return
		}
		accept := sha1.Sum([]byte(req.Header.Get("Sec-WebSocket-Key") + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
		_, err = fmt.Fprintf(c, "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n", base64.StdEncoding.EncodeToString(accept[:]))
		if err != nil {
			done <- err
			return
		}
		if _, _, _, err = readFrame(r); err != nil {
			done <- err
			return
		}
		for _, f := range frames {
			if err = writeCDPTestHeader(c, f.opcode, f.final, uint64(len(f.payload))); err != nil {
				done <- err
				return
			}
			if _, err = c.Write(f.payload); err != nil {
				done <- err
				return
			}
			if f.opcode == 9 {
				op, fin, payload, pongErr := readFrame(r)
				if pongErr != nil {
					done <- pongErr
					return
				}
				if op != 10 || !fin || !bytes.Equal(payload, f.payload) {
					done <- fmt.Errorf("incorrect pong")
					return
				}
			}
		}
		if deadline {
			// Keep the socket open until the client's unchanged deadline closes it.
			_, err = r.ReadByte()
			if err != io.EOF {
				done <- fmt.Errorf("expected deadline closure, got %v", err)
				return
			}
		}
		done <- nil
	}()
	port := fmt.Sprint(ln.Addr().(*net.TCPAddr).Port)
	timeout := 2 * time.Second
	if deadline {
		timeout = 100 * time.Millisecond
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	value := browserData{Name: "unchanged"}
	err = cdpCommandWithPortFilter(ctx, "ws://127.0.0.1:"+port+"/devtools/page/1", "Runtime.evaluate", nil, &value, func(p string) bool { return p == port })
	return value, err, <-done
}

func TestCDPMessageFragments(t *testing.T) {
	const limit = 4 << 20
	reply := []byte(`{"id":1,"result":{"result":{"value":{"name":"Matyikó Tamás","sos":true,"lang":"hu-HU"}}}}`)
	event := []byte(`{"method":"Runtime.consoleAPICalled"}`)
	data := func(op byte, fin bool, p []byte) cdpTestFrame { return cdpTestFrame{op, fin, p} }
	valid := data(1, true, reply)
	padding := bytes.Repeat([]byte(" "), limit-len(reply))
	exact := append(append([]byte(nil), padding...), reply...)
	many := []cdpTestFrame{data(1, false, bytes.Repeat([]byte(" "), 65536))}
	for i := 1; i < limit/65536; i++ {
		many = append(many, data(0, false, bytes.Repeat([]byte(" "), 65536)))
	}
	many = append(many, data(0, true, reply))
	tests := []struct {
		name     string
		frames   []cdpTestFrame
		wantErr  string
		deadline bool
	}{
		{"unfragmented text", []cdpTestFrame{valid}, "", false},
		{"unfragmented binary", []cdpTestFrame{data(2, true, reply)}, "", false},
		{"fragmented text with controls", []cdpTestFrame{data(1, false, reply[:20]), data(9, true, []byte("ping")), data(10, true, []byte("pong")), data(0, false, reply[20:40]), data(0, true, reply[40:])}, "", false},
		{"fragmented binary", []cdpTestFrame{data(2, false, reply[:20]), data(0, true, reply[20:])}, "", false},
		{"empty fragments", []cdpTestFrame{data(1, false, nil), data(0, false, nil), data(0, false, reply), data(0, true, nil)}, "", false},
		{"exact limit fragmented with ping", []cdpTestFrame{data(1, false, exact), data(9, true, []byte("ping")), data(0, true, nil)}, "", false},
		{"exact limit unfragmented", []cdpTestFrame{data(1, true, exact)}, "", false},
		{"two fragments exceed limit", []cdpTestFrame{data(1, false, exact), data(0, true, []byte(" "))}, "túl nagy CDP válasz", false},
		{"many small fragments exceed limit", many, "túl nagy CDP válasz", false},
		{"single frame exceeds limit", []cdpTestFrame{data(1, true, append(append([]byte(nil), exact...), ' '))}, "túl nagy CDP válasz", false},
		{"standalone continuation", []cdpTestFrame{data(0, true, reply)}, "CDP folytatókeret kezdő üzenet nélkül", false},
		{"nonfinal standalone continuation", []cdpTestFrame{data(0, false, nil)}, "CDP folytatókeret kezdő üzenet nélkül", false},
		{"text interrupts fragments", []cdpTestFrame{data(1, false, nil), valid}, "új CDP üzenet befejezetlen töredékek közben", false},
		{"binary interrupts fragments", []cdpTestFrame{data(1, false, reply[:20]), data(2, false, reply)}, "új CDP üzenet befejezetlen töredékek közben", false},
		{"continuation after completed event", []cdpTestFrame{data(1, true, event), data(0, true, reply)}, "CDP folytatókeret kezdő üzenet nélkül", false},
		{"continuation after invalid JSON", []cdpTestFrame{data(1, true, []byte("{")), data(0, true, reply)}, "CDP folytatókeret kezdő üzenet nélkül", false},
		{"fresh message after event", []cdpTestFrame{data(1, false, event[:10]), data(0, true, event[10:]), valid}, "", false},
		{"fresh message after invalid JSON", []cdpTestFrame{data(1, false, []byte("{")), data(0, true, nil), valid}, "", false},
		{"unfinished message deadline", []cdpTestFrame{data(1, false, reply[:20])}, "", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			value, err, serverErr := runCDPFrameTest(t, tt.frames, tt.deadline)
			if tt.deadline {
				if e, ok := err.(net.Error); !ok || !e.Timeout() {
					t.Fatalf("expected timeout, got %v", err)
				}
			} else if tt.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
					t.Fatalf("expected %q, got %v", tt.wantErr, err)
				}
			} else {
				if err != nil || serverErr != nil {
					t.Fatalf("client=%v server=%v", err, serverErr)
				}
				if value.Name != "Matyikó Tamás" || !value.SOS || value.Lang != "hu-HU" {
					t.Fatalf("incorrect value: %+v", value)
				}
			}
			if (tt.wantErr != "" || tt.deadline) && value.Name != "unchanged" {
				t.Fatalf("rejected response changed destination: %+v", value)
			}
		})
	}
}

func TestReadFrameMessageBudgetBeforePayload(t *testing.T) {
	for _, op := range []byte{0, 1, 2} {
		for _, size := range []uint64{2, 126, 65536} {
			t.Run(fmt.Sprintf("opcode%d_length%d", op, size), func(t *testing.T) {
				var wire bytes.Buffer
				if err := writeCDPTestHeader(&wire, op, true, size); err != nil {
					t.Fatal(err)
				}
				// No payload is supplied: rejection must happen from the declared size.
				_, _, payload, err := readFrameWithLimit(&wire, 1)
				if err == nil || err.Error() != "túl nagy CDP válasz" || payload != nil {
					t.Fatalf("payload=%v err=%v", payload, err)
				}
			})
		}
	}
	for _, op := range []byte{9, 10} {
		var wire bytes.Buffer
		if err := writeCDPTestHeader(&wire, op, true, 1); err != nil {
			t.Fatal(err)
		}
		wire.WriteByte('x')
		_, _, payload, err := readFrameWithLimit(&wire, 0)
		if err != nil || string(payload) != "x" {
			t.Fatalf("control frame: payload=%q err=%v", payload, err)
		}
	}
	var wire bytes.Buffer
	if err := writeCDPTestHeader(&wire, 1, true, (4<<20)+1); err != nil {
		t.Fatal(err)
	}
	_, _, payload, err := readFrame(&wire)
	if err == nil || err.Error() != "túl nagy CDP válasz" || payload != nil {
		t.Fatalf("original per-frame bound lost: %v", err)
	}
}
