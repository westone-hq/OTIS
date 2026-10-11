import csv
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np
from scipy import signal

from compare_noise_pcm import a_weighting_sos, compare


class NoiseComparisonTest(unittest.TestCase):
    def test_filter_response_and_stability(self):
        sos = a_weighting_sos(44100)
        frequencies = [63, 125, 500, 1000, 2000]
        _, h = signal.sosfreqz(sos, worN=frequencies, fs=44100)
        np.testing.assert_allclose(20 * np.log10(abs(h)),
                                   [-26.2, -16.1, -3.2, 0, 1.2], atol=.15)
        _, poles, _ = signal.sos2zpk(sos)
        self.assertTrue(np.all(abs(poles) < 1))

    def test_replay_irregular_reads_and_uncalibrated_default(self):
        rate, window = 44100, 1378
        t = np.arange(rate * 2) / rate
        pcm = np.round(4000 * np.sin(2 * np.pi * 1000 * t)).astype('<i2')
        x = pcm.astype(float) / 32768
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            pcm.tofile(directory / 'audio.pcm')
            (directory / 'metadata.json').write_text(json.dumps(dict(
                sample_rate=rate, window_samples=window, hop_samples=86,
                offset=87.3, format='s16le', channels=1)))
            ends = [86, 1378, 2001, 18000, 44100, len(pcm)]
            with (directory / 'calculations.csv').open('w', newline='') as f:
                w = csv.writer(f)
                w.writerow(['frame_end', 'read_count', 'read_ns', 'calculated_ns',
                            'write_ns', 'dbfs', 'value', 'hardware_frame', 'hardware_ns'])
                previous = 0
                for end in ends:
                    value = '' if end < window else 20 * np.log10(np.sqrt(np.mean(x[end-window:end]**2)))
                    w.writerow([end, end-previous, 10, 11, 12, value,
                                '' if value == '' else round(value + 87.3, 3), '', ''])
                    previous = end
            (directory / 'sensor_noise.csv').write_text(
                'sensor_ns,saved_ns,calculated_ns,frame_end,value\n'
                '10,1000011,11,1378,66\n10,2000011,11,1378,66\n')
            summary = compare(directory, directory / 'analysis')
            self.assertLess(summary['current_replay_max_dbfs_error'], 1e-8)
            self.assertIsNone(summary['a_leq_estimated_dba'])
            self.assertEqual(summary['sensor_snapshot_repeat_percent'], 100)
            self.assertAlmostEqual(summary['sensor_snapshot_age_ms_median'], 1.5)
            self.assertAlmostEqual(summary['a_leq_dbfs'], 20*np.log10(4000/32768/np.sqrt(2)), delta=.05)


if __name__ == '__main__':
    unittest.main()
