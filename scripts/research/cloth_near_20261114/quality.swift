// H9 expanded qualification. Not a benchmark or full App/shot simulation.
try checkConstantArrayABI()
let candidate=try constantArray(lampCandidate)
let headroom=pow(2.0,0.1)-1
let fragment="""
#pragma body
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
func install(_ s:SceneFixture,_ source:String){for m in s.mats{var mods=m.shaderModifiers ?? [:];mods[.surface]=source;mods[.fragment]=fragment;m.shaderModifiers=mods};SCNTransaction.flush()}
try baseline.write(to:output.appendingPathComponent("baseline.surface"),atomically:true,encoding:.utf8)
try candidate.write(to:output.appendingPathComponent("constant-lamp.surface"),atomically:true,encoding:.utf8)
let colors:[(String,[Double])]=[("green",[48,155,32]),("tournamentBlue",[50,141,181]),("mistGray",[133,140,139]),("burgundy",[121,62,75]),("blueGray",[88,126,142]),("camel",[171,146,108])]
var comparisons=[[String:Any]](),largest=0,aaChanges=0
func compare(_ scene:SceneFixture,_ target:Target,_ name:String)throws {
 install(scene,baseline);_=try target.batch(3);let a=try target.read();_=try target.frame();let aa=try target.read()
 install(scene,candidate);_=try target.batch(3);let b=try target.read()
 let delta=difference(a,b),noise=difference(a,aa)
 largest=max(largest,delta["maximumChannelDifference"]!);aaChanges+=noise["changedPixels"]!
 try target.save(a,name+"-baseline");try target.save(b,name+"-candidate")
 comparisons.append(["name":name,"delta":delta,"aa":noise])
 try write(["cases":comparisons,"width":maxWidth,"maximumChannelDifference":largest,"aaChangedPixels":aaChanges],"results.json")
}
for pose in ["single-low","single-near","scatter-overview"] {
 try autoreleasepool {
  let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
  for m in scene.mats{field.install(on:m)}
  let originalRoughness=scene.mats.map{$0.roughness.contents}
  var appearances=colors.map{($0.0,$0.1,Double(0.65),Double(-1))}
  if pose=="single-near" {appearances += [("normal-zero",[48,155,32],0,-1),("normal-one",[48,155,32],1,-1),("rough-low",[48,155,32],0.65,0.05),("rough-high",[48,155,32],0.65,1)]}
  for (name,rgb,normal,roughness) in appearances {
   for (i,m) in scene.mats.enumerated(){
    m.diffuse.contents=NSColor(srgbRed:rgb[0]/255,green:rgb[1]/255,blue:rgb[2]/255,alpha:1)
    m.multiply.contents=(name=="green" || name.hasPrefix("normal") || name.hasPrefix("rough")) ? NSColor(srgbRed:0.54,green:0.73,blue:0.54,alpha:1):NSColor.white
    m.normal.intensity=CGFloat(normal)
    if roughness>=0{m.roughness.contents=Float(roughness)}else{m.roughness.contents=originalRoughness[i]}
   }
   for state in [0,5]{_=input(scene,pose,state);try compare(scene,target,"\(pose)-\(name)-\(state)")}
  }
  for (i,m) in scene.mats.enumerated(){m.diffuse.contents=NSColor(srgbRed:48/255,green:155/255,blue:32/255,alpha:1);m.multiply.contents=NSColor(srgbRed:0.54,green:0.73,blue:0.54,alpha:1);m.normal.intensity=0.65;m.roughness.contents=originalRoughness[i]}
  let zero=Array(repeating:SIMD4<Float>(0,0,0,0),count:16)
  var boundaries=[("empty",zero)]
  var slot15=zero;slot15[15]=SIMD4(0,0,0.028575,0.85);boundaries.append(("slot15",slot15))
  var overlap=zero;for i in 0..<16{overlap[i]=SIMD4(Float(i%4)*0.01,Float(i/4)*0.01,0.028575,Float(i+1)/20)};boundaries.append(("overlap-partial",overlap))
  for (name,ball) in [("height-zero",SIMD4<Float>(0,0,0,0.85)),("below-bed",SIMD4(0,0,-0.05,0.85)),("cone-limit",SIMD4(0,0,2.2,0.85)),("above-lamp",SIMD4(0,0,2.3,0.85)),("outside-x",SIMD4(2.55,0,0.028575,0.85)),("outside-z",SIMD4(0,1.28,0.028575,0.85)),("opaque-over-one",SIMD4(0,0,0.028575,1))] {
   var balls=zero;balls[0]=ball;boundaries.append((name,balls))
  }
  for (name,balls) in boundaries {
   _=input(scene,pose,0)
   let data=balls.withUnsafeBytes{Data($0)}
   for m in scene.mats{m.setValue(data as NSData,forKey:"contactUniforms")}
   try compare(scene,target,"\(pose)-boundary-\(name)")
  }
 }
}
try need(largest==0 && aaChanges==0,"Exact expanded qualification failed")
print("H9 expanded \(comparisons.count) cases: zero differences")
