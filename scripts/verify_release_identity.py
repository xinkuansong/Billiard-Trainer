#!/usr/bin/env python3
"""Fail a release candidate with mismatched CuePhys identity or placeholder configuration."""
import argparse
import datetime
import json
from pathlib import Path
from pathlib import PurePosixPath
import plistlib
import re
import subprocess
import tempfile
import zipfile

from verify_model_packaging import bundle_problems

BUNDLE = 'com.youbilliards.cuephys'
TEAM = 'KWH2GRNSKG'


def configuration_errors(info, extension):
    expected = {
        'CFBundleIdentifier': BUNDLE,
        'CFBundleDisplayName': 'CuePhys',
        'API_BASE_URL': 'https://api.cuephys.com',
        'LEGAL_TERMS_URL': 'https://youbilliards.com/legal/cuephys-terms/',
        'LEGAL_PRIVACY_URL': 'https://youbilliards.com/legal/cuephys-privacy/',
        'WECHAT_LINK_HOST': 'youbilliards.com',
        'WECHAT_UNIVERSAL_LINK': 'https://youbilliards.com/cuephys/wechat/',
        'NSSupportsLiveActivities': True,
    }
    errors = [key + ' does not match the release identity' for key, value in expected.items()
              if info.get(key) != value]
    app_id = info.get('WECHAT_APP_ID', '')
    if not re.fullmatch(r'wx[0-9a-fA-F]{16}', app_id) or app_id.lower() == 'wx' + '0' * 16:
        errors.append('WECHAT_APP_ID is missing or a placeholder; approved credentials are required')
    schemes = [scheme for item in info.get('CFBundleURLTypes', []) for scheme in item.get('CFBundleURLSchemes', [])]
    if schemes != [app_id]:
        errors.append('WeChat URL scheme must match the configured AppID')
    if extension.get('CFBundleIdentifier') != BUNDLE + '.liveactivity':
        errors.append('Live Activity extension Bundle ID mismatch')
    if not info.get('NSPhotoLibraryAddUsageDescription'):
        errors.append('Photo add permission copy is missing')
    if not info.get('CFBundleShortVersionString') or not info.get('CFBundleVersion'):
        errors.append('Version/build number is missing')
    return errors


def signing_errors(entitlements, profile, bundle_id):
    errors = []
    expected = TEAM + '.' + bundle_id
    if entitlements.get('application-identifier') != expected:
        errors.append('Signed application-identifier mismatch')
    if entitlements.get('com.apple.developer.team-identifier') != TEAM:
        errors.append('Signed team identifier mismatch')
    profile_id = profile.get('Entitlements', {}).get('application-identifier', '')
    # Apple expands a profile's terminal wildcard when signing an individual app.
    # The signed identity itself must still be the exact current bundle above.
    matches_profile = profile_id == expected or (
        isinstance(profile_id, str) and profile_id.startswith(TEAM + '.')
        and profile_id.endswith('.*') and profile_id.count('*') == 1
        and expected.startswith(profile_id[:-1]))
    if profile.get('TeamIdentifier') != [TEAM] or not matches_profile:
        errors.append('Provisioning profile does not match the current team and app')
    expires = profile.get('ExpirationDate')
    if not isinstance(expires, datetime.datetime) or expires.replace(tzinfo=datetime.timezone.utc) <= datetime.datetime.now(datetime.timezone.utc):
        errors.append('Provisioning profile is expired or lacks an expiration date')
    if bundle_id == BUNDLE:
        if entitlements.get('com.apple.developer.applesignin') != ['Default']:
            errors.append('Sign in with Apple entitlement mismatch')
        if entitlements.get('com.apple.developer.associated-domains') != ['applinks:youbilliards.com']:
            errors.append('Associated Domains entitlement mismatch')
    return errors


def distribution_errors(entitlements, profile):
    errors = []
    if entitlements.get('get-task-allow') is not False or profile.get('Entitlements', {}).get('get-task-allow') is not False:
        errors.append('App Store distribution requires get-task-allow=false in signature and profile')
    if 'ProvisionedDevices' in profile or profile.get('ProvisionsAllDevices'):
        errors.append('Device-limited or enterprise provisioning is not an App Store distribution profile')
    return errors


def inspect(app, require_distribution=False):
    errors = []
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    extensions = list((app / 'PlugIns').glob('*.appex'))
    if len(extensions) != 1:
        raise ValueError('Expected exactly one Live Activity extension')
    extension = extensions[0]
    extension_info = plistlib.loads((extension / 'Info.plist').read_bytes())
    errors += configuration_errors(info, extension_info)
    for binary, bundle_id in [(app, BUNDLE), (extension, BUNDLE + '.liveactivity')]:
        try:
            subprocess.run(['codesign', '--verify', '--strict', str(binary)], check=True, capture_output=True)
            raw = subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(binary)], stderr=subprocess.DEVNULL)
            entitlements = plistlib.loads(raw)
            raw_profile = subprocess.check_output(['security', 'cms', '-D', '-i', str(binary / 'embedded.mobileprovision')], stderr=subprocess.DEVNULL)
            profile = plistlib.loads(raw_profile)
            errors += [binary.name + ': ' + e for e in signing_errors(entitlements, profile, bundle_id)]
            if require_distribution:
                errors += [binary.name + ': ' + e for e in distribution_errors(entitlements, profile)]
        except (OSError, subprocess.CalledProcessError, plistlib.InvalidFileException):
            errors.append(binary.name + ': signing/profile could not be verified')
    if not (app / 'PrivacyInfo.xcprivacy').is_file():
        errors.append('Privacy manifest is missing from app bundle')
    errors += bundle_problems(app)
    return errors


def inspect_ipa(ipa, require_distribution=False):
    with zipfile.ZipFile(ipa) as archive, tempfile.TemporaryDirectory(prefix='cuephys-release-check-') as temp:
        for name in archive.namelist():
            member = PurePosixPath(name)
            if member.is_absolute() or '..' in member.parts:
                raise ValueError('Unsafe IPA member path')
        archive.extractall(temp)
        # zipfile does not restore executable permission bits from an IPA.
        for member in archive.infolist():
            mode = (member.external_attr >> 16) & 0o777
            if mode:
                (Path(temp) / member.filename).chmod(mode)
        apps = list((Path(temp) / 'Payload').glob('*.app'))
        if len(apps) != 1:
            raise ValueError('Expected exactly one app in IPA Payload')
        return inspect(apps[0], require_distribution)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    package = parser.add_mutually_exclusive_group(required=True)
    package.add_argument('--app', type=Path)
    package.add_argument('--ipa', type=Path)
    parser.add_argument('--require-distribution', action='store_true',
                        help='Additionally require App Store distribution signing, after export/re-signing')
    args = parser.parse_args()
    try:
        errors = (inspect(args.app, args.require_distribution) if args.app
                  else inspect_ipa(args.ipa, args.require_distribution))
    except (OSError, ValueError, plistlib.InvalidFileException, zipfile.BadZipFile):
        errors = ['Candidate package could not be inspected']
    print(json.dumps({'ok': not errors, 'errors': errors}, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(main())
