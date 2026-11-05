// Fast feedback loop for the Realtime Database rules parser.
// Usage: node scripts/rules_probe.js <rules-file.json>
const fs = require('fs');

const file = process.argv[2];
const body = fs.readFileSync(file, 'utf8');
const host = process.env.EMU_HOST || 'http://127.0.0.1:9000';
const ns = process.env.EMU_NS || 'demo-delicia';

(async () => {
  try {
    const res = await fetch(`${host}/.settings/rules.json?ns=${ns}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body,
    });
    const text = await res.text();
    console.log('HTTP', res.status);
    console.log(text.slice(0, 2000));
  } catch (e) {
    console.log('REQUEST FAILED:', e.message);
  }
})();
