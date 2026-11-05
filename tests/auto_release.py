#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('auto_release', Path(__file__).resolve().parents[1] / 'scripts/auto_release.py')
auto = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auto)

class ReleaseSelection(unittest.TestCase):
    def release(self, tag, asset=None, **kwargs):
        return dict(tag_name=tag, assets=[dict(name=asset or f'EnhanceQoL-{tag}.zip')],
                    draft=kwargs.get('draft', False), prerelease=kwargs.get('prerelease', False),
                    published_at=kwargs.get('published_at', '2026-10-13T12:00:00Z'))

    def test_skip_unpublished_prerelease_and_other_flavors(self):
        cases = [self.release('13.12.2', draft=True), self.release('13.12.3', prerelease=True),
                 self.release('13.12.4', asset='EnhanceQoL-13.12.4-forever.zip'),
                 self.release('13.12.5', asset='EnhanceQoL-13.12.5-bcc.zip'),
                 self.release('13.12.6-beta1')]
        self.assertIsNone(auto.latest_retail([cases]))

    def test_paginated_unsorted_releases(self):
        old = self.release('13.12.0', published_at='2026-10-12T12:00:00Z')
        new = self.release('13.13.0')
        self.assertEqual(auto.latest_retail([[new], [old]])['tag_name'], '13.13.0')

class PayloadChanges(unittest.TestCase):
    def test_additions_removals_and_changes(self):
        self.assertEqual(auto.differences({'same': b'a', 'removed': b'a', 'changed': b'a'},
                                         {'same': b'a', 'added': b'a', 'changed': b'b'}),
                         ['added', 'changed', 'removed'])

    def test_identical_payload(self):
        self.assertEqual(auto.differences({'runtime.lua': b'a'}, {'runtime.lua': b'a'}), [])

if __name__ == '__main__':
    unittest.main()
