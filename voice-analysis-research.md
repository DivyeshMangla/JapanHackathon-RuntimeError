# Smartphone-Based Voice Analysis: Sensors, Methods, and Feedback Engine

Research reference for the voice therapy adherence app. Covers every sensor on a modern smartphone, what each can contribute to voice analysis, how to process its data, what the output means clinically, and how to turn the results into positive or negative feedback.

---

## 1. Summary

- The **microphone is the only sensor that measures the voice itself**. Every clinically meaningful acoustic parameter comes from it.
- The other sensors act as **quality control** (motion, distance, noise, orientation) or **context** (breathing, environment, activity). They make microphone results trustworthy and comparable across sessions.
- Phone recordings are reliable for **F0, CPPS, AVQI, LTAS slope, MPT, and s/z ratio**. Jitter, shimmer, and HNR are unreliable on phones and should be secondary outcomes only.
- Feedback must be **relative to the patient's own baseline**, recorded on the same device under the same protocol. Absolute norms are a secondary reference.
- Audio can also **verify that exercises were performed correctly**, turning self-reported adherence into objective adherence (Section 9).
- Capture, quality control, live feedback, exercise verification, and most measures can run **on the phone**. Composite indices tied to Praat (AVQI, ABI, DSI) need Praat-identical algorithms and are computed offline (Section 11).
- Exercises are **prescribed by the treating SLP** from a library approved by the expert panel (Section 7). Patient status is concluded from standardized probe recordings plus adherence, not from exercise audio alone (Section 8).
- The app supports therapy monitoring. It does not diagnose. All clinical interpretation stays with the treating SLP.

---

## 2. Complete Sensor Inventory

Verdict key:
- **Core**: directly measures voice
- **QC**: improves recording quality or validity
- **Context**: adds supporting information
- **External**: requires an add-on device
- **Not useful**: no meaningful contribution

| # | Sensor | What it captures | Voice relevance | Verdict |
|---|---|---|---|---|
| 1 | Microphone (primary, bottom) | Sound pressure, typically 44.1 or 48 kHz | All acoustic voice parameters | Core |
| 2 | Secondary microphones (top, rear) | Sound from other positions | Noise estimation, but OS noise suppression combines them unpredictably | QC |
| 3 | Speaker + microphone (active sonar) | Reflected inaudible chirps (18-22 kHz) | Breathing rate and chest/abdomen movement | Context |
| 4 | Accelerometer | Linear acceleration, capped at 200 Hz on Android 12+ without special permission | Phone movement during recording; too slow for voice signal | QC |
| 5 | Gyroscope | Angular velocity, same 200 Hz cap | Phone rotation and hand tremor during recording | QC |
| 6 | Magnetometer | Magnetic field | Contributes to orientation estimate only | QC |
| 7 | Rotation vector (fused) | Device orientation in 3D | Verifies phone angle (e.g., 45 degrees) is consistent across sessions | QC |
| 8 | Proximity sensor | Near/far, usually binary at about 5 cm | Detects phone held too close to mouth | QC |
| 9 | Ambient light sensor | Illuminance (lux) | Environment logging only | Context |
| 10 | Barometer | Air pressure | Altitude/weather; no reliable voice or breath use | Not useful |
| 11 | Front camera | Video frames | Mouth-to-phone distance, posture, mouth opening during exercises | QC |
| 12 | Depth sensor (TrueDepth, ToF) | Per-pixel distance | Accurate mouth-to-phone distance where available | QC |
| 13 | Rear camera + flash | Fingertip PPG | Heart rate; possible arousal/stress context | Context |
| 14 | Touchscreen | Taps, timing | Adherence logging, task timing | Context |
| 15 | System clock | Time | MPT, s/z durations, practice duration, timestamps | Core (for timed tasks) |
| 16 | Step counter / activity recognition | Steps, walking, still | Confirms patient was stationary while recording | QC |
| 17 | GPS / location | Position | No voice value; privacy cost | Not useful |
| 18 | Biometric (fingerprint, face unlock) | Identity | App lock only | Not useful for analysis |
| 19 | Bluetooth / USB peripherals | External devices | Headset mic, neck accelerometer, smartwatch | External |

---

## 3. Sensor-by-Sensor Analysis

### 3.1 Microphone (Core)

**Captures:** the acoustic voice signal.

**Analysis:**
1. Record uncompressed WAV, 44.1 kHz, 16-bit, mono.
2. Request the unprocessed audio source where the OS allows it (Android `AudioSource.UNPROCESSED`, iOS `measurement` mode). This disables automatic gain control and noise suppression, which otherwise distort perturbation and noise measures.
3. Extract time, frequency, and cepstral features (Section 4).

**Leads to:** pitch level and stability, voice quality, dysphonia severity, breath support, glottal efficiency.

**Validity on phones:**
- Mean F0 and CPPS show acceptable random error across phone models; jitter and shimmer random error is problematic (Jannetts et al., 2019).
- Higher-end phones reliably capture F0, CPPS, LTAS slope, and GNE. Spectral measures stay stable under ambient noise; jitter and shimmer degrade (QMU thesis).
- HNR and shimmer variants show device bias and should be interpreted with caution (Journal of Voice, 2025).
- Smartphone AVQI measurements agree acceptably with studio recordings, even with moderate added noise (Uloza et al.).

### 3.2 Speaker + Microphone as Active Sonar (Context)

**Captures:** echoes of an inaudible frequency-modulated chirp reflected off the chest and abdomen.

**Analysis:** emit an 18-22 kHz FMCW chirp, cross-correlate the received signal with the transmitted one, track the phase or range change of the chest reflection over time, then band-pass filter at breathing frequencies (0.1-0.7 Hz).

**Leads to:** breathing rate, breath depth trend, inhalation-to-exhalation ratio. Relevant to breath-support exercises.

**Evidence:** ApneaApp used this method to track breathing and classified 32 of 37 sleep-study patients correctly.

