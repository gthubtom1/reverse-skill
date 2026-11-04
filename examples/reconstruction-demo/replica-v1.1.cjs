// Independent implementation of the documented v1.1 business contract.
const fs = require('node:fs');
function evaluate(request) {
  const entries = request.values;
  if (!Array.isArray(entries) || entries.length > 100) return {ok:false,error:'invalid_values'};
  let gross = 0;
  for (let index = 0; index < entries.length; index++) {
    const n = entries[index];
    if (!Number.isInteger(n) || n < 0 || n > 1000000) return {ok:false,error:'invalid_values'};
    gross += n;
  }
  if (request.op === 'count') return {ok:true,count:entries.length};
  if (request.op !== 'total') return {ok:false,error:'unsupported_operation'};
  const rate = request.discount_percent == null ? 0 : request.discount_percent;
  if (!Number.isInteger(rate) || rate < 0 || rate > 50) return {ok:false,error:'invalid_discount'};
  return {ok:true,total:Math.floor((gross * (100 - rate)) / 100)};
}
let result;
try { const request = JSON.parse(fs.readFileSync(0, 'utf8')); if (request === null || Array.isArray(request) || typeof request !== 'object') throw new Error('object expected'); result = evaluate(request); }
catch { result = {ok:false,error:'invalid_json'}; }
console.log(JSON.stringify({result,ui:{brand:'My Lab',theme:'indigo'}}));
