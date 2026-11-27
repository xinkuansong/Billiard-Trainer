import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const dir=process.argv[2];
const html=fs.readFileSync(dir+'/review.html','utf8');
const data=html.match(/<script id="data" type="application\/json">([\s\S]*?)<\/script>/)[1];
const geometry=html.match(/<script id="geometry" type="application\/json">([\s\S]*?)<\/script>/)[1];
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const elements=new Map();
function element(id){if(!elements.has(id)){const classes=new Set();elements.set(id,{textContent:'',innerHTML:'',value:'',disabled:false,open:false,classList:{add:x=>classes.add(x),remove:x=>classes.delete(x),contains:x=>classes.has(x)}});}return elements.get(id);}
element('data').textContent=data;element('geometry').textContent=geometry;element('family').value='twoA';element('zone').value='all';
const context=vm.createContext({document:{getElementById:element},console});
vm.runInContext(script,context);
let renders=0;
for(const f of ['twoA','twoB','own','black','joint']){
 element('family').value=f;
 for(const z of ['all','long','short','open']){
  element('zone').value=z;element('zone').onchange();
  const count=vm.runInContext('pool.length',context);
  assert.equal(count,{all:500,long:250,short:150,open:100}[z]);
  assert(element('answer').classList.contains('hide'));
  element('reveal').onclick();assert(!element('answer').classList.contains('hide'));
  element('next').onclick();assert(element('answer').classList.contains('hide'));
  element('prev').onclick();assert(element('prev').disabled);
 }
 element('zone').value='all';element('zone').onchange();
 for(let i=0;i<500;i++){
  vm.runInContext(`selected=${i};display()`,context);element('reveal').onclick();
  for(const id of ['opening','reference','zoom','comparison']){
   const svg=element(id).innerHTML;assert(svg.startsWith('<svg'));assert(!/NaN|Infinity|undefined/.test(svg));
  }
  renders++;
 }
 assert(element('next').disabled);
}
const result={passed:true,questionsRendered:renders,filterStates:20,answerHiddenOnQuestionChange:true,scope:'Real gallery script executed with a minimal DOM harness; not browser visual acceptance'};
fs.writeFileSync(dir+'/gallery-check.json',JSON.stringify(result,null,2));console.log(result);