**Limitations:** cannot run while the patient is phonating into the same microphone; speaker frequency response above 18 kHz varies by phone. Treat as a future research extension, not a prototype feature.

### 3.3 Accelerometer and Gyroscope (QC)

**Captures:** phone motion.

**Why not as a voice sensor:** the MEMS gyroscope does pick up acoustic energy below 200 Hz (Gyrophone, Michalevsky et al., 2014), but the 200 Hz sampling cap means it can only resolve components up to 100 Hz. That misses most of the female F0 range and all harmonics. Clinical neck-surface accelerometry instead uses a dedicated sensor taped to the neck, sampled at 11,025 Hz.

**Analysis for QC:** compute RMS of high-pass filtered acceleration and angular velocity during the recording window.

**Leads to:** rejection or warning when the phone moved during recording (motion changes mouth-to-mic distance and angle, which shifts intensity and spectral measures).

### 3.4 Magnetometer and Rotation Vector (QC)

**Captures:** device orientation.

**Analysis:** read pitch and roll from the fused rotation vector at recording start and throughout.

**Leads to:** a consistency check that the phone is held at the same angle every session. Store the angle with each recording.

### 3.5 Proximity Sensor (QC)

**Captures:** whether an object is within about 5 cm.

**Leads to:** a warning if the phone is pressed against the face, which causes proximity effect (bass boost) and breath noise.

### 3.6 Front Camera and Depth Sensor (QC)

**Captures:** face position.

**Analysis:** run on-device face landmark detection (Google ML Kit or MediaPipe Face Mesh). Estimate distance with the pinhole model:

```
distance_mm = focal_length_px * interpupillary_distance_mm / interpupillary_distance_px
```

Use about 63 mm as the adult interpupillary distance, or measure it once per patient in clinic. On phones with depth sensors, read distance directly.

**Leads to:** live guidance ("move closer", "hold still") until the mouth is at the protocol distance (10-15 cm). Optionally, mouth-opening measurement during articulation or resonance exercises.

**Privacy:** process frames in memory only. Never store video.

### 3.7 Rear Camera PPG (Context)

**Captures:** blood volume changes in the fingertip.

**Leads to:** heart rate before practice. Weak link to voice; not recommended for this study.

### 3.8 Clock, Touchscreen, Activity Recognition (Core for timing, QC, Context)

**Leads to:** MPT and s/z durations (combined with voice activity detection on the microphone signal), adherence logs, practice duration, and confirmation that the patient was stationary.

### 3.9 External Sensors via Bluetooth or USB (External)

| Device | Benefit |
|---|---|
| Wired or Bluetooth headset microphone | Fixed mouth-to-mic distance; removes the biggest source of session-to-session variability |
| Neck-surface accelerometer | Voice use outside practice sessions (phonation time, cycle dose) without recording speech content |
| Smartwatch | Heart rate, activity context |

Research groups have built smartphone-based ambulatory voice monitors using a neck-mounted accelerometer that computes SPL, F0, voicing duration, and vocal dose measures (Mehta et al.). This is the strongest path for monitoring daily voice use, but it requires extra hardware and is out of scope for the prototype.

---

## 4. Acoustic Parameters

### 4.1 Primary Parameters (reliable on phones)

| Parameter | Task | What it reflects | Better direction | Reference values |
|---|---|---|---|---|
| CPPS (dB) | Sustained /a/ | Periodicity and overall dysphonia severity | Higher | Praat cutoff 14.45 dB (Murton et al., 2020) |
| CPPS (dB) | Reading passage | Same, in connected speech | Higher | Praat cutoff 9.33 dB, Rainbow Passage (Murton et al., 2020) |
| AVQI | Vowel + passage | Composite voice quality index | Lower | Threshold is language-specific; requires local validation |
| MPT (s) | Sustained /a/, maximum | Breath support, glottal efficiency | Higher | Western norms 25-35 s men, 15-25 s women; under 10 s is a red flag |
| s/z ratio | Sustained /s/ and /z/ | Glottal air leak | Closer to 1.0 | Above 1.4 suggests pathology |
| F0 mean (Hz) | Vowel, passage | Pitch level | Therapist-defined target | Varies by sex and age |
| F0 SD (Hz) | Vowel | Pitch stability | Lower in sustained vowel | Patient baseline |
| LTAS slope (dB) | Passage | Spectral energy balance, breathiness | Patient baseline | Patient baseline |

Notes:
- CPPS cutoffs depend on exact Praat settings. Use the same settings for every analysis, or the cutoffs do not apply.
- A South Asian normative sample reported lower MPT (about 15.4 s men, 13.2 s women) than Western norms. Use local norms or each patient's own baseline.
- An AVQI change of 0.95 has been linked to a clinically meaningful change judged by experts; 1.36 or more is linked to a meaningful change in patient self-perceived disability.

### 4.2 Secondary Parameters (unreliable on phones)

| Parameter | What it reflects | Commonly cited threshold | Status |
|---|---|---|---|
| Jitter local (%) | Cycle-to-cycle period variation | 1.04% (MDVP) | Report with stated limitation |
| Shimmer local (%) | Cycle-to-cycle amplitude variation | 3.81% (MDVP) | Report with stated limitation |
| HNR (dB) | Harmonic vs noise energy | About 20 dB for /a/ | Device-biased; within-patient trend only |

### 4.3 Recording Quality Thresholds

| Check | Rule | Source |
|---|---|---|
| Signal-to-noise ratio | 42 dB or higher recommended; below 30 dB unsuitable for perturbation measures | Deliyski et al., 2005 |
| Clipping | Fewer than 0.1% of samples at full scale | Engineering rule |
| Vowel duration | At least 3 s of stable phonation | Common protocol |
| Phone motion | Gyroscope RMS below a device-calibrated threshold | Engineering rule |
| Mouth-to-mic distance | Within 10-15 cm | Common protocol |

### 4.4 Additional Acoustic Measures

