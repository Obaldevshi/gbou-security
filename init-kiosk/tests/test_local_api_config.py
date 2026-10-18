import importlib.util
from pathlib import Path
import unittest
import urllib.request

spec = importlib.util.spec_from_file_location('kiosk_server', Path(__file__).parents[1] / 'server.py')
kiosk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kiosk)


class LocalApiConfigTests(unittest.TestCase):
    def test_legacy_default_is_unchanged(self):
        self.assertEqual(kiosk.configured_api_base({}),
                         'https://obaldevshi-gbou-security-ac8a.twc1.net/api/v1')

    def test_local_config_is_exact_loopback_endpoint(self):
        self.assertEqual(kiosk.configured_api_base({
            'GBOU_KIOSK_LOCAL_MODE': '1',
            'GBOU_API_BASE': 'http://127.0.0.1:8081/api/v1/',
        }), 'http://127.0.0.1:8081/api/v1')

    def test_local_mode_never_falls_back_or_redirects_credentials(self):
        for address in ('', 'https://cloud.example/api/v1',
                        'http://192.168.1.85:8081/api/v1',
                        'http://localhost:8081/api/v1',
                        'http://127.0.0.1:8080/api/v1',
                        'http://user:pass@127.0.0.1:8081/api/v1',
                        'http://127.0.0.1:8081/api/v1?redirect=cloud',
                        'http://127.0.0.1:8081/api/v1#cloud'):
            with self.subTest(address=address), self.assertRaises(ValueError):
                kiosk.configured_api_base({'GBOU_KIOSK_LOCAL_MODE': '1', 'GBOU_API_BASE': address})
        handler = kiosk.NoApiRedirect()
        request = urllib.request.Request('http://127.0.0.1:8081/api/v1/auth/login',
                                         headers={'Authorization': 'Bearer test-only'})
        self.assertIsNone(handler.redirect_request(request, None, 307, 'redirect', {},
                                                   'https://cloud.example/api/v1/auth/login'))

    def test_remote_plaintext_and_bad_mode_are_rejected(self):
        for environment in ({'GBOU_API_BASE': 'http://cloud.example/api/v1'},
                            {'GBOU_KIOSK_LOCAL_MODE': 'typo'},
                            {'GBOU_API_BASE': 'https:///api/v1'}):
            with self.assertRaises(ValueError):
                kiosk.configured_api_base(environment)

    def test_api_opener_has_no_environment_proxy(self):
        self.assertFalse(any(isinstance(handler, urllib.request.ProxyHandler)
                             for handler in kiosk.API_OPENER.handlers))


if __name__ == '__main__':
    unittest.main()
