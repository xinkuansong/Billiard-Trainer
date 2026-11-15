let capture=MTLCaptureManager.shared()
try need(capture.supportsDestination(.gpuTraceDocument),"GPU trace capture unsupported")
try FileManager.default.createDirectory(at:captureWork,withIntermediateDirectories:true)
let headroom=pow(2.0,0.1)-1
let fragment="""
#pragma body
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
var reports=[[String:Any]]()
let captureVariants = experimentRound == "h9-capture"
 ? [("baseline",baseline),("constant-lamp",try unwrap(ClothShadowProgram.replacingLocalBalls(in: baseline),"Actual production H9"))]
 : [("baseline",baseline),("lamp-mask",lampCandidate),("squared",try squaredBlockers(baseline,"diagnosticGlobalQuality ? shadowMask:0u"))]
for (name,source) in captureVariants {
 let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
 for m in scene.mats {field.install(on:m);var mods=m.shaderModifiers ?? [:];mods[.surface]=source;mods[.fragment]=fragment;m.shaderModifiers=mods}
 _=input(scene,"single-near",0);_=try target.batch(8)
 let url=captureWork.appendingPathComponent(name+".gputrace")
 let descriptor=MTLCaptureDescriptor();descriptor.captureObject=device;descriptor.destination = .gpuTraceDocument;descriptor.outputURL=url
 try capture.startCapture(with:descriptor)
 do {_=try target.frame();capture.stopCapture()}catch{capture.stopCapture();throw error}
 try source.write(to:output.appendingPathComponent(name+".surface"),atomically:true,encoding:.utf8)
 try need(FileManager.default.fileExists(atPath:url.path),"Missing GPU trace")
 reports.append(["variant":name,"trace":url.path,"device":device.name,"purpose":"compiled program inspection, not performance ranking"])
 try write(reports,"results.json")
}
