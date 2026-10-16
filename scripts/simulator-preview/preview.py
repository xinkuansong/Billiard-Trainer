#!/usr/bin/env python3
"""Control review simulators only on explicit calls; launch success never means page READY."""
import argparse
from contextlib import ExitStack
import datetime
import fcntl
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from simulator_lifecycle import device_lease

ROOT = Path(__file__).resolve().parents[2]
CONFIG = Path(__file__).with_name('devices.json')
DRILL_INDEX = ROOT / 'QiuJi/Resources/Drills/index.json'
THEORY_IDS = tuple(f't{index:02}' for index in range(1, 11)) + ('flow', 'quickRef')
LIVE_REVIEW_CAPABILITY = b'QIUJI_LIVE_REVIEW_THEORY_V1'
DRILL_DETAIL_CAPABILITY = b'QIUJI_LIVE_REVIEW_DRILL_DETAIL_V1'
# Only these shared review arguments may accompany the supported page routes.
PAGE_FLAGS = {'-resetDebugPremium', '-v50.inMemoryStore',
              '-v51.followSystemAppearance', '-forcePremium', '-forceNonPremium'}
PAGE_VALUES = {'-AppleLanguages': '(zh-Hans)', '-AppleLocale': 'zh_CN',
               '-hasCompletedOnboarding': 'YES'}
ERRORS = (ValueError, RuntimeError, OSError, KeyError, subprocess.TimeoutExpired)
KEYBOARD_CHECK_ACTIONS = {'status', 'start', 'restart', 'open-page'}


def hardware_keyboard_policy(preferences, udid):
    """Resolve the persisted Simulator policy, not current onscreen visibility.

    A one-shot Toggle Software Keyboard does not disable hardware connection.
    Require an explicit false rather than guessing Simulator's implicit default.
    Device overrides take precedence over the global setting.
    """
    if not isinstance(preferences, dict):
        raise ValueError('Simulator preferences are not a dictionary')
    devices = preferences.get('DevicePreferences', {})
    if not isinstance(devices, dict) or not isinstance(devices.get(udid, {}), dict):
        raise ValueError('Simulator DevicePreferences are malformed')
    device = devices.get(udid, {})
    source = device if 'ConnectHardwareKeyboard' in device else preferences
    value = source.get('ConnectHardwareKeyboard')
    return {'hardwareConnected': value if type(value) is bool else None,
            'source': 'device' if source is device else 'global-or-default',
            'policy': 'SOFTWARE_INPUT' if value is False else 'NEEDS_CONFIGURATION',
            'onscreenKeyboard': 'NOT_CHECKED'}


# UserDefaults argument-domain overrides, opt-in for L02 visual preparation.
# Values match UserPreferences and the selected() appearance defaults. The
# detail camera is a fresh DrillSceneController.topDown2D state, not a saved key.
FIXTURES = {'l02-default': (
    '-clothColor.v1', 'green', '-tableStyle.v1', 'charcoal',
    '-roomStyle.v1', 'tournament', '-showsTableSights.v1', 'YES',
    '-ballStickerStyle.v1', 'modern', '-cueStyle.v1', 'original',
    '-renderFrameRate', '60',
)}


def select_devices(devices, selection):
    if selection is None:
        return devices
    selected = []
    for key in selection.split(','):
        key = key.strip()
        matches = [d for d in devices if key in (d['label'], d['label'].split('-')[0], d['udid'])]
        if len(matches) != 1:
            raise ValueError(f'Unknown or ambiguous device: {key}')
        if matches[0] not in selected:
            selected.append(matches[0])
    return selected


def fingerprint(app):
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    executable = app / info['CFBundleExecutable']
    with executable.open('rb') as f:
        digest = hashlib.file_digest(f, 'sha256').hexdigest()
    return info['CFBundleIdentifier'], digest


