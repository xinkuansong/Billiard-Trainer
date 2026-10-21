(()=>{
  const G=DiamondGeometry,T=G.setup(TABLE_GEOMETRY),$=id=>document.getElementById(id),NS='http://www.w3.org/2000/svg';
  const labels=['满球','3/4 球','半球','1/4 球','1/8 球'],colors=['#d8e8dd','#8cd8be','#ffd07b','#a4c8ff','#d3b7f0'];
  const names={alpha:['球型角直接当切角','忽略球径'],dual_directions:['双方向颗星角表','10 个斜率间隔 / 两方向作差'],ratio_exact_oracle:['A/(B−D) 精确计算','坐标计算基准，非实战口诀'],ratio_quarter_grid:['距离比例 / 1/4 格','A、B−D 各估至 1/4 格'],ratio_table10:['10 项距离比例表','含档间线性插值，需投影'],standard_direction:['标准进球方向','0 / 26.6 / 45 / 63.4 / 90°'],fraction5_oracle:['五档厚度 / 最优选档','预知角度的乐观下界'],locus_quarter_template:['1/4 颗星轨迹模板','需预先为当前 O、P 制作'],first_order_oracle:['一阶球径修正','精确 α + D/r·sinα'],first_order_mental:['5°估角 + 简化修正','需先会独立估 α'],dual_first_order:['双方向 + 球径修正','颗星角表后再修正']};
  let state={c:[4.4,2.8],o:[2,2],pocket:0,real:false,practice:false,revealed:false,noise:0,seed:1,lines:[]},drag=null;
  let drawing=false,draft=null,lineEdit=null,activePointer=null;
  const deg=x=>x*180/Math.PI,fmt=(x,n=1)=>Number.isFinite(x)?x.toFixed(n):'—';
  const point=p=>[60+p[0]*100,60+p[1]*100];
  function el(tag,attrs={},parent=$('table')){const e=document.createElementNS(NS,tag);Object.entries(attrs).forEach(([k,v])=>e.setAttribute(k,v));parent.append(e);return e;}
  function line(a,b,color,width=1.5,dash='',parent=$('table')){const [x1,y1]=point(a),[x2,y2]=point(b);return el('line',{x1,y1,x2,y2,stroke:color,'stroke-width':width,'stroke-dasharray':dash},parent);}
  function text(x,y,value,attrs={},parent=$('table')){const e=el('text',{x,y,fill:'#e4eee9','font-size':13,...attrs},parent);e.textContent=value;return e;}
  function seeded(seed){return()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};}
  function pocket(){return state.real?T.pockets[state.pocket].center:T.ideal[state.pocket];}
  function draw(){
    const p=pocket(),q=G.solve(state.c,state.o,p,T.D),reason=G.validity(state.c,state.o,p,T,state.real,state.pocket),visible=!state.practice||state.revealed;
    $('table').replaceChildren();
    const defs=el('defs'),clip=el('clipPath',{id:'feltClip'},defs);el('rect',{x:60,y:60,width:800,height:400},clip); const legalClip=el('clipPath',{id:'legalClip'},defs);el('rect',{x:60+T.D*50,y:60+T.D*50,width:800-T.D*100,height:400-T.D*100},legalClip);
    el('rect',{x:20,y:20,width:880,height:480,rx:18,fill:'#304e41'});
    el('rect',{x:60,y:60,width:800,height:400,fill:'#246851',id:'felt','data-width':8,'data-height':4});
    const content=el('g',{'clip-path':'url(#feltClip)'});
    if(!state.practice&&$('grid').checked){for(let x=0;x<=8;x+=.5)line([x,0],[x,4],x%1?'#36745f':'#50826f',x%1?.65:1,'',content);for(let y=0;y<=4;y+=.5)line([0,y],[8,y],y%1?'#36745f':'#50826f',y%1?.65:1,'',content);}
    for(let x=0;x<=8;x++)text(60+100*x,13,x,{'text-anchor':'middle','font-size':12,fill:'#647169'});
    for(let y=0;y<=4;y++)text(7,65+100*y,y,{'text-anchor':'middle','font-size':12,fill:'#647169'});
    const sights=state.real?T.sights:[...[1,2,3,5,6,7].flatMap(x=>[[x,-.28],[x,4.28]]),...[1,2,3].flatMap(y=>[[-.28,y],[8.28,y]])];
    for(const s of sights){const [x,y]=point(s);el('path',{d:`M ${x} ${y-4} l 3 4 -3 4 -3 -4 Z`,fill:'#e2dfca'});}
    const ps=state.real?T.pockets.map(x=>x.center):T.ideal;
    ps.forEach((pt,i)=>{const [cx,cy]=point(pt);el('circle',{cx,cy,r:14,fill:'#142b22',stroke:i===state.pocket?'#ffd07b':'#718f7f','stroke-width':i===state.pocket?3:1});if(i===state.pocket)text(cx,cy+4,'P',{'text-anchor':'middle','font-size':12,fill:'#ffd07b'});});
    if(state.real){for(const l of T.lines)line(l.start,l.end,'#afd0bf',1);for(const a of T.arcs){let span=((a.end-a.start)%(2*Math.PI)+2*Math.PI)%(2*Math.PI);let pts=[];for(let j=0;j<=24;j++)pts.push(point(G.add(a.center,[a.radius*Math.cos(a.start+span*j/24),a.radius*Math.sin(a.start+span*j/24)])).join(','));el('polyline',{points:pts.join(' '),fill:'none',stroke:'#afd0bf','stroke-width':1});}}
    if(visible&&$('loci').checked&&G.inside(q.G,T.D)){
      const n=[-q.u[1],q.u[0]],locusGroup=el('g',{'clip-path':'url(#legalClip)'});
      G.anchors.forEach((theta,i)=>{for(const side of i===0?[1]:[-1,1]){const d=G.add(G.mul(q.u,-Math.cos(theta)),G.mul(n,side*Math.sin(theta))),end=G.endpoint(q.G,d);line(q.G,end,colors[i],i===2?2.5:1.6,i===2?'':'5 4',locusGroup);}});
    }
    if(visible){
      if($('co').checked)line(state.c,state.o,'#cfdfd5',1.5,'5 5',content);
      if($('op').checked)line(state.o,p,'#ffd07b',2,'',content);
      if($('projection').checked){const foot=G.sub(state.o,G.mul(q.u,q.B));line(state.c,foot,'#a4c8ff',1.7,'4 4',content);line(foot,state.o,'#a4c8ff',1.7,'4 4',content);const [x,y]=point(foot);text(x+6,y-7,`A ${fmt(q.A,2)} / B ${fmt(q.B,2)}`,{'font-size':12},content);}
      if(!reason&&$('aim').checked)line(state.c,G.add(q.G,G.mul(q.e,.35)),'#fff',2,'',content);
    }
    drawAnnotations();
    const hitRadius=Math.max(17,22/Math.max($('table').getBoundingClientRect().width/920,.1));
    for(const [key,label,fill] of [['c','C','#fffdf5'],['o','O','#e6a147']]){const [cx,cy]=point(state[key]);el('circle',{cx,cy,r:hitRadius,fill:'transparent','data-ball':key,tabindex:0,role:'button','aria-label':label==='C'?'母球，可用方向键微调':'目标球，可用方向键微调'});el('circle',{cx,cy,r:T.D*50,fill,stroke:'#183f30','stroke-width':1,'pointer-events':'none'});text(cx+14,cy-13,label,{'font-size':15,'font-weight':600},$('table'));}
    $('legend').innerHTML=visible&&$('loci').checked?labels.map((s,i)=>`<span><i class="dot" style="background:${colors[i]};border:1px solid #a0ada5"></i>${s}</span>`).join(''):'';
    $('status').className='status'+(reason?' error':'');
    $('status').textContent=reason||((state.practice&&!state.revealed)?'先观察颗星和两球位置，作出判断后揭示。':'几何可直切 · '+(state.real?'已筛查库鼻与袋角入口；未模拟动态进球。':'理想无袋角模型；不等同真实可进袋。'));
    $('reveal').textContent=state.revealed?'隐藏答案再判断':'揭示几何结果';
    $('metrics').hidden=!visible;$('analysis').hidden=!visible;$('coordinatePanel').hidden=state.practice&&!state.revealed;$('guessPanel').hidden=!state.practice;
    for(const id of ['co','op','projection','aim','loci','grid'])$(id).disabled=state.practice&&!state.revealed;
    $('alpha').textContent=visible?fmt(deg(q.alpha))+'°':'—';
    $('theta').textContent=!reason&&visible?fmt(deg(q.theta))+'°':'不可达';
    $('fraction').textContent=!reason&&visible?fmt(q.f*100)+'%':'—';
    const k=G.anchors.reduce((a,t,i)=>Math.abs(t-q.theta)<Math.abs(G.anchors[a]-q.theta)?i:a,0);
    $('fractionLabel').textContent=!reason?`最近锚点：${labels[k]}；仍需档间微调`:'不输出可用瞄准厚度';
    [['cx',state.c[0]],['cy',state.c[1]],['ox',state.o[0]],['oy',state.o[1]]].forEach(([id,val])=>{if(document.activeElement!==$(id))$(id).value=val.toFixed(3);});
    drawFront(q,visible&&!reason);
    $('guessResult').textContent=state.practice&&state.revealed&&!reason?`该档角度差 ${fmt(Math.abs(deg(Math.asin(1-Number($('guess').value))-q.theta)))}°` :'';
    if(visible)drawMethods(q,reason);
    window.labState={...state,truth:{alpha:q.alpha,theta:q.theta,f:q.f,aimX:q.aimX,contactX:q.contactX},reason};
  }
  function drawAnnotations(){
    $('annotations')?.remove();
    const group=el('g',{id:'annotations'});
    const strokes=[...state.lines,...(draft?[draft]:[])];
    strokes.forEach((segment,i)=>{
      line(segment[0],segment[1],'#ff8f96',3,'',group).setAttribute('pointer-events','none');
      segment.forEach((p,end)=>{
        const [cx,cy]=point(p);
        el('circle',{cx,cy,r:4,fill:'#ff8f96',stroke:'#402e34','stroke-width':1,'pointer-events':'none'},group);
        if(drawing&&i<state.lines.length)el('circle',{cx,cy,r:13,fill:'transparent','data-line':i,'data-end':end},group);
      });
    });
    $('table').classList.toggle('drawing',drawing);
    $('drawLine').setAttribute('aria-pressed',String(drawing));
    $('moveBalls').setAttribute('aria-pressed',String(!drawing));
    $('undoLine').disabled=!state.lines.length;
    $('clearLines').disabled=!state.lines.length;
    $('lineHint').textContent=drawing?`拖动绘制直线，拖端点调整；Esc取消本笔。已画 ${state.lines.length} 条。`:`拖动母球或目标球；已保留 ${state.lines.length} 条手画线。`;
  }
  function drawFront(q,show){
    const svg=$('front');svg.replaceChildren();
    if(!show){text(150,95,state.practice&&!state.revealed?'判断后揭示':'当前球型不可直切',{'text-anchor':'middle',fill:'#647169'},svg);$('aimDescription').textContent='接触点与瞄准点使用不同标记。';return;}
    const cx=150,cy=78,r=43,s=43/(T.D/2),aim=cx+q.aimX*s,cp=cx+q.contactX*s;
    el('line',{x1:18,y1:cy,x2:282,y2:cy,stroke:'#c7d2c8'},svg);
    el('circle',{cx,cy,r,fill:'#e6a147',stroke:'#ae752d'},svg);
    el('circle',{cx:aim,cy,r,fill:'#fff','fill-opacity':.2,stroke:'#6d8a7b','stroke-dasharray':'5 4'},svg);
    el('line',{x1:aim,y1:19,x2:aim,y2:138,stroke:'#235eac','stroke-dasharray':'3 3'},svg);
    el('path',{d:`M ${aim-6} ${cy} h 12 M ${aim} ${cy-6} v 12`,stroke:'#235eac','stroke-width':2.5},svg);
    el('circle',{cx:cp,cy,r:4,fill:'#a12d37',stroke:'#fff','stroke-width':1},svg);
    el('circle',{cx,cy,r:2,fill:'#654b25'},svg);
    text(150,158,`＋ 瞄准参考：${fmt(q.aimX/(T.D/2),2)} R`,{'text-anchor':'middle',fill:'#235eac','font-size':13},svg);
    text(150,181,`● 接触点投影：${fmt(q.contactX/(T.D/2),2)} R`,{'text-anchor':'middle',fill:'#a12d37','font-size':13},svg);
    $('aimDescription').textContent=`瞄准参考在${Math.abs(q.aimX)>T.D/2+1e-8?'球轮廓之外':Math.abs(Math.abs(q.aimX)-T.D/2)<1e-8?'球边':'球轮廓之内'}。横向瞄准偏移是接触点投影偏移的两倍；接触点不是球杆所指位置。`;
  }
  function drawMethods(q,reason){
    const rng=seeded(state.seed),jitter=p=>p.map(x=>x+(rng()*2-1)*state.noise),cn=jitter(state.c),on=jitter(state.o),pred=G.predict(cn,on,pocket(),T.D);
    $('methods').innerHTML=Object.entries(names).map(([key,[title,note]])=>{const t=reason?NaN:pred[key];return `<tr><td>${title}<small>${note}</small></td><td>${fmt(deg(t))}°</td><td>${fmt(deg(Math.abs(t-q.theta)))}°</td><td>${fmt(Math.abs(Math.sin(t)-Math.sin(q.theta))*100)} pp</td></tr>`;}).join('');
    const mirror=v=>[state.pocket%2?8-v[0]:v[0],state.pocket>=2?4-v[1]:v[1]],oc=mirror(state.o),cc=mirror(cn),oo=mirror(on);
    if(reason||state.pocket>=4||Math.abs(oc[0]-oc[1])>1e-8){$('diagonalRule').textContent='当前不是可用的45°角袋基准球型。选择“45°角袋”示例查看；不把相近方向强行当成45°。';}
    else{const a=(oo[0]+oo[1])/2,delta=Math.abs(cc[0]-cc[1]),net=cc[0]+cc[1]-2*a-.25;
      $('diagonalRule').textContent=net>0?`已知45°布置。横竖差 Δ=${fmt(delta,2)}；和扣双目标、再扣¼格，净量=${fmt(net,2)}。5Δ=${fmt(5*delta,2)} ${5*delta>3*net?'>':'≤'} 三倍净量 ${fmt(3*net,2)}：口诀判${5*delta>3*net?'偏薄':'偏厚'}。估角 ${fmt(deg(Math.atan2(delta,net)))}°（当前观测误差±${state.noise}格）。`:'受扰动后净量≤0：这组观测不能使用口诀。';}
  }
  function random(){const rng=seeded(++state.seed*773);for(let i=0;i<5000;i++){
    const c=[T.D/2+rng()*(8-T.D),T.D/2+rng()*(4-T.D)],o=[T.D/2+rng()*(8-T.D),T.D/2+rng()*(4-T.D)];
    if(!G.validity(c,o,pocket(),T,state.real,state.pocket)){state.c=c;state.o=o;state.revealed=false;draw();return;}}
    $('status').textContent='未找到有效球型，请切换袋口后重试。';}
  $('model').onchange=e=>{state.real=e.target.value==='production';state.revealed=false;draw();};
  $('pocket').onchange=e=>{state.pocket=Number(e.target.value);state.revealed=false;draw();};
  $('mode').onchange=e=>{state.practice=e.target.value==='practice';state.revealed=false;draw();};
  $('noise').onchange=e=>{state.noise=Number(e.target.value);draw();};$('perturb').onclick=()=>{state.seed++;draw();};
  $('random').onclick=random;$('reveal').onclick=()=>{state.revealed=!state.revealed;$('reveal').textContent=state.revealed?'隐藏答案再判断':'揭示几何结果';draw();};$('guess').onchange=draw;
  ['grid','co','op','projection','aim','loci'].forEach(id=>$(id).onchange=draw);
  ['cx','cy','ox','oy'].forEach(id=>$(id).onchange=()=>{const v=Number($(id).value);if(Number.isFinite(v)){const axis=id[1]==='x'?0:1;state[id[0]][axis]=Math.max(T.D/2,Math.min((axis?4:8)-T.D/2,v));state.revealed=false;}draw();});
  const svg=$('table');
  function eventPoint(e,annotation=false){const p=svg.createSVGPoint();p.x=e.clientX;p.y=e.clientY;const q=p.matrixTransform(svg.getScreenCTM().inverse());const inset=annotation?-.4:T.D/2;return [Math.max(inset,Math.min(8-inset,(q.x-60)/100)),Math.max(inset,Math.min(4-inset,(q.y-60)/100))];}
  function cancelGesture(){
    if(lineEdit)state.lines[lineEdit.index]=lineEdit.original;
    drag=null;draft=null;lineEdit=null;
    if(activePointer!==null&&svg.hasPointerCapture(activePointer))svg.releasePointerCapture(activePointer);
    activePointer=null;
  }
  svg.onpointerdown=e=>{
    if(activePointer!==null||e.button!==0)return;
    if(drawing){
      const handle=e.target.closest('[data-line]');
      if(handle){const index=Number(handle.dataset.line);lineEdit={index,end:Number(handle.dataset.end),original:state.lines[index].map(p=>p.slice())};}
      else{const p=eventPoint(e,true);draft=[p,p.slice()];}
    }else{const ball=e.target.closest('[data-ball]');if(!ball)return;drag=ball.dataset.ball;}
    activePointer=e.pointerId;svg.setPointerCapture(e.pointerId);e.preventDefault();drawAnnotations();
  };
  svg.onpointermove=e=>{
    if(e.pointerId!==activePointer)return;
    if(draft){draft[1]=eventPoint(e,true);drawAnnotations();}
    else if(lineEdit){state.lines[lineEdit.index][lineEdit.end]=eventPoint(e,true);drawAnnotations();}
    else if(drag){state[drag]=eventPoint(e);state.revealed=false;draw();}
  };
  svg.onpointerup=e=>{
    if(e.pointerId!==activePointer)return;
    if(draft){draft[1]=eventPoint(e,true);if(G.norm(G.sub(draft[1],draft[0]))>.02)state.lines.push(draft);}
    if(lineEdit)state.lines[lineEdit.index][lineEdit.end]=eventPoint(e,true);
    lineEdit=null;cancelGesture();draw();
  };
  svg.onpointercancel=()=>{cancelGesture();draw();};
  svg.onlostpointercapture=()=>{if(activePointer!==null){cancelGesture();draw();}};
  $('drawLine').onclick=()=>{cancelGesture();drawing=true;drawAnnotations();};
  $('moveBalls').onclick=()=>{cancelGesture();drawing=false;drawAnnotations();};
  $('undoLine').onclick=()=>{cancelGesture();state.lines.pop();draw();};
  $('clearLines').onclick=()=>{cancelGesture();state.lines=[];draw();};
  document.addEventListener('keydown',e=>{if(e.key==='Escape'&&(draft||lineEdit)){e.preventDefault();cancelGesture();draw();}});
  svg.onkeydown=e=>{const ball=e.target.closest('[data-ball]');if(!ball)return;const dirs={ArrowLeft:[-.05,0],ArrowRight:[.05,0],ArrowUp:[0,-.05],ArrowDown:[0,.05]};if(dirs[e.key]){e.preventDefault();const key=ball.dataset.ball;state[key]=G.add(state[key],dirs[e.key]).map((v,i)=>Math.max(T.D/2,Math.min((i?4:8)-T.D/2,v)));state.revealed=false;draw();svg.querySelector(`[data-ball="${key}"]`).focus();}};
  document.querySelectorAll('[data-preset]').forEach(btn=>btn.onclick=()=>{
    state.pocket=0;$('pocket').value='0';state.o=[2,2];state.revealed=false;
    const which=btn.dataset.preset;
    if(which==='diagonal')state.c=[4.4,2.8];if(which==='near')state.c=[2.45,2.25];if(which==='invalid')state.c=[1.6,2];
    if(which==='thin'){const q=G.solve([4,3],state.o,pocket(),T.D),n=[-q.u[1],q.u[0]],t=55*Math.PI/180;state.c=G.add(q.G,G.add(G.mul(q.u,-1.7*Math.cos(t)),G.mul(n,1.7*Math.sin(t))));}
    draw();
  });
  $('export').onclick=()=>{const blob=new Blob([JSON.stringify({...state,geometrySource:TABLE_GEOMETRY.source_hashes,truth:window.labState.truth},null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='diamond-shot.json';a.click();URL.revokeObjectURL(url);};
  $('stats').innerHTML='<p>两套模型各 120,000 组有效样本，共 240,000 组；六袋各 20,000。所有方法使用相同球型和同组扰动。</p>'+[0,.1,.25].map(noise=>{const row=STATS.find(r=>r.model==='production'&&r.group==='all'&&r.method==='ratio_exact_oracle'&&r.noise_grid===noise);return row?`<p>实际几何、±${noise}格：精确公式 MAE ${fmt(row.mae_deg,2)}° / P95 ${fmt(row.p95_deg,2)}°；返回率 ${fmt(row.coverage*100)}%。</p>`:'';}).join('');
  draw();
})();
