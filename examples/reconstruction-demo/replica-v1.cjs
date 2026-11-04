// Independently written fixture implementation; does not call the originals.
const fs = require('node:fs');
function run(request) {
  const list = request.values;
  if (!Array.isArray(list) || list.length > 100) return {ok:false,error:'invalid_values'};
  let amount = 0;
  for (const entry of list) {
    if (!Number.isInteger(entry) || entry < 0 || entry > 1000000) return {ok:false,error:'invalid_values'};
    amount += entry;
  }
  return request.op === 'total' ? {ok:true,total:amount} : {ok:false,error:'unsupported_operation'};
}
let result;
try { const request = JSON.parse(fs.readFileSync(0, 'utf8')); if (request === null || Array.isArray(request) || typeof request !== 'object') throw new Error('object expected'); result = run(request); }
catch { result = {ok:false,error:'invalid_json'}; }
console.log(JSON.stringify({result,ui:{brand:'My Lab',theme:'indigo'}}));
