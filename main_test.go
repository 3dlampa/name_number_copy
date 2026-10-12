package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"testing"
	"time"
)

func mkTab(host, id, port string) tab {
	return tab{Type: "page", URL: "https://" + host + "/proadmin/index.php?route=sale/order/info&user_token=xyz&order_id=" + id, WS: "ws://127.0.0.1:" + port + "/devtools/page/1"}
}

func TestUniqueOrdersAndInvisibleSingleOrder(t *testing.T) {
	single := uniqueOrders([]tab{mkTab("3dlampa.hu", "132688", "9222"), mkTab("www.3dlampa.hu", "132688", "9223")})
	if len(single) != 1 || shouldShowChoiceConsole(single) {
		t.Fatalf("duplikált megnyitásnál nem jelenhet meg konzol: %+v", single)
	}
	all := append(single, uniqueOrders([]tab{mkTab("3dlampa.ro", "120", "9223")})...)
	if !shouldShowChoiceConsole(all) {
		t.Fatal("több egyedi rendelésnél kötelező a választó")
	}
	if shouldShowChoiceConsole(nil) {
		t.Fatal("üres listánál nem nyílhat konzol")
	}
}
func TestPrefixAndSOS(t *testing.T) {
	tests := map[string]string{"3dlampa.hu": "HU", "3dmeglepetes.hu": "HU", "3dlampa.ro": "RO", "3dlampa.sk": "SK", "3dlampa.cz": "CZ", "3dlampa.pl": "PL", "3dlampa.bg": "BG"}
	for host, expected := range tests {
		o, ok := parseTab(mkTab(host, "132688", "9222"))
		if !ok {
			t.Fatalf("nem olvasható URL: %s", host)
		}
		if o.Code != expected {
			t.Fatalf("%s -> %s a(z) %s helyett", host, o.Code, expected)
		}
		o.Name = "Matyikó Tamás"
		if got := formatValue(o); got != expected+" 132688 - Matyikó Tamás -" {
			t.Errorf("%s: %q", host, got)
		}
		o.SOS = true
		if got := formatValue(o); got != expected+" 132688 - SOS - Matyikó Tamás -" {
			t.Errorf("SOS %s: %q", host, got)
		}
	}
}
func TestRejectOrderListAndMalformedURLs(t *testing.T) {
	bad := []string{
		"https://3dlampa.hu/proadmin/index.php?route=sale/order&user_token=x&order_id=11",
		"https://3dlampa.hu/proadmin/index.php?route=sale/order/info&user_token=x",
		"https://3dlampa.hu/proadmin/index.php?route=sale/order/info&order_id=12",
		"https://3dlampa.hu/proadmin/index.php?route=sale/order/info&order_id=abc&user_token=x",
		"file:///C:/Scripts/orders",
	}
	for _, u := range bad {
		_, ok := parseTab(tab{Type: "page", URL: u, WS: "ws://127.0.0.1:9222/devtools/page/1"})
		if ok {
			t.Errorf("tiltott URL elfogadva: %s", u)
		}
	}
}
func TestWebSocketFrames(t *testing.T) {
	for _, sz := range []int{4, 126, 90000} {
		v := bytes.Repeat([]byte("a"), sz)
		var b bytes.Buffer
		if err := sendFrame(&b, 1, v); err != nil {
			t.Fatal(err)
		}
		op, fin, actual, err := readFrame(&b)
		if err != nil || op != 1 || !fin || !bytes.Equal(v, actual) {
			t.Fatalf("keret méret=%d op=%d fin=%v err=%v", sz, op, fin, err)
		}
	}
}
func writeUnmaskedServerFrame(w io.Writer, payload []byte) error {
	var b bytes.Buffer
	b.WriteByte(0x81)
	if len(payload) <= 125 {
		b.WriteByte(byte(len(payload)))
	} else {
		b.WriteByte(126)
		_ = binary.Write(&b, binary.BigEndian, uint16(len(payload)))
	}
	b.Write(payload)
	_, err := w.Write(b.Bytes())
	return err
}
func TestCDPHandshakeAndExtractObject(t *testing.T) {
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
		r := bufio.NewReader(c)
		req, err := http.ReadRequest(r)
		if err != nil {
			done <- err
			return
		}
		key := req.Header.Get("Sec-WebSocket-Key")
		accept := sha1.Sum([]byte(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
		_, err = fmt.Fprintf(c, "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n", base64.StdEncoding.EncodeToString(accept[:]))
		if err != nil {
			done <- err
			return
		}
		_, _, frame, err := readFrame(r)
		if err != nil {
			done <- err
			return
		}
		var cmd struct {
			Method string `json:"method"`
			Params struct {
				Expression string `json:"expression"`
			} `json:"params"`
		}
		if err = json.Unmarshal(frame, &cmd); err != nil {
			done <- err
			return
		}
		if cmd.Method != "Runtime.evaluate" || !strings.Contains(cmd.Params.Expression, "Customer info") {
			done <- fmt.Errorf("bad CDP query: %v", cmd.Method)
			return
		}
		text := []byte(`{"id":1,"result":{"result":{"value":{"name":"Matyikó Tamás","sos":true,"lang":"hu-HU"}}}}`)
		done <- writeUnmaskedServerFrame(c, text)
	}()
	port := ln.Addr().(*net.TCPAddr).Port
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	var value browserData
	u := fmt.Sprintf("ws://127.0.0.1:%d/devtools/page/1", port)
	err = cdpCommandWithPortFilter(ctx, u, "Runtime.evaluate", map[string]any{"expression": extractorJS, "returnByValue": true}, &value, func(p string) bool { return p == fmt.Sprint(port) })
	if err != nil {
		t.Fatal(err)
	}
	if value.Name != "Matyikó Tamás" || !value.SOS {
		t.Fatalf("hibás CDP kiolvasás: %+v", value)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}
func TestRejectForeignWebSocket(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	var v browserData
	for _, u := range []string{"ws://8.8.8.8:9222/devtools/page/1", "ws://127.0.0.1:12345/devtools/page/1", "wss://127.0.0.1:9222/devtools/page/1"} {
		err := cdpCommand(ctx, u, "Runtime.evaluate", nil, &v)
		if err == nil {
			t.Fatalf("tiltott kapcsolat elfogadva: %s", u)
		}
	}
}
func TestExtractJS(t *testing.T) {
	for _, s := range []string{"Vásárló adatok", "Vevő adatok", "Customer details", "Customer info", "SOS|S\\.\\s*O"} {
		if !strings.Contains(extractorJS, s) {
			t.Errorf("hiányzó kinyerési minta: %s", s)
		}
	}
}