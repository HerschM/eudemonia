# Eudemonia — Google Play Console Submission Texts

Draft v0.1, 2026-11-25 — not published; founder approval required before any use.

Everything here describes the first release: Capture and Synthesis only; capture starts from a persistent notification, a home-screen widget, or inside the app; no Accessibility permission; no volume-button trigger. Every statement must be checked against the actual build before it is pasted into Play Console. Placeholders in square brackets must be filled.

## (a) Foreground service declaration: `microphone` type

### Description of the user-visible feature

Eudemonia is a voice note app. The user records a spoken thought, and the app transcribes it and turns related thoughts into organized notes, all on the phone.

Recording is started by the user, by tapping Record in one of three places: the app's persistent notification (including from the lock screen), the app's home-screen widget, or the record button inside the app. While a recording is in progress, the app shows a notification with a running timer and a Stop and Save button. The user stops the recording by tapping that button or the stop button in the app. The recording is then saved on the device and queued for transcription.

The app never records unless the user has tapped Record. It does not listen in the background, does not record on a schedule, and does not start recording from any event other than the user's tap. It shows the notification for as long as it is recording.

### Why the service must continue when the app is not in front

A user records a thought by tapping the notification button on the lock screen, or the widget on the home screen. In both cases the app's screen is not open and is not in front. If recording stopped when the app left the foreground, the user could not make a voice note from the lock screen, from the home screen, or after switching to another app while talking. The foreground service keeps the microphone capture running, with a visible notification, until the user taps stop. Users also record while walking or while using another app, and need the recording to carry on when the screen turns off.

[Founder: Confirm the final wording of the service type and that the persistent notification (always present) and the recording notification (while recording) are described correctly for the build. If the app uses one service for both, say so. If the persistent notification uses a different foreground service type, it needs its own declaration.]

### Shot list for the short required video

Purpose: show a user starting and stopping a recording, and the foreground service notification while it runs. Length: 30 to 60 seconds. Screen recording of a real phone, with no edits that hide anything. Voice-over optional; captions help.

| # | Shot | What must be visible |
| :-- | :-- | :-- |
| 1 | Phone on the lock screen | Eudemonia's persistent notification with the Record Thought button. |
| 2 | User taps Record Thought on the lock screen | The notification changes to show the elapsed timer (for example "Recording 00:06") and a Stop and Save button. The app is not open. |
| 3 | User speaks a short sentence | Timer counting up. Microphone indicator (Android privacy dot) visible if the device shows it. |
| 4 | User unlocks and opens another app, then pulls down the notification shade | Recording notification still showing the timer. Proves recording continues when Eudemonia is not in front. |
| 5 | User taps Stop and Save in the notification | The notification returns to its idle state. |
| 6 | User opens Eudemonia | A new note card appears, queued and then transcribed, with its play button. |
| 7 | Repeat start and stop once from the home-screen widget | Widget tap starts the recording; the same notification appears; stop works. |
| 8 | Repeat start and stop once inside the app | Record button, timer, stop. |

Tip: record on Android 14 or later, since the review may use it. Say in the Play Console text field that all recording is started by a user tap.

## (b) Privacy policy draft

**DRAFT — the founder must review; not legal advice.**

Add this to a public web page and link it in Play Console. Also link it from inside the app (Settings) and from the landing page.

---

### Eudemonia Privacy Policy

Last updated: [DATE]

Eudemonia is made by [COMPANY NAME] ("I", "we"). This policy explains what the Eudemonia app does with your information. The short version: your recordings, transcripts and notes stay on your phone, and I do not collect them.

**What Eudemonia does not collect**

I do not collect your name, email address, location, contacts, or any other personal data through the app. There is no account. The app does not upload your recordings, transcripts or notes to me or to anyone else. [Confirm: no analytics, no crash-reporting service, no advertising in the app.]

**What stays on your phone**

When you use Eudemonia, the app stores the following on your phone only:
- Audio recordings you make.
- Text transcripts of those recordings.
- Notes the app writes from your transcripts, and the folders and settings you choose.

