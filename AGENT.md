# AGENT.md — Market-Ready Voice Assistant Stabilization

## Role

You are a senior Flutter engineer improving an existing quiz/exam app voice assistant.

The current workflow is already correct and must be preserved:

```text
Enter MCQ screen
→ assistant reads the question first
→ after TTS finishes, assistant listens
→ user says answer/command
→ assistant follows command
```

Do not redesign this workflow. Your job is to fix platform issues, improve recognition reliability, and make the assistant production-ready for different English accents.

---

## Main Goal

Make the voice assistant reliable on iOS and Android, and more tolerant of global English accents.

The app currently uses:

- `speech_to_text`
- `flutter_tts`
- existing voice parser / voice command processor
- existing quiz and review voice flows

Keep existing features working.

---

## Known Client Feedback

Client reported:

```text
iPhone: voice assistant works about 60% of the time; user must repeat commands.
Android: voice assistant does not recognize voice input at all.
```

Treat this as the main production bug to fix.

---

## Known Audit Findings

### Critical Issues

1. Android first-run permission/init flow is broken.
   - Manifest has RECORD_AUDIO, but auto voice flow may check permission and return before requesting it.
   - Voice mode may call speech init without requesting permission.

2. Android listen start can be treated as failed too early.
   - Do not rely on immediate `speech.isListening` after `speech.listen()`.
   - Android listening status can update asynchronously.

3. iOS partial results are processed too early.
   - Partial transcripts can be unstable.
   - Do not execute commands from weak partial text like only `option` before final `option A`.

4. STT locale and TTS language must be separated.
   - STT must use `speechLocaleCode`.
   - TTS must use `languageCode`.

5. TTS/listening lifecycle must be locked.
   - Listening must not start while TTS is reading.
   - Auto-listen starts only after TTS completion.
   - User mic tap can interrupt TTS intentionally.

6. MCQ answer parsing should use the canonical normalizer/parser.
   - Avoid duplicate parsing and duplicate normalizers.

7. Cloud fallback may exist but must be optional and safe.
   - No API keys in Flutter.
   - Never upload audio if disabled.
   - Never execute cloud transcript directly.

---

## Non-Negotiable Rules

- Do not rewrite the whole voice assistant.
- Do not change the working MCQ startup flow.
- Do not redesign UI unless required for a bug fix.
- Do not change unrelated quiz/business logic.
- Do not add provider API keys or secrets to Flutter.
- Do not store raw audio permanently.
- Keep app working offline with native STT.
- Cloud fallback must be optional.
- Final submit must remain safe.
- All transcripts must pass through the same parser/safety layer before command execution.
- Prefer small, localized fixes.
- Run `flutter analyze` after changes.

---

## Correct Voice Pipeline

All recognized text should follow this pipeline:

```text
raw STT transcript
→ canonical normalizer
→ screen-aware parser
→ fuzzy/alias matching
→ confidence decision
→ safety policy
→ execute / ask retry / ask yes-no / fallback
```

Cloud transcript and learned corrections must also pass through this same pipeline.

---

## Platform Requirements

### Android

Fix and verify:

- `RECORD_AUDIO` permission exists.
- Permission is requested when user enables voice or auto voice starts.
- Do not silently return false when permission is missing.
- `speech_to_text.initialize()` is called safely before listen.
- Do not treat immediate `speech.isListening == false` as listen failure.
- Use status callbacks/logs to track real listen state.
- If Android speech service is unavailable, show helpful message.
- Add debug logs for permission, init, listen start, status, errors.

### iOS

Fix and verify:

- `NSMicrophoneUsageDescription` exists.
- `NSSpeechRecognitionUsageDescription` exists.
- Speech and mic permission handling is correct.
- Do not execute weak partial transcripts.
- Use final result for command execution unless a partial phrase is stable and complete.
- Do not stop STT before full command is received.
- TTS must finish before auto-listen starts.

---

## Accent Recognition Requirements

