package main

import (
	_ "embed"
	"bufio"
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

// 2026-10-12: A korábbi, konzol nélküli Go EXE működésének rekonstruált kiadása.
// Konzol kizárólag akkor nyílik, ha több KÜLÖNBÖZŐ rendelés közül kell választani.
// Nem használ Python-t, nem aktiválja a böngészőfüleket.
//go:embed VERSION
var embeddedVersion string

// Az EXE verziója a kiadás egységes VERSION fájljából származik.
var appVersion = strings.TrimSpace(embeddedVersion)

var ports = []string{"9222", "9223"} // Brave és egy második Chromium-alapú böngésző

// A feltöltött eredeti EXE-ből azonosított Javascript kinyerő, szó szerint megtartva.
const extractorJS = `(() => {
  const clean = s => String(s || '').replace(/\s+/g, ' ').trim();
  const raw = document.body ? String(document.body.innerText || document.body.textContent || '') : '';
  const text = clean(raw);
  const sos = /(^|[^A-Za-zÁÉÍÓÖŐÚÜŰáéíóöőúüű0-9])(?:SOS|S\.\s*O\.\s*S\.)(?=$|[^A-Za-zÁÉÍÓÖŐÚÜŰáéíóöőúüű0-9])/i.test(text);
  // A magyar/angol felismerés megmarad; román, szlovák és cseh címsorokkal bővül.
  const marker = /(?:Vásárló adatok|Vevő adatok|Customer details|Customer info|Customer information|Date(?:le)? client(?:ului)?|Detalii(?:le)? client(?:ului)?|Detalii despre client|Informa(?:ț|ţ|t)ii(?:le)? (?:despre )?client(?:ului)?|Date (?:cumpărător|cumparator)|Informácie o zákazníkovi|Údaje o zákazníkovi|Zákaznícke údaje|Informace o zákazníkovi|Údaje zákazníka)/i;
  const stop = /(?:Magánszemély|Cég|E-mail|Email|Telefon|Telefón|Phone|Telephone|Lehetőségek|Opțiuni|Optiuni|Persoan(?:ă|a) fizic(?:ă|a)|Persoan(?:ă|a) juridic(?:ă|a)|Companie|Firma|Customer group|Adresa|Address|Facturare|Livrare|Doručenie|Doprava|Platba|Payment)/i;
  const bad = /^(?:vevő|vásárló|ügyfél|customer(?: name)?|client(?:ul)?|nume(?:le)?(?: client(?:ului)?)?|prenume(?:le)?|nume și prenume|name|first ?name|last ?name|név|magánszemély|cég|email|e-mail|telefon|phone|persoană fizică|persoana fizica|persoană juridică|persoana juridica|opțiuni|optiuni|comanda|comandă|detalii(?: client)?|date(?:le)? client(?:ului)?|informații(?: client)?|informaţii(?: client)?|szerkesztés|edit|törlés|delete|megtekintés|view|rendelés|orders?)$/i;
  function valid(input) {
    const s = clean(input).replace(/^[\s\-–:]+|[\s\-–:]+$/g, '');
    if (s.length < 3 || s.length > 140 || bad.test(s)) return '';
    if (/[@<>\[\]{}]|https?:\/\/|www\./i.test(s)) return '';
    if (/^\+?[0-9][0-9\s().-]+$/.test(s) || /^\d+$/.test(s)) return '';
    if (/\b(?:telefon|email|e-mail|opțiuni|optiuni|customer group|persoană fizică|persoana fizica)\b/i.test(s)) return '';
    return s;
  }
  const delabel = s => clean(s).replace(/^(?:Nume(?:le)?(?: client(?:ului)?)?|Prenume(?:le)?|Client(?:ul)?|Customer|Vevő|Vásárló|Name|Név)\s*[:：-]\s*/i, '');
  const stops = new RegExp('\\s+(?:' + stop.source.slice(3, -1) + '|\\+\\d|[\\w.+-]+@[\\w.-]+)(?=\\s|$|[:.])', 'i');
  let name = '';

  // Az ügyfélkártya saját linkje megbízhatóbb, mint a teljes oldal szövege.
  const headings = document.body && document.body.querySelectorAll
    ? document.body.querySelectorAll('.panel-heading, .card-header, .panel-title, h3, h4, legend') : [];
  for (const heading of headings) {
    if (!marker.test(clean(heading.innerText || heading.textContent || ''))) continue;
    const panel = heading.closest ? heading.closest('.panel, .card, .box') : null;
    if (!panel || !panel.querySelectorAll) continue;
    const links = panel.querySelectorAll('a[href*="route=customer/customer"], a[href*="customer_id="]');
    for (const a of links) {
      const candidate = valid(a.innerText || a.textContent || '');
      if (candidate && candidate.split(/\s+/).length >= 2) { name = candidate; break; }
    }
    if (name) break;
  }

  // A lokalizált fejléc utáni sorokat elemezzük, nem az egész rendelést.
  if (!name) {
    const lines = raw.split(/[\r\n]+/).map(clean).filter(Boolean);
    const start = lines.findIndex(line => marker.test(line));
    if (start >= 0) {
      const match = marker.exec(lines[start]);
      const inline = lines[start].slice(match.index + match[0].length).replace(/^\s*[:\-]\s*/, '');
      if (inline) name = valid(delabel(inline.split(stops)[0]));
      if (!name) {
        let first = '', last = '';
        for (const line of lines.slice(start + 1, start + 12)) {
          if (stop.test(line) && !/^(?:Nume|Prenume|Client|Vevő|Vásárló)\s*:/i.test(line)) break;
          const fm = /^(?:Prenume|First\s*name|Keresztnév)\s*[:：-]\s*(.+)$/i.exec(line);
          const lm = /^(?:Nume(?:le)?|Last\s*name|Vezetéknév)\s*[:：-]\s*(.+)$/i.exec(line);
          if (fm) { first = valid(fm[1]); continue; }
          if (lm) { last = valid(lm[1]); continue; }
          const candidate = valid(delabel(line));
          if (candidate && candidate.split(/\s+/).length >= 2) { name = candidate; break; }
        }
        if (!name && first && last) name = first + ' ' + last;
      }
    }
  }

  // A korábbi egysoros OpenCart-szövegekhez kompatibilis tartalék.
  if (!name) {
    const m = marker.exec(text);
    if (m) {
      const tail = text.slice(m.index + m[0].length, m.index + m[0].length + 450);
      name = valid(delabel(tail.split(stops)[0]));
    }
  }
  return {name, lang: (document.documentElement && document.documentElement.lang) || '', sos, href: location.href || ''};
})()`

type tab struct {
	Type  string `json:"type"`
	URL   string `json:"url"`
	Title string `json:"title"`
	WS    string `json:"webSocketDebuggerUrl"`
	Port  string `json:"-"`
}

type order struct {
	ID    string
	Host  string
	Shop  string
	Code  string
	URL   string
	Title string
	Tabs  []tab
	Name  string
	SOS   bool
	Err   error
}

var idRegexp = regexp.MustCompile(`^[0-9]{1,20}$`)
var validNameRegexp = regexp.MustCompile(`(?i)^\s*(?:vásárló|vevő|customer|magánszemély|cég|e-mail|email|telefon|lehetőségek|rendelések|orders?)\s*$`)

func shopCode(host string) string {
	host = strings.ToLower(strings.TrimPrefix(host, "www."))
	switch {
	case strings.HasSuffix(host, ".hu"):
		return "HU"
	case strings.HasSuffix(host, ".ro"):
		return "RO"
	case strings.HasSuffix(host, ".sk"):
		return "SK"
	case strings.HasSuffix(host, ".cz"):
		return "CZ"
	case strings.HasSuffix(host, ".pl"):
		return "PL"
	case strings.HasSuffix(host, ".bg"):
		return "BG"
	default:
		return "" // ne adjunk hozzá megalapozatlan országkódot
	}
}

func parseTab(t tab) (order, bool) {
	u, err := url.Parse(t.URL)
	if err != nil || (u.Scheme != "https" && u.Scheme != "http") || t.WS == "" || t.Type != "page" {
		return order{}, false
	}
	q := u.Query()
	route := strings.Trim(q.Get("route"), "/")
	if route != "sale/order/info" && route != "sale/order/edit" {
		return order{}, false
	}
	id := q.Get("order_id")
	if !idRegexp.MatchString(id) || (q.Get("user_token") == "" && q.Get("token") == "") {
		return order{}, false
	}
	host := strings.ToLower(u.Hostname())
	if host == "" {
		return order{}, false
	}
	canonical := strings.TrimPrefix(host, "www.")
	shop := canonical
	switch canonical {
	case "3dlampa.hu":
		shop = "3d lámpa"
	case "3dmeglepetes.hu":
		shop = "3d meglepetés"
	}
	return order{ID: id, Host: canonical, Shop: shop, Code: shopCode(canonical), URL: t.URL, Title: t.Title, Tabs: []tab{t}}, true
}

func uniqueOrders(tabs []tab) []order {
	seen := make(map[string]int)
	var out []order
	for _, t := range tabs {
		o, ok := parseTab(t)
		if !ok {
			continue
		}
		k := o.Host + "|" + o.ID
		if i, exists := seen[k]; exists {
			out[i].Tabs = append(out[i].Tabs, t)
			continue
		}
		seen[k] = len(out)
		out = append(out, o)
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Host != out[j].Host {
			return out[i].Host < out[j].Host
		}
		a, ea := strconv.ParseUint(out[i].ID, 10, 64)
		b, eb := strconv.ParseUint(out[j].ID, 10, 64)
		if ea == nil && eb == nil {
			return a < b
		}
		return out[i].ID < out[j].ID
	})
	return out
}

