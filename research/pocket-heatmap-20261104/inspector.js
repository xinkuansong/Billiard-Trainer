const letters=['E','A','F','B','C','D'],names=['左下角袋','左上角袋','右下角袋','右上角袋','左中袋','右中袋'];
const palette=['#dd8740','#3778c7','#b56cbc','#2c9b64','#c85361','#35a6aa'];
function cellAt(ix,iz){return DATA.cells[ix*DATA.nz+iz]}
function nearest(x,z){const ix=Math.max(0,Math.min(DATA.nx-1,Math.round((x-DATA.x[0])/(DATA.x.at(-1)-DATA.x[0])*(DATA.nx-1))));const iz=Math.max(0,Math.min(DATA.nz-1,Math.round((z-DATA.z[0])/(DATA.z.at(-1)-DATA.z[0])*(DATA.nz-1))));return cellAt(ix,iz)}
function ranking(c){return c.valid?c.widths.map((width,pocket)=>({pocket,width})).sort((a,b)=>b.width-a.width||a.pocket-b.pocket):[]}
function color(w){if(w<=0)return '#bfc5c1';return LUT[Math.min(255,Math.round(Math.sqrt(w/VMAX)*255))]}
const SCALE=290,CX=225,CY=420;
function xy(x,z){return [CX+z*SCALE,CY-x*SCALE]}
function gridBounds(a,i){return [i===0?a[0]:(a[i-1]+a[i])/2,i===a.length-1?a.at(-1):(a[i]+a[i+1])/2]}
function draw(canvas,region,c){const ctx=canvas.getContext('2d');ctx.clearRect(0,0,450,840);ctx.fillStyle='#f4f2ec';ctx.fillRect(0,0,450,840);
 for(const q of DATA.cells){if(!q.valid)continue;const [x0,x1]=gridBounds(DATA.x,q.ix),[z0,z1]=gridBounds(DATA.z,q.iz),[left,top]=xy(x1,z0);ctx.fillStyle=region?(q.bestPocket<0?'#bfc5c1':palette[q.bestPocket]):color(q.maxDegrees);ctx.fillRect(left,top,(z1-z0)*SCALE+.1,(x1-x0)*SCALE+.1);
 if(region&&q.ties.length>1){const [x,y]=xy(DATA.x[q.ix],DATA.z[q.iz]);ctx.fillStyle='#fff';ctx.fillRect(x-.6,y-.6,1.2,1.2)}}
 ctx.strokeStyle='#736650';ctx.lineWidth=8;const [l,t]=xy(1.27,-.635);ctx.strokeRect(l,t,1.27*SCALE,2.54*SCALE);
 if(c&&c.valid){const target=[DATA.x[c.ix],DATA.z[c.iz]],[px,py]=xy(...target);const i=c.bestInterval;if(i&&i.leftEnd){ctx.beginPath();ctx.moveTo(px,py);ctx.lineTo(...xy(...i.leftEnd));ctx.lineTo(...xy(...i.rightEnd));ctx.closePath();ctx.fillStyle='#ffffff66';ctx.fill();ctx.strokeStyle='#fff';ctx.lineWidth=1.5;ctx.stroke()};ctx.beginPath();ctx.arc(px,py,DATA.radius*SCALE,0,2*Math.PI);ctx.fillStyle='#f8faf4';ctx.fill();ctx.strokeStyle='#173e35';ctx.lineWidth=2;ctx.stroke()}
 for(const p of DATA.pockets){const [x,y]=xy(...p.center);ctx.beginPath();ctx.arc(x,y,12,0,2*Math.PI);ctx.fillStyle='#233a32';ctx.fill();ctx.fillStyle='#fff';ctx.font='bold 13px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(letters[p.index],x,y)}
}
function description(c){if(!c.valid)return '该位置不在本轮有效采样域。';const selected=c.maxDegrees>0?c.ties.map(p=>letters[p]+' '+names[p]).join(' / '):'未找到非零干净窗口';return `采样点 X ${(DATA.x[c.ix]*100).toFixed(1)} cm，Z ${(DATA.z[c.iz]*100).toFixed(1)} cm；最佳：${selected}；最大容错角 ${c.maxDegrees.toFixed(2)}°。`}
function setup(){const heat=document.getElementById('heat'),region=document.getElementById('region'),detail=document.getElementById('detail'),list=document.getElementById('ranking');let current=nearest(0,0);
 function select(c){current=c;draw(heat,false,c);draw(region,true,c);detail.textContent=description(c);list.innerHTML=ranking(c).map(q=>`<tr><td><span style="color:${palette[q.pocket]}">●</span> ${letters[q.pocket]} ${names[q.pocket]}</td><td>${q.width.toFixed(2)}°</td><td>${c.ties.includes(q.pocket)?'并列最优'.replace('并列',c.ties.length>1?'并列':''):''}</td></tr>`).join('')}
 for(const cv of [heat,region])cv.addEventListener('click',event=>{const r=cv.getBoundingClientRect(),u=(event.clientX-r.left)*450/r.width,v=(event.clientY-r.top)*840/r.height;const z=(u-CX)/SCALE,x=(CY-v)/SCALE;if(x<DATA.x[0]-1e-9||x>DATA.x.at(-1)+1e-9||z<DATA.z[0]-1e-9||z>DATA.z.at(-1)+1e-9)return;select(nearest(x,z))});select(current)}
if(typeof document!=='undefined')setup();
