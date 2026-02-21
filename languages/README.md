# Language Packs

Janus orchestrator language packs live here as `.txt` files.

## Format

- File name: `<code>.txt` (examples: `en.txt`, `es.txt`)
- Encoding: UTF-8
- Syntax per line: `key=value`
- Comments: lines starting with `#`
- Empty lines are ignored

## Example

```txt
language_name=English
app_title=Janus Orchestrator
main_menu_title=Main Menu
```

If a key is missing in your language file, the UI falls back to `en.txt`.
