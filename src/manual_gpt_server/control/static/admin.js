// web/static/admin.js
const status     = document.getElementById('status');
const log        = document.getElementById('log');
const reply      = document.getElementById('reply');
const sendBtn    = document.getElementById('send');
const streamBtn  = document.getElementById('send-stream');

let ws = null;
let currentRequest = null;

function connect() {
  ws = new WebSocket(`ws://${location.host}/admin`);

  ws.onopen = () => {
    status.textContent = 'подключено';
    status.className = 'ok';
  };
  ws.onclose = () => {
    status.textContent = 'отключено — переподключение...';
    status.className = 'err';
    setTimeout(connect, 1000);
  };
  ws.onerror = () => ws.close();
  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data);
    if (msg.type === 'request') {
      currentRequest = msg;
      renderRequest(msg.messages);
      reply.value = '';
      enableComposer(true);
      reply.focus();
    }
  };
}

function enableComposer(on) {
  reply.disabled = !on;
  sendBtn.disabled = !on;
  streamBtn.disabled = !on;
}

function renderRequest(messages) {
  const div = document.createElement('div');
  div.className = 'request';
  const head = document.createElement('h3');
  head.textContent = 'Request';
  div.appendChild(head);
  for (const m of messages) {
    const row = document.createElement('div');
    row.className = 'msg';
    const who = document.createElement('b');
    who.textContent = m.role + ': ';
    row.appendChild(who);
    row.appendChild(document.createTextNode(m.content));
    div.appendChild(row);
  }
  log.appendChild(div);
  log.scrollIntoView({ block: 'end' });
}

function finish() {
  currentRequest = null;
  enableComposer(false);
  reply.value = '';
}

sendBtn.onclick = () => {
  if (!currentRequest) return;
  ws.send(JSON.stringify({ type: 'delta', content: reply.value }));
  ws.send(JSON.stringify({ type: 'done' }));
  finish();
};

streamBtn.onclick = async () => {
  if (!currentRequest) return;
  const text = reply.value;
  const words = text.split(/(\s+)/);  // сохраняем пробелы
  for (const w of words) {
    if (!w) continue;
    ws.send(JSON.stringify({ type: 'delta', content: w }));
    await new Promise(r => setTimeout(r, 40));
  }
  ws.send(JSON.stringify({ type: 'done' }));
  finish();
};

connect();