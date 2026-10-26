
(()=>{
const root=document.getElementById('center-speed-13'), data=JSON.parse(root.querySelector('[data-values]').textContent);
const svg=root.querySelector('.table-view'), detail=root.querySelector('[data-detail]'), legend=root.querySelector('.speed-legend'), zoom=root.querySelector('[data-zoom]');
let selected=null, enlarged=false;
const ns='http://www.w3.org/2000/svg', color=i=>`var(--viz-series-${i%6+1})`, fmt=v=>String(v);
function el(tag,attrs={},text,parent=svg){const n=document.createElementNS(ns,tag);Object.entries(attrs).forEach(([k,v])=>n.setAttribute(k,v));if(text!==undefined)n.textContent=text;parent.appendChild(n);return n}
function save(){window.openai?.setWidgetState({modelContent:{selectedSpeed:selected===null?null:data.rows[selected].v,spinX:0,spinY:0,aim:'fixed',referenceSpeed:2.625},privateContent:{selected,enlarged}})?.catch(()=>{})}
function restore(s){const p=s?.privateContent??{};selected=Number.isInteger(p.selected)&&p.selected>=0&&p.selected<13?p.selected:null;enlarged=!!p.enlarged;zoom.checked=enlarged}
data.rows.forEach((r,i)=>{const b=document.createElement('button');b.type='button';b.className='speed-choice cursor-interaction';b.dataset.index=i;b.style.setProperty('--series',color(i));b.setAttribute('aria-pressed','false');const s=document.createElement('span');s.className='swatch';s.setAttribute('aria-hidden','true');b.append(s,document.createTextNode(`${i+1} · ${fmt(r.v)} · ${r.rails.length}库`));b.setAttribute('aria-label',`第${i+1}档，${r.v}米每秒，${r.rails.length}库，${r.pot?'目标球进袋':'目标球未进袋'}`);b.onclick=()=>{selected=selected===i?null:i;draw();save()};legend.appendChild(b)});
root.querySelector('[data-all]').onclick=()=>{selected=null;draw();save()};zoom.onchange=()=>{enlarged=zoom.checked;draw();save()};
function draw(){
const w=root.clientWidth, pad=20, bounds=enlarged?[-1.12,-.32,-.24,.33]:[-1.40,1.40,-.76,.76],scale=(w-2*pad)/(bounds[1]-bounds[0]),h=(bounds[3]-bounds[2])*scale+2*pad;
svg.setAttribute('viewBox',`0 0 ${w} ${h}`);svg.style.height=h+'px';svg.replaceChildren();
const x=v=>pad+(v-bounds[0])*scale,y=v=>pad+(v-bounds[2])*scale;
el('title',{},'固定中心击球，只改变杆速');el('desc',{},'母球与第一目标球位置固定；每条曲线来自原生物理模拟。编号与下方13档杆速对应。');
const defs=el('defs'),clip=el('clipPath',{id:'center-speed-clip'},undefined,defs);el('rect',{x:0,y:0,width:w,height:h},undefined,clip);
const g=el('g',{'clip-path':'url(#center-speed-clip)'});
const line=(a,b,stroke,width=1,dash='')=>el('line',{x1:x(a[0]),y1:y(a[1]),x2:x(b[0]),y2:y(b[1]),stroke,'stroke-width':width,'stroke-dasharray':dash},undefined,g);
const path=(pts,stroke,width,opacity=1,dash='')=>el('path',{d:pts.map((p,j)=>`${j?'L':'M'}${x(p[0]).toFixed(2)},${y(p[1]).toFixed(2)}`).join(' '),fill:'none',stroke,'stroke-width':width,opacity,'stroke-linejoin':'round','stroke-linecap':'round','stroke-dasharray':dash},undefined,g);
data.geometry.lines.slice(0,6).forEach(l=>line([l.start.x,l.start.z],[l.end.x,l.end.z],'var(--muted-foreground)',3));
data.geometry.pockets.forEach((p,i)=>{el('circle',{cx:x(p.center.x),cy:y(p.center.z),r:p.radius*scale,fill:i===2?'var(--yellow)':'var(--muted-foreground)'},undefined,g)});
const ref=data.rows[selected??6];path(ref.objectPath,'var(--yellow)',1.7,.9,'5 4');
const order=data.rows.map((r,i)=>i).filter(i=>i!==selected);if(selected!==null)order.push(selected);
order.forEach(i=>{const r=data.rows[i],strong=selected===null||selected===i;path(r.cuePath,color(i),selected===i?3:1.65,strong?.85:.12);if(!r.scratch)el('circle',{cx:x(r.stop[0]),cy:y(r.stop[1]),r:selected===i?6:4,fill:'var(--background)',stroke:color(i),'stroke-width':selected===i?2.5:1.5,opacity:strong?1:.2},undefined,g)});
const occupied=[];
function label(p,text,priority=false){const cx=x(p[0]),cy=y(p[1]);if(cx<0||cx>w||cy<0||cy>h)return;const tw=Math.max(14,text.length*7),th=16;
for(const [dx,dy] of [[10,-10],[10,18],[-tw-8,-10],[-tw-8,18],[10,-26],[-tw-8,34],[10,34]]){let a=cx+dx,b=cy+dy,box=[a-2,b-th,a+tw+2,b+3];if(box[0]<1||box[2]>w-1||box[1]<1||box[3]>h-1)continue;if(occupied.some(q=>!(box[2]+3<q[0]||box[0]-3>q[2]||box[3]+3<q[1]||box[1]-3>q[3])))continue;occupied.push(box);el('text',{x:a,y:b,'paint-order':'stroke',stroke:'var(--background)','stroke-width':3,'stroke-linejoin':'round'},text,g);return}
}
const ball=(p,fill,stroke)=>el('circle',{cx:x(p[0]),cy:y(p[1]),r:data.geometry.radius*scale,fill,stroke,'stroke-width':2},undefined,g);
ball(data.cue,'var(--background)','var(--foreground)');ball(data.target,'var(--yellow)','var(--foreground)');label(data.cue,'C',true);label(data.target,'①',true);
if(selected!==null)label(data.rows[selected].stop,String(selected+1),true);else if(!enlarged)data.rows.forEach((r,i)=>label(r.stop,String(i+1)));
const sb=enlarged?.1:.5, yy=h-9;el('line',{x1:w-12-sb*scale,y1:yy,x2:w-12,y2:yy,stroke:'var(--foreground)','stroke-width':2});el('text',{x:w-12,y:yy-6,'text-anchor':'end'},`${sb*100} cm`);
detail.textContent=selected===null?`13档叠加 · ${data.rows.filter(r=>r.pot).length}/13 目标球进指定袋`:`第${selected+1}档 · ${ref.v} m/s · ${ref.rails.length}库 · 碰球后行程 ${ref.length.toFixed(2)} m · ${ref.pot?'目标球进袋':'目标球未进袋'}${ref.scratch?' · 母球落袋':''}`;
legend.querySelectorAll('button').forEach((b,i)=>b.setAttribute('aria-pressed',String(selected===i)));
root.dataset.selected=selected??'all';root.dataset.zoom=String(enlarged);
}
restore(window.openai?.widgetState);new ResizeObserver(draw).observe(root);draw();
window.addEventListener('openai:set_globals',e=>{if(e.detail?.globals?.widgetState){restore(e.detail.globals.widgetState);draw()}});
})();
