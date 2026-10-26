
#include <vector>
#include <algorithm>
#include <cmath>
extern "C" double similarity(const double *a,int n,const double *b,int m,double sigma) {
 std::vector<double> prev(m+1,0),cur(m+1,0);
 double la=0,lb=0;for(int i=0;i<n;i++)la+=a[3*i+2];for(int j=0;j<m;j++)lb+=b[3*j+2];
 for(int i=0;i<n;i++){cur[0]=0;for(int j=0;j<m;j++){
 double d=std::hypot(a[3*i]-b[3*j],a[3*i+1]-b[3*j+1]);
 double gain=std::min(a[3*i+2],b[3*j+2])*std::exp2(-d/sigma);
 cur[j+1]=std::max({prev[j+1],cur[j],prev[j]+gain});
 }prev.swap(cur);}
 return 100*prev[m]/std::max(la,lb);
}
