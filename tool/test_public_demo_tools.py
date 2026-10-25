"""Offline wrapper regressions; only synthetic settings are used."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('build_web', Path(__file__).with_name('build_web.py'))
web = importlib.util.module_from_spec(spec)
spec.loader.exec_module(web)


class PublicDemoToolsTest(unittest.TestCase):
    def test_default_never_reads_ignored_local_file(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'config').mkdir()
            (root / 'config/supabase.local.json').write_text('not JSON: must not be read')
            with patch.object(web, 'ROOT', root), patch.dict(os.environ, {}, clear=True):
                self.assertIsNone(web.client_config())

    def test_optional_empty_ci_variables_use_dart_defaults(self):
        with patch.dict(os.environ, {'SUPABASE_URL': '', 'SUPABASE_PUBLISHABLE_KEY': ''}, clear=True):
            self.assertIsNone(web.client_config())

    def test_explicit_file_then_environment_field_override(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'client with spaces.json'
            path.write_text(json.dumps({'SUPABASE_URL': 'https://fixture.invalid',
                'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_fixture'}))
            with patch.dict(os.environ, {'SUPABASE_URL': 'https://override.invalid'}, clear=True):
                settings = web.client_config(path)
                self.assertEqual(settings['SUPABASE_PUBLISHABLE_KEY'], 'sb_publishable_fixture')
                self.assertEqual(settings['SUPABASE_URL'], 'https://override.invalid')

    def test_single_field_override_leaves_other_default_in_dart(self):
        with patch.dict(os.environ, {'SUPABASE_URL': 'https://fixture.invalid'}, clear=True):
            self.assertEqual(web.client_config(), {'SUPABASE_URL': 'https://fixture.invalid'})

    def test_invalid_explicit_settings_are_not_silently_ignored(self):
        # Deliberately invalid synthetic fixture; never a real server key.
        for data in [{'SUPABASE_PUBLISHABLE_KEY': 'sb_secret_fixture'},
                     {'SUPABASE_PUBLISHABLE_KEY': ''}, {'SUPABASE_URL': ''},
                     {'SUPABASE_URL': 'http://fixture.invalid'}, {'SUPABASE_URL': []}]:
            with self.subTest(fields=list(data)), tempfile.TemporaryDirectory() as temp:
                path = Path(temp) / 'client.json'
                path.write_text(json.dumps(data))
                with patch.dict(os.environ, {}, clear=True):
                    with self.assertRaises(ValueError):
                        web.client_config(path)

    def test_build_passes_explicit_fields_only_and_cleans_temporary_file(self):
        observed = []
        def run(command, **kwargs):
            flag = next(x for x in command if x.startswith('--dart-define-from-file='))
            path = Path(flag.split('=', 1)[1]); observed.append(path)
            self.assertEqual(json.loads(path.read_text()), {'SUPABASE_URL': 'https://override.invalid'})
            self.assertIn('/Etkinlikler/', command)
        with patch.dict(os.environ, {'SUPABASE_URL': 'https://override.invalid'}, clear=True), \
             patch('sys.argv', ['build_web.py', '--base-href', '/Etkinlikler/']), \
             patch.object(web.subprocess, 'run', side_effect=run), \
             contextlib.redirect_stdout(io.StringIO()):
            web.main()
        self.assertFalse(observed[0].exists())

    def test_run_wrapper_does_not_auto_select_local_config(self):
        with tempfile.TemporaryDirectory(prefix='demo wrapper ') as temp:
            root = Path(temp)
            (root / 'tool').mkdir(); (root / 'config').mkdir()
            script = root / 'tool/run.sh'
            shutil.copyfile(Path(__file__).with_name('run.sh'), script)
            local = root / 'config/supabase.local.json'; local.write_text('keep unchanged')
            mock = root / 'mock flutter'
            mock.write_text('#!/usr/bin/env python3\nimport sys,json\nprint(json.dumps(sys.argv[1:]))\n')
            mock.chmod(0o700)
            env = os.environ | {'FLUTTER_BIN': str(mock)}
            for extra in [[], ['--dart-define-from-file=client with spaces.json'], ['--dart-define=SUPABASE_URL=https://fixture.invalid']]:
                args = [*extra, '-d', 'iPhone 17']
                result = subprocess.run(['bash', str(script), *args], env=env,
                                        text=True, capture_output=True, check=True)
                self.assertEqual(json.loads(result.stdout), ['run', *args])
                self.assertEqual(local.read_text(), 'keep unchanged')


if __name__ == '__main__':
    unittest.main()