func formatValue(o order) string {
	// Prefix a számtól és a záró kötőjel után pontosan egy szóközzel.
	prefix := o.ID
	if o.Code != "" {
		prefix = o.Code + " " + prefix
	}
	if o.SOS {
		return fmt.Sprintf("%s - SOS - %s - ", prefix, o.Name)
	}
	return fmt.Sprintf("%s - %s - ", prefix, o.Name)
}

func listTabs() []tab {
	client := http.Client{Timeout: 2200 * time.Millisecond}
	var all []tab
	seen := make(map[string]bool)
	for _, p := range ports {
		for _, path := range []string{"/json/list", "/json"} {
			req, err := http.NewRequest("GET", "http://127.0.0.1:"+p+path, nil)
			if err != nil {
				continue
			}
			resp, err := client.Do(req)
			if err != nil {
				continue
			}
			var ts []tab
			err = json.NewDecoder(io.LimitReader(resp.Body, 3<<20)).Decode(&ts)
			resp.Body.Close()
			if err != nil || resp.StatusCode != 200 {
				continue
			}
			for _, t := range ts {
				if t.WS == "" {
					continue
				}
				k := t.WS
				if !seen[k] {
					seen[k] = true
					t.Port = p
					all = append(all, t)
				}
			}
			break
		}
	}
	return all
}

