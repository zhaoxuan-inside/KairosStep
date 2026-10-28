#!/usr/bin/env python3
"""Build complete offline detail records from the numbered source manuscript.

The manuscript is the source of truth. Existing hand-edited detail records are
retained; this script fills the rest without inventing medical or legal claims.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/HowToLiveBetter.md'
ADVICE = ROOT / 'app/assets/data/advice.json'
DETAIL = ROOT / 'app/assets/data/detail.json'
FIELDS = {'成本': 'cost', '说人话': 'plain', '收益': 'benefit', '证据等级': 'grade', '来源': 'sources', '备注': 'notes'}


def main():
    source = SOURCE.read_text(encoding='utf-8')
    advice = json.loads(ADVICE.read_text(encoding='utf-8'))['list']
    detail = json.loads(DETAIL.read_text(encoding='utf-8'))
    headings = list(re.finditer(r'^#### \d+\. (.+)$', source, re.M))
    if len(headings) != len(advice):
        raise ValueError(f'{len(headings)} source sections for {len(advice)} advices')
    for i, (heading, item) in enumerate(zip(headings, advice)):
        if heading.group(1).strip() != item['t']:
            raise ValueError(f"Title mismatch for advice {item['id']}")
        body = source[heading.end():headings[i+1].start() if i+1 < len(headings) else len(source)]
        found = {}
        for match in re.finditer(r'^- (成本|说人话|收益|证据等级|来源|备注)[：:]\s*(.*)$', body, re.M):
            found[FIELDS[match.group(1)]] = match.group(2).strip()
        if set(found) != set(FIELDS.values()):
            raise ValueError(f"Missing detail field for advice {item['id']}: {set(FIELDS.values())-set(found)}")
        key = str(item['id'])
        plain = found['plain']
        sentence = re.search(r'[。！？]', plain)
        summary = plain[:sentence.end()] if sentence else plain
        if key == '675':
            summary = '一个人住、暂时没人照应时，先找能帮忙开门的邻居，向社区登记探访，再在手机里设好紧急联络。'
        if key in detail:
            detail[key]['h'] = summary
            continue
        detail[key] = {
            'h': summary,
            'cost': found['cost'],
            'plain': found['plain'],
            'benefit': found['benefit'],
            'grade': found['grade'][:1] if found['grade'][:1] in 'ABC' else 'C',
            'sources': [[found['sources'], '']],
            'notes': found['notes'],
            'rel': [],
        }
    ordered = {str(a['id']): detail[str(a['id'])] for a in advice}
    DETAIL.write_text(json.dumps(ordered, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    print(f'Built {len(ordered)} advice details')


if __name__ == '__main__':
    main()
