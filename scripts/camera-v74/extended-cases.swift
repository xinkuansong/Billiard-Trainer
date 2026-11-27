for degrees: Float in [0.1, 1, 5, 15] {
    var c=fresh();precondition(c.select(.thirdPerson,shot:shot(degrees),resetThirdPerson:true))
    measure("small-angle-\(degrees)",c)
}
for (name,distance,height,fov) in [("radial",Float(2.6),Float(0.65),Float(0)),
                                  ("height",1.65,1.4,0),("fov",1.65,0.65,75)] {
    let base=fresh();var snap=base.snapshot()
    snap.state.distance=distance;snap.state.height=height
    if fov>0 { snap.state.observationHorizontalFOV=fov }
    snap.pose=P01CameraMotion.evaluate(state:snap.state,shot:snap.shot,layout:layout)!
    var c=P01CameraMotion(recording:.init(geometryID:"v74",initial:snap,layout:layout,inputs:[]))!
    precondition(c.select(.thirdPerson,resetThirdPerson:true));measure(name+"-reset",c)
}
for scale: Float in [0.5,2] {
    var c=fresh();precondition(c.select(.firstPerson,animated:false))
    c.pinch(scale,preservingPitch:true)
    precondition(c.select(.firstPerson));measure("first-dolly-reset-\(scale)",c)
}
