
  (() => {
    const root = document.getElementById("receiving-zones");
    const data = JSON.parse(root.querySelector("#receiving-zones-data").textContent);
    const svg = root.querySelector(".board");
    const NS="http://www.w3.org/2000/svg", R=data.ballRadius;
    const pocketNames=["左上角袋","右上角袋","左下角袋","右下角袋","上中袋","下中袋"];
    const groups=[["D","默认距离","20–60厘米"],["N","放近一点","12–60厘米"],["F","放远一点","20–90厘米"]];
    const saved=window.openai?.widgetState;
    let selected=data.samples.find(s=>s.id===(saved?.modelContent?.sampleId||saved?.privateContent?.sampleId))||data.samples[0];
    function el(tag,attrs,parent=svg) {
      const node=document.createElementNS(NS,tag);
      for(const [k,v] of Object.entries(attrs)) node.setAttribute(k,v);
      parent.appendChild(node); return node;
    }
    function textAt(x,y,text,attrs={}) {
      const n=el("text",{x,y,...attrs}); n.textContent=text; return n;
    }
    const add=(a,b)=>[a[0]+b[0],a[1]+b[1]];
    const sub=(a,b)=>[a[0]-b[0],a[1]-b[1]];
    const mul=(a,s)=>[a[0]*s,a[1]*s];
    const unit=a=>mul(a,1/Math.hypot(...a));
    function zonePoint(sample,deg,distance) {
      const u=unit(sub(data.pockets[sample.p2],sample.b2));
      const g=sub(sample.b2,mul(u,2*R));
      const a=deg*Math.PI/180;
      const w=[-u[0]*Math.cos(a)+u[1]*Math.sin(a),-u[0]*Math.sin(a)-u[1]*Math.cos(a)];
      const t=-2*R*Math.cos(a)+Math.sqrt(distance*distance-(2*R*Math.sin(a))**2);
      return add(g,mul(w,t));
    }
    function draw() {
      const s=selected;
      const W=Math.max(280,root.getBoundingClientRect().width);
      const pad=W<450?32:42, scale=(W-2*pad)/data.length;
      const H=data.width*scale+2*pad;
      const xy=p=>[pad+p[0]*scale,pad+p[1]*scale];
      svg.replaceChildren();
      svg.setAttribute("viewBox",`0 0 ${W} ${H}`);
      svg.style.height=`${H}px`;
      const title=el("title",{}); title.textContent=`${s.id}，母球及①②，接球距离${s.dmin*100}至${s.dmax*100}厘米，左右各20度`;
      const desc=el("desc",{}); desc.textContent="等比例球桌。阴影为母球球心的目标区域，圆环为人为选择的落点示意，不表示模拟结果。";
      const defs=el("defs",{});
      const clip=el("clipPath",{id:"receiving-zone-clip"},defs);
      el("rect",{x:pad+R*scale,y:pad+R*scale,width:(data.length-2*R)*scale,height:(data.width-2*R)*scale},clip);
      for (const [id,color] of [["one","var(--viz-series-3)"],["two","var(--viz-series-4)"]]) {
        const marker=el("marker",{id:`rz-${id}`,viewBox:"0 0 10 10",refX:9,refY:5,markerWidth:6,markerHeight:6,orient:"auto"},defs);
        el("path",{d:"M0 0L10 5L0 10Z",fill:color},marker);
      }
      el("rect",{x:pad-10,y:pad-10,width:data.length*scale+20,height:data.width*scale+20,rx:8,fill:"var(--muted)"});
      el("rect",{x:pad,y:pad,width:data.length*scale,height:data.width*scale,fill:"var(--background)",stroke:"var(--border)","stroke-width":1});
      function path(dmin,dmax,fill,opacity) {
        const pts=[];
        for(let a=-20;a<=20;a+=.5)pts.push(xy(zonePoint(s,a,dmax)));
        for(let a=20;a>=-20;a-=.5)pts.push(xy(zonePoint(s,a,dmin)));
        el("path",{d:pts.map((p,i)=>(i?"L":"M")+p.join(",")).join("")+"Z",fill,opacity,"clip-path":"url(#receiving-zone-clip)"});
      }
      path(.20,.60,"var(--viz-series-1)",.28);
      if(s.dmin<.20)path(s.dmin,.20,"var(--viz-series-2)",.48);
      if(s.dmax>.60)path(.60,s.dmax,"var(--viz-series-2)",.48);
      function contour(distance,dash) {
        const pts=[];for(let a=-20;a<=20;a+=.5)pts.push(xy(zonePoint(s,a,distance)));
        el("path",{d:pts.map((p,i)=>(i?"L":"M")+p.join(",")).join(""),fill:"none",stroke:"var(--foreground)","stroke-width":1,opacity:.55,"stroke-dasharray":dash,"clip-path":"url(#receiving-zone-clip)"});
      }
      contour(s.dmin,"");contour(s.dmax,"");
      if(s.dmin<.20)contour(.20,"3 3");
      if(s.dmax>.60)contour(.60,"3 3");
      for(const angle of [-20,20]) {
        const a=xy(zonePoint(s,angle,s.dmin)),b=xy(zonePoint(s,angle,s.dmax));
        el("line",{x1:a[0],y1:a[1],x2:b[0],y2:b[1],stroke:"var(--foreground)","stroke-width":1,opacity:.55,"clip-path":"url(#receiving-zone-clip)"});
      }
      const u=unit(sub(data.pockets[s.p2],s.b2)),g=sub(s.b2,mul(u,2*R)),gp=xy(g);
      const axisEnd=xy(zonePoint(s,0,s.dmax));
      el("line",{x1:gp[0],y1:gp[1],x2:axisEnd[0],y2:axisEnd[1],stroke:"var(--foreground)","stroke-dasharray":"2 4",opacity:.3,"clip-path":"url(#receiving-zone-clip)"});
      el("circle",{cx:gp[0],cy:gp[1],r:R*scale,fill:"none",stroke:"var(--foreground)","stroke-dasharray":"2 2",opacity:.4});
      for(let i=0;i<data.pockets.length;i++) {
        const p=xy(data.pockets[i]);
        el("circle",{cx:p[0],cy:p[1],r:6,fill:"var(--foreground)",opacity:.8});
      }
      function potLine(ball,pocket,color,marker,label) {
        const a=xy(ball),b=xy(data.pockets[pocket]);
        el("line",{x1:a[0],y1:a[1],x2:b[0],y2:b[1],stroke:color,"stroke-width":1.7,"stroke-dasharray":"5 4","marker-end":`url(#rz-${marker})`});
        let labelX=b[0],anchor="middle";
        if(pocket===0||pocket===2){labelX=b[0]+12;anchor="start"}
        if(pocket===1||pocket===3){labelX=b[0]-12;anchor="end"}
        textAt(labelX,b[1]+(pocket===0||pocket===1||pocket===4?-13:23),label,{"text-anchor":anchor});
      }
      potLine(s.b1,s.p1,"var(--viz-series-3)","one","①袋");
      potLine(s.b2,s.p2,"var(--viz-series-4)","two","②袋");
      function ball(p,label,fill,dx,dy) {
        const a=xy(p);el("circle",{cx:a[0],cy:a[1],r:R*scale,fill,stroke:"var(--foreground)","stroke-width":1});
        textAt(a[0]+dx,a[1]+dy,label,{class:"label-halo","text-anchor":"middle"});
      }
      ball(s.cue,"母球","var(--background)",0,22);
      ball(s.b1,"①","var(--viz-series-3)",-13,-10);
      ball(s.b2,"②","var(--viz-series-4)",13,-10);
      const probe=xy(s.probe);
      el("circle",{cx:probe[0],cy:probe[1],r:Math.max(4,R*scale),fill:"none",stroke:"var(--foreground)","stroke-width":1.6});
      el("circle",{cx:probe[0],cy:probe[1],r:1.7,fill:"var(--foreground)"});
      textAt(probe[0],probe[1]+23,`${Math.round(s.probeDistance*100)} cm`,{"text-anchor":"middle",class:"label-halo"});
      const rulerA=xy([.08,1.18]),rulerB=xy([.58,1.18]);
      el("line",{x1:rulerA[0],y1:rulerA[1],x2:rulerB[0],y2:rulerB[1],stroke:"var(--foreground)","stroke-width":1});
      for(const a of [rulerA,rulerB])el("line",{x1:a[0],y1:a[1]-3,x2:a[0],y2:a[1]+3,stroke:"var(--foreground)"});
      textAt((rulerA[0]+rulerB[0])/2,rulerA[1]-6,"50 cm",{"text-anchor":"middle",class:"label-halo"});
      root.querySelector(".sample-title").textContent=`${s.id} · ${s.title}`;
      root.querySelector(".meta").textContent=`① → ${pocketNames[s.p1]}　② → ${pocketNames[s.p2]}　目标距离 ${Math.round(s.dmin*100)}–${Math.round(s.dmax*100)}厘米`;
      root.querySelector(".sample-detail").textContent=s.id[0]==="D"
        ?`落点示意距② ${Math.round(s.probeDistance*100)}厘米，位于默认目标区。`
        :s.id[0]==="N"
        ?"近端新增12–20厘米；16厘米落点位于新增部分，原20–60厘米仍保留。"
        :`远端新增60–90厘米；${Math.round(s.probeDistance*100)}厘米落点位于新增部分，原20–60厘米仍保留。`;
      root.querySelectorAll("[data-sample]").forEach(b=>b.setAttribute("aria-pressed",String(b.dataset.sample===s.id)));
    }
    for(const [prefix,label,range] of groups) {
      const group=document.createElement("div");group.className="sample-group";
      const heading=document.createElement("div");heading.className="text-small";heading.textContent=`${label} · ${range}`;group.appendChild(heading);
      const buttons=document.createElement("div");buttons.className="sample-buttons";group.appendChild(buttons);
      for(const s of data.samples.filter(s=>s.id.startsWith(prefix))) {
        const b=document.createElement("button");b.type="button";b.className="btn";b.dataset.sample=s.id;
        b.textContent=s.id;b.setAttribute("aria-label",s.id+" "+s.title);
        b.addEventListener("click",()=>{
          selected=s;draw();
          window.openai?.setWidgetState?.({modelContent:{sampleId:s.id,title:s.title,rangeCm:[s.dmin*100,s.dmax*100]},privateContent:{sampleId:s.id}})?.catch(()=>{});
        });buttons.appendChild(b);
      }
      root.querySelector(".sample-groups").appendChild(group);
    }
    window.addEventListener("openai:set_globals",event=>{
      const state=event.detail?.globals?.widgetState;
      const found=data.samples.find(s=>s.id===(state?.modelContent?.sampleId||state?.privateContent?.sampleId));
      if(found){selected=found;draw()}
    });
    new ResizeObserver(draw).observe(root);
    draw();
  })();