| Measure | Task | What it reflects | Method |
|---|---|---|---|
| H1-H2 (dB) | Sustained /a/ | Breathy (high) vs pressed (low) phonation | Amplitude difference between first and second harmonics |
| Spectral tilt, alpha ratio, Hammarberg index | Vowel, passage | Energy balance; vocal effort and breathiness | Band energy ratios from the spectrum (e.g., 50-1000 Hz vs 1-5 kHz) |
| GNE | Sustained /a/ | Glottal excitation vs turbulent noise | Correlation of Hilbert envelopes across frequency bands |
| Formants F1-F3 (Hz) | Vowels /a/, /i/, /u/ | Resonance and articulation; target of resonant voice therapy | LPC (Burg method) |
| Vowel space area | Corner vowels | Articulatory range | Area of the F1-F2 triangle |
| Voice breaks (%), unvoiced fraction | Sustained /a/ | Phonation instability, vocal fry | Proportion of unvoiced frames inside the phonation |
| F0 range (semitones) | Pitch glides | Pitch flexibility | 12 x log2(F0 max / F0 min) |
| Speaking F0 | Spontaneous speech | Habitual pitch, often the real therapy target | Median F0 over voiced frames |

### 4.5 Composite Indices

| Index | Inputs | Note |
|---|---|---|
| AVQI | CPPS, HNR, shimmer, LTAS slope, tilt | Covered in 4.1 |
| ABI (Acoustic Breathiness Index) | CPPS, jitter, GNE, high-frequency noise, H1-H2, shimmer, period SD | Breathiness-specific counterpart to AVQI; published Praat script |
| DSI (Dysphonia Severity Index) | MPT, highest F0, lowest intensity, jitter | DSI = 0.13 x MPT + 0.0053 x F0-high - 0.26 x I-low - 1.18 x jitter(%) + 12.4. Healthy voices score around +5, severe dysphonia around -5. Requires calibrated intensity (4.6) |

### 4.6 Loudness Measures (require calibration)

Phone microphones report relative level (dBFS), not sound pressure level (dB SPL). One calibration step per study phone unlocks absolute loudness.

**Calibration:**
1. Place a sound level meter and the phone side by side, 30 cm from the speaker's mouth.
2. Record 5 sustained vowels at different loudness levels on both.
3. Compute the per-device offset: offset = SLM dB(A) - phone level. Check that it is constant across levels (linear response).
4. Store the offset with the device ID; apply it to every recording from that phone.

**Measures unlocked:**

| Measure | Task | What it reflects |
|---|---|---|
| Habitual loudness (dB SPL) | Spontaneous speech | Excess loudness is a common hyperfunction target |
| Dynamic range (dB) | Softest and loudest sustained /a/ | Vocal fold control |
| Voice range profile (phonetogram) | Soft and loud phonation across the pitch range | Full pitch-loudness capacity |
| Soft phonation threshold | Softest /a/ at several pitches | Early sensitive marker of vocal fold change |
| DSI | See 4.5 | Composite severity |

### 4.7 Speech and Breath Patterns

| Measure | Task | What it reflects | Method |
|---|---|---|---|
| Speech rate (syllables/s) | Passage, spontaneous | Rate control | Syllable nuclei from intensity peaks in voiced regions (de Jong and Wempe Praat script) |
| Pause count and duration | Passage, spontaneous | Fluency, breath planning | Silent intervals above 250 ms |
| Breath group length (s, syllables) | Passage | Breath support in real speech | Speech between pauses that contain inhalation noise |
| Loudness decay within a breath group | Passage | Running out of air at phrase ends | Intensity slope across each breath group |

---

## 5. Signal Processing Pipeline

1. **Capture:** WAV, 44.1 kHz, 16-bit, mono, unprocessed audio source. Patient stays silent for the first 0.5 s to give a noise reference.
2. **Quality gate:** SNR, clipping, duration, motion, distance (Section 4.3). Failed recordings are rejected with a re-record prompt.
3. **Segmentation:** voice activity detection; for vowels, keep the stable middle 3 s.
4. **Framing:** 40 ms frames, Hanning window.
5. **Spectrum (FFT):** converts each frame to frequency; harmonics appear at F0, 2xF0, 3xF0.
6. **F0 (autocorrelation or YIN):** finds the repeating period T; F0 = 1/T.
7. **Cepstrum:** FFT of the log magnitude spectrum. A regular voice gives a sharp peak at quefrency 1/F0. CPP is that peak's height above a regression line; CPPS smooths across time and quefrency first.
8. **Perturbation:** mark glottal cycles; jitter from period variation, shimmer from amplitude variation.
9. **Harmonicity:** HNR from autocorrelation.
10. **LTAS:** average spectrum across the passage; slope compares low- and high-frequency energy.
11. **AVQI:** computed with the published AVQI Praat script (Maryn and colleagues) from the concatenated vowel and passage.
12. **Feedback engine:** compares results with the patient's baseline (Section 6).

### Where each step runs

| Step | Location | Reason |
|---|---|---|
| Capture, quality gate, live F0 meter, timers | Phone (Flutter) | Real-time feedback; no data leaves the device |
| Feature extraction and AVQI | Institution server (Python + Parselmouth) | Praat-identical values that reviewers accept |
| Feedback engine | Institution server | Needs baseline history |
| Display | Phone and therapist panel | |

Section 11 shows which measures can move fully onto the phone.

Flutter packages for on-device work: `record` (audio), `sensors_plus` (accelerometer, gyroscope, magnetometer), `google_mlkit_face_detection` (distance), an FFT package such as `fftea`, and a YIN pitch detector for the live meter.

---

## 6. Feedback Engine

### 6.1 Logic

1. **Baseline:** record each task 3 times in clinic on the study device. The mean is the baseline value; the spread gives the patient's personal measurement noise.
2. **Personal minimal detectable change (MDC95):**

   ```
   MDC95 = 1.96 * sqrt(2) * SEM
   ```

   SEM is estimated from the standard deviation of the 3 baseline trials. Changes smaller than MDC95 are treated as measurement noise.
