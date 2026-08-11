# Security and privacy

VitalRise holds some of the most sensitive text a man will ever type into a
phone. This document states what is protected, how, and — just as
importantly — what is not.

## Regulatory position

VitalRise is a **wellness and education product**, not a medical device and
not a covered entity under HIPAA. It has no clinician relationship, submits
no claims, and does not diagnose or treat.

That means HIPAA does not legally apply. We follow its principles anyway —
minimum necessary, access control, audit, encryption, breach readiness —
because the data is sensitive regardless of which statute happens to cover
it, and because a product in this category that treats privacy casually
deserves to fail.

If the product later adds telehealth or clinician review, the position
changes and a formal HIPAA assessment becomes mandatory before launch.

## Threat model

| Threat | Addressed | How |
| --- | --- | --- |
| Lost or stolen unlocked phone | Partly | OS-level device lock is the primary control. Optional app lock is a known gap (below). |
| Device backup extraction (iCloud/Android backup) | Yes | Keystore key is `first_unlock_this_device` on iOS and non-exportable on Android, so backups contain ciphertext with no key. |
| Filesystem dump / rooted or jailbroken device | Partly | Data is encrypted at rest, but a root-level attacker can read the keystore. No client-side scheme defends against this. |
| Another user's data via the API | Yes | Row-level security on every table, `WITH CHECK` on every write. |
| Stolen app binary / extracted keys | Yes | The app holds only the publishable key. Model and service-role keys exist solely in Edge Function environments. |
| Network interception | Yes | TLS throughout; no custom certificate handling or pinning bypass. |
| Analytics leaking health data | Yes | Events are a closed enum with no parameters. There is no code path that can attach a score or an answer. |
| Coach conversation exposure | Yes | Chat never leaves the device. The server sees a question and retrieved passages for one call and stores neither. |
| Compromised analytics or model vendor | Partly | Neither receives health data; the model vendor sees question text transiently. |

## Encryption at rest

`lib/core/security/crypto_box.dart`

- **AES-256-GCM**, authenticated encryption.
- A fresh 96-bit nonce per record, so identical plaintexts do not produce
  identical ciphertexts.
- The MAC is verified on read; tampered or truncated records return `null`
  rather than decrypting to garbage.
- The key is generated on first launch and stored in the platform keystore
  (Keychain on iOS, Android Keystore with AES-GCM under RSA key wrapping).
- A corrupt stored key rotates rather than throwing — a user must never be
  permanently locked out of their own app by a bad keystore entry.

Encrypted: assessment answers and results, habit logs, progress check-ins,
diet preferences, coach history.

Not encrypted: theme, text scale, high-contrast, and whether onboarding is
done. These are not health data, and the first frame has to render before
the keystore is available.

### What this does and does not buy

It defends against a device backup, a filesystem dump and a shared device.
It does **not** defend against an attacker with live debugger access to an
unlocked device — at that point the key is reachable by definition. Claiming
otherwise would be dishonest.

## Data minimisation

The coach sends the smallest useful payload:

```json
{
  "question": "...",
  "profile": { "top_causes": [...], "program_week": 3 },
  "context": [ /* passages from the bundled library */ ],
  "history": [ /* last 6 turns, text only */ ]
}
```

No user id, no email, no scores beyond the coarse cause names, no
timestamps, no message ids. History is truncated to six turns and text
only — nothing that could re-identify a session.

`CoachContext` is a small explicit struct rather than a serialised profile
precisely so that adding a field to the profile cannot silently start
shipping it off-device.

## Analytics

`AnalyticsService.log` takes an `AnalyticsEvent` enum value and nothing
else. There is no parameter map, so there is no way to attach a score, an
answer, a body measurement or a root cause even by accident. Adding an event
means editing the enum, which forces the question to be asked in review.

Analytics is opt-out from settings, and Firebase is entirely optional —
`FIREBASE_ENABLED=false` produces a build with no analytics at all.

## Server-side controls

Detail in `supabase/README.md`. The essentials:

- RLS enabled on every table holding user data, no exceptions.
- Default grants revoked, so a missing policy fails closed.
- Policies use `(select auth.uid())` — evaluated once per statement rather
  than once per row, which keeps it fast on large tables.
- `WITH CHECK` on every insert and update, so a user cannot write a row
  belonging to somebody else.
- `assessments` has no update policy: it is append-only history, and editing
  a past result would rewrite the baseline every trend is measured from.
- `coach_events` is insert-only with no read policy at all — no feature
  needs to read it, and every read path is a potential leak.
- The service-role key exists only in the reminder function's environment.

## Deletion

"Delete all my data" in settings:

1. Calls `delete_my_data()`, a `security definer` function that removes
   every row for `auth.uid()` in one transaction. It takes no parameters, so
   there is nothing an attacker could point at another user.
2. Clears every local key.
3. Destroys the encryption key, so anything left on disk by the filesystem
   is permanently unrecoverable.

The confirmation dialog says plainly that there is no undo.

Coach events are anonymised rather than deleted (`user_id` set to null) so
aggregate safety monitoring survives — they never contained message text.

## Known gaps

Stated rather than hidden:

1. **No app-level lock.** Anyone with the unlocked phone can open VitalRise.
   Biometric app lock is the highest-value next security feature for this
   product specifically, because of who might pick up the phone.
2. **No certificate pinning.** Standard TLS only. Pinning would raise the
   bar against a compromised device CA at the cost of operational fragility.
3. **No jailbreak/root detection.** Deliberate: it is trivially bypassed,
   and it punishes legitimate power users.
4. **Model vendor sees question text.** Transiently, under the vendor's
   retention policy, with no identifiers attached. Users who want zero
   third-party exposure can use the app without an account — the offline
   coach answers from the bundled library and makes no network calls.
5. **Screenshots are not blocked.** `FLAG_SECURE` would prevent screenshots
   and app-switcher previews. Worth considering, at the cost of breaking
   legitimate screenshots.

## Incident response

If a breach is suspected:

1. Rotate `ANTHROPIC_API_KEY`, `FCM_SERVER_KEY` and `CRON_SECRET`
   immediately (`supabase secrets set`). None is in the app, so no release
   is needed.
2. Rotate the service-role key from the Supabase dashboard.
3. The publishable key cannot be "leaked" — it is public. If it is being
   abused, the problem is a policy gap; audit `0002_rls.sql` before
   assuming otherwise.
4. Query `coach_safety_daily` and Postgres logs for anomalous volume. Note
   that no table contains message text, which materially limits what a
   database breach could expose.
5. Notify affected users within the window their jurisdiction requires
   (72 hours under GDPR).