type browserData struct {
	Name string `json:"name"`
	Lang string `json:"lang"`
	SOS  bool   `json:"sos"`
	Href string `json:"href"`
}

func normalizeName(s string) string {
	s = strings.Join(strings.Fields(strings.ReplaceAll(s, "\u00a0", " ")), " ")
	if len([]rune(s)) < 3 || len([]rune(s)) > 140 || validNameRegexp.MatchString(s) || strings.ContainsAny(s, "<>@{}") {
		return ""
	}
	return s
}

func populateOrder(o *order) {
	// A több azonos rendelésfül közül először a listában találtat olvassuk, szükség esetén a többit.
	for _, t := range o.Tabs {
		ctx, cancel := context.WithTimeout(context.Background(), 7*time.Second)
		var d browserData
		err := cdpCommand(ctx, t.WS, "Runtime.evaluate", map[string]any{
			"expression": extractorJS, "returnByValue": true, "silent": true, "awaitPromise": false,
		}, &d)
		cancel()
		if err != nil {
			o.Err = err
			continue
		}
		name := normalizeName(d.Name)
		if name == "" {
			o.Err = errors.New("a vevő neve nem olvasható")
			continue
		}
		o.Name = name
		o.SOS = d.SOS
		o.Err = nil
		return
	}
}

func recordError(err error) {
	if err == nil {
		return
	}
	p := filepath.Join(os.TempDir(), "name_number_copy_error.log")
	f, e := os.OpenFile(p, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if e != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "%s | %s | %v\r\n", time.Now().Format(time.RFC3339), appVersion, err)
}

// shouldShowChoiceConsole guarantees a completely invisible single-order path.
func shouldShowChoiceConsole(orders []order) bool { return len(orders) > 1 }