3. **Literature threshold where one exists:** AVQI uses 0.95.
4. **Per-metric classification:** Improved, Stable, or Declined.
5. **Overall rating from primary metrics:**
   - Positive: 2 or more improved, none declined
   - Negative: 2 or more declined
   - Stable: none improved, none declined
   - Mixed: anything else
6. **Absolute flag:** also report whether CPPS crosses the published cutoff.

### 6.2 Who sees what

| Audience | Content | Reason |
|---|---|---|
| Patient | Plain-language summary focused on practice and adherence; recording quality prompts | Avoids alarming or diagnostic language from a single home sample |
| Therapist | Full metric table, per-metric change, overall rating, flags, trend charts | Clinical interpretation is the SLP's role |

A Negative rating notifies the therapist; the patient sees an encouraging message and a suggestion to discuss progress at the next session.

### 6.3 Reference Implementation (server side)

Pin the `praat-parselmouth` version and verify extracted values against the Praat GUI on 5 sample recordings before use; Praat command arguments differ between versions.

```python
import math
import statistics
from dataclasses import dataclass
from enum import Enum

import parselmouth
from parselmouth.praat import call

PITCH_FLOOR_HZ = 75
PITCH_CEILING_HZ = 600
NOISE_LEAD_IN_S = 0.5


@dataclass(frozen=True)
class QualityReport:
    snr_db: float
    clipped_fraction: float
    voiced_duration_s: float

    @property
    def passed(self) -> bool:
        return (
            self.snr_db >= 30
            and self.clipped_fraction < 0.001
            and self.voiced_duration_s >= 3.0
        )


def check_quality(path: str) -> QualityReport:
    sound = parselmouth.Sound(path)
    noise = sound.extract_part(0, NOISE_LEAD_IN_S)
    signal = sound.extract_part(NOISE_LEAD_IN_S, sound.get_total_duration())
    noise_rms = max(call(noise, "Get root-mean-square", 0, 0), 1e-9)
    signal_rms = call(signal, "Get root-mean-square", 0, 0)
    samples = sound.values.flatten()
    clipped = sum(1 for s in samples if abs(s) >= 0.99) / len(samples)
    return QualityReport(
        snr_db=20 * math.log10(signal_rms / noise_rms),
        clipped_fraction=clipped,
        voiced_duration_s=voiced_duration(sound),
    )


def voiced_duration(sound: parselmouth.Sound) -> float:
    time_step = 0.01
    pitch = sound.to_pitch(time_step, PITCH_FLOOR_HZ, PITCH_CEILING_HZ)
    voiced_frames = sum(1 for f in pitch.selected_array["frequency"] if f > 0)
    return voiced_frames * time_step


def extract_features(path: str) -> dict[str, float]:
    sound = parselmouth.Sound(path)
    pitch = call(sound, "To Pitch", 0.0, PITCH_FLOOR_HZ, PITCH_CEILING_HZ)
    points = call(sound, "To PointProcess (periodic, cc)", PITCH_FLOOR_HZ, PITCH_CEILING_HZ)
    harmonicity = call(sound, "To Harmonicity (cc)", 0.01, PITCH_FLOOR_HZ, 0.1, 1.0)
    cepstrogram = call(sound, "To PowerCepstrogram", 60, 0.002, 5000, 50)
    return {
        "f0_mean_hz": call(pitch, "Get mean", 0, 0, "Hertz"),
        "f0_sd_hz": call(pitch, "Get standard deviation", 0, 0, "Hertz"),
        "jitter_local_pct": 100 * call(points, "Get jitter (local)", 0, 0, 0.0001, 0.02, 1.3),
        "shimmer_local_pct": 100 * call(
            [sound, points], "Get shimmer (local)", 0, 0, 0.0001, 0.02, 1.3, 1.6
        ),
        "hnr_db": call(harmonicity, "Get mean", 0, 0),
        "cpps_db": call(
            cepstrogram, "Get CPPS", False, 0.02, 0.0005, 60, 330, 0.05,
            "Parabolic", 0.001, 0.0, "Straight", "Robust",
        ),
        "voiced_duration_s": voiced_duration(sound),
    }


class Direction(Enum):
    HIGHER_BETTER = "higher"
    LOWER_BETTER = "lower"
    CLOSER_TO_ONE = "closer_to_one"


class Change(Enum):
    IMPROVED = "improved"
    STABLE = "stable"
    DECLINED = "declined"


class Rating(Enum):
    POSITIVE = "positive"
    NEGATIVE = "negative"
    STABLE = "stable"
    MIXED = "mixed"


@dataclass(frozen=True)
class Metric:
    key: str
    direction: Direction
    primary: bool
    minimum_change: float
    literature_change: float | None = None


# minimum_change values are provisional floors used when baseline trials are
# nearly identical; replace them with values from the study's test-retest data.
METRICS = (
    Metric("cpps_vowel_db", Direction.HIGHER_BETTER, True, 0.5),
    Metric("cpps_passage_db", Direction.HIGHER_BETTER, True, 0.5),
    Metric("avqi", Direction.LOWER_BETTER, True, 0.5, literature_change=0.95),
    Metric("mpt_s", Direction.HIGHER_BETTER, True, 2.0),
    Metric("sz_ratio", Direction.CLOSER_TO_ONE, True, 0.1),
    Metric("hnr_db", Direction.HIGHER_BETTER, False, 1.0),
    Metric("jitter_local_pct", Direction.LOWER_BETTER, False, 0.2),
    Metric("shimmer_local_pct", Direction.LOWER_BETTER, False, 0.5),
)


@dataclass(frozen=True)
class MetricResult:
    metric: Metric
    baseline: float
    current: float
    threshold: float
    change: Change


def personal_mdc(trials: list[float]) -> float:
    if len(trials) < 2:
        return 0.0
    return 1.96 * math.sqrt(2) * statistics.stdev(trials)


def classify(metric: Metric, baseline_trials: list[float], current: float) -> MetricResult:
    baseline = statistics.mean(baseline_trials)
    threshold = metric.literature_change or max(
        personal_mdc(baseline_trials), metric.minimum_change
    )
    if metric.direction is Direction.HIGHER_BETTER:
        gain = current - baseline
    elif metric.direction is Direction.LOWER_BETTER:
        gain = baseline - current
    else:
        gain = abs(baseline - 1.0) - abs(current - 1.0)

    if gain >= threshold:
        change = Change.IMPROVED
    elif gain <= -threshold:
        change = Change.DECLINED
    else:
        change = Change.STABLE
    return MetricResult(metric, baseline, current, threshold, change)


def overall_rating(results: list[MetricResult]) -> Rating:
    primary = [r for r in results if r.metric.primary]
    improved = sum(r.change is Change.IMPROVED for r in primary)
    declined = sum(r.change is Change.DECLINED for r in primary)
    if declined >= 2:
        return Rating.NEGATIVE
    if improved >= 2 and declined == 0:
        return Rating.POSITIVE
    if improved == 0 and declined == 0:
        return Rating.STABLE
    return Rating.MIXED


PATIENT_MESSAGES = {
    Rating.POSITIVE: "Your recent recordings show progress compared with your starting point. Keep up your daily practice.",
    Rating.STABLE: "Your voice measurements are steady. Consistent practice is what drives change over the coming weeks.",
    Rating.MIXED: "Some measurements improved and some did not. Your therapist will review them with you.",
    Rating.NEGATIVE: "Your therapist has been notified to review your recent recordings. Continue your exercises as prescribed.",
}


def evaluate(
    baseline: dict[str, list[float]], current: dict[str, float]
) -> tuple[Rating, list[MetricResult], str]:
    results = [
        classify(m, baseline[m.key], current[m.key])
        for m in METRICS
        if m.key in baseline and m.key in current
    ]
    rating = overall_rating(results)
    return rating, results, PATIENT_MESSAGES[rating]
```

