try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let guardSource=try String(contentsOf:package.appendingPathComponent("candidate.surface"),encoding:.utf8)
let emitter=String(guardSource[guardSource.range(of:"float3 v62EmitterCenter(")!.lowerBound..<guardSource.range(of:"float v62RectIrradiance(")!.lowerBound])
let baseline=try unwrap(StaticClothIrradiance.replacingDiffuse(in:guardSource),"C1 baseline")
let diffuseField=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:repository.appendingPathComponent("QiuJi/Resources/StaticClothIrradiance-v1.bin"))
let fields:[MTLTexture]=[]
try need(baseline.contains("int samplesZ=shadowPossible?4:2;"),"Sampling anchor drift")
let candidate=baseline.replacingOccurrences(of:"int samplesZ=shadowPossible?4:2;",with:"int samplesZ=shadowPossible?4:1;")
try baseline.write(to:output.appendingPathComponent("baseline.surface"),atomically:true,encoding:.utf8)
try candidate.write(to:output.appendingPathComponent("candidate.surface"),atomically:true,encoding:.utf8)
try write(["additionalTextureBytes":0,"sampling":"four far samples, original long axis, original near64"],"resources.json")
// __DRAW_HELPERS__
