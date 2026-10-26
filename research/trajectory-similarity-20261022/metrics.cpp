#include <vector>
#include <cmath>
#include <algorithm>
#include <limits>
// Euclidean centimetres; unrestricted closed-end monotone paths.
extern "C" void metrics(const double* a,int n,const double* b,int m,double* out) {
    const double inf=std::numeric_limits<double>::infinity();
    std::vector<double> f(m,inf),d(m,inf),s(m,inf),mnB(m,inf);
    std::vector<int> lens(m,0);
    double sumA=0;
    for(int i=0;i<n;i++) {
        double pf=inf,pd=inf,ps=inf,rowmin=inf;int pl=0;
        for(int j=0;j<m;j++) {
            double c=std::hypot(a[2*i]-b[2*j],a[2*i+1]-b[2*j+1]);
            double oldf=f[j],oldd=d[j],olds=s[j];int oldl=lens[j];
            rowmin=std::min(rowmin,c);mnB[j]=std::min(mnB[j],c);
            if(i==0 && j==0){f[j]=c;d[j]=c;lens[j]=1;s[j]=2*c;}
            else {
                f[j]=std::max(c,std::min({oldf,pf,j?f[j-1]:inf}));
                auto best=std::pair<double,int>(oldd,oldl);
                if(i && j)best=std::min(best,std::pair<double,int>(pd,pl));
                if(j)best=std::min(best,std::pair<double,int>(d[j-1],lens[j-1]));
                d[j]=best.first+c;lens[j]=best.second+1;
                s[j]=std::min({olds+c,j?s[j-1]+c:inf,(i&&j)?ps+2*c:inf});
            }
            pf=oldf;pd=oldd;pl=oldl;ps=olds;
        }
        sumA+=rowmin;
    }
    double sumB=0;for(auto x:mnB)sumB+=x;
    out[0]=f[m-1];out[1]=d[m-1]/lens[m-1];out[2]=0.5*(sumA/n+sumB/m);
    out[3]=lens[m-1];out[4]=s[m-1]/(n+m);out[5]=d[m-1];
}
