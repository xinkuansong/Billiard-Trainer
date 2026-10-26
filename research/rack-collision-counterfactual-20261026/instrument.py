def instrument(name,s):
 if name=='CollisionDetector.swift':
  s=s.replace('struct CollisionDetector {','struct CollisionDetector {\n    static var researchBoundedApproaching = false')
  marker='        let roots = QuarticSolver.solveQuartic(a: a, b: b, c: c, d: d, e: e)'
  assert s.count(marker)==1
  s=s.replace(marker,'''        if researchBoundedApproaching {
            let bounded = QuarticSolver.boundedRealRoots(coefficients:[a,b,c,d,e],maxTime:maxTime)
            let entering = bounded.filter { t in
                let relativePosition = dp + dv*t + da*(0.5*t*t)
                let relativeVelocity = dv + da*t
                return dot(relativePosition,relativeVelocity) < 0
            }
            return smallestPositiveRoot(roots:entering,maxTime:maxTime)
        }
'''+marker)
 if name=='EventDrivenEngine.swift':
  marker='    private func resolveBallBallCollision(ballA: String, ballB: String) {'
  assert s.count(marker)==1
  s=s.replace(marker,'''    static var researchCanonicalPairs = false
'''+marker+'''
        if Self.researchCanonicalPairs && ballA > ballB {
            resolveBallBallCollision(ballA:ballB,ballB:ballA)
            return
        }
''')
 return s
