
#include <vector>
#include <cmath>
#include <algorithm>
extern "C" double p15(const double *a,int n,const double *b,int m,double sigma,double ax,double az,double bx,double bz){
 auto k=[&](double x,double z,double y,double w){return std::pow(std::hypot(x-y,z-w),1.5);};
 double la=0,lb=0;for(int i=0;i<n;i++)la+=a[5*i+4];for(int j=0;j<m;j++)lb+=b[5*j+4];
 if(la+lb==0)return 100*std::exp2(-std::pow(k(ax,az,bx,bz),1.0/1.5)/sigma);
 std::vector<double> prev(m+1,0),cur(m+1,0);
 for(int j=0;j<m;j++)prev[j+1]=prev[j]+b[5*j+4]*k(ax,az,b[5*j],b[5*j+1]);
 for(int i=0;i<n;i++){
 const double *p=a+5*i;cur[0]=prev[0]+p[4]*k(p[0],p[1],bx,bz);
 for(int j=0;j<m;j++){
 const double *q=b+5*j;
 double up=prev[j+1]+p[4]*k(p[0],p[1],q[2],q[3]);
 double left=cur[j]+q[4]*k(p[2],p[3],q[0],q[1]);
 double diag=prev[j]+(p[4]+q[4])*k(p[0],p[1],q[0],q[1]);
 cur[j+1]=std::min({up,left,diag});
 }prev.swap(cur);
 }return 100*std::exp2(-std::pow(prev[m]/(la+lb),1.0/1.5)/sigma);
}