func run() error {
	orders := uniqueOrders(listTabs())
	if len(orders) == 0 {
		return errors.New("nem található nyitott OpenCart rendelésrészletező oldal a 9222 vagy 9223 porton")
	}
	// Egy rendelés esetén NINCS AllocConsole / SetForegroundWindow / GUI ablak.
	if !shouldShowChoiceConsole(orders) {
		populateOrder(&orders[0])
		if orders[0].Name == "" {
			return fmt.Errorf("%s: %v", orders[0].ID, orders[0].Err)
		}
		return copyClipboard(formatValue(orders[0]))
	}
	// Kettő vagy több egyedi rendelésnél először háttérben kiolvassuk a vevőneveket.
	// Az Illustrator fölé ne nyissunk üres/fehér konzolt adatgyűjtés közben.
	for i := range orders {
		populateOrder(&orders[i])
	}
	previousWindow := getForegroundWindow()
	if err := openChoiceConsole(); err != nil {
		return fmt.Errorf("választó konzol: %w", err)
	}
	// A konzolból érkező billentyűesemény után még a FreeConsole előtt
	// visszaadjuk a fókuszt az eredeti ablaknak. A bezárás után egyszer
	// ellenőrizzük, hogy a Windows tényleg ott hagyta-e.
	defer func() {
		restoreForeground(previousWindow)
		closeChoiceConsole()
		if previousWindow != 0 && getForegroundWindow() != previousWindow {
			restoreForeground(previousWindow)
		}
	}()
	writeChoiceConsole("NYITOTT RENDELÉSEK\r\n\r\n")
	for i, o := range orders {
		code := ""
		if o.Code != "" {
			code = o.Code + " "
		}
		name := o.Name
		if name == "" {
			name = "[név nem olvasható]"
		}
		sos := ""
		if o.SOS {
			sos = "SOS - "
		}
		writeChoiceConsole(fmt.Sprintf("%d. %s | %s%s - %s%s\r\n", i+1, o.Shop, code, o.ID, sos, name))
	}
	if len(orders) > 9 {
		writeChoiceConsole("\r\n1-9: csak a számot nyomd meg. 10-től: 0 + sorszám + Enter. Esc = bezárás.\r\n")
	} else {
		writeChoiceConsole("\r\nVálassz sorszámot (Enter nem kell), Esc = bezárás.\r\n")
	}
	for {
		choice, err := readChoiceConsole(len(orders))
		if err != nil {
			return err
		}
		if choice < 0 {
			return nil // Esc: nincs vágólapmódosítás.
		}
		if orders[choice].Name == "" {
			writeChoiceConsole("\r\nA kiválasztott rendelésből nem olvasható ki a vevőnév. Válassz másikat vagy Esc!\r\n")
			continue
		}
		if err := copyClipboard(formatValue(orders[choice])); err != nil {
			return err
		}
		break
	}
	// Kilép a függvényből -> FreeConsole és fókuszvisszaállítás.
	return nil
}

func main() {
	if err := run(); err != nil {
		recordError(err)
	}
}

// ---- Mini WebSocket kliens: CDP Chrome/Brave Runtime.evaluate, külső DLL és csomag nélkül ----
func cdpCommand(ctx context.Context, wsAddress, method string, params any, dest any) error {
	return cdpCommandWithPortFilter(ctx, wsAddress, method, params, dest, func(p string) bool {
		return p == "9222" || p == "9223"
	})
}

