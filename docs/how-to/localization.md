> status: current (2026-09-11)

# Localisation

## Current State (as of May 2026)

### Languages
| Code | Language | Coverage |
|------|----------|----------|
| `ar` | Arabic | 99% |
| `de` | German | 99% |
| `en` | English (source) | — |
| `es` | Spanish | 99% |
| `fr` | French | 99% |
| `hi` | Hindi | 99% |
| `id` | Indonesian | 99% |
| `it` | Italian | 99% |
| `ja` | Japanese | 99% |
| `ko` | Korean | 99% |
| `pt-BR` | Portuguese (Brazil) | 99% |
| `ru` | Russian | 99% |
| `sr` | Serbian | 99% |
| `hr` | Croatian | 99% |
| `tr` | Turkish | 99% |
| `zh-Hans` | Chinese (Simplified) | 99% |

**Total keys: 261.** The 3 intentionally untranslated keys are the empty key, `%lld`, and `%lld s` — these are format-specifier-only strings that need no translation.

The strings file lives at:
```
NewTubeApp/NewTube/Localizable.xcstrings
```

---

## Adding or Fixing Translations

The automation script lives in `scripts/`:
```
scripts/translate_strings.py
```

It uses Google Translate (via `deep-translator`, no API key required) and correctly protects `%@`, `%lld`, `%d`, `%.2g` format specifiers from being translated or transliterated.

### One-time setup

```bash
python3 -m venv /tmp/loctranslate_venv
/tmp/loctranslate_venv/bin/pip install deep-translator
```

The venv lives in `/tmp/` so it is wiped on reboot. Re-run the two commands above whenever needed.

---

### Dry run — preview what would be translated without writing anything

```bash
cd scripts
/tmp/loctranslate_venv/bin/python3 translate_strings.py --dry-run
```

---

### Fill missing translations — any new keys added by a developer

Run with no flags. The script is **additive only** — it skips any key/language pair that already has a translation.

```bash
cd scripts
/tmp/loctranslate_venv/bin/python3 translate_strings.py
```

---

### Re-translate an entire language — e.g. after discovering bad output

Overwrites every entry for that language, even ones that already exist.

```bash
/tmp/loctranslate_venv/bin/python3 translate_strings.py --fix-lang sr
/tmp/loctranslate_venv/bin/python3 translate_strings.py --fix-lang hr
```

---

### Adding a new language

1. Open `translate_strings.py` and add an entry to the `LANG_MAP` dict:
   ```python
   LANG_MAP = {
       ...
       "nl": "nl",   # Dutch — xcstrings code : GoogleTranslator code
   }
   ```
   Use the [xcstrings language code](https://developer.apple.com/documentation/xcode/choosing-localization-regions-and-scripts) as the key and the [Google Translate language code](https://py-googletrans.readthedocs.io/en/latest/#googletrans-languages) as the value. Usually they match; notable exceptions are `pt-BR → pt` and `zh-Hans → zh-CN`.

2. Add the language to `knownRegions` in the Xcode project file:
   ```
   NewTube/NewTubeApp/NewTubeApp.xcodeproj/project.pbxproj
   ```
   Find the `knownRegions` block and add the new code:
   ```
   knownRegions = (
       Base,
       en,
       sr,
       hr,
       nl,   ← add here
   );
   ```

3. Run the script:
   ```bash
   cd scripts
   /tmp/loctranslate_venv/bin/python3 translate_strings.py
   ```

4. Commit both `Localizable.xcstrings` and `project.xcproj`.

---

### Adding new localised strings (developer workflow)

When a developer adds a new string in Swift, they use `String(localized:)` with a key that is the English text itself:

```swift
Text(String(localized: "My New Feature"))
```

Xcode will extract it into `Localizable.xcstrings` with an empty `localizations` dict. After merging, run the script once to fill all languages automatically:

```bash
/tmp/loctranslate_venv/bin/python3 translate_strings.py
```

---

## Checking coverage

```bash
cd "NewTubeApp/NewTube"
python3 - <<'EOF'
import json
with open('Localizable.xcstrings') as f:
    data = json.load(f)
strings = data['strings']
total = len(strings)
langs = sorted({l for v in strings.values() for l in v.get('localizations', {})})
print(f'Total keys: {total}\n')
for lang in langs:
    count = sum(1 for v in strings.values() if lang in v.get('localizations', {}))
    print(f'{lang:10} {count:4}/{total}  ({count/total*100:.0f}%)')
EOF
```

---

## Known limitations

- **Machine translation quality** — Google Translate is used for all strings. Translations are generally good for UI labels and short phrases, but long or idiomatic strings may need native review before a public release.
- **Cyrillic/non-Latin script caution** — Format specifiers (`%@`, `%lld`, etc.) are protected by `⟪0⟫` / `⟪1⟫` symbol brackets before translation and restored afterwards. This avoids the transliteration bug where Cyrillic engines turned `FMTSPEC0END` into `ФМТСПЕЦ0ЕНД`.
- **Plural forms** — The xcstrings file currently has no plural entries (all entries are `stringUnit`). If a string needs plural handling (e.g. "1 video / 2 videos"), add it manually in Xcode using the plural editor, then mark it `extractionState: manual` so the script does not overwrite it.
- **The `en` column shows 1%** — This is expected. In xcstrings, English strings are the *key*, so they are not duplicated in a `localizations.en` entry. The 3 explicit `en` entries in the file are Xcode-managed stubs.
