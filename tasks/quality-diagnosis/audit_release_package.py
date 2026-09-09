#!/usr/bin/python3
"""Read one terminal local diagnostic Release package; emit only allowed metadata."""
import collections
import hashlib
import json
import pathlib
import plistlib
import re
import subprocess
import sys
import urllib.parse

repo = pathlib.Path(__file__).resolve().parents[2]
name = sys.argv[1]
assert re.fullmatch(r'formal-004-release-[0-9]+', name)
run = repo / 'build/quality-diagnosis' / name
assert (run / 'xcode-exit.txt').read_text().strip() == '0'
app = run / 'DerivedData/Build/Products/Release-iphonesimulator/球迹.app'
assert app.is_dir()

def read(path):
    return plistlib.loads(path.read_bytes())

def shape(value):
    raw = value.strip() if isinstance(value, str) else ''
    try:
        u = urllib.parse.urlsplit(raw)
        host = (u.hostname or '').lower()
        return dict(nonempty=bool(raw), unexpanded='$(' in raw, scheme=u.scheme,
                    has_host=bool(host), has_credentials=bool(u.username or u.password),
                    placeholder_host=host in ['example.com', 'yourdomain.com'],
                    legal_valid=u.scheme.lower() == 'https' and bool(host) and host not in ['example.com', 'yourdomain.com'])
    except ValueError:
        return dict(nonempty=bool(raw), parse_error=True)

p = read(app / 'Info.plist')
keys = ['CFBundleIdentifier', 'CFBundleName', 'CFBundleDisplayName',
        'CFBundleShortVersionString', 'CFBundleVersion', 'CFBundleDevelopmentRegion',
        'MinimumOSVersion', 'UIDeviceFamily', 'UISupportedInterfaceOrientations',
        'UISupportedInterfaceOrientations~ipad', 'NSCameraUsageDescription',
        'NSPhotoLibraryUsageDescription', 'NSPhotoLibraryAddUsageDescription',
        'NSSupportsLiveActivities', 'UIBackgroundModes']
report = {'app': {k: p.get(k) for k in keys}}
report['url_shapes'] = {k: shape(p.get(k)) for k in ['API_BASE_URL', 'LEGAL_TERMS_URL', 'LEGAL_PRIVACY_URL', 'WECHAT_UNIVERSAL_LINK']}
wid = p.get('WECHAT_APP_ID', '')
schemes = [s for item in p.get('CFBundleURLTypes', []) for s in item.get('CFBundleURLSchemes', [])]
report['wechat'] = {'app_id_present': bool(wid), 'unexpanded': '$(' in wid,
                    'configured_prefix_scheme_matches': bool(wid) and 'wx' + wid in schemes}
ats = p.get('NSAppTransportSecurity', {})
report['ats'] = {'arbitrary_loads': ats.get('NSAllowsArbitraryLoads', False),
                 'insecure_exception_count': sum(bool(v.get('NSExceptionAllowsInsecureHTTPLoads')) for v in ats.get('NSExceptionDomains', {}).values())}
report['extensions'] = []
for ext in sorted((app / 'PlugIns').glob('*.appex')):
    e = read(ext / 'Info.plist')
    report['extensions'].append({'path': ext.name, 'id': e.get('CFBundleIdentifier'),
        'version': e.get('CFBundleShortVersionString'), 'build': e.get('CFBundleVersion'),
        'point': e.get('NSExtension', {}).get('NSExtensionPointIdentifier'),
        'executable_present': (ext / e.get('CFBundleExecutable', '__missing__')).is_file()})
report['privacy'] = read(app / 'PrivacyInfo.xcprivacy')
files = [f for f in app.rglob('*') if f.is_file()]
sizes = [(f.stat().st_size, str(f.relative_to(app))) for f in files]
totals = collections.Counter()
for size, rel in sizes:
    totals[rel.split('/')[0]] += size
report['package'] = {'file_count': len(files), 'logical_bytes': sum(n for n, _ in sizes),
    'top20': sorted(sizes, reverse=True)[:20], 'top_level_bytes': dict(totals),
    'disk_kib': int(subprocess.check_output(['du', '-sk', str(app)], text=True).split()[0])}
bad_dirs = {'DrillTutorials', 'Videos', 'Previews', 'content'}
bad_ext = {'.swift', '.xcconfig', '.p12', '.mobileprovision', '.cer', '.pem', '.key'}
report['suspect_paths_only'] = [str(f.relative_to(app)) for f in files if
    bad_dirs.intersection(f.relative_to(app).parts) or f.suffix.lower() in bad_ext or
    f.name.startswith('.env') or any(x.endswith('.xctest') for x in f.parts)]
audio = {'.caf', '.wav', '.m4a', '.mp3', '.aiff', '.aif'}
report['audio_paths'] = [str(f.relative_to(app)) for f in files if f.suffix.lower() in audio]
report['retired_board_candidates'] = [str(f.relative_to(app)) for f in files if
    f.suffix == '.json' and 'DrillBoards' in f.parts and re.search(r'c(?:002|006|007|062|066)(?:_|[.])', f.name)]
binary = app / p['CFBundleExecutable']
needles = ['-forcePremium', '-forceNonPremium', '-resetDebugPremium', '-v50.inMemoryStore',
           '-deeplink.silu', '-deeplink.settings', '-w7.forceDailyLimit', '-w7.forceDailyLimitNear']
strings = set(subprocess.check_output(['/usr/bin/strings', str(binary)], text=True).splitlines())
report['exact_diagnostic_argument_strings'] = [x for x in needles if x in strings]
report['binary_architectures'] = subprocess.check_output(['/usr/bin/lipo', '-archs', str(binary)], text=True).strip()
log = (run / 'xcode-build.log').read_text()
swift = [x for x in log.splitlines() if 'swiftc ' in x or 'swift-frontend ' in x]
report['build_evidence'] = {'succeeded_marker': '** BUILD SUCCEEDED **' in log,
    'swift_command_count': len(swift), 'optimized_command_count': sum(bool(re.search(r' -O(?: |$)', x)) for x in swift),
    'debug_define_command_count': sum(bool(re.search(r' -D ?DEBUG(?: |$)', x)) for x in swift)}
(run / 'package-audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
(run / 'package-sha256.json').write_text(json.dumps({str(f.relative_to(app)): hashlib.sha256(f.read_bytes()).hexdigest() for f in files}, indent=2) + '\n')
print(json.dumps({k: report[k] for k in ['app', 'url_shapes', 'extensions', 'suspect_paths_only', 'audio_paths', 'retired_board_candidates', 'exact_diagnostic_argument_strings', 'binary_architectures', 'build_evidence']}, ensure_ascii=False, indent=2))
print('PACKAGE', report['package']['file_count'], report['package']['logical_bytes'], 'bytes')
