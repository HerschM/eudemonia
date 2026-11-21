# Voice Sample Recording Script — Real-User Evaluation Set

> Purpose: real recordings, made with the app on the real phone, with known correct text. They are the ground truth for measuring speech recognition accuracy and cleanup quality end to end (TASK-062, test foundation).

## How to record

1. Open Eudemonia on the phone. Record each item below as **one separate capture, in order**.
2. Use the floating button at the bottom of the Capture tab (tap to start, tap again to stop) unless the item says **volume buttons**.
3. Wait for `Captured a new note [#NN]` before starting the next item. You do not need to wait for processing to finish.
4. Read the quoted text naturally, at your normal pace. **Say the filler words that are written** ("um", "uh", "like"); they are part of the test. Do not read the punctuation aloud.
5. If you make a mistake, delete that card and record the item again before moving on. If you skip or reorder anything, just tell me which numbers.
6. Do not delete any card when you are done, including failed ones (item 20 is meant to fail).
7. Leave the phone connected by USB and tell me you are finished.

Items marked **(free)** have no script: speak in your own words. Total time is about 15 minutes.

## A. Short thoughts (quiet room, phone in hand)

1. "Remind me to call the dentist tomorrow at nine thirty and book a cleaning."
2. "Um, so I was thinking, uh, what if the app could, like, suggest a folder automatically based on, you know, what I actually said."
3. "Meeting with Priya on Thursday at three PM to review the fourth quarter budget. It's around forty two thousand dollars."
4. "I felt really calm after the walk this morning. Honestly, it's the best I've felt all week."
5. "Buy milk."
6. "I need to fix the Riverpod provider that rebuilds the database query on every frame, and then check the Kotlin foreground service."

## B. Medium thoughts (quiet room)

7. "Okay, a few things for the weekend. First, pick up the dry cleaning before noon on Saturday. Second, order a birthday cake for Anjali, chocolate, for about twelve people. Third, renew the car insurance, it expires on the thirtieth. And, uh, don't forget to water the plants."
8. "Let's schedule the design review for Tuesday. No wait, not Tuesday, make it Wednesday at eleven, because Rahul is out on Tuesday. And send the invite to the whole team, not just the designers."
9. "So, um, two unrelated things. The onboarding screen feels too long, I think we should cut it down to, like, three steps. And separately, I keep forgetting to stretch in the evenings, which is basically why my back hurts."
10. **(free)** In your own words, about 20 to 30 seconds: something you actually need to do this week.

## C. Long thoughts (quiet room)

11. About one minute:
"I've been thinking about how I capture ideas during the day, and the problem is not that I don't have ideas. The problem is that by the time I get my phone out, unlock it, find the right app and start typing, the thought has already changed shape. What I remember is a summary of the idea, not the idea itself. So the whole point of this app is to remove every step between having a thought and saving it. I press two buttons, I talk, and I'm done. Everything else, the transcription, the cleanup, the sorting into folders, can happen later, when I'm not paying attention. If that works reliably, I think I will actually trust it, and trust is what makes a tool part of your day."

12. About two minutes:
"Here is a longer note about the plan for the next few weeks, so I don't lose track of it. The first priority is reliability. If I press the buttons and nothing is recorded, even once, I will stop trusting the app, so capture has to work every single time, with the screen off, in my pocket, and when the app has been closed for hours. The second priority is the quality of the text. I don't want a rough transcript with every um and uh left in. I want clean sentences that still sound like me, with nothing added and nothing removed. Names, numbers and dates matter the most, because those are the things I will act on later. The third priority is speed, but only in the background. I don't mind if a thought takes fifteen or twenty seconds to process, as long as the recording itself starts instantly. After that, I want related thoughts to be grouped together. If I record four ideas on a morning walk about the same project, I want to see one clear note, not four fragments. And finally, the app should tell me the truth about what it's doing. If something failed, show me that it failed and let me retry. If the phone is too hot or low on memory, wait and try again later. I would rather see an honest delay than a wrong result. That's the plan. I'll review it again at the end of the month and decide what to change."

13. **(free)** In your own words, one and a half to two minutes: talk through any idea or plan you have, the way you would on a walk. Do not prepare it.

## D. Real-world conditions

14. **Walking outdoors, phone in hand.** "Um, quick thought while I'm walking. The capture button should, like, vibrate differently when it starts and when it stops, so I know without looking."
15. **Phone in your pocket, start and stop with the volume buttons** (press volume up and volume down together). "Testing capture from my pocket. Remember to send the invoice to the client by Friday afternoon."
16. **Background noise** (TV, music or a café, at normal volume). "Note to self, the grocery list is eggs, bread, spinach, two onions and a bottle of olive oil."
17. **Quiet voice, almost a whisper.** "It's late, so I'm speaking quietly. I want to write down that the idea about weekly reviews was a good one."
18. **Fast speech**, as quick as you comfortably can. "I need to book flights for the conference, confirm the hotel, tell Sana I'm arriving on the fourteenth, and print the tickets before I leave."
19. **Long pause in the middle.** Say the first sentence, stay silent for about five seconds, then say the second. "I want to remember the name of that restaurant." (pause) "It was called The Blue Door, near the old station."
20. **Silence.** Start a capture, say nothing for five seconds, stop. This one should fail with "No speech detected".
21. **Phone on a table about one metre away**, normal voice. "This is a test from across the desk. The meeting notes are in the shared folder under planning."

## E. Optional, only if it reflects how you really use it

22. **(free)** If you naturally mix another language into your notes, record one short thought the way you would really say it, and tell me which language. The current speech model is not expected to handle every language; this tells us where it stands.
