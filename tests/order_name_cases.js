// Executes the EXACT JavaScript embedded into the production Go EXE.
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const assert = require('node:assert/strict');
const main = fs.readFileSync(path.join(__dirname,'..','main.go'),'utf8');
const tick = String.fromCharCode(96);
const start = main.indexOf('const extractorJS = ' + tick);
if (start < 0) throw new Error('Production extractor start not found');
const bodyStart = start + ('const extractorJS = ' + tick).length;
const bodyEnd = main.indexOf(tick, bodyStart); // Win checkout may use CRLF; no line-ending assumptions
if (bodyEnd < 0) throw new Error('Production extractor end not found');
const extractorJS = main.slice(bodyStart, bodyEnd);
function extract(text,headings=[]) {
  const page = {body:{innerText:text,querySelectorAll:()=>headings},documentElement:{lang:'ro-RO'}};
  return vm.runInNewContext(extractorJS,{document:page,location:{href:'https://3dlampa.ro/proadmin/index.php?route=sale/order/info&order_id=191'}});
}
const cases = [
  ['HU original','Rendelés info\nVásárló adatok\nMatyikó Tamás\nMagánszemély\nE-mail test@example.com','Matyikó Tamás'],
  ['RO Datele clientului','Comanda #191\nDatele clientului\nIon Popescu\nPersoană fizică\nE-mail test@example.com','Ion Popescu'],
  ['RO Detalii client','Comanda #191\nDetalii client\nMaria Ionescu\nPersoană fizică\nTelefon 0712312345','Maria Ionescu'],
  ['RO separated Nume/Prenume','Comanda #191\nDetalii client\nNume: Popescu\nPrenume: Elena\nTelefon 0712312345','Elena Popescu'],
  ['RO inline','Comanda #191 Detalii client Andrei Georgescu Persoană fizică Telefon 0712312345','Andrei Georgescu'],
  ['RO information header','Informații despre client\nIoana-Maria Rădulescu\nOpțiuni','Ioana-Maria Rădulescu'],
  ['SK heading','Informácie o zákazníkovi\nPeter Novák\nTelefón 123','Peter Novák'],
  ['CZ heading','Informace o zákazníkovi\nJan Novák\nTelefon 123','Jan Novák'],
  ['EN original','Customer info\nWesley Gergely\nEmail test@example.com','Wesley Gergely'],
  ['no matching customer heading','Comanda #191\nDetalii comanda\nEmail x@y.z\nTelefon','']
];
for(const [label,text,expected] of cases) {
  const got=extract(text);
  assert.equal(got.name,expected, label + ' yielded ' + JSON.stringify(got));
  console.log('PASS:',label);
}
const panel={querySelectorAll:()=>[{innerText:'Cătălin Ionescu'}]};
const heading={innerText:'Detalii client',closest:()=>panel};
assert.equal(extract('Comanda #191\nDetalii client\nTelefon +400000',[heading]).name,'Cătălin Ionescu');
assert.equal(extract('Detalii client\nIon Popescu\nTelefon 000\nLivrare SOS').sos,true);
console.log('PASS: DOM customer anchor and SOS');
