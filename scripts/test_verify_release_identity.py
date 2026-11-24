import datetime
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile
from verify_release_identity import BUNDLE, TEAM, configuration_errors, signing_errors, distribution_errors, inspect_ipa


class ReleaseIdentityTests(unittest.TestCase):
    def fixture(self):
        app_id = 'wx1234567890abcdef'
        return dict(CFBundleIdentifier=BUNDLE, CFBundleDisplayName='CuePhys',
            API_BASE_URL='https://api.cuephys.com',
            LEGAL_TERMS_URL='https://youbilliards.com/legal/cuephys-terms/',
            LEGAL_PRIVACY_URL='https://youbilliards.com/legal/cuephys-privacy/',
            WECHAT_LINK_HOST='youbilliards.com', WECHAT_UNIVERSAL_LINK='https://youbilliards.com/cuephys/wechat/',
            WECHAT_APP_ID=app_id, CFBundleURLTypes=[{'CFBundleURLSchemes': [app_id]}],
            NSSupportsLiveActivities=True, NSPhotoLibraryAddUsageDescription='保存分享卡',
            CFBundleShortVersionString='1.0', CFBundleVersion='1')

    def test_complete_configuration_and_wrong_identity_fields(self):
        info = self.fixture(); extension = {'CFBundleIdentifier': BUNDLE + '.liveactivity'}
        self.assertEqual(configuration_errors(info, extension), [])
        for key in ['CFBundleIdentifier', 'CFBundleDisplayName', 'API_BASE_URL', 'LEGAL_TERMS_URL',
                    'LEGAL_PRIVACY_URL', 'WECHAT_LINK_HOST', 'WECHAT_UNIVERSAL_LINK', 'WECHAT_APP_ID']:
            with self.subTest(key=key):
                self.assertTrue(configuration_errors(dict(info, **{key: 'old-or-placeholder'}), extension))
        self.assertTrue(configuration_errors(info, {'CFBundleIdentifier': 'old.extension'}))
        self.assertTrue(configuration_errors(dict(info, CFBundleURLTypes=[]), extension))
        self.assertTrue(configuration_errors(dict(info, WECHAT_APP_ID='wx'+'0'*16), extension))

    def test_signature_profile_and_capabilities_must_agree(self):
        entitlement = {'application-identifier': TEAM+'.'+BUNDLE, 'com.apple.developer.team-identifier': TEAM,
                       'com.apple.developer.applesignin': ['Default'],
                       'com.apple.developer.associated-domains': ['applinks:youbilliards.com']}
        profile = {'TeamIdentifier': [TEAM], 'Entitlements': dict(entitlement),
                   'ExpirationDate': datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=1)}
        self.assertEqual(signing_errors(entitlement, profile, BUNDLE), [])
        for key in entitlement:
            with self.subTest(key=key):
                self.assertTrue(signing_errors(dict(entitlement, **{key: 'old'}), profile, BUNDLE))
        self.assertTrue(signing_errors(entitlement, dict(profile, TeamIdentifier=['OTHERTEAM1']), BUNDLE))
        self.assertTrue(signing_errors(entitlement, dict(profile, ExpirationDate=datetime.datetime(2000,1,1)), BUNDLE))

    def test_wildcard_profile_authorizes_exact_extension_but_never_another_team_or_prefix(self):
        bundle = BUNDLE + '.liveactivity'
        signed = {'application-identifier': TEAM+'.'+bundle, 'com.apple.developer.team-identifier': TEAM}
        profile = {'TeamIdentifier': [TEAM],
                   'ExpirationDate': datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=1)}
        for identifier in [TEAM+'.*', TEAM+'.'+BUNDLE+'.*', TEAM+'.'+bundle]:
            with self.subTest(identifier=identifier):
                self.assertEqual(signing_errors(signed, dict(profile, Entitlements={'application-identifier':identifier}), bundle), [])
        for identifier in ['OTHERTEAM1.*', TEAM+'.com.other.*', TEAM+'.com.you*', '*', TEAM+'.*.*', None]:
            with self.subTest(identifier=identifier):
                self.assertTrue(signing_errors(signed, dict(profile, Entitlements={'application-identifier':identifier}), bundle))
        self.assertTrue(signing_errors(dict(signed, **{'application-identifier': TEAM+'.*'}),
                                       dict(profile, Entitlements={'application-identifier':TEAM+'.*'}), bundle))

    def test_app_store_distribution_rejects_development_and_device_limited_profiles(self):
        signed = {'get-task-allow': False}
        profile = {'Entitlements': dict(signed)}
        self.assertEqual(distribution_errors(signed, profile), [])
        self.assertTrue(distribution_errors({'get-task-allow': True}, profile))
        self.assertTrue(distribution_errors({}, profile))
        self.assertTrue(distribution_errors(signed, {'Entitlements': {'get-task-allow': True}}))
        self.assertTrue(distribution_errors(signed, dict(profile, ProvisionedDevices=['fixture-device'])))
        self.assertTrue(distribution_errors(signed, dict(profile, ProvisionsAllDevices=True)))

    def test_exported_ipa_inspects_real_payload_and_rejects_ambiguous_or_unsafe_archives(self):
        with tempfile.TemporaryDirectory() as temp:
            ipa = Path(temp) / 'CuePhys.ipa'
            with zipfile.ZipFile(ipa, 'w') as archive:
                archive.writestr('Payload/CuePhys.app/Info.plist', b'fixture')
            with patch('verify_release_identity.inspect', return_value=['fixture signing error']) as inspect:
                self.assertEqual(inspect_ipa(ipa, True), ['fixture signing error'])
                payload, distribution = inspect.call_args.args
                self.assertEqual(payload.name, 'CuePhys.app')
                self.assertTrue(distribution)
            for entries in [[], ['Payload/A.app/file', 'Payload/B.app/file'], ['../escape']]:
                with self.subTest(entries=entries):
                    with zipfile.ZipFile(ipa, 'w') as archive:
                        for entry in entries: archive.writestr(entry, b'fixture')
                    with self.assertRaises(ValueError): inspect_ipa(ipa, True)


if __name__ == '__main__':
    unittest.main()
