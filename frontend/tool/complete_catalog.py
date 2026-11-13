"""Development-only translation of static UI strings; never shipped or called by the app."""
import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = json.loads((root / 'test-results/catalog-source.json').read_text(encoding='utf-8-sig'))
output = root / 'test-results/completed-catalog.json'
result = json.loads(output.read_text(encoding='utf-8')) if output.exists() else {}
for language, entries in source.items():
    pending = [(key, text) for key, text in entries.items() if key not in result.get(language, {})]
    result.setdefault(language, {})
    while pending:
        batch, size = [], 0
        while pending and (not batch or size + len(pending[0][1]) < 3500):
            item = pending.pop(0)
            batch.append(item)
            size += len(item[1]) + 30
        tokens = {}
        def protect(match):
            token = f'ZXQPH{len(tokens):04d}QXZ'
            tokens[token] = match.group(0)
            return token
        text = '\n'.join(f'ZXQKEY{i:04d}QXZ\n' + re.sub(r'\{\w+\}|MySold|SUPPRIMER|DELETE', protect, value) for i, (_, value) in enumerate(batch))
        url = 'https://translate.googleapis.com/translate_a/single?' + urllib.parse.urlencode(dict(client='gtx', sl='auto', tl=language, dt='t', q=text))
        for attempt in range(5):
            try:
                with urllib.request.urlopen(url, timeout=35) as response:
                    data = json.load(response)
                translated = ''.join(part[0] for part in data[0] if part[0])
                matches = list(re.finditer(r'ZXQKEY(\d{4})QXZ', translated))
                if len(matches) != len(batch):
                    raise ValueError('Translation markers changed; refusing ambiguous output')
                for i, match in enumerate(matches):
                    value = translated[match.end():matches[i+1].start() if i+1 < len(matches) else None].strip()
                    for token, original in tokens.items():
                        value = value.replace(token, original)
                    key, original = batch[i]
                    if set(re.findall(r'\{\w+\}', value)) != set(re.findall(r'\{\w+\}', original)) or 'ZXQPH' in value:
                        raise ValueError('Translation placeholders changed')
                    result[language][key] = value
                output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
                print(language, len(result[language]), '/', len(entries), flush=True)
                break
            except Exception:
                if attempt == 4:
                    raise
                time.sleep(2 ** attempt)
        time.sleep(.2)
