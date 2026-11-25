# Eudemonia — Paywall and Trial Copy

Draft v0.1, 2026-11-25 — not published; founder approval required before any use.

In-app wording. American spelling. No exclamation marks. Placeholders in square brackets must be filled before use.

## Rule that governs every screen below

Nothing may ever sit between the user and starting a recording. No paywall, trial message, reminder, download prompt or thank-you may appear before, during or in place of the record action. Every message below is shown only on the Synthesis screen, in Settings, or after a recording has already started and finished. Every dismiss button must work on the first tap.

## 1. Trial-start message

Shown the first time the user opens the Synthesis screen. A dismissible card or bottom sheet.

**Title:** Synthesis is free to try

**Body:** Synthesis turns your rambling thoughts into clean, organized notes. Try it free: [TRIAL: to be decided — e.g. first N syntheses or N days]. Recording and transcription stay free forever.

**Button:** Got it

**Small line:** Nothing leaves your phone.

Variant that explains the download, shown only if the model is not yet on the phone:

**Title:** One download first

**Body:** Synthesis runs on your phone, so it needs a one-time download of about 2.5 GB. Use Wi-Fi if you can. You can keep recording while it downloads.

**Buttons:** Download now · Not now

**Small line:** You only do this once. After that Synthesis works without a connection.

## 2. Gentle mid-trial reminder

Shown once, on the Synthesis screen, at about the halfway point of the trial. Never as a pop-up over a recording. Dismissible and not repeated.

**Title:** [N] left in your free trial

**Body:** You have [REMAINING TRIAL: e.g. 5 syntheses or 7 days] left. After that, Synthesis is a one-time purchase of [PRICE: $39.99, launch offer $29.99]. No subscription. Recording and transcription stay free.

**Buttons:** See details · Dismiss

## 3. Paywall screen

Shown on the Synthesis screen when the trial has ended and the user asks for a synthesis. It replaces only the Synthesis action. The capture screen and record button are untouched.

**Headline:** Keep turning rambles into clean notes

**Three bullets:**
- Your rambling thoughts, rewritten as clear, organized notes
- Pay once. No subscription, ever
- Runs on your phone. Your recordings and notes never leave it

**Price line:** [PRICE: $39.99, launch offer $29.99] · one-time purchase

**Primary button:** Buy Synthesis

**Secondary link:** Restore purchase

**Sentence that must appear on this screen:** Recording and transcription stay free, always.

**Close control:** a plain "Not now" or close icon at the top. It returns to the notes list with nothing lost. Notes you already have stay readable. Thoughts captured after the trial ends keep being recorded and transcribed, and wait for Synthesis.

**Fine print line:** Billed once through Google Play. Needs a phone with about 8 GB of memory.

Reviewer questions for the founder:
- What happens to a note that was already synthesized when the trial ends: can the user still change its style, merge or move thoughts? This copy assumes they can read it, and that actions needing a new synthesis are the paid part. Decide and adjust the "Close control" paragraph to match.

## 4. Message for phones that cannot run Synthesis

Shown on the Synthesis screen only, in place of the trial message and the paywall. The user is never offered the purchase on a phone that cannot run it.

**Title:** Synthesis needs a bigger phone

**Body:** Synthesis needs about 8 GB of memory, and this phone has [DETECTED MEMORY]. Everything else works here, free: recording, transcription, playback and editing.

**Button:** Back to my notes

**Small line:** You will not be asked to pay for something this phone cannot run.

Alternative short body, if space is tight: This phone has less than the 8 GB of memory Synthesis needs. Recording and transcription still work, and stay free.

Note for developer: the exact memory threshold must come from the build, not from this draft. "About 8 GB" is the founder's figure.

## 5. Post-purchase thank-you

Shown once, as a dismissible card on the Synthesis screen. Do not show it over a recording.

**Title:** Thank you

**Body:** Synthesis is yours, for good. No subscription, no renewal. I am one person building this, so your support means a lot.

**Buttons:** Continue · Tell me what you think (opens an email to [SUPPORT EMAIL])

Optional second line, only if true at launch: You can restore this purchase on any phone with the same Google account, from Settings.

## 6. Message when a purchase fails or cannot be checked

Not requested, but a paywall without this is incomplete.

**Title:** That did not go through

**Body:** Google Play could not complete the purchase. You have not been charged unless Google Play tells you otherwise. Try again, or tap Restore purchase if you have already bought Synthesis.

**Buttons:** Try again · Close
