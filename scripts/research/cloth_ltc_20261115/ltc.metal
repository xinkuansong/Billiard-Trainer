// H18 independent LTC density and polygon integral, local Z is shading normal.
float3 h18Transform(float3 q,float4 a,float4 b) {
 return float3(a.x*q.x+a.y*q.z,a.z*q.y,a.w*q.x+b.x*q.z);
}
float h18Density(float3 l,float4 a,float4 b) {
 float3 q=h18Transform(l,a,b);float q2=dot(q,q);
 float determinant=a.z*(a.x*b.x-a.y*a.w);
 return b.y*determinant*max(0.0,q.z)/(3.14159265*q2*q2);
}
float h18Edge(float3 p,float3 q) {
 float3 cr=cross(p,q);float sine=length(cr);
 return cr.z*atan2(sine,dot(p,q))/max(1e-8,sine);
}
float3 h18World(float3 q,float3 wx,float3 wy,float3 wz){return float3(dot(q,wx),dot(q,wy),dot(q,wz));}
float h18Polygon(float3 c,float3 u,float3 v,float3 wx,float3 wy,float3 wz,float amplitude) {
 float3 q0=h18World(c-u-v,wx,wy,wz),q1=h18World(c+u-v,wx,wy,wz);
 float3 q2=h18World(c+u+v,wx,wy,wz),q3=h18World(c-u+v,wx,wy,wz);
 if(min(min(q0.z,q1.z),min(q2.z,q3.z))>0.0){
  q0=normalize(q0);q1=normalize(q1);q2=normalize(q2);q3=normalize(q3);
  return abs(h18Edge(q0,q1)+h18Edge(q1,q2)+h18Edge(q2,q3)+h18Edge(q3,q0))*amplitude/(2.0*3.14159265);
 }
 float3 transformed[4]={q0,q1,q2,q3};
 float3 clipped[6];int count=0;
 for(int j=0;j<4;++j){
  float3 p=transformed[j],q=transformed[(j+1)%4];
  if(p.z>0.0)clipped[count++]=p;
  if((p.z>0.0)!=(q.z>0.0))clipped[count++]=p+(q-p)*p.z/(p.z-q.z);
 }
 if(count<3)return 0.0;
 for(int j=0;j<count;++j)clipped[j]=normalize(clipped[j]);
 float total=0.0;
 for(int j=0;j<count;++j){float3 p=clipped[j],q=clipped[(j+1)%count];float3 cr=cross(p,q);float sine=length(cr);total+=cr.z*atan2(sine,dot(p,q))/max(1e-8,sine);}
 return abs(total)*amplitude/(2.0*3.14159265);
}
