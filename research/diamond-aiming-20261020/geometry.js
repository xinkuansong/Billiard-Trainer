/* Frictionless geometry; only visible C, O, and selected P are inputs. */
(function(root){
  const add=(a,b)=>[a[0]+b[0],a[1]+b[1]], sub=(a,b)=>[a[0]-b[0],a[1]-b[1]], mul=(a,s)=>[a[0]*s,a[1]*s];
  const dot=(a,b)=>a[0]*b[0]+a[1]*b[1], cross=(a,b)=>a[0]*b[1]-a[1]*b[0], norm=a=>Math.hypot(...a);
  const unit=a=>mul(a,1/Math.max(norm(a),1e-15)), clamp=(x,a,b)=>Math.min(b,Math.max(a,x)), tau=2*Math.PI;
  const wrap=x=>(x%tau+tau)%tau, arcHas=(x,a,b)=>wrap(x-a)<=wrap(b-a)+1e-10;
  const fractions=[1,.75,.5,.25,.125], anchors=fractions.map(f=>Math.asin(1-f));
  function solve(c,o,p,D){
    const u=unit(sub(p,o)), w=sub(c,o), aSigned=cross(u,w), A=Math.abs(aSigned), B=-dot(w,u), H=B-D;
    const G=sub(o,mul(u,D)), e=unit(sub(G,c)), n=[-e[1],e[0]], contact=sub(o,mul(u,D/2));
    const aimX=dot(sub(G,o),n), contactX=dot(sub(contact,o),n);
    return {u,A,B,H,G,e,n,contact,aimX,contactX,r:norm(w),alpha:Math.atan2(A,B),theta:Math.atan2(A,H),
      f:1-A/Math.max(Math.hypot(A,H),1e-15),side:Math.sign(aSigned),
      valid:norm(sub(p,o))>1e-9&&norm(w)>D+1e-9&&H>1e-9};
  }
  const inside=(p,D)=>p[0]>=D/2&&p[0]<=8-D/2&&p[1]>=D/2&&p[1]<=4-D/2;
  function pointSeg(p,a,b){const v=sub(b,a),t=clamp(dot(sub(p,a),v)/Math.max(dot(v,v),1e-30),0,1);return norm(sub(p,add(a,mul(v,t))));}
  function segDist(a,b,c,d){
    const v=sub(b,a),w=sub(d,c),den=cross(v,w);
    if(Math.abs(den)>1e-15){const t=cross(sub(c,a),w)/den,s=cross(sub(c,a),v)/den;if(t>=0&&t<=1&&s>=0&&s<=1)return 0;}
    return Math.min(pointSeg(c,a,b),pointSeg(d,a,b),pointSeg(a,c,d),pointSeg(b,c,d));
  }
  function arcDist(a,b,c,r,start,end){
    const v=sub(b,a),w=sub(a,c),z=sub(b,c),normal=Math.atan2(v[1],v[0])+Math.PI/2;
    let best=Infinity;
    for(const angle of [start,end,Math.atan2(w[1],w[0]),Math.atan2(z[1],z[0]),normal,normal+Math.PI]){
      if(arcHas(angle,start,end))best=Math.min(best,pointSeg(add(c,[r*Math.cos(angle),r*Math.sin(angle)]),a,b));
    }
    const vv=dot(v,v),av=dot(w,v),disc=av*av-vv*(dot(w,w)-r*r);
    if(disc>=0)for(const sign of [-1,1]){const t=(-av+sign*Math.sqrt(disc))/Math.max(vv,1e-30),q=sub(add(a,mul(v,t)),c);
      if(t>=0&&t<=1&&arcHas(Math.atan2(q[1],q[0]),start,end))return 0;}
    return best;
  }
  function setup(raw){
    const U=raw.length_m/8,D=raw.diameter_m/U,grid=v=>add(mul(v,1/U),[4,2]);
    return {D,U,ideal:[[0,0],[8,0],[0,4],[8,4],[4,0],[4,4]],
      pockets:raw.pockets.map(p=>({center:grid(p.center),radius:p.radius/U,lip:p.lip.map(grid)})),
      lines:raw.lines.map(l=>({start:grid(l.start),end:grid(l.end)})),
      arcs:raw.arcs.map(a=>({...a,center:grid(a.center),radius:a.radius/U})),sights:raw.sights_m.map(grid)};
  }
  function pathClear(a,b,table){
    return table.lines.every(l=>segDist(a,b,l.start,l.end)>=table.D/2-1e-8)&&
      table.arcs.every(l=>arcDist(a,b,l.center,l.radius,l.start,l.end)>=table.D/2-1e-8);
  }
  function captureEnd(o,spec){
    const p=spec.center,v=sub(p,o);let lo=0,hi=1;
    for(let i=0;i<spec.lip.length;i++){
      const a=spec.lip[i],edge=sub(spec.lip[(i+1)%spec.lip.length],a),base=cross(edge,sub(o,a)),change=cross(edge,v);
      if(change>1e-15)lo=Math.max(lo,-base/change);else if(change< -1e-15)hi=Math.min(hi,-base/change);else if(base<0)hi=-1;
    }
    const t=Math.min(1-spec.radius/norm(v),lo<=hi?lo:Infinity);
    return add(o,mul(v,t));
  }
  function validity(c,o,p,table,real,pocket){
    const q=solve(c,o,p,table.D);
    if(norm(sub(c,o))<=table.D+1e-9)return '两球重叠或贴球：本模型不处理';
    if(norm(sub(p,o))<=1e-9)return '目标球与袋心重合';
    if(q.H<=1e-9)return '不可直切：B − D ≤ 0（擦边极限也不传递正向冲量）';
    if(!inside(c,table.D)||!inside(o,table.D)||!inside(q.G,table.D))return '碰撞路径超出保守合法球心区域';
    if(real&&(!pathClear(c,q.G,table)||!pathClear(o,captureEnd(o,table.pockets[pocket]),table)))return '直线路径被库鼻或袋角遮挡';
    return '';
  }
  function endpoint(g,d){let ts=[];for(const [i,k] of [[0,0],[0,8],[1,0],[1,4]]){if(Math.abs(d[i])>1e-12){const t=(k-g[i])/d[i];if(t>1e-8)ts.push(t);}}
    return ts.length?add(g,mul(d,Math.min(...ts))):g;}
  function quant(v,base){const actual=Math.atan2(v[1],v[0]);let best=0,error=Infinity;
    for(const a of base)for(const t of [a,Math.PI-a,Math.PI+a,tau-a]){const e=Math.abs(Math.atan2(Math.sin(actual-t),Math.cos(actual-t)));if(e<error){error=e;best=t;}}
    return best;}
  function predict(c,o,p,D){
    const q=solve(c,o,p,D),deg=x=>x*180/Math.PI,rad=x=>x*Math.PI/180,nearest=(a,x)=>a.reduce((i,v,j)=>Math.abs(v-x)<Math.abs(a[i]-x)?j:i,0);
    const base=[0,.25,1/3,.5,2/3,1,1.5,2,3,4,Infinity].map(Math.atan), d1=quant(sub(o,c),base),d2=quant(sub(p,o),base);
    const dual=Math.abs(Math.atan2(Math.sin(d1-d2),Math.cos(d1-d2)));
    const std=quant(sub(p,o),[0,.5,1,2,Infinity].map(Math.atan)),u=[Math.cos(std),Math.sin(std)],h=-dot(sub(c,o),u)-D;
    const ratios=[0,.25,.5,.6,1,8/7,1.8,2,4,8], labels=[0,14.5,26.6,30,45,48.6,61,63.4,76,83],ratio=q.A/q.H;
    let i=ratios.findIndex(r=>r>=ratio);if(i<0)i=ratios.length-1;
    const table=i===0?0:labels[i-1]+(labels[i]-labels[i-1])*(ratio-ratios[i-1])/(ratios[i]-ratios[i-1]);
    const normal=[-q.u[1],q.u[0]],sign=q.side||1;
    const rays=anchors.map(t=>{const d=add(mul(q.u,-Math.cos(t)),mul(normal,sign*Math.sin(t))),end=endpoint(q.G,d).map(x=>Math.round(x*4)/4),w=sub(end,q.G);return Math.atan2(Math.abs(cross(q.u,w)),-dot(q.u,w));});
    const coarse=Math.round(deg(q.alpha)/5)*5, sines=[0,.25,.5,.75,.875,1],s=sines[nearest(sines,Math.sin(rad(coarse)))];
    const values={alpha:q.alpha,dual_directions:dual,ratio_exact_oracle:q.theta,
      ratio_quarter_grid:Math.round(q.H*4)>0?Math.atan2(Math.round(q.A*4)/4,Math.round(q.H*4)/4):NaN,
      ratio_table10:ratio<=8?rad(table):NaN,standard_direction:h>0?Math.atan2(Math.abs(cross(u,sub(c,o))),h):NaN,
      fraction5_oracle:anchors[nearest(anchors,q.theta)],locus_quarter_template:inside(q.G,D)?anchors[nearest(rays,q.theta)]:NaN,
      first_order_oracle:q.alpha+D/q.r*Math.sin(q.alpha),first_order_mental:rad(coarse+10/q.r*s),dual_first_order:dual+D/q.r*Math.sin(dual)};
    for(const k of Object.keys(values))if(!q.valid||values[k]>=Math.PI/2)values[k]=NaN;
    return values;
  }
  root.DiamondGeometry={add,sub,mul,dot,cross,norm,unit,solve,inside,pointSeg,segDist,arcDist,setup,pathClear,captureEnd,validity,endpoint,predict,fractions,anchors};
  if(typeof module!=='undefined')module.exports=root.DiamondGeometry;
})(typeof window!=='undefined'?window:globalThis);
