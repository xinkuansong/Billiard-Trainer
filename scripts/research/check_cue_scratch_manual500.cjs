const fs=require('fs'),path=require('path'),assert=require('assert'),vm=require('vm');
const root=path.resolve(__dirname,'../..');const dir=path.join(root,'output/cue-scratch-research-20261004/manual-500');
const rows=JSON.parse(fs.readFileSync(path.join(dir,'cards.json')));const app=fs.readFileSync(path.join(__dirname,'cue_scratch_manual500.js'),'utf8');
const {filterCases,selectionPayload}=require('./cue_scratch_manual500.js');
const base={scope:'main',rail:'',distance:'',angle:'',target:'',scratch:'',query:''};
assert.equal(filterCases(rows,base,new Set()).length,118);
assert.equal(filterCases(rows,{...base,scope:'all'},new Set()).length,172);
assert.equal(filterCases(rows,{...base,scope:'selected'},new Set(['M013'])).length,1);
assert.equal(selectionPayload(rows,new Set(['M013'])).selected[0].id,'M013');
for(const [rail,count]of [[0,57],[1,31],[2,18],[3,12]])assert.equal(filterCases(rows,{...base,rail:String(rail)},new Set()).length,count);
for(const [distance,count]of [['60-90',43],['90-120',28],['120+',47]])assert.equal(filterCases(rows,{...base,distance},new Set()).length,count);
assert.equal(filterCases(rows,{...base,angle:'small'},new Set()).length,7);
assert.equal(filterCases(rows,{...base,query:'M498'},new Set()).length,1);
assert.equal(filterCases(rows,{...base,scope:'selected'},new Set(['M007','R001'])).length,2);
assert.equal(filterCases(rows,{...base,scope:'history'},new Set()).length,11);
assert.equal(selectionPayload(rows,new Set(['M007','R001','FAKE'])).selected.length,2);
assert.equal(filterCases([{...rows[0],speed:4.5},{...rows[0],speed:4.50001}],base,new Set()).length,1);
assert.equal(selectionPayload(rows,new Set(['M007','M001'])).selected.length,1);
// Exercise DOM handlers in an isolated stub, without browser navigation.
class Element{constructor(tag='div'){this.tag=tag;this.children=[];this.value='';this.dataset={};this.classList={toggle:()=>{}};this.listeners={};this.textContent='';}append(...x){this.children.push(...x)}replaceChildren(...x){this.children=x}setAttribute(k,v){this[k]=v}addEventListener(e,f){this.listeners[e]=f}click(){if(this.onclick)this.onclick()}focus(){}select(){}scrollIntoView(){}showModal(){this.open=true}close(){this.open=false}}
function boot(saved,failStorage=false){const ids={};for(const id of ['results','case-data','scope','rail','distance','angle','target','scratch','query','chosen-count','chosen-ids','storage-note','grid','result-count','empty','large-image','large-label','image-dialog','close-image','reset','download','copy','copy-status'])ids[id]=new Element();ids['case-data'].textContent=JSON.stringify(rows);ids.scope.value='main';const buttons=['prev','next','prev','next'].map(d=>{const e=new Element('button');e.dataset.page=d;return e});const downloads=[];const store={value:saved};const listeners={};const context={document:{getElementById:id=>ids[id],createElement:t=>new Element(t),querySelectorAll:()=>buttons},window:{addEventListener:(n,f)=>listeners[n]=f},location:{hash:''},localStorage:{getItem:()=>{if(failStorage)throw Error('blocked');return store.value},setItem:(k,v)=>{if(failStorage)throw Error('blocked');store.value=v}},navigator:{clipboard:{writeText:async()=>{}}},Blob,URL:{createObjectURL:b=>{downloads.push(b);return 'blob:test'},revokeObjectURL:()=>{}},setTimeout:f=>f()};vm.runInNewContext(app,context);return{ids,buttons,store,downloads,context,listeners};}
const ui=boot('[]');assert.equal(ui.ids.grid.children.length,30);assert(ui.buttons[0].disabled);ui.buttons[1].click();assert.equal(ui.ids.grid.children[0].id,'M095');
ui.ids.query.value='M007';ui.ids.query.listeners.input();const card=ui.ids.grid.children[0];const checkbox=card.children[0].children[0];checkbox.checked=true;checkbox.onchange();assert.equal(ui.ids['chosen-ids'].value,'M007');assert.deepEqual(JSON.parse(ui.store.value),['M007']);ui.ids.download.click();assert.equal(ui.downloads.length,1);
const hidden=boot(JSON.stringify(['M007','M001']));assert(hidden.ids['chosen-count'].textContent.includes('另有 1'));assert.equal(hidden.ids['chosen-ids'].value,'M007');
const restored=boot(ui.store.value);assert(restored.ids.grid.children[0].children[0].children[0].checked);
ui.context.location.hash='#R001';ui.listeners.hashchange();assert.equal(ui.ids.grid.children[0].id,'R001');assert.equal(ui.ids.scope.value,'history');
ui.context.location.hash='#M013';ui.listeners.hashchange();assert.equal(ui.ids.grid.children[0].id,'M013');assert.equal(ui.ids.scope.value,'all');
ui.ids.reset.click();assert.equal(ui.ids.grid.children.length,30);assert.equal(ui.ids.scope.value,'main');
const unavailable=boot('[]',true);assert(unavailable.ids['storage-note'].textContent.includes('不能保存'));const cb=unavailable.ids.grid.children[0].children[0].children[0];cb.checked=true;cb.onchange();assert.equal(unavailable.ids['chosen-ids'].value,'M007');
for(const x of rows)assert(fs.existsSync(path.join(dir,x.id+'.svg')));
const report={passed:true,mainCases:118,historicalAppendix:6,checked:['rail/distance/angle/query filters','historical map scope','selected-only includes archive','pagination','checkbox selection','storage roundtrip','blocked-storage fallback','export handler','hash navigation','reset','506 SVG links'],environment:'Node isolated DOM stub; browser visual layout/download behavior not verified'};
fs.writeFileSync(path.join(dir,'ui-logic-check.json'),JSON.stringify(report,null,2));console.log(report);
