# The setup wizard

The BxCachy setup wizard: a full-screen terminal form written in BoxLang on MatchBox's terminal canvas (`docs/tui.md` in the MatchBox repo). It draws pages given as
JSON and writes the answers as JSON. It runs nothing itself; `bxcachy init` starts it and acts on the answers
(COMMAND-CONTRACT.md section 14).

```
bxcachy wizard --pages=pages.json --out=answers.json [--answers=saved.json]
bxcachy wizard --demo [--out=answers.json]        # built-in pages, to try it
```

Exit codes: 0 answers written, 130 cancelled (nothing written), 2 usage, 4 unreadable pages or answers file.

## Pages

```json
{ "title": "BxCachy", "tagline": "...", "version": "0.12.0",
  "pages": [ { "id": "desktop", "title": "Desktop", "intro": "...",
    "questions": [
      { "type": "choice",  "id": "desktops", "label": "...", "help": "...", "default": "both",
        "options": [ { "value": "hyprland", "label": "Hyprland", "description": "shown under the list when focused", "group": "optional heading" } ] },
      { "type": "multi",   "id": "layouts",  "label": "...", "default": ["us"], "options": [ ... ] },
      { "type": "text",    "id": "git_name", "label": "...", "placeholder": "...", "default": "" },
      { "type": "number",  "id": "workspaces", "label": "...", "min": 1, "max": 10, "default": 2 },
      { "type": "confirm", "id": "natural_scroll", "label": "...", "default": false },
      { "type": "info",    "label": "...", "help": "..." } ] } ] }
```

Any question may carry `"when": { "id": "other_question", "in": ["a", "b"] }` (or `"equals": "a"`): it is shown only while that answer matches, and a hidden question is left out of the review and the answers file.

Answers are a flat JSON object keyed by question id: a string (choice, text), an array of strings (multi), a number, or a bool.

## Keys and mouse

Up/Down (or j/k) move, Space selects or toggles, Enter finishes the question and moves on, Left/Right change a number,
Tab/PageDown next page, Esc/Shift-Tab/PageUp previous page, Ctrl-C cancels. Clicks select options and jump to visited steps.
Text fields take typing directly (Backspace deletes, Ctrl-U clears).

## Look

Catppuccin Frappe neutrals with the Ortus brand gradient (cyan `#00DBFF` to green `#00FF78`), true colour, a fade-in between
screens and a soft shimmer. The splash uses the official BoxLang icon as half-block pixel art (`assets/wizard/art-*.txt`, embedded by `bootstrap/gen-wizard.sh` into `src/bxcachy/WizardData.bx`). Every screen shows "Powered by BoxLang / www.boxlang.io". It needs a 76x24 terminal; larger is nicer.

## Code

| Class | Does |
|---|---|
| `WizardApp` | State and key handling, no drawing (unit tested). |
| `WizardView` | Draws a frame on the canvas and records click regions; testable with `tui.render_to_string`. |
| `Wizard` | The run loop: events in, frames out. |
| `WizardData` | Generated: demo pages and splash art. |

## Developing

Needs MatchBox built with `bif-tui`.

```
(cd src && matchbox ../tests/wizard_app_test.bxs)    # logic
(cd src && matchbox ../tests/wizard_view_test.bxs)   # what each screen shows
bash tests/wizard-test.sh BXCACHY_NATIVE             # end to end in a pseudo-terminal
python3 tools/record-wizard.py --bin BXCACHY_NATIVE --out /tmp/rec   # mp4 and gif (needs Pillow, pyte, ffmpeg)
```
