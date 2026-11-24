import datetime
import unittest
from verify_release_identity import BUNDLE, TEAM, configuration_errors, signing_errors


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


if __name__ == '__main__':
    unittest.main()
