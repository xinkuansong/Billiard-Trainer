// PACK is generated from validated local PNG evidence. No network access.
const report = {batch:PACK.batch, entries:[], status:'RUNNING'};
const startedAt=Date.now();
const touchedSections=new Set();
async function run() {
 if(figma.root.name !== '球迹｜App原生截图评审') throw Error('Wrong destination file');
 await figma.loadAllPagesAsync();
 const pages = ['00｜评审入口','10｜训练首页与计划','11｜训练过程与总结','20｜动作库与精讲','30｜练习与理论','40｜记录与统计','50｜我的与设置','60｜账号与订阅','70｜每日清台','71｜其他球桌与训练工具','80｜系统与内部工具','90｜历史版本'];
 for(const name of pages) {
  if(!figma.root.children.some(p=>p.name===name)) {
   const p=figma.root.children.length===1&&figma.currentPage.name==='Page 1'&&figma.currentPage.children.length===0 ? figma.currentPage : figma.createPage();
   p.name=name;
  }
 }
 await figma.loadFontAsync({family:'Inter',style:'Regular'});
 function label(parent, text, x, y) {const n=figma.createText();parent.appendChild(n);n.fontName={family:'Inter',style:'Regular'};n.fontSize=16;n.characters=text;n.x=x;n.y=y;n.fills=[{type:'SOLID',color:{r:.1,g:.15,b:.12}}];return n;}
 const index=figma.root.children.find(p=>p.name===pages[0]);
 if(index.children.length===0)label(index,'球迹 App 原生截图评审\n基线 f75cbafd｜五窗口 × 浅深色\n图片来自原生 App；AI 检查与用户认可分别记录。\n请在对应页面截图上评论；修后新增版本并保留旧图与评论位置。\n当前仅试点采集中，未采页面仍待补齐。',0,0);
 for(const e of PACK.entries) {
  const p=figma.root.children.find(p=>p.name===e.page);
  await figma.setCurrentPageAsync(p);
  let section=p.children.find(n=>n.type==='SECTION'&&n.getPluginData('pageId')===e.pageId);
  if(!section){const bottom=Math.max(0,...p.children.filter(n=>n.type==='SECTION').map(n=>n.y+n.height));section=figma.createSection();p.appendChild(section);section.name=e.pageId+'｜'+e.pageName;section.setPluginData('pageId',e.pageId);section.x=0;section.y=bottom+400;section.resizeWithoutConstraints(6000,3800);section.fills=[{type:'SOLID',color:{r:.94,g:.95,b:.94}}];}
  const prior=section.findAll(n=>n.type==='FRAME'&&n.getPluginData('slotId')===e.slotId);
  let frame=prior.find(n=>n.getPluginData('sha256')===e.sha256);
  const skipped=!!frame;
  if(!frame){
   touchedSections.add(section.id);
   // Keep prior screenshot nodes untouched: comments stay attached to their original evidence.
   frame=figma.createFrame();section.appendChild(frame);frame.name=e.slotId+'｜'+e.captureId+'｜待用户评审';frame.resize(e.width,e.height);frame.x=e.x;frame.y=prior.length ? section.height+160 : e.y;frame.fills=[];
   frame.setPluginData('slotId',e.slotId);frame.setPluginData('sha256',e.sha256);frame.setPluginData('captureId',e.captureId);
   const rectangle=figma.createRectangle();frame.appendChild(rectangle);rectangle.name='原生截图｜'+e.sha256.slice(0,12);rectangle.resize(e.width,e.height);
   const image=figma.createImage(figma.base64Decode(e.png));rectangle.fills=[{type:'IMAGE',imageHash:image.hash,scaleMode:'FIT'}];
   const caption=label(section,e.label,frame.x,frame.y-48);
   if(e.layoutGroup){
    frame.setPluginData('atlasLayout',JSON.stringify({group:e.layoutGroup+'/revision-'+prior.length,device:e.device,orientation:e.orientation,theme:e.theme,slice:e.slice||0}));
    caption.setPluginData('atlasCaptionFor',frame.id);
   }
   section.resizeWithoutConstraints(Math.max(section.width,frame.x+frame.width+80),Math.max(section.height,frame.y+frame.height+80));
  }
  section.setPluginData('current:'+e.slotId,frame.id);
  const image=frame.children.find(n=>n.type==='RECTANGLE');
  const paint=image.fills[0];const size=await figma.getImageByHash(paint.imageHash).getSizeAsync();
  if(size.width!==e.pixelWidth||size.height!==e.pixelHeight||frame.width!==e.width||frame.height!==e.height)throw Error('Readback size mismatch '+e.slotId);
  report.entries.push({slotId:e.slotId,captureId:e.captureId,sha256:e.sha256,page:p.id,section:section.id,frame:frame.id,image:image.id,imageHash:paint.imageHash,pixels:size,skipped,priorFrames:prior.map(n=>n.id)});
 }
 report.importMilliseconds=Date.now()-startedAt;
 // Long-page slices use rows that grow with actual captures, never reserved giant gaps.
 // Preserve node identities when moving them: existing screenshot comments stay attached.
 for(const page of figma.root.children)for(const section of page.children.filter(n=>n.type==='SECTION'&&n.getPluginData('pageId'))){
  if(!touchedSections.has(section.id))continue;
  const managed=section.children.filter(n=>n.type==='FRAME'&&n.getPluginData('atlasLayout'));
  if(!managed.length)continue;
  const fixed=section.children.filter(n=>!n.getPluginData('atlasLayout')&&!n.getPluginData('atlasCaptionFor'));
  let y=Math.max(100,...fixed.map(n=>n.y+n.height+140));
  const metadata=new Map(managed.map(n=>[n.id,JSON.parse(n.getPluginData('atlasLayout'))]));
  const captions=new Map(section.children.filter(n=>n.getPluginData('atlasCaptionFor')).map(n=>[n.getPluginData('atlasCaptionFor'),n]));
  const groups=[...new Set(managed.map(n=>metadata.get(n.id).group))].sort();
  for(const group of groups){
   for(const family of ['phone','pad'])for(const theme of ['light','dark']){
    const members=managed.filter(n=>{const m=metadata.get(n.id);return m.group===group&&m.theme===theme&&(m.device==='pad')===(family==='pad')});
    if(!members.length)continue;
    const columns=family==='phone'?['small','standard','large']:['portrait','landscape'];
    let height=0;
    for(let column=0;column<columns.length;column++){
     const frames=members.filter(n=>{const m=metadata.get(n.id);return (family==='phone'?m.device:m.orientation)===columns[column]}).sort((a,b)=>metadata.get(a.id).slice-metadata.get(b.id).slice);
     let cy=y;
     for(const frame of frames){frame.x=family==='phone'?[80,550,1050][column]:[80,1050][column];frame.y=cy;const caption=captions.get(frame.id);if(caption){caption.x=frame.x;caption.y=cy-40;}cy+=frame.height+100;}
     height=Math.max(height,cy-y);
    }
    y+=height+100;
   }
   y+=150;
  }
  section.resizeWithoutConstraints(section.width,y+80);
 }
 // Earlier sections can grow when more environments arrive. Keep their nodes intact
 // and move later owned sections below them so the atlas never overlaps screenshots.
 report.sectionLayout=[];
 for(const p of figma.root.children){
  const sections=p.children.filter(n=>n.type==='SECTION'&&!!n.getPluginData('pageId')).sort((a,b)=>a.y-b.y);
  let bottom=0;
  for(const section of sections){section.y=Math.max(section.y,bottom);bottom=section.y+section.height+400;report.sectionLayout.push({id:section.id,page:p.id,y:section.y,height:section.height});}
 }
 report.pages=figma.root.children.map(p=>({id:p.id,name:p.name,captures:p.findAll(n=>n.type==='FRAME'&&!!n.getPluginData('slotId')).length}));
 const total=report.pages.reduce((n,p)=>n+p.captures,0);
 const overview='球迹 App 原生截图评审\n基线 f75cbafd｜五窗口 × 浅深色\n已导入 '+total+' 张原生截图（含历史与滚动切片）；不代表全 App 覆盖或用户认可。\n\n从左侧业务 Page 进入；Section 按页面编号分组，图上标签标明尺寸、主题与状态。\n请在对应截图上评论；修后新增版本，保留旧图与评论位置。\n页面首屏、长页与弹层分批补齐；尚未采集的 Page 保留空目录。\n\n'+report.pages.slice(1).map(p=>p.name+'   '+p.captures+' 张').join('\n');
 let overviewNode=index.children.find(n=>n.type==='TEXT'&&(n.getPluginData('atlasOverview')==='v4'||n.characters.includes('当前仅试点采集中，未采页面仍待补齐。')));
 if(!overviewNode)overviewNode=label(index,overview,0,0);else overviewNode.characters=overview;
 overviewNode.setPluginData('atlasOverview','v4');
 report.totalMilliseconds=Date.now()-startedAt;report.relaidOutSections=[...touchedSections];
 report.totalCaptures=total;report.status='IMPORTED_READBACK_OK';
 if(report.entries.length){await figma.setCurrentPageAsync(await figma.getNodeByIdAsync(report.entries[0].page));const n=await figma.getNodeByIdAsync(report.entries[0].frame);figma.currentPage.selection=[n];figma.viewport.scrollAndZoomIntoView([n]);}
}
run().catch(e=>{report.status='FAILED';report.error=String(e)}).then(()=>{
 const data=JSON.stringify(report,null,2);
 figma.showUI('<button id="save">Save atlas receipt</button><button id="close">Close</button><pre>'+report.status+'\n'+report.entries.length+' entries</pre><script>const data='+JSON.stringify(data)+';document.getElementById("save").onclick=()=>{const a=document.createElement("a");a.href=URL.createObjectURL(new Blob([data],{type:"application/json"}));a.download="atlas-'+PACK.batch+'-receipt.json";a.click()};document.getElementById("close").onclick=()=>parent.postMessage({pluginMessage:{close:true}},"*");</script>',{width:420,height:160});
 figma.ui.onmessage=()=>figma.closePlugin();
});
