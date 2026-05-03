# Voice Mode — Complete Guide

> Hands-free exam practice using text-to-speech and voice commands.

---

## Table of Contents

1. [Overview](#overview)
2. [How It Works](#how-it-works)
3. [Enabling Voice Mode](#enabling-voice-mode)
4. [Answering Questions by Voice](#answering-questions-by-voice)
5. [All Voice Commands](#all-voice-commands)
6. [Status Indicators](#status-indicators)
7. [Interrupting the Reading](#interrupting-the-reading)
8. [Important Rules](#important-rules)
9. [Platform Notes](#platform-notes)
10. [Troubleshooting](#troubleshooting)

---

## Overview

Voice Mode lets you practice exam questions completely hands-free.

- The app **reads questions and options aloud**
- You **respond by voice** to select answers, navigate, flag, and view explanations
- Works on both **Android** and **iOS**
- Uses the **device's built-in speech engine** — no paid API, no extra cost

---

## How It Works

```
Voice Mode ON
      │
      ▼
App reads question + all options aloud
      │
      ▼
Mic opens automatically after reading finishes
      │
      ▼
You speak a command  (e.g. "second")
      │
      ▼
App confirms  ("Correct! Say next to continue.")
      │
      ▼
Mic opens again → ready for next command
      │
      ▼
  Loop continues...
```

> **Key rule:** The app never speaks and listens at the same time.
> Reading → then listening. This makes recognition reliable.

---

## Enabling Voice Mode

On the exam screen, tap the **mic icon (🎤)** in the top-right corner,
next to the volume button.

| Icon state | Meaning |
|---|---|
| Grey outline mic | Voice mode is **OFF** |
| Green filled mic | Voice mode is **ON** — idle |
| Red filled mic (pulsing) | Voice mode is **ON** — actively listening |

Tap the icon again at any time to turn voice mode off.

---

## Answering Questions by Voice

> Single letters (A, B, C, D) are **not reliable** for voice recognition.
> Always use the words below for best results.

### Recommended — Ordinal Words (most reliable)

| Say | Selects |
|---|---|
| **"first"** | Option A |
| **"second"** | Option B |
| **"third"** | Option C |
| **"fourth"** | Option D |

### Also Accepted — Phrase + Letter

| Say | Selects |
|---|---|
| "select A" / "select B" / "select C" / "select D" | A / B / C / D |
| "answer A" / "answer B" / "answer C" / "answer D" | A / B / C / D |
| "option A" / "option B" / "option C" / "option D" | A / B / C / D |
| "I choose A" / "I choose B" / "I choose C" / "I choose D" | A / B / C / D |
| "my answer is A" / "my answer is B" | A / B |
| "the answer is C" / "the answer is D" | C / D |

### After You Answer

- **Correct** → App says: *"Correct! Option B is the right answer. Say next to continue."*
- **Wrong** → App says: *"Incorrect. The correct answer is option C. Say next to move on."*
- **Already answered** → App says: *"This question is already answered."*

---

## All Voice Commands

### Navigation

| Say | Action |
|---|---|
| `next` / `skip` / `continue` | Go to the next question |
| `back` / `previous` / `go back` | Go to the previous question |
| `question 5` / `go to 3` / `number 7` | Jump directly to that question |

### Answer

| Say | Action |
|---|---|
| `first` / `second` / `third` / `fourth` | Select option A / B / C / D |
| `select A` / `answer B` / `option C` | Select that specific option |

### Question Tools

| Say | Action |
|---|---|
| `read` / `repeat` / `again` | Re-read the current question from the start |
| `flag` / `mark` / `bookmark` | Flag this question for review |
| `explain` / `explanation` / `why` | Show and read the explanation aloud |

### Exam

| Say | Action |
|---|---|
| `review` / `open review` / `exam review` | Open the exam review screen |
| `submit` / `finish` / `done` | Open the exam review screen and continue to final confirmation |
| `stop` / `quiet` / `silence` | Stop reading, open mic to give answer |

### Review Screen

| Say | Action |
|---|---|
| `submit` / `finish` | Start final submission confirmation |
| `confirm submit` / `confirm` | Submit final answers from the review screen |
| `question 5` / `go to question 5` | Return to that question |
| `unanswered` / `flagged` | Jump back to the first unanswered or flagged question |
| `back` / `return` | Return to the exam screen |
| `read` / `summary` | Hear the review summary again |

### Help

| Say | Action |
|---|---|
| `help` / `commands` | App reads all available commands aloud |

---

## Status Indicators

The **bottom overlay bar** shows voice mode status at all times.

| Bar appearance | Status | What to do |
|---|---|---|
| Blue border — "Speaking..." | App is reading aloud | Wait, or tap mic to interrupt |
| Red border — "Listening..." (pulsing mic) | Mic is open | Speak your command now |
| Grey border — "Voice mode active — tap mic to speak" | Mic is idle | Tap mic button to open |
| `Heard: "second"` text | Shows what the app recognised | Confirm it heard correctly |

---

## Interrupting the Reading

If the app is reading and you already know the answer:

1. **Tap the mic button** in the bottom overlay bar
2. Reading stops immediately
3. Mic opens — speak your answer

You do not need to wait for the full reading to finish.

---

## Important Rules

### 1. Wait for the mic to open before speaking
The red pulsing mic means it is actively listening.
Speaking before that will not be captured.

### 2. Use "first / second / third / fourth" for answers
This is the most reliable input method.
Single letters ("A", "B") often fail because voice engines
are trained on full English words, not isolated letters.

### 3. Speak clearly at normal volume
No need to shout or raise your voice.
Normal conversational speed and volume gives the best results.

### 4. One command at a time
Speak one command, wait for the app to respond, then speak again.
Saying multiple commands at once will only process the first one.

### 5. Mic closes after 5 seconds of silence
If you do not speak within 5 seconds of the mic opening, it closes automatically.
Tap the mic button at the bottom to reopen it.

### 6. Flag before moving on (unanswered questions)
You must either answer or flag every question before you can go to the next.
If you want to skip a question, say **"flag"** first, then **"next"**.

---

## Platform Notes

### Android
- Uses **Google Speech Recognition** engine
- Requires an **active internet connection**
- If offline, voice recognition will not work — use tap controls instead
- Microphone permission must be granted on first use

### iOS
- Uses **Apple Speech Recognition** (Siri engine)
- Works **offline** — no internet required
- Both microphone and speech recognition permissions must be granted on first use
- A permission dialog appears automatically the first time voice mode is turned on

---

## Troubleshooting

| Problem | Cause | Solution |
|---|---|---|
| App says "Not recognised" | Unclear speech or single letter said | Use `first / second / third / fourth` |
| App says "I heard X. Not recognised" | Partial match but no command found | Try one of the exact phrases from the commands table |
| Mic opens and closes very quickly | No internet (Android) or permission denied | Check internet / grant mic permission in device settings |
| Wrong answer selected | Homophone confusion (e.g. "free" heard as "three") | Speak more slowly; use explicit phrase like "select C" |
| Reading is too slow | Default TTS speed | Tap the volume icon (🔊) to stop, answer by tap instead |
| Voice mode turns off by itself | Mic icon was tapped again | Tap the mic icon again to re-enable |
| App asks for confirmation after "submit" | Safety check to prevent accidental submission | Say `confirm submit` to finish |
| Explanation does not read | No answer selected yet | Select an answer first, then say "explain" |

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────┐
│              VOICE MODE COMMANDS                 │
├─────────────────────┬───────────────────────────┤
│  Answer             │  first / second /          │
│                     │  third / fourth            │
├─────────────────────┼───────────────────────────┤
│  Navigate           │  next / back               │
│                     │  question [number]         │
├─────────────────────┼───────────────────────────┤
│  Tools              │  read / flag / explain     │
├─────────────────────┼───────────────────────────┤
│  Exam               │  review / submit / stop    │
├─────────────────────┼───────────────────────────┤
│  Review             │  submit / confirm submit   │
├─────────────────────┼───────────────────────────┤
│  Help               │  help                      │
└─────────────────────┴───────────────────────────┘
```

---

*Voice Mode — EJ Flutter App*
