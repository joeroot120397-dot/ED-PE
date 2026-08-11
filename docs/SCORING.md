# The scoring engine

`lib/features/assessment/domain/scoring_engine.dart`

Every number this app shows a user comes from here. This document is the
reference for what each weight means and why it was chosen, so the engine
can be audited, argued with and changed deliberately rather than by feel.

## What kind of thing this is

These weights are **editorial**, not learned. They encode a point of view
about which levers matter, informed by the literature on erectile and
ejaculatory function, and they produce a *ranking of trainable factors* —
not a diagnosis. Nothing here is validated against clinical outcomes, and
the app says so on every screen.

Where a design decision is clinically motivated (rather than arbitrary), it
is called out below and mirrored in a code comment.

## The burden scale

Every answer normalises to a **burden** in `0..1`:

- `0.0` — no concern at all
- `1.0` — the worst answer available for that question

Putting every question on one scale is what lets the engine combine "how
often do you get an erection" with "how many hours do you sit" using plain
weights. The mapping lives in `QuestionBank`, on each `AnswerOption`.

Numeric questions map through `burdenFromNumber`. Erection hardness, for
example, is `(10 - value) / 9`, so 10/10 is zero burden and 1/10 is maximum.

**Unanswered questions are dropped, and the remaining weights are
renormalised.** This matters: if they defaulted to zero, a man who answered
one ED question with the worst possible answer and quit would score as
low-risk. There is a test for exactly that case.

## Section weights

### ED risk (`_edWeights`)

| Question | Weight | Why |
| --- | --- | --- |
| `b_maintain` | 0.22 | Losing an erection mid-act is the most actionable pattern and the one pelvic floor training most directly helps. |
| `b_achieve` | 0.20 | Core IIEF-style item. |
| `b_hardness` | 0.18 | Rigidity, not just presence — the distinction the ischiocavernosus controls. |
| `b_morning` | 0.16 | The strongest single organic/psychogenic discriminator available by self-report. |
| `b_loss_during` | 0.14 | Points specifically at the venous seal. |
| `b_duration` | 0.10 | Chronicity, weighted lowest because it describes history rather than current severity. |

### PE risk (`_peWeights`)

| Question | Weight | Why |
| --- | --- | --- |
| `c_latency` | 0.35 | The defining measure. |
| `c_control` | 0.30 | Control matters as much as time; a man who lasts two minutes deliberately is in a different position from one who cannot influence it. |
| `c_anticipatory_anxiety` | 0.20 | Both a cause and a consequence; heavily weighted because it is the part the app can train. |
| `c_satisfaction` | 0.15 | The distress criterion. Low weight because it is downstream of the other three. |

### Lifestyle burden (`_lifestyleWeights`)

| Question | Weight | Why |
| --- | --- | --- |
| `d_sleep` | 0.22 | Largest testosterone lever available without a prescription. |
| `d_exercise` | 0.22 | Drives endothelial function, body composition and mood at once. |
| `d_smoking` | 0.20 | Directly constricts the arteries in question, and highly reversible. |
| `d_alcohol` | 0.14 | Suppresses testicular function and fragments REM. |
| `d_sitting` | 0.12 | Perineal compression and pelvic floor disuse. |
| `d_stress` | 0.10 | Weighted low here because Section F covers it in more depth. |

### Medical burden (`_medicalWeights`)

| Question | Weight |
| --- | --- |
| `e_diabetes` | 0.22 |
| `e_heart` | 0.20 |
| `e_blood_pressure` | 0.18 |
| `e_weight_status` | 0.14 |
| `e_testosterone` | 0.10 |
| `e_thyroid` | 0.08 |
| `e_mood` | 0.08 |

Diabetes and cardiovascular disease lead because they damage the exact
tissue an erection depends on. Testosterone and thyroid are weighted low
here on purpose — they mostly drive **referral flags**, not app content,
because the app cannot address them.

### Psychological burden (`_psychWeights`)

| Question | Weight |
| --- | --- |
| `f_performance_anxiety` | 0.34 |
| `f_work_stress` | 0.20 |
| `f_relationship` | 0.18 |
| `f_porn` | 0.18 |
| `f_masturbation` | 0.10 |

Masturbation frequency is weighted lowest deliberately. It is normal
behaviour and only relevant when it differs sharply from partnered sex; a
higher weight would turn a wellness app into a moralising one.

## The four scores

```
edRisk        = edBurden × ageAdjust × 100
peRisk        = peBurden × 100
lifestyle     = (1 − lifestyleBurden) × 100

sexualHealth  = 100 − 100 × ( 0.30·edBurden·ageAdjust
                            + 0.22·peBurden
                            + 0.20·lifestyleBurden
                            + 0.16·medicalBurden
                            + 0.12·psychBurden )
```

The composite weights sum to 1.0.

**Direction is not uniform** and is the single most common misreading:
sexual health and lifestyle are higher-is-better; ED and PE risk are
higher-is-worse. `ScoreRing` takes `higherIsBetter` as a *required*
argument for this reason — a default would eventually paint a reassuring
green ring on a high ED risk.