def page_arguments(config, page, drill_id=None, content_id=None):
    arguments = config['launchArguments']
    if any(arg.startswith(('-deeplink.', '-liveReview')) for arg in arguments):
        raise ValueError('Configured deep link conflicts with the requested page')
    if page != 'theory' and content_id is not None:
        raise ValueError(f'{page} does not accept --content-id')
    if '-forcePremium' in arguments and '-forceNonPremium' in arguments:
        raise ValueError('Configured premium and non-premium review flags conflict')
    result = []
    for index, argument in enumerate(arguments):
        if argument in PAGE_FLAGS:
            result.append(argument)
        elif argument in PAGE_VALUES:
            value = PAGE_VALUES[argument]
            if index + 1 >= len(arguments) or arguments[index + 1] != value:
                raise ValueError(f'Unexpected shared page argument value: {argument}')
            result.extend([argument, value])
    # All home fixtures and other page probes are intentionally excluded.
    if page == 'home':
        if drill_id is not None:
            raise ValueError('home does not accept --drill-id')
        # RootView returns the real MainTabView. The empty in-memory schedule is
        # an explicit review fixture, not a claim about a real first launch.
        if '-v50.inMemoryStore' not in result:
            raise ValueError('home requires the configured in-memory review store')
        result.append('-v54.todayState=empty')
    elif page == 'settings':
        if drill_id is not None:
            raise ValueError('settings does not accept --drill-id')
        result.append('-deeplink.settings')
    elif page == 'drill-detail':
        if not drill_id or not re.fullmatch(r'drill_[a-z][0-9]{3}', drill_id):
            raise ValueError('drill-detail requires a valid --drill-id (for example drill_c001)')
        index = json.loads(DRILL_INDEX.read_text())
        active_ids = {item for category in index['categories'] for item in category['drills']}
        if drill_id not in active_ids:
            raise ValueError(f'Drill ID is not in the current bundled index: {drill_id}')
        result.extend(['-liveReview.pageId=drill-detail', f'-liveReview.contentId={drill_id}'])
    elif page == 'theory':
        if drill_id is not None:
            raise ValueError('theory does not accept --drill-id')
        if content_id not in THEORY_IDS:
            raise ValueError('theory requires a registered --content-id (for example t01)')
        result.extend(['-liveReview.pageId=theory', f'-liveReview.contentId={content_id}'])
    else:
        raise ValueError(f'Unsupported page: {page}')
    return result


def require_live_review_capability(app, page='theory'):
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if 'iPhoneSimulator' not in info.get('CFBundleSupportedPlatforms', []):
        raise ValueError(f'{page} review requires an installed simulator build')
    executable = app / info['CFBundleExecutable']
    capability = {'theory': LIVE_REVIEW_CAPABILITY, 'drill-detail': DRILL_DETAIL_CAPABILITY}[page]
    if capability not in executable.read_bytes():
        raise ValueError(f'Installed App lacks the Debug Simulator {page} review capability; build and install the new App first')
    return capability.decode('ascii')


