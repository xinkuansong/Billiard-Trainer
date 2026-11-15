try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let guardSource=try String(contentsOf:package.appendingPathComponent("candidate.surface"),encoding:.utf8)
let emitter=String(guardSource[guardSource.range(of:"float3 v62EmitterCenter(")!.lowerBound..<guardSource.range(of:"float v62RectIrradiance(")!.lowerBound])
let baseline=try unwrap(StaticClothIrradiance.replacingDiffuse(in:guardSource),"C1 baseline")
let diffuseField=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:repository.appendingPathComponent("QiuJi/Resources/StaticClothIrradiance-v1.bin"))
let fields:[MTLTexture]=[]
let loop=try unwrap(baseline.range(of:"for(int panel=0;panel<2;++panel) {",options:.backwards),"Loop")
let end=try unwrap(baseline.range(of:"E=temporalFieldDiffuse",range:loop.upperBound..<baseline.endIndex),"Diffuse end")
let oldLoop=String(baseline[loop.lowerBound..<end.lowerBound])
try need(oldLoop.contains("int samplesX=shadowPossible?8:2;") && oldLoop.contains("int samplesZ=shadowPossible?4:2;"),"Sampling anchor drift")
let farLoop=oldLoop
 .replacingOccurrences(of:"int samplesX=shadowPossible?8:2;",with:"const int samplesX=2;")
 .replacingOccurrences(of:"int samplesZ=shadowPossible?4:2;",with:"const int samplesZ=2;")
 .replacingOccurrences(of:"if(shadowPossible) {",with:"if(false) {")
let candidate=baseline.replacingOccurrences(of:oldLoop,with:"if(!shadowPossible){\n"+farLoop+"\n}else{\n"+oldLoop+"\n}\n")
try baseline.write(to:output.appendingPathComponent("baseline.surface"),atomically:true,encoding:.utf8)
try candidate.write(to:output.appendingPathComponent("candidate.surface"),atomically:true,encoding:.utf8)
try write(["additionalTextureBytes":0,"additionalPreparationGPU_MS":0,"sampling":"original eight far samples; original near path; original sample position expressions"],"resources.json")
// __DRAW_HELPERS__