// A teszt szerver random localhost portot használ; élesben kizárólag 9222 és 9223 engedélyezett.
func cdpCommandWithPortFilter(ctx context.Context, wsAddress, method string, params any, dest any, allowedPort func(string) bool) error {
	u, err := url.Parse(wsAddress)
	if err != nil || u.Scheme != "ws" {
		return fmt.Errorf("hibás CDP WebSocket URL: %q", wsAddress)
	}
	host := u.Hostname()
	if host != "localhost" && host != "127.0.0.1" && host != "[::1]" && host != "::1" {
		return errors.New("nem helyi websocket cím")
	}
	port := u.Port()
	if !allowedPort(port) {
		return errors.New("nem engedélyezett CDP port")
	}
	d := net.Dialer{Timeout: 3 * time.Second}
	conn, err := d.DialContext(ctx, "tcp", net.JoinHostPort(host, port))
	if err != nil {
		return err
	}
	defer conn.Close()
	deadline, ok := ctx.Deadline()
	if ok {
		_ = conn.SetDeadline(deadline)
	}
	var nonce [16]byte
	if _, err = rand.Read(nonce[:]); err != nil {
		return err
	}
	wsKey := base64.StdEncoding.EncodeToString(nonce[:])
	uri := u.RequestURI()
	_, err = fmt.Fprintf(conn, "GET %s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: %s\r\n\r\n", uri, u.Host, wsKey)
	if err != nil {
		return err
	}
	reader := bufio.NewReader(conn)
	resp, err := http.ReadResponse(reader, nil)
	if err != nil {
		return err
	}
	if resp.StatusCode != 101 {
		return fmt.Errorf("CDP WS kapcsolat: HTTP %d", resp.StatusCode)
	}
	h := sha1.Sum([]byte(wsKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
	if resp.Header.Get("Sec-WebSocket-Accept") != base64.StdEncoding.EncodeToString(h[:]) {
		return errors.New("CDP handshake hiba")
	}
	payload, err := json.Marshal(map[string]any{"id": 1, "method": method, "params": params})
	if err != nil {
		return err
	}
	if err = sendFrame(conn, 1, payload); err != nil {
		return err
	}
	var message []byte
	for {
		opcode, final, frame, err := readFrame(reader)
		if err != nil {
			return err
		}
		switch opcode {
		case 8:
			return errors.New("CDP kapcsolat lezárva")
		case 9:
			if err = sendFrame(conn, 10, frame); err != nil {
				return err
			}
			continue
		case 10:
			continue
		case 1, 2:
			message = append(message[:0], frame...)
		case 0:
			message = append(message, frame...)
		default:
			continue
		}
		if !final {
			continue
		}
		var envelope struct {
			ID     int             `json:"id"`
			Error  json.RawMessage `json:"error"`
			Result struct {
				ExceptionDetails json.RawMessage `json:"exceptionDetails"`
				Result           struct {
					Value json.RawMessage `json:"value"`
				} `json:"result"`
			} `json:"result"`
		}
		if err = json.Unmarshal(message, &envelope); err != nil {
			continue
		}
		if envelope.ID != 1 {
			continue
		} // aszinkron CDP esemény
		if len(envelope.Error) > 0 {
			return fmt.Errorf("CDP hiba: %s", envelope.Error)
		}
		if len(envelope.Result.ExceptionDetails) > 0 {
			return errors.New("Javascript kinyerés hiba")
		}
		if len(envelope.Result.Result.Value) == 0 {
			return errors.New("CDP eredmény üres")
		}
		if err = json.Unmarshal(envelope.Result.Result.Value, dest); err != nil {
			return err
		}
		return nil
	}
}

func sendFrame(w io.Writer, opcode byte, payload []byte) error {
	var header bytes.Buffer
	header.WriteByte(0x80 | opcode)
	n := len(payload)
	switch {
	case n <= 125:
		header.WriteByte(byte(n) | 0x80)
	case n <= 65535:
		header.WriteByte(0x80 | 126)
		_ = binary.Write(&header, binary.BigEndian, uint16(n))
	default:
		header.WriteByte(0x80 | 127)
		_ = binary.Write(&header, binary.BigEndian, uint64(n))
	}
	var key [4]byte
	if _, err := rand.Read(key[:]); err != nil {
		return err
	}
	header.Write(key[:])
	encoded := make([]byte, n)
	for i, c := range payload {
		encoded[i] = c ^ key[i%4]
	}
	if _, err := w.Write(header.Bytes()); err != nil {
		return err
	}
	_, err := w.Write(encoded)
	return err
}
func readFrame(r io.Reader) (opcode byte, final bool, payload []byte, err error) {
	var h [2]byte
	if _, err = io.ReadFull(r, h[:]); err != nil {
		return
	}
	final = h[0]&0x80 != 0
	opcode = h[0] & 0xf
	n := uint64(h[1] & 0x7f)
	if n == 126 {
		var s uint16
		err = binary.Read(r, binary.BigEndian, &s)
		n = uint64(s)
	}
	if n == 127 {
		err = binary.Read(r, binary.BigEndian, &n)
	}
	if err != nil {
		return
	}
	if n > 4<<20 {
		err = errors.New("túl nagy CDP válasz")
		return
	}
	var mask [4]byte
	masked := h[1]&0x80 != 0
	if masked {
		_, err = io.ReadFull(r, mask[:])
		if err != nil {
			return
		}
	}
	payload = make([]byte, n)
	_, err = io.ReadFull(r, payload)
	if err != nil {
		return
	}
	if masked {
		for i := range payload {
			payload[i] ^= mask[i%4]
		}
	}
	return
}
