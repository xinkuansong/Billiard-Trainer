def instrument(s):
 def once(a,b):
  nonlocal s
  assert s.count(a)==1,(a,s.count(a));s=s.replace(a,b)
 once('                    candidates.append(immediate)','                    ResearchTrace.candidate("immediate", a:ballA,b:ballB,dt:0,now:currentTime,horizon:detectionMaxTime)\n                    candidates.append(immediate)')
 start=s.index('                // Check cache first',s.index('// Find ball-ball collisions'));end=s.index('// Find ball-cushion collisions',start)
 chunk=s[start:end]
 chunk=chunk.replace('                        candidates.append(cached)','                        ResearchTrace.candidate("cache",a:ballA,b:ballB,dt:cached.time,now:currentTime,horizon:detectionMaxTime)\n                        candidates.append(cached)')
 chunk=chunk.replace('time: collisionTime,','time: collisionTime,')
 marker='                    eventCache.setBallBall(ballA: nameA, ballB: nameB, event: event, currentTime: currentTime)'
 assert chunk.count(marker)==2
 chunk=chunk.replace(marker,'                    ResearchTrace.candidate("quartic",a:ballA,b:ballB,dt:event.time,now:currentTime,horizon:detectionMaxTime)\n'+marker,1)
 idx=chunk.index('// Quartic missed')
 chunk=chunk[:idx]+chunk[idx:].replace(marker,'                    ResearchTrace.candidate("fallback",a:ballA,b:ballB,dt:event.time,now:currentTime,horizon:detectionMaxTime)\n'+marker,1)
 s=s[:start]+chunk+s[end:]
 once('        return candidates.min()','        let researchSelected = candidates.min()\n        ResearchTrace.selected(researchSelected,now:currentTime)\n        return researchSelected')
 once('        // Ref: pooltool/physics/resolve/ball_ball/core.py CoreBallBallCollision.make_kiss\n', '        ResearchTrace.pair("beforeKiss",a:stateA,b:stateB,now:currentTime)\n        // Ref: pooltool/physics/resolve/ball_ball/core.py CoreBallBallCollision.make_kiss\n')
 once('        let approach = ContactSoundEvent.approach(stateA.velocity - stateB.velocity,','        ResearchTrace.pair("beforeImpulse",a:stateA,b:stateB,now:currentTime)\n        let approach = ContactSoundEvent.approach(stateA.velocity - stateB.velocity,')
 once('        balls[ballA] = stateA\n        balls[ballB] = stateB','        ResearchTrace.pair("afterImpulse",a:stateA,b:stateB,now:currentTime)\n        balls[ballA] = stateA\n        balls[ballB] = stateB')
 return s
