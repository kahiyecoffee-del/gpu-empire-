"""Checks translated .arb files against the English template.

    python3 tool/l10n/check_arb.py lib/l10n/app_de.arb [...]

Every key must be present, no extra keys, and each message must use exactly
the same {placeholders} as English.
"""
import json
import re
import sys
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parents[2] / 'lib/l10n/app_en.arb'
PLACEHOLDER = re.compile(r'\{(\w+)\}')


def messages(path):
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    return data, {k: v for k, v in data.items() if not k.startswith('@')}


def check(path):
    _, en = messages(TEMPLATE)
    data, tr = messages(path)
    errors = []
    if '@@locale' not in data:
        errors.append('missing @@locale')
    for key, text in en.items():
        if key not in tr:
            errors.append(f'missing {key}')
            continue
        if not isinstance(tr[key], str) or not tr[key].strip():
            errors.append(f'empty {key}')
            continue
        want = sorted(PLACEHOLDER.findall(text))
        got = sorted(PLACEHOLDER.findall(tr[key]))
        if want != got:
            errors.append(f'placeholders differ in {key}: {got} != {want}')
    for key in tr:
        if key not in en:
            errors.append(f'extra key {key}')
    return errors


if __name__ == '__main__':
    failed = False
    for path in sys.argv[1:]:
        errors = check(path)
        status = 'OK' if not errors else f'{len(errors)} problem(s)'
        print(f'{path}: {status}')
        for e in errors:
            print('  ', e)
        failed |= bool(errors)
    sys.exit(1 if failed else 0)
