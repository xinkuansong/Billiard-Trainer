import XCTest
import SceneKit
import simd
@testable import CuePhys

final class LineWidthScreenshotTests: XCTestCase {
    @MainActor func testExportWidthComparison() throws {
        let profiles: [(String, Float, Float)] = [("A  当前 · 主线 5.6 / 辅助 4 mm",0.0028,0.002),
            ("B  候选 · 主线 5 / 辅助 4 mm",0.0025,0.002),
            ("C  候选 · 主线 4 / 辅助 2.8 mm",0.002,0.0014)]
        let size = CGSize(width:1688,height:780)
        for view in ["aim-top", "aim-3d", "jump-side"] {
            let scene = AngleTrainingScene(); scene.setupScene(recipe:.liveReference)
            scene.setCameraMode(view == "aim-top" ? .topDown2D : .perspective3D,animated:false)
            scene.hideAllBalls(); scene.hideAllVisualization()
            let camera = SCNNode(); camera.camera = scene.cameraNode.camera?.copy() as? SCNCamera
            camera.camera?.zNear=0.01; camera.camera?.zFar=50
            scene.rootNode.addChildNode(camera)
            let y=scene.surfaceY+BallPhysics.radius
            let cue=SCNVector3(-0.65,y,0),target=SCNVector3(0.45,y,0)
            var shot: SpatialPracticeRecord.Shot?
            if view == "jump-side" {
                let q=try XCTUnwrap(try SpatialQuizBank.load(.jump).questions.first)
                let solved=SpatialQuizPhysics.solve(board:q.board,input:q.reference)
                XCTAssertTrue(solved.outcome.succeeded)
                let frozen=try XCTUnwrap(SpatialPracticeRecord.freeze(prediction:solved.prediction,input:q.reference.spatialInput,before:SpatialQuizInstance(q).board))
                shot=frozen
                for (key,pose) in frozen.before { scene.showBall(key:key,scenePosition:pose.position.scene) }
                scene.configureBallInstances([q.board.targetName,"_8"])
                let peak=try XCTUnwrap(frozen.paths[PositionPlayBall.cueKey]?.filter { $0.time <= (frozen.firstContactTime ?? 0) }.max { $0.position.y < $1.position.y })
                XCTAssertGreaterThan(peak.position.y,y+0.01)
                scene.cueBallNode?.position=peak.position.scene
                let dx=q.board.target.x-q.board.cue.x,dz=q.board.target.z-q.board.cue.z
                let len=hypotf(dx,dz),ux=dx/len,uz=dz/len
                let focus=SCNVector3(q.board.obstacle.x,scene.surfaceY+0.08,q.board.obstacle.z)
                camera.camera?.usesOrthographicProjection=false;camera.camera?.fieldOfView=42
                camera.position=SCNVector3(focus.x-ux*0.22+uz*0.82,scene.surfaceY+0.34,focus.z-uz*0.22-ux*0.82)
                camera.look(at:focus)
                let meta=XCTAttachment(data:try JSONEncoder().encode(q),uniformTypeIdentifier:"public.json")
                meta.name="jump-source";meta.lifetime = .keepAlways;add(meta)
            } else {
                scene.showBall(key:PositionPlayBall.cueKey,scenePosition:cue)
                scene.showBall(key:"_1",scenePosition:target);scene.configureBallInstances(["_1"])
                if view == "aim-top" {
                    camera.camera?.usesOrthographicProjection=true;camera.camera?.orthographicScale=0.83
                    camera.position=SCNVector3(0,scene.surfaceY+5,0);camera.eulerAngles=SCNVector3(-Float.pi/2,0,0)
                } else {
                    camera.camera?.usesOrthographicProjection=false;camera.camera?.fieldOfView=50
                    camera.position=SCNVector3(-1.15,scene.surfaceY+1.05,0.70);camera.look(at:SCNVector3(-0.05,scene.surfaceY,0))
                    scene.updateCueStick(cueBallPosition:cue,aimDirection:SCNVector3(1,0,0),elevationOverride:0.05235988,updatesCamera:false)
                }
            }
            let renderer=SCNRenderer(device:try XCTUnwrap(MTLCreateSystemDefaultDevice()),options:nil)
            renderer.scene=scene;renderer.pointOfView=camera;renderer.delegate=scene.contactOcclusion
            var pictures:[UIImage]=[]
            for (index,profile) in profiles.enumerated() {
                let holder=SCNNode();scene.rootNode.addChildNode(holder)
                if let shot {
                    WidthComparisonRendering.comparisonRadius=profile.1
                    WidthComparisonRendering.appendBallRoute(shot,key:PositionPlayBall.cueKey,detail:.minimal,to:holder,scene:scene)
                } else {
                    let ghost=SCNVector3(target.x-2*BallPhysics.radius,y,target.z)
                    XCTAssertEqual(target.x-ghost.x,2*BallPhysics.radius,accuracy:0.000001)
                    let main=scene.addLine(from:cue,to:ghost,color:TrajectoryStyle.aimColor,radius:profile.1,placement:.table)
                    holder.addChildNode(main)
                    var nodes:[SCNNode]=[]
                    scene.addDashedPolyline([target,SCNVector3(1.15,y,0)],color:TrajectoryStyle.potColor(for:"_1"),radius:profile.1,placement:.table,into:&nodes)
                    scene.addDashedPolyline([ghost,SCNVector3(ghost.x,y,0.52)],color:TrajectoryStyle.hintColor,radius:profile.2,dash:TrajectoryStyle.hintDash,gap:TrajectoryStyle.hintGap,placement:.table,into:&nodes)
                    for node in nodes { holder.addChildNode(node) }
                }
                SCNTransaction.flush()
                _=renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
                let image=renderer.snapshot(atTime:1,with:size,antialiasingMode:.multisampling4X)
                pictures.append(image)
                let attachment=XCTAttachment(image:image);attachment.name="\(view)-\(index)";attachment.lifetime = .keepAlways;add(attachment)
                holder.removeFromParentNode();SCNTransaction.flush()
            }
            let format=UIGraphicsImageRendererFormat();format.scale=1
            let plate=UIGraphicsImageRenderer(size:CGSize(width:size.width,height:(size.height+68)*3),format:format).image { _ in
                UIColor(white:0.07,alpha:1).setFill();UIRectFill(CGRect(x:0,y:0,width:size.width,height:(size.height+68)*3))
                for i in 0..<3 {
                    let top=CGFloat(i)*(size.height+68)
                    (profiles[i].0 as NSString).draw(at:CGPoint(x:30,y:top+16),withAttributes:[.font:UIFont.systemFont(ofSize:29,weight:.semibold),.foregroundColor:UIColor.white])
                    pictures[i].draw(in:CGRect(x:0,y:top+68,width:size.width,height:size.height))
                }
            }
            let attachment=XCTAttachment(image:plate);attachment.name="comparison-\(view)";attachment.lifetime = .keepAlways;add(attachment)
        }
    }
}
