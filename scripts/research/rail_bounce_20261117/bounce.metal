// One diffuse bounce from the finite cloth bed. The rectangle excludes the
// rail tops; pocket cut-outs and further bounces are not represented here.
float railBedFormFactor(float3 p, float3 n) {
    float3 corners[4]={float3(-1.27,0.8,-0.635)-p,float3(-1.27,0.8,0.635)-p,
                       float3(1.27,0.8,0.635)-p,float3(1.27,0.8,-0.635)-p};
    float3 clipped[8];int count=0;
    for(int i=0;i<4;++i){
        float3 a=corners[i],b=corners[(i+1)%4];float da=dot(a,n),db=dot(b,n);
        if(da>=0.0)clipped[count++]=a;
        if((da>=0.0)!=(db>=0.0))clipped[count++]=a+(b-a)*(da/(da-db));
    }
    if(count<3)return 0.0;
    float integral=0.0;
    for(int i=0;i<count;++i){
        float3 a=normalize(clipped[i]),b=normalize(clipped[(i+1)%count]);
        float3 c=cross(a,b);float len=length(c);
        if(len>1e-7)integral+=atan2(len,dot(a,b))*dot(c,n)/len;
    }
    return clamp(abs(integral)/(2.0*3.14159265),0.0,1.0);
}
