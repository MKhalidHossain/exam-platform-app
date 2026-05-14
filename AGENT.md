নিচের prompt টা Codex-এ দিন। এটা আপনার existing `AGENT.md` update করবে, Codex issue report-এর C1–C5 / M1–M6 findings যোগ করবে, এবং future implementation prompts যেন কম context use করে সেই rule add করবে। Codex report অনুযায়ী main issues হলো cloud fallback wired না, corrections parser-এ apply না, STT locale ভুল, TTS/listening overlap, risky submit inconsistency ইত্যাদি। 

```text id="x4rsls"
Task: Update AGENT.md only.

Use minimum context.
Do not scan unrelated files.
Do not modify app source code.
Do not implement fixes.
Touch only:
AGENT.md

Goal:
Update AGENT.md with the latest voice assistant issue findings and optimized implementation rules.

Add a new section near the top:

## Current Voice Assistant Issues Found By Audit

Critical issues:
1. Cloud fallback is configured but not actually usable from screens.
   Required fix:
   - wire cloudFallbackEnabled, CloudSpeechService, fallback audio file, locale, and available commands into voice processing
   - start/stop recorder around native listening
   - clean temporary audio files
   - never upload audio when cloud fallback is disabled
   - never execute cloud transcript directly; always parse through normalizer/parser/safety policy

2. Voice calibration/user corrections are saved but not applied to command parsing.
   Required fix:
   - load learned corrections per screen/context
   - pass corrections into VoiceCommandParser.parse
   - apply correction before fuzzy matching
   - do not auto-learn risky commands

3. Speech locale setting is ignored.
   Required fix:
   - use speechLocaleCode for speech_to_text/STT
   - use languageCode only for flutter_tts/TTS
   - centralize locale resolution
   - safely fallback if selected STT locale is unsupported

4. TTS and listening can overlap or restart at the wrong time.
   Required fix:
   - prevent listening while TTS is speaking
   - resume listening only after TTS completion
   - allow intentional mic-tap interruption
   - guard against multiple active speech/listening sessions

5. Risky submit/final-submit handling is inconsistent.
   Required fix:
   - define one screen-aware submit safety policy
   - weak fuzzy submit must never execute
   - cloud-only uncertain submit must never execute
   - final submit from review screen must require explicit confirm submit
   - learned correction must not trigger final submit automatically

Medium issues:
1. Listening restart loop is too aggressive.
2. No real audio quality feedback for quiet/noisy environments.
3. Fuzzy matching is Levenshtein-only with weak ambiguity handling.
4. Duplicate command normalizers can drift.
5. Voice analytics are incomplete outside MCQ.
6. NativeSpeechService exists but screens bypass it and duplicate STT logic.

Low priority improvements:
1. Calibration should be real voice calibration, not only manual text entry.
2. Overlay hints should be driven by current screen command availability.
3. Offline/cloud-unavailable behavior should be clearly surfaced.
4. Mic permission recovery should include clear app-settings guidance where supported.

Add another section:

## Low Context Codex Rules

Rules for future Codex tasks:
- Do not re-audit the repo unless explicitly asked.
- Do not scan unrelated files.
- Work only on files listed in the prompt.
- Make the smallest safe change.
- Do not rewrite the whole voice assistant.
- Do not refactor unrelated screens.
- Do not add API keys/secrets in Flutter.
- Stop after the requested step.
- Run formatter and targeted tests only when possible.
- If a setting or dependency is missing, add a small TODO instead of broad refactor.
- Preserve all existing voice features unless they are clearly broken.

Add another section:

## Recommended Fix Order

Use this order:
1. Fix STT locale resolution.
2. Consolidate duplicate normalizers.
3. Fix TTS/listening lifecycle.
4. Add safe listening restart/backoff.
5. Apply learned corrections to parser.
6. Fix risky submit/final-submit safety.
7. Improve fuzzy ambiguity handling.
8. Route native STT through NativeSpeechService where practical.
9. Wire optional cloud fallback and audio buffer.
10. Add audio quality and mic permission feedback.
11. Fill analytics gaps.
12. Final verification.

Add another section:

## Critical Safety Rules

- Never execute final submit from fuzzy match alone.
- Never execute final submit from cloud transcript alone.
- Never execute final submit from learned correction alone.
- Final submit must require explicit confirm submit on review screen.
- Cloud fallback must be optional and disabled by default if setting is missing.
- If cloud fallback is disabled, no audio upload is allowed.
- STT transcript, cloud transcript, and learned corrections must all pass through the same parser and safety policy.

Add another section:

## Definition Of Done For Voice Upgrade

The voice assistant upgrade is complete only when:
- STT uses speechLocaleCode, not TTS languageCode.
- TTS uses languageCode and keeps existing pitch/speed settings.
- One canonical normalizer is used.
- Learned corrections are applied in parser.
- Parser is screen-aware.
- Fuzzy ambiguity asks confirmation instead of guessing.
- TTS and listening do not overlap.
- Listening restart loop is guarded.
- Risky submit/final submit is protected.
- Cloud fallback is wired but optional.
- No API keys exist in Flutter.
- Temp audio files are cleaned.
- App works offline with native STT and parser.
- Analytics explain command failures.
- flutter analyze passes.
- voice-related tests pass.

Keep the existing AGENT.md content.
Only append or merge these sections cleanly.
Do not duplicate existing sections if similar sections already exist.
Return a short summary of what was updated.
```
