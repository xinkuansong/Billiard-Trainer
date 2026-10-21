const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const G=require('./geometry.js'),raw=JSON.parse(fs.readFileSync(path.join(__dirname,'geometry.json'))),table=G.setup(raw);
const fixtures=JSON.parse(fs.readFileSync(path.join(__dirname,'results/fixtures.json')));
for(const f of fixtures){
 const q=G.solve(f.c,f.o,f.p,table.D);
 for(const k of ['alpha','theta','f'])assert(Math.abs(q[k]-f[k])<1e-10,`${k}: ${JSON.stringify(f)}`);
 assert(Math.abs(q.aimX-2*q.contactX)<1e-12);
 assert.equal(G.validity(f.c,f.o,f.p,table,f.model==='production',f.pocket),'');
}
assert.equal(G.validity([1.6,2],[2,2],[0,0],table,false,0).startsWith('不可直切'),true);
for(const theta of G.anchors){
 const o=[2,2],p=[0,0],u=G.unit(G.sub(p,o)),n=[-u[1],u[0]],g=G.sub(o,G.mul(u,table.D));
 const c=G.add(g,G.add(G.mul(u,-2*Math.cos(theta)),G.mul(n,2*Math.sin(theta))));
 const q=G.solve(c,o,p,table.D);assert(Math.abs(q.theta-theta)<1e-10);
 assert(Math.abs(Math.abs(q.aimX)-table.D*Math.sin(theta))<1e-12);
}
console.log(`PASS: ${fixtures.length} Python/JavaScript fixtures, first-hit validity, 5 front-view anchors, invalid boundary`);