def parse_options(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('action', choices=['status', 'start', 'restart', 'theme', 'install', 'shutdown', 'open-page'])
    parser.add_argument('--only', help='Comma-separated numbers (01–10), full labels or UDIDs; default all ten')
    parser.add_argument('--appearance', choices=['light', 'dark'])
    parser.add_argument('--app', type=Path, help='Simulator .app; required for install')
    parser.add_argument('--page', choices=['home', 'settings', 'drill-detail', 'theory'])
    parser.add_argument('--drill-id', help='Active bundled Drill ID; required for drill-detail')
    parser.add_argument('--content-id', choices=THEORY_IDS, help='Registered theory page ID; required for theory')
    parser.add_argument('--fixture', choices=sorted(FIXTURES),
                        help='Explicit L02 visual defaults; omit for interactive settings review')
    parser.add_argument('--dry-run', action='store_true', help='Read preflight, print commands, make no changes or logs')
    options = parser.parse_args(argv)
    # argparse normally accepts a repeated option with the last value winning.
    # A page request must have one unambiguous identity instead.
    actual_argv = sys.argv[1:] if argv is None else argv
    for key in ('--page', '--drill-id', '--content-id'):
        if sum(arg == key or arg.startswith(key + '=') for arg in actual_argv) > 1:
            parser.error(f'Duplicate option: {key}')
    if options.action == 'theme' and not options.appearance:
        parser.error('theme requires --appearance')
    if options.action == 'install' and not options.app:
        parser.error('install requires --app')
    if options.appearance and options.action != 'theme':
        parser.error('--appearance is only valid for theme')
    if options.app and options.action != 'install':
        parser.error('--app is only valid for install')
    if options.action == 'open-page':
        if not options.page:
            parser.error('open-page requires --page')
        if options.page == 'drill-detail' and not options.drill_id:
            parser.error('drill-detail requires --drill-id')
        if options.page != 'drill-detail' and options.drill_id is not None:
            parser.error(f'{options.page} does not accept --drill-id')
        if options.page == 'theory' and not options.content_id:
            parser.error('theory requires --content-id')
        if options.page != 'theory' and options.content_id is not None:
            parser.error(f'{options.page} does not accept --content-id')
    elif options.page is not None or options.drill_id is not None or options.content_id is not None or options.fixture is not None:
        parser.error('--page, --drill-id, --content-id and --fixture are only valid for open-page')
    return options


def main(argv=None):
    options = parse_options(argv)
    config = json.loads(CONFIG.read_text())
    devices = select_devices(config['devices'], options.only)
    launch_args = page_arguments(config, options.page, options.drill_id, options.content_id) if options.action == 'open-page' else config['launchArguments']
    if options.fixture:
        launch_args += list(FIXTURES[options.fixture])
    source = options.app.expanduser().resolve() if options.app else None
    target_page = options.page if options.action == 'open-page' else None
    results = [{'label': d['label'], 'udid': d['udid'], 'targetPage': target_page,
                'drillId': options.drill_id, 'contentId': options.drill_id if options.page == 'drill-detail' else options.content_id,
                'fixture': options.fixture, 'commandStatus': 'PENDING',
                'pageStatus': 'NOT_CHECKED', 'phase': 'preflight'} for d in devices]
    log_dir = None
    lock = None
    leases = ExitStack()
    current = None

    def save_results():
        if log_dir:
            (log_dir / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))

    def fail(row, error):
        row['commandStatus'] = 'FAILED'
        row['error'] = {'type': type(error).__name__, 'message': str(error)}
        print(row['label'], row['phase'], 'FAILED:', error, file=sys.stderr)

    def run(*args, change=False, timeout=180):
        if change and options.dry_run:
            print('DRY-RUN', json.dumps(args, ensure_ascii=False))
            return ''
        record = {'args': args, 'device': current['label'] if current else None,
                  'phase': current['phase'] if current else 'preflight'}
        try:
            completed = subprocess.run(args, text=True, capture_output=True, timeout=timeout)
        except subprocess.TimeoutExpired as exc:
            record.update({'error': 'TimeoutExpired', 'timeoutSeconds': timeout})
            if log_dir:
                stamp = datetime.datetime.now().strftime('%H%M%S%f')
                for stream in ('stdout', 'stderr'):
                    raw = getattr(exc, stream) or b''
                    if isinstance(raw, str):
                        raw = raw.encode()
                    path = log_dir / f'{stamp}-{stream}.bin'
                    path.write_bytes(raw)
                    record[stream + 'Path'] = str(path)
            write_command(record)
            raise
        except OSError as exc:
            record.update({'error': type(exc).__name__, 'message': str(exc)})
            write_command(record)
            raise
        record.update({'exit': completed.returncode, 'stdout': completed.stdout, 'stderr': completed.stderr})
        write_command(record)
        if completed.returncode:
            raise RuntimeError(f'{args}: {completed.stderr.strip()}')
        return completed.stdout.strip()

    def write_command(record):
        if log_dir:
            with (log_dir / 'commands.jsonl').open('a') as f:
                f.write(json.dumps(record, ensure_ascii=False) + '\n')

    try:
        # No daemon, polling, retries or UI operations; every change needs a fresh explicit call.
        if options.action != 'status' and not options.dry_run:
            base = ROOT / 'output/simulator-preview'
            base.mkdir(parents=True, exist_ok=True)
            lock = (base / 'control.lock').open('a')
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            log_dir = base / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
            log_dir.mkdir()
            (log_dir / 'run.json').write_text(json.dumps({
                'request': vars(options), 'runtime': config['runtime'],
                'bundleIdentifier': config['bundleIdentifier'], 'launchArguments': launch_args,
                'devices': devices, 'pageVerification': 'Required separately by the review controller'
            }, default=str, ensure_ascii=False, indent=2))
            save_results()
            for device in sorted(devices, key=lambda d: d['udid']):
                leases.enter_context(device_lease(device['udid'], 'simulator-preview:' + options.action))
        try:
            live = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '-j'))
            lookup = {d['udid']: (runtime, d) for runtime, rows in live['devices'].items() for d in rows}
            keyboard_preferences = None
            if options.action in KEYBOARD_CHECK_ACTIONS:
                raw = run('defaults', 'export', 'com.apple.iphonesimulator', '-')
                try:
                    keyboard_preferences = plistlib.loads(raw.encode('utf-8'))
                except Exception as error:
                    raise ValueError('Cannot decode Simulator keyboard preferences') from error
            if source:
                bundle, digest = fingerprint(source)
                if bundle != config['bundleIdentifier']:
                    raise ValueError('Wrong App bundle identifier')
                info = plistlib.loads((source / 'Info.plist').read_bytes())
                if 'iPhoneSimulator' not in info.get('CFBundleSupportedPlatforms', []):
                    raise ValueError('App is not a simulator build')
        except ERRORS as error:
            for row in results:
                fail(row, error)
            save_results()
            return 1
        # Validate every target before any mutation; a failed preflight aborts the entire request.
        for device, row in zip(devices, results):
            current = row
            try:
                runtime, actual = lookup.get(device['udid'], (None, {}))
                if runtime != config['runtime'] or actual.get('deviceTypeIdentifier') != device['deviceTypeIdentifier']:
                    raise ValueError(f"Missing or changed environment: {device['label']}")
                row['simulatorState'] = actual['state']
                if options.action in KEYBOARD_CHECK_ACTIONS:
                    row['keyboard'] = hardware_keyboard_policy(keyboard_preferences, device['udid'])
                    if options.action != 'status' and row['keyboard']['policy'] != 'SOFTWARE_INPUT':
                        raise ValueError(f"{device['label']}: disconnect Simulator I/O > Keyboard > Connect Hardware Keyboard before launching; a software-keyboard toggle is not persistent policy")
                if options.action in ('restart', 'theme', 'install', 'open-page') and actual['state'] != 'Booted':
                    raise ValueError(f"{device['label']} is not Booted; use start first")
                if options.action == 'open-page':
                    installed = Path(run('xcrun', 'simctl', 'get_app_container', device['udid'], config['bundleIdentifier'], 'app'))
                    bundle, digest = fingerprint(installed)
                    if bundle != config['bundleIdentifier']:
                        raise ValueError('Installed App bundle identifier mismatch')
                    row['appExecutableSHA256'] = digest
                    if options.page in ('theory', 'drill-detail'):
                        row['liveReviewCapability'] = require_live_review_capability(installed, options.page)
                    row['appearance'] = run('xcrun', 'simctl', 'ui', device['udid'], 'appearance')
                    if row['appearance'] not in ('light', 'dark'):
                        raise ValueError(f"Unexpected appearance readback: {row['appearance']!r}")
            except ERRORS as error:
                fail(row, error)
            save_results()
        if options.action == 'open-page' and not any(row['commandStatus'] == 'FAILED' for row in results):
            # A selected review group must show one installed artifact and theme.
            # Their identity remains in results; this does not certify a particular baseline.
            hashes = {row['appExecutableSHA256'] for row in results}
            appearances = {row['appearance'] for row in results}
            if len(hashes) != 1 or len(appearances) != 1:
                error = ValueError('Mixed installed App versions or appearances; align the selected devices before opening a page')
                for row in results:
                    fail(row, error)
                save_results()
        if any(row['commandStatus'] == 'FAILED' for row in results):
            for row in results:
                if row['commandStatus'] == 'PENDING':
                    row.update({'commandStatus': 'BLOCKED', 'reason': 'Request aborted before mutation because another target failed preflight'})
            save_results()
            return 1
        current = None
        # Stage before installing anywhere: installing on the source simulator changes its app path.
        if source and not options.dry_run:
            try:
                staged = log_dir / 'App.app'
                run('cp', '-cR', str(source), str(staged), change=True)
                if fingerprint(staged) != (bundle, digest):
                    raise ValueError('Staged App fingerprint mismatch')
                source = staged
            except ERRORS as error:
                for row in results:
                    row['phase'] = 'staging'
                    fail(row, error)
                save_results()
                return 1
        for device, row in zip(devices, results):
            current = row
            uid = device['udid']
            state = row['simulatorState']
            row['phase'] = 'action'
            try:
                if options.action == 'status':
                    theme = run('xcrun', 'simctl', 'ui', uid, 'appearance') if state == 'Booted' else 'unknown'
                    print(f"{device['label']:16} {state:10} theme={theme} keyboard={row['keyboard']['policy']} onscreen=NOT_CHECKED target-direction={device['orientation']} (not measured)")
                elif options.action == 'start':
                    if state == 'Booted':
                        row.update({'commandStatus': 'SKIPPED', 'reason': 'Already Booted; App and current page left untouched'})
                    else:
                        run('xcrun', 'simctl', 'boot', uid, change=True)
                        run('xcrun', 'simctl', 'bootstatus', uid, '-b', change=True)
                        row['phase'] = 'launch'
                        row['launchOutput'] = run('xcrun', 'simctl', 'launch', uid, config['bundleIdentifier'], *launch_args, change=True)
                elif options.action in ('restart', 'open-page'):
                    row['phase'] = 'launch'
                    row['launchOutput'] = run('xcrun', 'simctl', 'launch', '--terminate-running-process', uid,
                                              config['bundleIdentifier'], *launch_args, change=True)
                elif options.action == 'theme':
                    run('xcrun', 'simctl', 'ui', uid, 'appearance', options.appearance, change=True)
                    if not options.dry_run and run('xcrun', 'simctl', 'ui', uid, 'appearance') != options.appearance:
                        raise RuntimeError('Appearance readback mismatch')
                elif options.action == 'install':
                    run('xcrun', 'simctl', 'install', uid, str(source), change=True)
                    if not options.dry_run:
                        installed = Path(run('xcrun', 'simctl', 'get_app_container', uid, config['bundleIdentifier'], 'app'))
                        if fingerprint(installed) != (bundle, digest):
                            raise RuntimeError(f"Installed fingerprint mismatch: {device['label']}")
                        row['appExecutableSHA256'] = digest
                elif options.action == 'shutdown':
                    if state == 'Shutdown':
                        row.update({'commandStatus': 'SKIPPED', 'reason': 'Already Shutdown'})
                    else:
                        run('xcrun', 'simctl', 'shutdown', uid, change=True)
                if 'launchOutput' in row and not options.dry_run:
                    match = re.fullmatch(re.escape(config['bundleIdentifier']) + r':\s*([1-9][0-9]*)', row['launchOutput'])
                    if not match:
                        raise RuntimeError('Launch command returned no valid App PID; page remains unverified')
                    row['pid'] = int(match.group(1))
                if row['commandStatus'] == 'PENDING':
                    row['commandStatus'] = 'PLANNED' if options.dry_run else 'COMPLETE'
                if options.action != 'status':
                    print(device['label'], options.action, row['commandStatus'], 'page=NOT_CHECKED')
            except ERRORS as error:
                fail(row, error)
            save_results()
        return 1 if any(row['commandStatus'] == 'FAILED' for row in results) else 0
    finally:
        if log_dir:
            print('Command evidence:', log_dir)
        try:
            leases.close()
        finally:
            if lock:
                lock.close()
    # Windows, orientation, foreground page and interactivity require separate UI checks.


if __name__ == '__main__':
    try:
        sys.exit(main())
    except ERRORS as error:
        print('ERROR:', error, file=sys.stderr)
        sys.exit(1)
