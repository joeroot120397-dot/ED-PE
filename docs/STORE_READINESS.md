# App Store and Play Store readiness

Sexual-health apps get more review scrutiny than almost any other category.
Most rejections here are avoidable and predictable. This is the checklist.

## The rejection that actually happens

Apple 1.4.1 and Play's Health apps policy both reject apps that **imply
medical claims**. In this category that means:

| Never write | Write instead |
| --- | --- |
| "Cure ED" | "Support erection quality" |
| "Treat premature ejaculation" | "Train ejaculation control" |
| "Fix your erectile dysfunction" | "Improve pelvic floor strength" |
| "Diagnose your condition" | "Understand possible contributing factors" |
| "Clinically proven" | "Based on published research" |
| "Doctor recommended" | (only with a named, verifiable endorsement) |

This applies to the store listing, screenshots, keywords and in-app copy
alike. The app's own copy already follows it — do not undo that in
marketing.

## Age rating

**17+ / Mature 17+.** Do not attempt a lower rating. Under-rating a sexual
health app is a fast rejection and a trust problem.

- Apple: "Frequent/Intense Sexual Content or Nudity" → **None**;
  "Medical/Treatment Information" → **Infrequent/Mild**. There is no nudity
  in this app; the anatomy illustrations are clinical schematics.
- Google Play: complete the content rating questionnaire honestly. Select
  the sexual-health/education category.

The coach refuses users who state they are under 18 (`CoachSafety`), which
is worth mentioning in review notes.

## Privacy declarations

### Apple privacy nutrition label

| Category | Collected | Linked to user | Used for tracking |
| --- | --- | --- | --- |
| Health & Fitness | Yes | Yes | **No** |
| Contact Info (email) | Yes, if they sign in | Yes | **No** |
| Identifiers (user ID) | Yes, if they sign in | Yes | **No** |
| Usage Data | Yes, if analytics enabled | No | **No** |
| Diagnostics | Yes, if analytics enabled | No | **No** |

Tracking is **No** across the board. There is no advertising SDK, no IDFA
use, and no data broker. Do not add one — the moment you do, this app needs
App Tracking Transparency and the privacy label becomes far harder to
justify in this category.

### Play Data safety

- Data is encrypted in transit: **Yes**
- Data is encrypted at rest: **Yes** (AES-256-GCM, key in Android Keystore)
- Users can request deletion: **Yes** — in-app, Settings → Delete all my data
- Data shared with third parties: **No**
- Health data collected: **Yes** — declare it accurately

Play requires a deletion path reachable **outside** the app as well. Publish
a web deletion request form and link it from the store listing.

## Required before submission

- [ ] Privacy policy live at a public URL, covering health data specifically
- [ ] Terms of use live
- [ ] Web-based account deletion request page (Play requirement)
- [ ] Support email that a human monitors
- [ ] Sign in with Apple implemented, if Google sign-in ships (Apple 4.8)
- [ ] Screenshots for every required device size
- [ ] App icon with no alpha channel (iOS)
- [ ] Feature graphic 1024×500 (Play)

## Screenshots

What works for this category:

1. **Assessment** — shows substance, not a marketing promise
2. **Results with root causes** — the differentiated feature
3. **Exercise detail with animation** — shows real instructional content
4. **12-week programme** — shows structure
5. **Nutrition plan** — shows breadth
6. **Progress charts** — shows the long game

What to avoid: anything resembling before/after imagery, any body imagery
that could read as sexual content, and any text overlay making a claim the
app does not make.

Keep the disclaimer visible in at least one screenshot. Reviewers look for
it, and it signals the app knows what it is.

## Review notes to include

```
VitalRise is an educational wellness app for men's sexual health. It does
not diagnose, treat or prescribe, and it makes no medical claims.

The assessment is a structured self-reflection tool producing educational
guidance about lifestyle and exercise factors. Every screen displays:
"This application provides educational guidance only and is not a
substitute for medical advice. Consult a qualified healthcare professional
for diagnosis and treatment."

The AI coach is restricted to a curated wellness library. It refuses
medication questions and redirects them to a prescriber, and it returns
crisis resources for self-harm or medical-emergency messages without
calling a model. Users who state they are under 18 are turned away.

The app is fully functional without an account. To review without signing
in, open the app and complete the assessment; all features are available.

DEMO ACCOUNT (if you prefer to test sync):
  email: review@vitalrise.app
  password: <provide>

The anatomy section contains clinical schematic diagrams only. There is no
nudity or photographic content anywhere in the app.
```

## Common rejections and how this app answers them

| Reason | Answer |
| --- | --- |
| "Medical claims without evidence" | No cure or treatment claims anywhere; educational framing throughout. |
| "Missing disclaimer" | Every screen renders it structurally via `VitalScaffold`, and a test enforces it. |
| "Inappropriate age rating" | Rated 17+ from the start. |
| "No account deletion" | In-app, one tap from Settings, plus a web form. |
| "Sign in with Apple missing" | Implemented alongside Google. |
| "Health data undeclared" | Declared in both consoles. |
| "AI feature without safeguards" | Two-layer triage, documented in review notes and in `docs/SECURITY_PRIVACY.md`. |
| "Broken functionality" | Fully functional offline; reviewers on a restricted network still see a working app. |

## Post-launch

- Watch reviews for anyone describing a medical emergency and respond with
  a referral to care, never advice.
- Keep a copy of the exact review notes for each version — resubmissions go
  faster when the notes match what shipped.
- Any change to assessment wording, coach behaviour or claims should be
  re-read against the language table at the top of this document before it
  ships.
