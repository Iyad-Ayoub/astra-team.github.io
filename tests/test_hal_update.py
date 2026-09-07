"""Offline regression checks; never refresh the checked-in bibliography."""
import importlib.util
from pathlib import Path
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
            with self.assertRaises(TimeoutError):
                hal.download()
            self.assertEqual(sleep.call_count, 2)

    def test_download_rejects_oversize_and_bad_encoding(self):
        for body in [b'x' * (hal.MAX_BYTES + 1), b'\xff']:
            response = MagicMock()
            response.__enter__.return_value = response
            response.status = 200
            response.read.return_value = body
            with patch.object(hal.urllib.request, 'urlopen', return_value=response) as request:
                with self.assertRaises((ValueError, UnicodeDecodeError)):
                    hal.download()
                self.assertEqual(request.call_args.kwargs['timeout'], 30)


if __name__ == '__main__':
    unittest.main()
