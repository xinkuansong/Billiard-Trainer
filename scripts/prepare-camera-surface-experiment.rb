#!/usr/bin/env ruby
# Generate an isolated project; never rewrite the production project or its Info.plist.
require 'yaml'
require 'fileutils'
root = File.expand_path('..', __dir__)
out = File.join(root, 'build/camera-surface-experiment')
FileUtils.mkdir_p(out)
spec = YAML.load_file(File.join(root, 'project.yml'))
spec['name'] = 'CameraSurfaceLab'
spec['settings']['base']['INFOPLIST_FILE'] = File.join(root, 'QiuJi/Resources/Info.plist')
spec['targets']['QiuJiLiveActivityExtension']['settings']['base']['INFOPLIST_FILE'] = File.join(root, 'QiuJiLiveActivity/Info.plist')
app = spec['targets']['QiuJi']
app['sources'][0]['excludes'] << 'Resources/Info.plist'
plist = File.join(out, 'Info.plist')
app['settings']['base']['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.xinkuan.qiuji.camerasurface'
app['settings']['base']['CODE_SIGN_ENTITLEMENTS'] = ''
app['settings']['base']['INFOPLIST_FILE'] = plist
app['info']['path'] = plist
app['info']['properties']['CFBundleDisplayName'] = '球迹·曲面实验'
app['info']['properties']['CameraSurfaceExperiment'] = true
app['info']['properties'].delete('CFBundleURLTypes')
spec['targets']['QiuJiLiveActivityExtension']['settings']['base']['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.xinkuan.qiuji.camerasurface.liveactivity'
spec['targets']['QiuJiTests']['settings']['base']['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.xinkuan.qiuji.camerasurface.tests'
spec['targets']['QiuJiUITests']['settings']['base']['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.xinkuan.qiuji.camerasurface.uitests'
spec['configFiles'].transform_values! { |path| File.join(root, path) }
spec['targets'].each_value do |target|
  ['sources', 'resources'].each do |key|
    (target[key] || []).each { |source| source['path'] = File.join(root, source['path']) unless source['path'].start_with?('/') }
  end
end
path = File.join(out, 'project.yml')
File.write(path, YAML.dump(spec))
abort 'Camera experiment project generation failed' unless system('xcodegen', 'generate', '--spec', path, '--project-root', out, '--project', out)
