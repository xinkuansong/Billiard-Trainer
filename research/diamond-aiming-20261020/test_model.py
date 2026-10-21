import unittest, json, subprocess
import numpy as np
from model import *

class GeometryTests(unittest.TestCase):
    def test_source_dimensions(self):
        self.assertAlmostEqual(D,.18,places=7)
        self.assertAlmostEqual(RAW['length_m']/RAW['width_m'],2,places=7)
        self.assertEqual(len(RAW['sights_m']),18)
        self.assertTrue(np.allclose(REAL_P[0],[-.042/UNIT,-.042/UNIT],atol=2e-7))

    def test_constructed_angles_and_first_contact(self):
        rng=np.random.default_rng(912)
        n=10000; phi=rng.uniform(-np.pi,np.pi,n);theta=rng.uniform(0,np.pi/2-1e-5,n)
        u=np.c_[np.cos(phi),np.sin(phi)]; normal=np.c_[-u[:,1],u[:,0]]
        o=rng.uniform(-10,10,(n,2));p=o+u*rng.uniform(.1,10,(n,1));length=rng.uniform(.01,10,n)
        e=np.cos(theta)[:,None]*u+np.sin(theta)[:,None]*normal
        g=o-D*u;c=g-length[:,None]*e;q=solve(c,o,p)
        np.testing.assert_allclose(q['theta'],theta,atol=1e-12)
        np.testing.assert_allclose(q['f'],1-np.sin(theta),atol=1e-12)
        # All earlier points remain strictly outside the radius-D exclusion circle.
        for scale in [.1,.5,.999]: self.assertTrue(np.all(norm(c+scale*length[:,None]*e-o)>D))
        np.testing.assert_allclose(norm(g-o),D,atol=1e-12)

    def test_signed_angle_not_triangle_angle(self):
        q=solve(np.array([[4.,2.]]),np.array([[2.,2.]]),np.array([[0.,0.]]))
        self.assertAlmostEqual(float(q['alpha'][0]),np.pi/4)
        self.assertGreater(q['theta'][0],q['alpha'][0])

    def test_invalid_and_degenerate(self):
        o=np.array([[2.,2.]]);p=np.array([[0.,2.]])
        for c in [o,o+[[D,0]],o+[[-1,0]],o+[[D,1]]]:
            self.assertFalse(bool(solve(c,o,p)['valid'][0]))
        self.assertFalse(bool(solve(o+[[1,0]],o,o)['valid'][0]))

    def test_reflection_rotation_translation(self):
        c=np.array([[4.1,2.9]]);o=np.array([[2.,1.4]]);p=np.array([[0.,0.]])
        q=solve(c,o,p)
        for matrix in [np.array([[-1,0],[0,1]]),np.array([[0,-1],[1,0]]),-np.eye(2)]:
            t=np.array([10,-8]);other=solve(c@matrix+t,o@matrix+t,p@matrix+t)
            np.testing.assert_allclose(other['theta'],q['theta'],atol=1e-13)

    def test_locus_and_front_projection(self):
        o=np.array([2.,2.]);p=np.array([0.,0.]);u=unit(p-o);n=np.array([-u[1],u[0]]);g=o-D*u
        for t in ANCHORS:
            for side in [-1,1]:
                direction=-np.cos(t)*u+side*np.sin(t)*n
                for length in [.1,.5,2]:
                    c=g+length*direction;q=solve(c[None],o[None],p[None])
                    self.assertAlmostEqual(q['theta'][0],t,places=12)
                    e=unit(g-c);right=np.array([-e[1],e[0]])
                    aim=dot(g-o,right);contact=dot(-D/2*u,right)
                    self.assertAlmostEqual(aim,2*contact,places=12)
                    self.assertAlmostEqual(abs(aim),D*np.sin(t),places=12)
                    if t>np.pi/6+1e-8:self.assertGreater(abs(aim),D/2)

    def test_collision_primitives(self):
        a=np.array([[-2.,0.],[-2.,2.]]);b=np.array([[2.,0.],[2.,2.]])
        np.testing.assert_allclose(segment_arc_distance(a,b,np.zeros(2),1,0,np.pi),[0,1],atol=1e-12)
        np.testing.assert_allclose(segment_distance(a,b,np.array([0,-1]),np.array([0,1])),[0,1])
        # Endpoint-only closest case; normal point is outside the quarter arc.
        self.assertGreater(segment_arc_distance(np.array([[-2.,-2.]]),np.array([[-1.,-1.]]),np.zeros(2),1,0,np.pi/2)[0],2)

    def test_production_pocket_entry_and_rail_rejection(self):
        self.assertTrue(feasible(np.array([[4.,2.]]),np.array([[2.,2.]]),REAL_P[0],True,0)[0])
        # Very shallow side-pocket approach must meet a nose before reaching the lip.
        self.assertFalse(path_clear(np.array([[1.,.12]]),capture_endpoint(np.array([[1.,.12]]),4))[0])
        for pocket in range(6):
            o=np.array([[4.,2.]]) if pocket<4 else np.array([[4.,2.8]])
            end=capture_endpoint(o,pocket)
            self.assertTrue(np.all(np.isfinite(end)))

    def test_indistinguishable_positions(self):
        o=np.array([[2.,2.],[2.,2.]]);p=np.zeros((2,2));c=np.array([[2.35,2.35],[2.45,2.25]])
        q=solve(c,o,p)
        self.assertTrue(np.all(feasible(c,o,p)))
        self.assertGreater(np.rad2deg(np.ptp(q['theta'])),10)

    def test_diameter_error_bound(self):
        for r in [.181,.5,1,2,4,8]:
            alpha=np.linspace(0,np.arccos(D/r)-1e-10,10001)
            theta=np.arctan2(r*np.sin(alpha),r*np.cos(alpha)-D)
            self.assertLessEqual(float(np.max(theta-alpha)),np.arcsin(D/r)+1e-10)
            self.assertAlmostEqual(float(np.max(theta-alpha)),np.arcsin(D/r),places=6)

    def test_quarter_correction_bound(self):
        eta=D-.25/np.sqrt(2)
        for h in [.001,.25,.5,1,2]:
            a=np.geomspace(1e-8,1e3,10000)
            error=np.arctan2(a,h)-np.arctan2(a,h+eta)
            bound=np.arctan(eta/(2*np.sqrt(h*(h+eta))))
            self.assertLessEqual(float(np.max(error)),bound+1e-12)

    def test_all_methods_match_javascript(self):
        fixtures=json.loads((HERE/'results/fixtures.json').read_text())
        rng=np.random.default_rng(71);cases=[]
        for f in fixtures:
            for noise in [0,.1,.25]:
                c=np.array(f['c'])+rng.uniform(-noise,noise,2)
                o=np.array(f['o'])+rng.uniform(-noise,noise,2);p=np.array(f['p'])
                pred=predictions(c[None],o[None],p[None])
                cases.append(dict(c=c.tolist(),o=o.tolist(),p=p.tolist(),D=D,
                    expected={k:float(v[0]) if np.isfinite(v[0]) else None for k,v in pred.items()}))
        js="""const fs=require('fs'),G=require('./geometry.js');
        for(const v of JSON.parse(fs.readFileSync(0,'utf8'))){const got=G.predict(v.c,v.o,v.p,v.D);
          for(const [k,x] of Object.entries(v.expected)){if(x===null ? Number.isFinite(got[k]) : Math.abs(got[k]-x)>1e-9)
            throw Error(JSON.stringify({key:k,expected:x,got:got[k],c:v.c,o:v.o}));}}
        console.log('360 observation cases x 11 methods matched');"""
        result=subprocess.run(['node','-e',js],input=json.dumps(cases),text=True,cwd=HERE,capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr)

if __name__=='__main__':unittest.main(verbosity=2)
