const fs = require('node:fs');
let input;
try { input = JSON.parse(fs.readFileSync(0, 'utf8')); if (input === null || Array.isArray(input) || typeof input !== 'object') throw new Error('object expected'); }
catch { console.log(JSON.stringify({result: {ok: false, error: 'invalid_json'}})); process.exit(0); }
const good = Array.isArray(input.values) && input.values.length <= 100 && input.values.every(v => Number.isInteger(v) && v >= 0 && v <= 1000000);
let result;
if (!good) result = {ok: false, error: 'invalid_values'};
else if (input.op !== 'total') result = {ok: false, error: 'unsupported_operation'};
else result = {ok: true, total: input.values.reduce((sum, value) => sum + value, 0)};
console.log(JSON.stringify({result}));