Support common transcript variations:

```text
option bee -> option b
option be -> option b
opson bee -> option b
of shun b -> option b
answer sea / answer see -> answer c
option dee -> option d
fals / falls -> false
nex question -> next question
kweschen -> question
question five -> question 5
```

Use:

- canonical normalizer
- command aliases
- fuzzy matcher
- ambiguity detection
- learned corrections where safe

Do not over-normalize risky commands.

---

## Command Safety

### Quiz / MCQ Screen

- `submit` or `submit quiz` opens review only.
- It must not final-submit from quiz screen.

### Review Screen

- Strong direct `submit` or `submit quiz` may final-submit if current product behavior requires that.
- Weak, fuzzy, ambiguous, learned-only, or uncertain cloud submit must not final-submit directly.
- If confirmation is needed, use simple yes/no:
  - “Do you want to submit your quiz?”
  - User says “yes” or “no”
- Do not require the phrase “confirm submit” unless product requirements change.

### Other Screens

- Submit must not final-submit.

---

## TTS and Listening Lifecycle

Required behavior:

```text
TTS reading question -> listening blocked
TTS completed -> listening allowed if auto-listen enabled
manual mic tap -> may stop TTS and start listening
auto-listen -> must never stop active TTS
```

Guard all listen entry points:

```text
if TTS is speaking or question is reading:
    do not start listening
```

Check and guard:

- initState
- post-frame callbacks
- Future.delayed listen
- auto-listen
- resume-listen
- TTS completion handlers
- mic tap handler
- retry listen

Only one owner should schedule listening after TTS.

---

## Debug Logging Requirements

Use existing logging style or `debugPrint`.

Log:

- platform
- permission requested/result
- speech initialized
- speech available
- selected STT locale
- fallback STT locale
- listen start/stop
- speech status
- speech error
- recognized words
- finalResult
- confidence
- normalized transcript
- parser decision
- fallback used
- blocked listen reason

Do not log raw audio.

---

## Cloud Fallback Rules

Cloud fallback is optional and should be used only when:

- native STT fails
- parser cannot understand
- confidence is too low
- cloud fallback setting is enabled
- internet is available
- temporary audio exists

Rules:

- No cloud API keys in Flutter.
- Flutter calls backend only.
- Do not upload audio when fallback is disabled.
- Delete temporary audio after use.
- Cloud transcript must pass through the same parser/safety policy.
- Never execute cloud transcript directly.

---

## Recommended Fix Order

1. Android permission/init flow.
2. Android async listen-start handling.
3. iOS partial result handling.
4. STT locale vs TTS language separation.
5. TTS/listening lifecycle hardening.
6. Canonical normalizer/parser usage.
7. Fuzzy ambiguity improvements.
8. User correction learning integration.
9. Optional cloud fallback wiring.
10. Debug logs and analytics.
11. Real device QA.

---

## Low Context Coding Rules

For Codex/Claude Code tasks:

- Do not re-audit unless explicitly asked.
- Do not scan unrelated files.
- Work only on files listed in the prompt.
- Make the smallest safe change.
- Stop after the requested task.
- Do not rewrite screens.
- Do not refactor unrelated logic.
- If a broad fix is risky, add a TODO and explain.
- Run targeted tests when possible.
- Always report files changed and analyze/test result.

---

## Acceptance Criteria

The voice assistant is market-ready for this phase when:

- Android recognizes voice on real device after permission is granted.
- iPhone does not execute incomplete partial transcripts.
- MCQ screen reads question first, then listens.
- Listening never interrupts TTS unless user taps mic.
- STT uses `speechLocaleCode`.
- TTS uses `languageCode`, pitch, and speed.
- Parser uses canonical normalizer.
- Common accent variants are handled.
- Unknown commands give helpful retry feedback.
- Cloud fallback is optional and safe.
- No API keys/secrets exist in Flutter.
- Final submit remains safe.
- `flutter analyze` passes.
- Voice tests pass where available.