Speech-to-text and the language model that writes your notes run on your phone. This data is kept in the app's private storage. You can delete any note, and removing the app from your phone removes this data. [Confirm uninstall behavior and whether Android's backup feature copies app data to your Google account. If it does, say so here, or turn app backup off in the build.]

**Microphone permission**

The app asks for access to the microphone so it can record the thoughts you choose to record. It records only after you tap Record. The app shows a notification while recording is in progress.

**Notifications**

The app shows a persistent notification so you can start a recording quickly, including from the lock screen.

**Downloads**

The first time you use Synthesis, the app downloads a language model file of about 2.5 GB. This file is the same for everyone and contains none of your information. The download comes from [DOWNLOAD HOST — to be confirmed]. Like any download, the server that provides the file can see that a device requested it, such as the network address of the connection, under its own privacy practices. [Founder: verify what the download host logs, and whether any speech model is also downloaded.]

**Purchases**

If you buy Synthesis, the purchase is handled by Google Play. Google processes your payment and tells the app whether the purchase is valid. I do not receive your payment details. Google's use of your information is described in Google's privacy policy. [Confirm what the app stores locally about the purchase.]

**Sharing**

I do not sell, rent or share your data, because I do not have it.

**Children**

Eudemonia is not made for children under 13 [or the age in your target audience declaration], and I do not knowingly collect data from them.

**Changes to this policy**

If this policy changes, I will update the date at the top. If a future version of the app collects any data, I will say so here and in the app before it does.

**Contact**

[COMPANY NAME] · [SUPPORT EMAIL]

---

Reviewer notes on the policy: the site's email-form for the iPhone waiting list is separate from the app. If the website collects email addresses, the website needs its own short privacy notice. Legal compliance obligations (for example GDPR rights text) have not been addressed in this draft; the founder should check what applies.

## (c) Data safety form: suggested answers

**Verify against the actual build.** The answers below assume the build contains no analytics SDK, no crash reporter, no ad SDK, and no network calls other than Google Play Billing and the model download. Check the dependency list and run a network capture before submitting.

| Question in the form | Suggested answer | One-line reason |
| :-- | :-- | :-- |
| Does your app collect or share any of the required user data types? | No | Recordings, transcripts and notes stay on the device and are never sent to the developer or a third party. |
| Is all user data encrypted in transit? | Not applicable if no data is collected. If the form requires an answer: Yes | The only network traffic is the model download and Google Play Billing, both over HTTPS. Verify. |
| Do you provide a way for users to request that their data be deleted? | Not applicable if no data is collected | The developer holds no user data; the user deletes notes or uninstalls the app. |
| Personal info (name, email, address, and so on) | Not collected | No accounts and no forms in the app. |
| Financial info (payment info, purchase history) | Not collected by the developer | Purchases are handled by Google Play. Check how Play Console treats the Billing library. |
| Location | Not collected | The app has no location permission. Verify the manifest. |
| Audio files, voice or sound recordings | Not collected (processed on-device only) | Google's definition of "collected" means sent off the device; the recordings never leave it. Verify. |
| Messages, photos, videos, contacts, calendar | Not collected | The app does not request these. |
| App activity, web browsing | Not collected | No analytics. Verify. |
| App info and performance (crash logs, diagnostics) | Not collected | Only if no crash-reporting SDK is in the build. Android's own Play Console crash data is separate. Verify. |
| Device or other IDs | Not collected | No advertising ID and no analytics ID. Verify. |
| Is data shared with third parties? | No | There is no data to share. |
| Does the app have a privacy policy link? | Yes | Required for apps that handle personal or sensitive data and for the microphone permission. Use section (b). |
| Data handling declaration for the model download | None | The file is the same for every user and carries no user data. The server may log the request; see the policy. Verify what the host logs. |

Notes for the founder:
- Play's "collection" means data transmitted off the device. On-device processing that never leaves the phone is not collection, but read Google's current definition before relying on this.
- If the build includes any SDK that sends data (even crash logs), the "Not collected" answers must change.
- The microphone foreground service declaration in section (a) is a separate form from the Data safety form.
