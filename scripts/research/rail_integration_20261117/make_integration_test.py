from pathlib import Path
root=Path(__file__).parent
s=(root/'preview.swift').read_text().replace('testRailBedShadowPreview','testRailAppearanceIntegration')
# Compare production asset against freshly recomputed original geometry bake.
anchor='        let originals = mats.map { $0.shaderModifiers ?? [:] }'
replacement='''        let productionModifiers = mats.map { $0.shaderModifiers ?? [:] }
        let productionProperties = mats.map { $0.value(forKey: "bedRailVisibility") }
        for m in mats {
            try require(m.value(forKey: "bedRailVisibility") != nil, "Production resource installed")
            MobileRailAppearance.remove(from: m)
        }
        let originals = mats.map { $0.shaderModifiers ?? [:] }'''
assert s.count(anchor)==1;s=s.replace(anchor,replacement)
anchor='''            SCNTransaction.flush()
            _ = try target.render(frames: 8)'''
replacement='''            for (i,m) in mats.enumerated() {
                m.shaderModifiers=productionModifiers[i]
                m.setValue(productionProperties[i],forKey:"bedRailVisibility")
            }
            SCNTransaction.flush()
            _ = try target.render(frames: 8)
            let production = try target.readback()
            attach(production,"rail-integrated-\\(view)")
            try require(production.magentaPixels == 0,"Production shader compiled")
            try install("original")
            SCNTransaction.flush()
            _ = try target.render(frames: 8)'''
assert s.count(anchor)==1;s=s.replace(anchor,replacement)
anchor='''                let delta = difference(baseline,frame)'''
s=s.replace(anchor,'''                if mode == "bed" {
                    let productionDifference = difference(production,frame)
                    try require(productionDifference.maximum == 0, "Production matches approved geometry-baked preview exactly")
                }
'''+anchor)
(root/'integration.swift').write_text(s)
s=(root/'export.py').read_text().replace("['export.py','preview.swift','bvh.swift','bake.swift']","['integrate.py','integration.swift']").replace("'preview.swift'","'integration.swift'").replace("'--expected-count','1'","'--expected-count','3'").replace("testRailBedShadowPreview'","testRailAppearanceIntegration','--test','QiuJiTests/ClothAppearanceTests/testRailAppearanceSurvivesMaterialLifecycles','--test','QiuJiTests/ClothAppearanceTests/testApprovedBrightnessSurvivesAppearanceAndSceneRebuilds'")
(root/'integrate.py').write_text(s)
