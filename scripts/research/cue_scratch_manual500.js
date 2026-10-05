/* Local manual selection. No network requests or automatic submissions. */
const MAX_CUE_SPEED = 4.5;
function filterCases(rows, filters, selected) {
  const query = filters.query.trim().toUpperCase();
  return rows.filter(x => {
    if (x.speed > MAX_CUE_SPEED) return false;
    if (filters.scope === 'main' && x.archive) return false;
    if (filters.scope === 'main' && x.duplicateOf) return false;
    if (filters.scope === 'all' && x.archive) return false;
    if (filters.scope === 'history' && !x.old) return false;
    if (filters.scope === 'selected' && !selected.has(x.id)) return false;
    if (filters.rail !== '' && x.rails !== Number(filters.rail)) return false;
    if (filters.distance === '60-90' && !(x.distance >= 60 && x.distance < 90)) return false;
    if (filters.distance === '90-120' && !(x.distance >= 90 && x.distance < 120)) return false;
    if (filters.distance === '120+' && x.distance < 120) return false;
    if (filters.angle === 'small' && x.cut >= 5) return false;
    if (filters.angle === 'normal' && x.cut < 5) return false;
    if (filters.angle === 'thin' && x.cut < 60) return false;
    if (filters.target !== '' && x.target !== Number(filters.target)) return false;
    if (filters.scratch !== '' && x.scratch !== Number(filters.scratch)) return false;
    return !query || x.id.includes(query) || x.old.toUpperCase().includes(query);
  });
}
function selectionPayload(rows, selected) {
  return {version:'V023-manual500-r8-speed45', maxCueSpeed:MAX_CUE_SPEED, selected:rows.filter(x=>selected.has(x.id)&&x.speed<=MAX_CUE_SPEED).map(x=>({id:x.id,source:x.source,rails:x.rails,distanceCm:x.distance,archive:x.archive,cue:x.cue,object:x.object,speed:x.speed})), savedAt:new Date().toISOString()};
}
if (typeof module !== 'undefined') module.exports = {filterCases,selectionPayload};
if (typeof document !== 'undefined') {
  const rows = JSON.parse(document.getElementById('case-data').textContent);
  const byId = new Map(rows.map(x=>[x.id,x]));
  const storageKey='V023-manual500-r8-selected';
  let selected=new Set(); let storageAvailable=true;
  try {const saved=JSON.parse(localStorage.getItem(storageKey)||'[]');if(Array.isArray(saved))selected=new Set(saved.filter(x=>byId.has(x)));} catch(e) {storageAvailable=false;}
  const $=id=>document.getElementById(id);
  let page=0; const pageSize=30;
  function filters(){return Object.fromEntries(['scope','rail','distance','angle','target','scratch','query'].map(id=>[id,$(id).value]));}
  function selectionStatus(){
    const kept=rows.filter(x=>selected.has(x.id)&&x.speed<=MAX_CUE_SPEED);
    const hidden=selected.size-kept.length;
    $('chosen-count').textContent=`已选 ${kept.length} 个`+(hidden?`（另有 ${hidden} 个旧勾选杆速超限，已隐藏且不导出）`:'');
    $('chosen-ids').value=kept.map(x=>x.id).join('、');
    $('storage-note').textContent=storageAvailable?'勾选保存在当前浏览器。选完请导出清单备份，或把下方编号发给我。':'此浏览器不能保存本地勾选；关闭前请导出清单或复制编号。';
  }
  function save(){try{localStorage.setItem(storageKey,JSON.stringify([...selected]));}catch(e){storageAvailable=false;}selectionStatus();}
  function card(x){
    const el=document.createElement('article');el.id=x.id;
    const label=document.createElement('label');label.className='choose';const cb=document.createElement('input');cb.type='checkbox';cb.checked=selected.has(x.id);cb.setAttribute('aria-label','选择 '+x.id);
    cb.onchange=()=>{if(cb.checked)selected.add(x.id);else selected.delete(x.id);save();el.classList.toggle('chosen',cb.checked);if($('scope').value==='selected')render();};
    const heading=document.createElement('strong');heading.textContent=`${x.id} · ${x.rails}库`;label.append(cb,heading);el.append(label);el.classList.toggle('chosen',cb.checked);
    const tags=document.createElement('p');tags.className='metrics';tags.textContent=`球心距 ${x.distance.toFixed(1)} cm · 杆速 ${x.speed.toFixed(3)} m/s · 切角 ${x.cut.toFixed(1)}°`;el.append(tags);
    const img=document.createElement('img');img.src=x.id+'.svg';img.alt=x.id+'实测轨迹';img.loading='lazy';img.tabIndex=0;img.title='点击放大';img.onclick=()=>openImage(x);img.onkeydown=e=>{if(e.key==='Enter')openImage(x);};el.append(img);
    const notes=document.createElement('p');notes.className='notes';notes.textContent=`目标袋 ${x.target} → 母球袋 ${x.scratch}`+(x.cut<5?' · 小角度，保留供人工判断':'')+(x.archive?' · 旧版近球对照，不计入500例':'')+(x.old?' · 历史案例':'');el.append(notes);
    if(x.duplicateOf || x.similarIDs?.length){const group=document.createElement('p');group.className='notes';group.textContent=x.duplicateOf?'相似案例，主合集保留：':'已合并相似案例：';for(const id of (x.duplicateOf?[x.duplicateOf]:x.similarIDs)){const link=document.createElement('a');link.href='#'+id;link.textContent=id+' ';group.append(link);}el.append(group);}
    if(x.speedChecks){const checks=document.createElement('small');checks.textContent=`固定方向杆速 ±2%、±5% 测试：${x.speedChecks.sameRoute}/${x.speedChecks.tested} 次同路线`+(x.speedChecks.tested<4?'（边界外测试点未执行）':'')+'；不作为入选排名。';el.append(checks);}
    const details=document.createElement('details');const summary=document.createElement('summary');summary.textContent='复现参数';const pre=document.createElement('pre');pre.textContent=JSON.stringify({id:x.id,source:x.source,cue:x.cue,object:x.object,speed:x.speed},null,2);details.append(summary,pre);el.append(details);return el;
  }
  function render(){const matches=filterCases(rows,filters(),selected);const pages=Math.max(1,Math.ceil(matches.length/pageSize));page=Math.min(page,pages-1);$('grid').replaceChildren(...matches.slice(page*pageSize,(page+1)*pageSize).map(card));$('result-count').textContent=`符合 ${matches.length} 个 · 第 ${page+1} / ${pages} 页`;$('empty').hidden=matches.length>0;for(const b of document.querySelectorAll('[data-page]'))b.disabled=b.dataset.page==='prev'?page===0:page>=pages-1;selectionStatus();}
  function openImage(x){$('large-image').src=x.id+'.svg';$('large-label').textContent=`${x.id} · ${x.rails}库 · 球心距 ${x.distance.toFixed(1)} cm · ${x.speed.toFixed(3)} m/s`;$('image-dialog').showModal();}
  $('close-image').onclick=()=>$('image-dialog').close();
  for(const id of ['scope','rail','distance','angle','target','scratch','query'])$(id).addEventListener('input',()=>{page=0;render();});
  for(const b of document.querySelectorAll('[data-page]'))b.onclick=()=>{page+=b.dataset.page==='next'?1:-1;render();$('results').scrollIntoView({block:'start'});};
  $('reset').onclick=()=>{for(const id of ['rail','distance','angle','target','scratch','query'])$(id).value='';$('scope').value='main';page=0;render();};
  $('download').onclick=()=>{const blob=new Blob([JSON.stringify(selectionPayload(rows,selected),null,2)],{type:'application/json'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download='母球掉袋-手选清单.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
  $('copy').onclick=async()=>{const text=$('chosen-ids').value;try{await navigator.clipboard.writeText(text);$('copy-status').textContent='编号已复制';}catch(e){$('chosen-ids').focus();$('chosen-ids').select();$('copy-status').textContent='编号已选中，请按 ⌘C / Ctrl+C 复制';}};
  function fromHash(){const id=location.hash.slice(1).toUpperCase();if(byId.has(id)){for(const k of ['rail','distance','angle','target','scratch'])$(k).value='';$('scope').value=byId.get(id).archive?'history':byId.get(id).duplicateOf?'all':'main';$('query').value=id;page=0;render();}}
  window.addEventListener('hashchange',fromHash);render();fromHash();
}