AVQI is not computed in this file. Run the published AVQI Praat script through Parselmouth and add its output under the `avqi` key.

## 7. Exercise Library

### 7.1 Principle

Exercise selection is a clinical decision made by the treating SLP from the laryngoscopic diagnosis and assessment. Clinical guidance recommends laryngoscopy before voice therapy is prescribed (AAO-HNS, 2018). The app therefore holds a library of evidence-based exercises, and the therapist assigns exercises and dosage per patient. The Stage 3 expert panel approves the final library before the pilot.

### 7.2 Candidate Library

| Program | Typical indication | Home exercise | App verification | Progress marker | Evidence |
|---|---|---|---|---|---|
| Vocal Function Exercises (VFE) | Lesions, muscle tension dysphonia, hypophonia, aging voice | Sustained /i/ as long as possible on a set note; upward glide; downward glide; sustained notes (e.g., C-D-E-F-G) on "ol". Each 2 times, 2 times daily | Duration, glide range, voice breaks, pitch accuracy | Sustained /i/ duration toward goal (patient's longest /s/) | Systematic review: medium-to-large effects in most studies |
| SOVT: straw, straw in water, lip trill, tongue trill, humming | Phonotrauma, muscle tension, high effort | Sustained tones and glides through the occlusion | Voicing continuity, duration, glide range | Steadier, longer phonation; lower effort rating | Meta-analysis: mixed results |
| Resonant voice therapy | Nodules, phonotrauma | Hum "mmm" to chant to words to phrases with forward focus | Voicing, F0 stability, spectral balance | Probe CPPS, effort rating | Systematic review: low-quality evidence |
| Confidential voice / flow phonation | Phonotrauma, pressed voice | Easy, quiet, airflow-led voicing | Relative loudness below target band | Lower practice loudness | Limited trials |
| Breath support | Poor respiratory-phonatory coordination | Abdominal breathing, sustained /s/ | /s/ duration | Longer /s/, s/z ratio toward 1.0 | Expert practice |
| PhoRTE | Aging voice | Loud sustained /a/, loud glides, loud phrases | Relative loudness, glide range | Loudness, MPT | Small trials |
| LSVT LOUD | Parkinson's disease | Clinician-delivered | Logging only | Not implemented | Licensed; certified clinicians only |
| Vocal hygiene | All patients | Hydration, voice rest, reduced throat clearing | Daily checklist | Checklist completion | Guideline-supported preventive measure |
| Circumlaryngeal massage | Muscle tension dysphonia | SLP-taught | Checklist only | Not measurable by phone | Clinician technique |

### 7.3 Dosage Notes

- VFE dosage studies used 6-week protocols with twice-daily practice; low doses were insufficient for substantial change. A 4-week intervention may underestimate effects; state this as a limitation or ask the panel to consider 6 weeks.
- Dosage (repetitions, sessions per day, duration) is set by the therapist per patient and stored with each assignment.

### 7.4 Exercise Data Model

| Field | Example |
|---|---|
| id | vfe-1 |
| program | VFE |
| name | Sustained /i/ |
| instructions | Text plus demonstration audio recorded by the study SLP |
| verificationType | sustained, glide, notes, loudness, checklist |
| targets | durationS, pitchHz, toleranceCents, rangeSemitones, loudnessBand |
| defaultReps, defaultSessionsPerDay | 2, 2 |
| evidenceSource | Reference key from Section 18 |
| approvedBy, approvedDate | Expert panel sign-off |

An assignment links a patient to an exercise with therapist-set targets and dosage, a start date, and an end date.

---

## 8. Status Model

### 8.1 Two Kinds of Voice Data

| Data | When | Purpose |
|---|---|---|
| Practice audio | Every exercise session | Compliance (exercise performed on target) and within-exercise progress |
| Probe recordings | Baseline, weekly, week 4 | Patient status. Identical standard tasks for every patient (Section 14), so results compare across time and patients |

Status is never concluded from practice audio alone, because each patient performs different exercises.

### 8.2 Weekly Inputs

| Input | Definition |
|---|---|
| Adherence | Sessions completed / sessions prescribed |
| Compliance | Repetitions on target / repetitions attempted |
| Exercise progress | Trend of the exercise's progress marker (Section 7.2) |
| Probe change | Feedback engine rating (Section 6) |
| PROMs | VHI-10 change, mean weekly effort rating (Section 10) |

### 8.3 Status Matrix

| Adherence and compliance | Probe outcome | Status | Suggested action for therapist |
|---|---|---|---|
| High | Positive | On track | Continue plan |
| High | Stable or mixed | Plateau | Review exercise selection or dosage |
| Low | Stable or mixed | Adherence problem | Address practice barriers |
| Any | Negative | Needs review | Clinical check |
| Low | Positive | Improving despite low practice | Note for interpretation; may reflect in-clinic therapy |

"High" adherence uses a provisional cut-off of 80% of prescribed sessions, to be confirmed by the expert panel.

The status is a summary for the therapist. It is not a diagnosis, and the therapist makes all treatment decisions.

---

## 9. Exercise Verification

Adherence in the study currently relies on the patient marking an exercise as done. Audio recorded during practice can confirm the exercise was performed and performed on target. This runs on the phone in real time.

| Exercise | Acoustic signature detected | Pass criteria (set by the therapist per patient) |
|---|---|---|
| Sustained vowel or hum (/m/) | Continuous voicing; stable F0; for /m/, energy concentrated below 500 Hz | Target duration reached; F0 SD below limit |
| Pitch glides (sirens) | Smooth rising or falling F0 contour | Target semitone range covered; no voice breaks |
| Straw phonation, lip trills (SOVT) | Voicing with reduced high-frequency energy; for lip trills, low-frequency amplitude modulation from lip vibration | Target duration; continuous voicing |
| Vocal Function Exercises | Sustained /i/ duration; glides; sustained notes at prescribed pitches | Each note within a set tolerance (e.g., plus or minus 50 cents) of target pitch; duration goals met |
| Loudness targets | Relative intensity | Within the therapist-set band |

**Output per session:** repetitions attempted, repetitions on target, total phonation time. Store these as objective adherence alongside the patient's checkmark. The gap between the two is itself a useful study finding.

**Development:** record 10-20 correct and incorrect examples of each exercise with the SLP team and tune detection thresholds on them before the pilot.

**Privacy:** practice audio is analyzed in memory and discarded; only the derived counts are stored, unless the session is a scheduled monitoring recording.

---

## 10. Patient-Reported Outcomes

Acoustic measures alone do not capture how the patient experiences their voice. Collect these in the app:

| Instrument | Frequency | What it measures |
|---|---|---|
| VHI-10 (Voice Handicap Index-10) | Baseline, week 4 | Voice-related handicap; scores above 11 are commonly treated as abnormal |
| V-RQOL (Voice-Related Quality of Life) | Baseline, week 4 | Voice-related quality of life |
| Vocal Fatigue Index | Baseline, week 4 | Tiredness, discomfort, recovery with rest |
| Vocal effort rating (0-10) | After every practice session | Perceived effort; tracks day-to-day change |

Use validated translations for the study population's language where they exist, and obtain permission for any instrument that requires it. Do not reword items.

---

## 11. On-Device vs Offline Analysis

| Measure | On phone (Dart) | Offline (Python + Parselmouth) | Note |
|---|---|---|---|
| Quality gate (SNR, clipping, motion, distance) | Yes | | Must run live to prompt re-recording |
| Exercise verification | Yes | | Must run live |
| MPT, s/z ratio, voice breaks | Yes | Yes | Simple timing and voicing detection |
| F0 mean, SD, range, speaking F0 | Yes (YIN or autocorrelation) | Yes | Minor algorithm differences |
| Spectral tilt, H1-H2, LTAS, band ratios | Yes (FFT) | Yes | |
| Formants | Yes (LPC) | Yes | |
| Speech rate, pauses, breath groups | Yes | Yes | |
| CPPS | Possible | Yes | Published cutoffs only apply to Praat's exact algorithm and settings |
| Jitter, shimmer, HNR | Possible | Yes | Values depend on Praat's cycle detection; secondary outcomes anyway |
| AVQI, ABI, DSI | No | Yes | Formulas are calibrated on Praat outputs |

**Recommended split for the prototype and pilot:**
- **Phone:** capture, quality gate, live F0 meter, timers, exercise verification, PROMs.
- **Offline on an institution machine:** run the Parselmouth script on exported recordings for all clinical outcome measures. This keeps data off third-party cloud and keeps values comparable with published research.

**If every measure must run on the phone:** implement it in Dart, then validate each against Parselmouth on the same recordings (ICC above 0.90 and a Bland-Altman bias near zero) before applying any published threshold.

---

## 12. Future Extensions

| Extension | How | Why not now |
|---|---|---|
| Daily voice use (dosimetry) | Detect voicing in short microphone frames throughout the day, discard audio, store phonation time | Battery drain; continuous microphone access raises ethics concerns |
| Neck-surface accelerometer | External sensor taped to the neck, connected to the phone | Extra hardware; strongest method for daily voice monitoring |
| Breathing via active sonar | Speaker and microphone used as sonar (Section 3.2) | Cannot run during phonation; device variability |
| Machine-learning dysphonia screening | eGeMAPS feature set (88 standardized features) into a classifier | Needs a large labeled dataset and separate validation |

---

## 13. What a Phone Cannot Measure

| Measure | Required equipment |
|---|---|
| Nasalance | Nasometer with acoustically separated oral and nasal microphones |
| Airflow, subglottal pressure | Aerodynamic system (pneumotachograph, pressure transducer) |
| Vocal fold contact (EGG) | Electroglottograph |
| Vocal fold structure and vibration | Laryngeal endoscopy, stroboscopy |

---

## 14. Recording Protocol

| Item | Specification |
|---|---|
| Device | Same phone model for baseline and follow-up; ideally a study-owned phone kept in clinic |
| Microphone | Headset mic preferred; otherwise built-in bottom mic |
| Distance and angle | 10-15 cm from mouth, 45 degrees off-axis, checked by camera |
| Environment | Quiet room; app rejects recordings below SNR threshold |
| Lead-in | 0.5 s silence before each task |
| Tasks | Sustained /a/ x3 at comfortable pitch and loudness; sustained /a/ maximum x3 (MPT); /s/ and /z/ x2 each; corner vowels /a/, /i/, /u/; pitch glide up and down x2; softest and loudest /a/ (if calibrated); standardized reading passage; 30 s spontaneous speech |
| Format | WAV, 44.1 kHz, 16-bit, mono, unprocessed source |
| Metadata stored | Device model, OS version, phone angle, estimated distance, SNR, timestamp |

---

## 15. Validation Plan for the Study

1. **Concurrent validity:** record 10-15 participants simultaneously on the study phone and a reference microphone. Compare with Bland-Altman analysis and ICC for each parameter.
2. **Test-retest reliability:** two recordings of the same participants 1-2 days apart with no therapy in between. Compute ICC, SEM, and MDC95 per parameter. Replace the provisional floors in the code with these values.
3. **Feedback agreement:** compare the engine's Positive/Negative/Stable ratings against SLP perceptual ratings (CAPE-V or GRBAS) on the same recordings. Report agreement with Cohen's kappa.
4. **Exercise verification accuracy:** compare the app's on-target counts with SLP judgments of the same practice recordings. Report sensitivity and specificity per exercise.
5. **Local AVQI threshold:** if AVQI is used for absolute classification, validate a threshold for the study's language and passage.

---

## 16. Privacy and Data Handling

- Audio stays encrypted on the phone until upload to the institution server; no third-party cloud.
- Camera frames, sonar signals, and motion data are processed in memory; only derived numbers (distance, angle, motion RMS) are stored.
- No location data is collected.
- Recordings are named by participant code, never by name.
- Raw audio is retained only as long as the ethics approval permits.

---

## 17. Limitations

- Phone microphones and OS audio processing vary by model; absolute values are not comparable across devices.
- Published cutoffs come mostly from English and European-language samples and may not transfer to the study population.
- Home recordings have less controlled conditions than clinic recordings; use them for trend monitoring, not primary outcomes.
- A single recording can be affected by fatigue, illness, or time of day. Trends across several sessions are more meaningful than any one rating.
- The engine flags measurable change. It does not detect or diagnose vocal pathology.

---

## 18. Sources of Standard Practice

Use these to build and justify the exercise library, recording protocol, and outcome measures. Final content is approved by the study's SLP panel.

### 18.1 Clinical Guidelines and Protocols

| Source | Provides | Use in this project |
|---|---|---|
| AAO-HNS Clinical Practice Guideline: Hoarseness (Dysphonia), 2018 update | Evidence-based recommendations: laryngoscopy before voice therapy, advocating voice therapy, documenting outcomes | Justifies diagnosis-first prescription and outcome tracking |
| Patel et al., 2018: ASHA Recommended Protocols for Instrumental Assessment of Voice | Standard specifications for instrumentation, environment, voice tasks, analysis, and target measures | Basis for probe tasks and recording setup |
| ASHA Practice Portal: Voice Disorders (asha.org/practice-portal) | Overview of assessment and treatment approaches | Background and terminology |
| ASHA Evidence Maps (apps.asha.org/EvidenceMaps) | Summaries of systematic reviews per intervention | Evidence column in the exercise library |
| CAPE-V (ASHA) | Standard auditory-perceptual rating protocol and sentences | SLP perceptual ratings for validation |
| Dejonckere et al., 2001: European Laryngological Society basic protocol | Multidimensional voice assessment framework | Structure of baseline and follow-up assessment |
| Sri Ramachandra University voice assessment protocol | ELS protocol adapted for the Indian population | Local precedent for assessment structure |

### 18.2 Textbooks and Exercise Manuals

| Source | Provides |
|---|---|
| Stemple, Roy, Klaben: Clinical Voice Pathology: Theory and Management | Standard reference for voice disorders and therapy approaches |
| Behrman, Haskell: Exercises for Voice Therapy | Ready-to-use exercise descriptions; closest match to an app exercise library |
| Stemple, Hapner: Voice Therapy: Clinical Case Studies | Real therapy plans by disorder |
| Boone et al.: The Voice and Voice Therapy | Facilitating techniques and therapy approaches |
| Stemple: Vocal Function Exercises materials (Plural Publishing) | Official VFE protocol and pitch targets |
| Verdolini Abbott: Lessac-Madsen Resonant Voice Therapy clinician manual | Official resonant voice therapy hierarchy |

### 18.3 Reporting and Taxonomy

| Source | Use |
|---|---|
| Van Stan et al., 2015: A taxonomy of voice therapy | Consistent naming and classification of exercises in the app and paper |
| TIDieR checklist (Hoffmann et al., 2014) | Reporting the app intervention completely in the publication |

### 18.4 Indian Context

| Source | Use |
|---|---|
| All India Institute of Speech and Hearing (AIISH), Mysuru | National institute for SLP; protocols, student research, regional norms |
| Journal of Indian Speech Language and Hearing Association (JISHA) | Indian normative and treatment studies |
| Indian Journal of Otolaryngology and Head and Neck Surgery | Indian voice assessment protocols and acoustic norms |
| Standardized Hindi reading passages (Yadav, Kumar, Dey) | Candidate reading passage for probe recordings |
| Collaborating clinic's existing home-practice handouts | The most direct source; reflects what the clinic already prescribes |

### 18.5 Licensed Programs

LSVT LOUD and some branded programs require certification or licensing. Do not reproduce their materials in the app without permission.

---

## 19. References

1. Jannetts S, Schaeffler F, Beck J, Cowen S. Assessing voice health using smartphones: bias and random error of acoustic voice parameters captured by different smartphone types. 2019. https://eresearch.qmu.ac.uk/9179
2. Reliability and validity of acoustic voice analysis using smartphone recordings for clinical and remote assessment (doctoral thesis, Queen Margaret University). https://eresearch.qmu.ac.uk/handle/20.500.12289/14239
3. Comparison of acoustic voice features derived from mobile devices and studio microphone recordings. Journal of Voice. 2025;39(2):559.e1-559.e18. doi:10.1016/j.jvoice.2022.10.006
4. Smartphone recordings are comparable to gold standard recordings for acoustic measurements of voice. https://pmc.ncbi.nlm.nih.gov/articles/PMC10545813
5. Murton O, Hillman R, Mehta D. Cepstral peak prominence values for clinical voice evaluation. American Journal of Speech-Language Pathology. 2020;29(3):1596-1607. doi:10.1044/2020_AJSLP-20-00001
6. Uloza V, et al. Smartphone-based AVQI estimation (VoiceScreen). https://pmc.ncbi.nlm.nih.gov/articles/PMC9811036
7. AVQI validation review and clinically meaningful change. Frontiers in Digital Health. 2025. https://www.frontiersin.org/articles/10.3389/fdgth.2025.1610353/full
8. Michalevsky Y, Boneh D, Nakibly G. Gyrophone: recognizing speech from gyroscope signals. USENIX Security 2014. https://crypto.stanford.edu/gyrophone
9. Android 12 sensor rate limiting (200 Hz without HIGH_SAMPLING_RATE_SENSORS). https://docs.expo.dev/versions/latest/sdk/sensors
10. Mehta DD, et al. Smartphone-based ambulatory voice monitoring with neck-surface accelerometer. https://pmc.ncbi.nlm.nih.gov/articles/PMC4077201 and https://pmc.ncbi.nlm.nih.gov/articles/PMC6301575
11. Nandakumar R, Gollakota S, Watson N. Contactless sleep apnea detection on smartphones (ApneaApp). MobiSys 2015. https://homes.cs.washington.edu/~gshyam/Papers/apneaapp.pdf
12. Eckel FC, Boone DR. The s/z ratio as an indicator of laryngeal pathology. Journal of Speech and Hearing Disorders. 1981.
13. Maximum phonation time in Pakistani adults with normal voice. https://tehqeeqat.org/downloadpdf/20850
14. Deliyski DD, Shaw HS, Evans MK. Adverse effects of environmental noise on acoustic voice quality measurements. Journal of Voice. 2005.
15. Maryn Y, et al. The Acoustic Voice Quality Index: toward improved treatment outcomes assessment in voice disorders. Journal of Communication Disorders. 2010.
16. Boersma P, Weenink D. Praat: doing phonetics by computer. https://www.praat.org
17. Jadoul Y, Thompson B, de Boer B. Introducing Parselmouth: a Python interface to Praat. Journal of Phonetics. 2018.
18. Wuyts FL, et al. The Dysphonia Severity Index: an objective measure of vocal quality based on a multiparameter approach. Journal of Speech, Language, and Hearing Research. 2000.
19. Barsties v. Latoszek B, et al. The Acoustic Breathiness Index (ABI): a multivariate acoustic model for breathiness. Journal of Voice. 2017.
20. de Jong NH, Wempe T. Praat script to detect syllable nuclei and measure speech rate automatically. Behavior Research Methods. 2009.
21. Eyben F, et al. The Geneva Minimalistic Acoustic Parameter Set (GeMAPS) for voice research and affective computing. IEEE Transactions on Affective Computing. 2016.
22. Rosen CA, et al. Development and validation of the Voice Handicap Index-10. Laryngoscope. 2004.
23. Arffa RE, et al. Normative values for the Voice Handicap Index-10. Journal of Voice. 2012.
24. Hogikyan ND, Sethuraman G. Validation of an instrument to measure voice-related quality of life (V-RQOL). Journal of Voice. 1999.
25. Nanjundeswaran C, et al. Vocal Fatigue Index (VFI): development and validation. Journal of Voice. 2015.
26. Stemple JC, et al. Efficacy of vocal function exercises as a method of improving voice production. Journal of Voice. 1994.
27. Stachler RJ, et al. Clinical Practice Guideline: Hoarseness (Dysphonia) (Update). Otolaryngology-Head and Neck Surgery. 2018;158(1 Suppl):S1-S42.
28. Patel RR, et al. Recommended protocols for instrumental assessment of voice: ASHA expert panel. American Journal of Speech-Language Pathology. 2018;27(3):887-905.
29. Angadi V, Croake D, Stemple J. Effects of vocal function exercises: a systematic review. Journal of Voice. 2019;33(1):124.e13-124.e34.
30. Pozzali I, Pizzorni N, et al. Effectiveness of semi-occluded vocal tract exercises in patients with dysphonia: a systematic review and meta-analysis. Journal of Voice. 2024;38(1):245.e17-245.e35.
31. Verdolini-Marston K, Burke MK, Lessac A, Glaze L, Caldwell E. Preliminary study of two methods of treatment for laryngeal nodules. Journal of Voice. 1995.
32. Van Stan JH, et al. A taxonomy of voice therapy. American Journal of Speech-Language Pathology. 2015.
33. Hoffmann TC, et al. Better reporting of interventions: TIDieR checklist and guide. BMJ. 2014.
34. Dejonckere PH, et al. A basic protocol for functional assessment of voice pathology. European Archives of Oto-Rhino-Laryngology. 2001;258:77-82.
35. Multi Parametric Voice Assessment: Sri Ramachandra University Protocol. Indian Journal of Otolaryngology and Head and Neck Surgery. https://pmc.ncbi.nlm.nih.gov/articles/PMC3918278
36. Bane MH. Vocal function exercises for normal voice: the effects of varying dosage. University of Kentucky. 2016.