### The age adjustment

```
ageAdjust = clamp(1.0 + (45 − age) × 0.004, 0.88, 1.12)
```

Identical answers mean different things at 25 and at 65, so ED burden is
nudged up slightly for younger men and down for older ones. Bounded to ±12%
so it can never dominate an actual answer. Age is context, never a penalty.

## Body composition signals

Both map to the shared `0..1` scale by piecewise-linear interpolation.

**BMI:** flat 0 to 24, then 0.30 at 27, 0.55 at 30, 0.85 at 35, 1.0 at 40+.

**Waist-to-height:** flat 0 to 0.45, then 0.25 at 0.50, 0.55 at 0.55, 0.80
at 0.60, 1.0 at 0.65+.

`adiposity = max(bmiSignal, waistSignal)`. The maximum rather than the mean,
because a normal BMI with a large waist is the *more* concerning
presentation, and averaging would hide it. Waist predicts sexual function
better than weight because it measures the visceral fat that actually drives
aromatase activity and endothelial inflammation.

## Root cause confidences

Each cause is a weighted sum of signals, scaled to 0–100 and clamped.

| Cause | Signals (weight × burden) |
| --- | --- |
| **Pelvic floor weakness** | 0.24 loss-during, 0.18 ejaculatory control, 0.16 latency, 0.14 maintain, 0.14 sitting, 0.14 exercise |
| **Weight / metabolic** | 0.50 adiposity, 0.20 weight status, 0.15 exercise, 0.15 diabetes |
| **Anxiety** | 0.28 performance anxiety, 0.18 anticipatory anxiety, 0.14 stress, 0.14 mood, 0.14 relationship, 0.12 work stress |
| **Cardiovascular** | 0.24 heart, 0.22 blood pressure, 0.22 smoking, 0.16 morning erections, 0.16 adiposity |
| **Sedentary** | 0.40 exercise, 0.40 sitting, 0.20 adiposity |
| **Sleep deficiency** | 0.70 sleep, 0.15 stress, 0.15 mood |
| **Blood sugar** | 0.62 diabetes, 0.20 adiposity, 0.18 morning erections |

Signals are a list of `(weight, value)` records rather than a map. That is
not a style choice: two signals in the same table routinely share a weight,
and a map literal would silently drop one of them. An earlier draft of this
engine had exactly that bug.

### Modifiers

**Psychogenic bonus** — the most clinically meaningful piece of logic here:

```
anxiety += (1 − morningBurden) × edBurden × 0.22
```

Preserved morning erections alongside difficulty during sex is the classic
pointer toward a psychogenic driver: the hardware demonstrably works. The
bonus scales with *both* how intact morning erections are and how severe the
difficulty is, so it only fires when there is a real contradiction to
explain.

**Organic counterpart:**

```
cardiovascular += morningBurden × edBurden × 0.12
```

Absent morning erections with erectile difficulty points the other way.
Weighted lower than the psychogenic bonus because loss of morning erections
has more possible explanations (sleep, alcohol, medication) than preservation
does.

**Sudden onset:** `anxiety += 0.08 × edBurden` when onset was abrupt and
recent, which in an otherwise healthy man reads as situational.

**PE spillover:** `pelvicFloor += 0.10 × peBurden`. Fast, poorly controlled
ejaculation implies an untrained brake regardless of what else is going on.

### Bands

| Confidence | Band | Meaning |
| --- | --- | --- |
| ≥ 80 | Strong signal | |
| 65–79 | Likely driver | Counts as "primary" |
| 40–64 | Contributing | Earns programme content |
| 35–39 | Minor | Shown, not acted on |
| < 35 | — | Not surfaced as a driver |

Three or more causes at ≥ 65 sets `isMultifactorial`, which is the "Multiple
Causes" classification. This is the common case in men with several risk
factors, and the copy says so rather than pretending one cause dominates.

## Clinical flags

Flags route to a clinician instead of to app content. They are not scored
and they do not affect any number — they exist so the app hands over what it
cannot legitimately handle.

| Flag | Triggered by |
| --- | --- |
| Cardiovascular review | Diagnosed heart disease, uncontrolled BP, or high ED burden with cholesterol/medicated BP |
| Glycaemic review | Type 1, uncontrolled type 2, prediabetes, or untested with high adiposity |
| Hormonal review | Testosterone symptoms or diagnosis, hypothyroidism, or absent morning erections with high ED burden |
| Mental health support | Current or medicated depression/anxiety |
| Sudden onset review | Recent abrupt onset with ED burden ≥ 0.5 |
| Compulsive behaviour | Compulsive pornography use or multiple-daily masturbation |

Triage is deliberately over-inclusive. A false positive costs one
unnecessary "see a doctor" line; a false negative can cost far more.

## Changing the weights

1. Change the constant.
2. Run `flutter test test/assessment`. The healthy and severe fixtures pin
   both ends of every scale, several tests pin ordering relationships, and
   one pins the psychogenic/organic discrimination.
3. If a test fails, decide which is wrong — the weight or the test. Do not
   loosen a bound to make a change pass.
4. Update the table above in the same commit.
