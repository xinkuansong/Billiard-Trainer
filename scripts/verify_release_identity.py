#!/usr/bin/env python3
"""Fail a release candidate with mismatched CuePhys identity or placeholder configuration."""
import argparse
import datetime
import json
from pathlib import Path
import plistlib
import re
import subprocess

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
    if profile.get('TeamIdentifier') != [TEAM] or profile.get('Entitlements', {}).get('application-identifier') != expected:
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


def inspect(app):
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
            errors += [binary.name + ': ' + e for e in signing_errors(entitlements, plistlib.loads(raw_profile), bundle_id)]
        except (OSError, subprocess.CalledProcessError, plistlib.InvalidFileException):
            errors.append(binary.name + ': signing/profile could not be verified')
    if not (app / 'PrivacyInfo.xcprivacy').is_file():
        errors.append('Privacy manifest is missing from app bundle')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True, type=Path)
    args = parser.parse_args()
    try:
        errors = inspect(args.app)
    except (OSError, ValueError, plistlib.InvalidFileException):
        errors = ['Candidate package could not be inspected']
    print(json.dumps({'ok': not errors, 'errors': errors}, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(main())
