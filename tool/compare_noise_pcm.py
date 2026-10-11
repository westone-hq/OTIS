"""Replay Android noise diagnostics without changing live measurement values."""
import argparse
import csv
import json
from pathlib import Path

import numpy as np
from scipy import signal


def a_weighting_sos(rate):
    """Bilinear A-weighting approximation, normalized to 0 dB at 1 kHz.

    This is an experimental filter, not a claim of IEC tolerance compliance.
    """
    poles = -2 * np.pi * np.array([20.598997, 20.598997, 107.65265,
                                 737.86223, 12194.217, 12194.217])
    z, p, k = signal.bilinear_zpk(np.zeros(4), poles, 1.0, fs=rate)
    sos = signal.zpk2sos(z, p, k)
    _, response = signal.sosfreqz(sos, worN=[1000], fs=rate)
    sos[0, :3] /= abs(response[0])
    return sos


def moving_power(samples, window):
    cumulative = np.r_[0.0, np.cumsum(samples * samples)]
    ends = np.arange(window, len(samples) + 1)
    return (cumulative[ends] - cumulative[ends - window]) / window


def dbfs(power):
    return 10 * np.log10(np.maximum(power, 1e-10))


def compare(directory, output, a_offset=None):
    meta = json.loads((directory / 'metadata.json').read_text())
    if meta['format'] != 's16le' or meta['channels'] != 1:
        raise ValueError('Expected mono signed 16-bit little-endian PCM')
    pcm_path = directory / 'audio.pcm'
    if pcm_path.stat().st_size % 2:
        raise ValueError('Truncated PCM sample')
    x = np.fromfile(pcm_path, dtype='<i2').astype(float) / 32768
    rate, window = meta['sample_rate'], meta['window_samples']
    if len(x) < window:
        raise ValueError('Recording shorter than RMS window')
    # Causal filter with zero initial state: startup is retained and identified.
    weighted = signal.sosfilt(a_weighting_sos(rate), x)
    raw_power = moving_power(x, window)
    a_power = moving_power(weighted, window)
    fast = signal.lfilter([1 - np.exp(-1 / (rate * .125))],
                         [1, -np.exp(-1 / (rate * .125))], weighted**2)
    slow = signal.lfilter([1 - np.exp(-1 / rate)],
                         [1, -np.exp(-1 / rate)], weighted**2)
    with (directory / 'calculations.csv').open(newline='') as f:
        captured = list(csv.DictReader(f))
    output.mkdir(parents=True, exist_ok=True)
    errors = []
    anchors = []
    rows = []
    for row in captured:
        end = int(row['frame_end'])
        if end > len(x):
            raise ValueError('Calculation log refers to missing PCM samples')
        if row['hardware_ns']:
            anchors.append(int(row['hardware_ns']) - int(row['hardware_frame']) * 1e9 / rate)
        if end < window or not row['dbfs']:
            continue
        i = end - window
        raw = float(dbfs(raw_power[i]))
        a = float(dbfs(a_power[i]))
        current = round(float(np.clip(raw + meta['offset'], 0, 130)), 3)
        errors.append(raw - float(row['dbfs']))
        rows.append([end, end / rate, row['read_ns'], row['calculated_ns'],
                     row['write_ns'], raw, current, row['value'], a,
                     float(dbfs(fast[end - 1])), float(dbfs(slow[end - 1])),
                     '' if a_offset is None else a + a_offset])
    if not rows:
        raise ValueError('No complete calculation rows')
    with (output / 'comparison.csv').open('w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['frame_end', 'audio_end_seconds', 'read_ns', 'calculated_ns',
                         'write_ns', 'current_dbfs', 'current_estimate', 'captured_value',
                         'a_window_dbfs', 'a_fast_dbfs', 'a_slow_dbfs', 'a_window_estimated_dba'])
        writer.writerows(rows)
    with (directory / 'sensor_noise.csv').open(newline='') as f:
        sensors = list(csv.DictReader(f))
    valid = [r for r in sensors if int(r['calculated_ns']) > 0]
    ages = [(int(r['saved_ns']) - int(r['calculated_ns'])) / 1e6 for r in valid]
    repeat = sum(a['frame_end'] == b['frame_end'] for a, b in zip(valid, valid[1:]))
    summary = {
        'sample_rate': rate, 'seconds': len(x) / rate,
        'pcm_peak_fraction': float(np.max(np.abs(x))),
        'clipped_sample_count': int(np.count_nonzero((x <= -1) | (x >= 32767 / 32768))),
        'current_replay_max_dbfs_error': float(np.max(np.abs(errors))),
        'a_leq_dbfs': float(dbfs(np.mean(weighted**2))),
        'a_leq_estimated_dba': None if a_offset is None else float(dbfs(np.mean(weighted**2))) + a_offset,
        'sensor_snapshot_repeat_percent': None if len(valid) < 2 else 100 * repeat / (len(valid) - 1),
        'sensor_snapshot_age_ms_median': None if not ages else float(np.median(ages)),
        'sensor_snapshot_age_ms_p95': None if not ages else float(np.percentile(ages, 95)),
        'audio_frame_zero_boottime_ns_estimate': None if not anchors else int(np.median(anchors)),
        'hardware_anchor_spread_ms': None if not anchors else float(np.ptp(anchors) / 1e6),
        'a_offset': a_offset,
        'notes': ['A filter is a causal bilinear approximation; validate frequency response before production.',
                  'Fast/Slow start with zero energy; startup is included in output.',
                  'Frame/sample-rate time is nominal; hardware anchors may expose gaps or clock drift.',
                  'write_ns/saved_ns mark buffered writes, not disk flush or Dart receipt.',
                  'No A-weighted calibration is inferred from the existing offset.'],
    }
    (output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    # Plot is optional; CSV/JSON are always generated.
    try:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        data = np.array([r[:2] + r[5:7] + r[8:11] for r in rows], dtype=float)
        fig, ax = plt.subplots(figsize=(12, 5))
        for index, label in [(2, 'Current window dBFS'), (4, 'A window dBFS'),
                             (5, 'A Fast dBFS'), (6, 'A Slow dBFS')]:
            ax.plot(data[:, 1], data[:, index], label=label, linewidth=.8)
        ax.set(xlabel='Audio time (s)', ylabel='dBFS (uncalibrated)')
        ax.legend(); ax.grid(alpha=.3); fig.tight_layout()
        fig.savefig(output / 'comparison.png', dpi=150); plt.close(fig)
    except ImportError:
        pass
    return summary


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--a-offset', type=float, help='Separately verified A-weighted calibration offset')
    args = parser.parse_args()
    print(json.dumps(compare(args.directory, args.output or args.directory / 'analysis', args.a_offset), indent=2))
