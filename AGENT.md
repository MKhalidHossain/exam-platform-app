# Voice Assistant Submit + Last Question Next Flow Fix

## Goal

Fix the voice assistant flow bugs related to submit, confirm submit, finish, and next command on the last quiz question.

The current issue:
- When user says "submit", assistant asks for "confirm submit".
- Then user says "confirm submit", but assistant often cannot recognize it.
- This blocks the quiz flow.
- When user is on the last MCQ question and says "next", assistant asks user to say submit/finish, then asks for confirmation, and this also fails.

Required new behavior:
- On quiz/MCQ screen:
  - "submit" should directly go to review screen.
  - "finish" should directly go to review screen.
  - "go to review" should directly go to review screen.
  - "next" on normal question should go to next question.
  - "next" on last question should directly go to review screen.
- On review screen:
  - "submit" should final submit directly.
  - "finish" should final submit directly.
  - "final submit" should final submit directly.
- Do not require "confirm submit" for these flows.
- Do not ask user to say "confirm submit" or "confirm finish".
- Remove or bypass the broken voice confirmation requirement for submit/finish flows.

## Important Rules

- Do not rewrite the whole voice assistant.
- Do not remove existing voice features.
- Do not change unrelated quiz logic.
- Keep changes minimal and targeted.
- Preserve button/manual submit behavior.
- Only change voice command behavior where needed.
- Keep screen-aware command parsing.
- Keep fuzzy/accent-friendly command matching.
- Add tests for the fixed behavior.

## Expected Behavior

### Quiz Screen

```text
User says: "submit"
Expected: open review screen directly