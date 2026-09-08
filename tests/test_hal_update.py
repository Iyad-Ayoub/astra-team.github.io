"""Offline regression checks; never refresh the checked-in bibliography."""
import importlib.util
import http.client
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch, MagicMock
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('hal_update', ROOT / 'scripts/hal-export-to-bib.py')
hal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hal)


class HalTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.destination = Path(self.tmp.name) / 'publications.bib'
        self.original = (ROOT / '_bibliography/rits-astra.bib').read_bytes()
        self.destination.write_bytes(self.original)

    def assert_preserved(self):
        self.assertTrue(self.destination.read_bytes() == self.original)
        self.assertEqual(list(Path(self.tmp.name).iterdir()), [self.destination])

    def test_bad_responses_preserve_baseline(self):
        record = '@article{one, title={Title}, author={Author}, year={2025}, url={https://example.org}}'
        for response in ['', '<html>server error</html>', '@article{broken,', record,
                         record + '\n' + record, '@article{x, title={Missing fields}}']:
            with self.subTest(case=response[:12]), patch.object(hal, 'download', return_value=response):
                with self.assertRaises(Exception):
                    hal.refresh(self.destination)
                self.assert_preserved()

    def test_network_failure_preserves_baseline(self):
        with patch.object(hal, 'download', side_effect=urllib.error.URLError('offline')):
            with self.assertRaises(urllib.error.URLError):
                hal.refresh(self.destination)
        self.assert_preserved()

    def test_atomic_replace_failure_preserves_baseline(self):
        with patch.object(hal, 'download', return_value=self.original.decode()), \
                patch.object(hal.os, 'replace', side_effect=OSError('simulated')):
            with self.assertRaises(OSError):
                hal.refresh(self.destination)
        self.assert_preserved()

    def test_validator_failure_preserves_baseline(self):
        with patch.object(hal, 'download', return_value=self.original.decode()), \
                patch.object(hal.subprocess, 'run', side_effect=FileNotFoundError):
            with self.assertRaises(FileNotFoundError):
                hal.refresh(self.destination)
        self.assert_preserved()

    def test_valid_response_is_replaced(self):
        with patch.object(hal, 'download', return_value=self.original.decode()):
            hal.refresh(self.destination)
        self.assertTrue(self.destination.read_text() == hal.clean_bibtex(self.original.decode()))
        self.assertEqual(list(Path(self.tmp.name).iterdir()), [self.destination])

    def test_download_retries_and_times_out(self):
        with patch.object(hal.urllib.request, 'urlopen', side_effect=TimeoutError), \
                patch.object(hal.time, 'sleep') as sleep:
            with self.assertRaises(hal.RemoteFetchError):
                hal.download()
            self.assertEqual(sleep.call_count, 2)

    def test_download_rejects_oversize_and_bad_encoding(self):
        for body in [b'x' * (hal.MAX_BYTES + 1), b'\xff']:
            response = MagicMock()
            response.__enter__.return_value = response
            response.status = 200
            response.getheader.return_value = None
            response.read.return_value = body
            with patch.object(hal.urllib.request, 'urlopen', return_value=response) as request:
                with self.assertRaises((ValueError, UnicodeDecodeError)):
                    hal.download()
                self.assertEqual(request.call_args.kwargs['timeout'], 30)

    def test_successful_fetch_and_declared_truncation(self):
        response = MagicMock()
        response.__enter__.return_value = response
        response.status = 200
        body = self.original
        response.read.return_value = body
        for length in [None, str(len(body)), str(len(body) + 10)]:
            response.getheader.return_value = length
            with patch.object(hal.urllib.request, 'urlopen', return_value=response):
                if length == str(len(body) + 10):
                    self.assertEqual(hal.main(self.destination), 1)
                    self.assert_preserved()
                else:
                    self.assertEqual(hal.download(), body.decode('utf-8-sig'))

    def test_normalization_failure_is_fatal(self):
        with patch.object(hal, 'download', return_value=self.original.decode()), \
                patch.object(hal, 'clean_bibtex', side_effect=ValueError('normalizer bug')):
            self.assertEqual(hal.main(self.destination), 1)
        self.assert_preserved()

    def test_remote_failures_are_distinct_after_retries(self):
        errors = [urllib.error.URLError('offline'), socket.gaierror('dns'),
                  ConnectionResetError('reset'),
                  urllib.error.HTTPError(hal.URL, 503, 'Unavailable', {}, None)]
        for error in errors:
            with self.subTest(kind=type(error).__name__), \
                    patch.object(hal.urllib.request, 'urlopen', side_effect=error), \
                    patch.object(hal.time, 'sleep') as sleep:
                self.assertEqual(hal.main(self.destination), 75)
                self.assertEqual(sleep.call_count, 2)
                self.assert_preserved()

    def test_partial_response_and_local_fetch_bug_are_fatal(self):
        for error in [http.client.IncompleteRead(b'partial', 100), ValueError('logic bug'),
                      PermissionError('local failure')]:
            with self.subTest(kind=type(error).__name__), \
                    patch.object(hal.urllib.request, 'urlopen', side_effect=error):
                self.assertEqual(hal.main(self.destination), 1)
                self.assert_preserved()

    def test_timeout_after_fetch_is_not_remote_fallback(self):
        with patch.object(hal, 'download', return_value=self.original.decode()), \
                patch.object(hal.subprocess, 'run', side_effect=TimeoutError):
            self.assertEqual(hal.main(self.destination), 1)
        self.assert_preserved()

    def test_shell_exit_policy_offline(self):
        # Exercise the real shell and Python entry point against a disposable
        # bibliography. Only the HTTP boundary is mocked; no live HAL calls.
        fixture = Path(self.tmp.name) / 'fixture'
        scripts = fixture / 'scripts'
        scripts.mkdir(parents=True)
        bibliography = fixture / '_bibliography/rits-astra.bib'
        bibliography.parent.mkdir()
        for name in ['publication-update.sh', 'validate_bibliography.rb']:
            shutil.copyfile(ROOT / 'scripts' / name, scripts / name)
        shim = scripts / 'python3'
        shim.write_text(
            f'#!{sys.executable}\n'
            'import importlib.util, os, sys\n'
            'from pathlib import Path\n'
            'from unittest.mock import patch\n'
            f'spec = importlib.util.spec_from_file_location("hal", {str(ROOT / "scripts/hal-export-to-bib.py")!r})\n'
            'hal = importlib.util.module_from_spec(spec)\n'
            'spec.loader.exec_module(hal)\n'
            f'destination = Path({str(bibliography)!r})\n'
            'mode = os.environ["HAL_TEST_MODE"]\n'
            'if mode == "remote":\n'
            '    with patch.object(hal.urllib.request, "urlopen", side_effect=TimeoutError), patch.object(hal.time, "sleep"):\n'
            '        sys.exit(hal.main(destination))\n'
            'body = "" if mode == "invalid" else destination.read_text()\n'
            'with patch.object(hal, "download", return_value=body):\n'
            '    sys.exit(hal.main(destination))\n'
        )
        shim.chmod(0o755)
        for mode, expected, message in [('success', 0, 'replaced successfully'),
                                        ('remote', 0, 'WARNING:'),
                                        ('invalid', 1, 'ERROR:')]:
            with self.subTest(mode=mode):
                bibliography.write_bytes(self.original)
                inode = bibliography.stat().st_ino
                env = dict(os.environ, PATH=str(scripts) + os.pathsep + os.environ['PATH'],
                           HAL_TEST_MODE=mode, BUNDLE_GEMFILE=str(ROOT / 'Gemfile'))
                result = subprocess.run(['bash', str(scripts / 'publication-update.sh')],
                                        env=env, capture_output=True, text=True, check=False)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertIn(message, result.stdout + result.stderr)
                self.assertEqual(list(bibliography.parent.iterdir()), [bibliography])
                if mode == 'success':
                    self.assertEqual(bibliography.read_text(), hal.clean_bibtex(self.original.decode()))
                    self.assertNotEqual(bibliography.stat().st_ino, inode)
                else:
                    self.assertEqual(bibliography.read_bytes(), self.original)
                    self.assertEqual(bibliography.stat().st_ino, inode)
        # An outage is not permission to deploy an invalid/missing baseline.
        for body in [b'', None]:
            if body is None:
                bibliography.unlink()
            else:
                bibliography.write_bytes(body)
            env['HAL_TEST_MODE'] = 'remote'
            result = subprocess.run(['bash', str(scripts / 'publication-update.sh')],
                                    env=env, capture_output=True, text=True, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('ERROR:', result.stderr)
            self.assertEqual(bibliography.read_bytes() if bibliography.exists() else None, body)


if __name__ == '__main__':
    unittest.main()
