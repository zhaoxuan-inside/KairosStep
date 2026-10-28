#!/usr/bin/env python3
"""Audit current content assets without changing advice or assigning clinical validity.

Run from any directory. --check compares the saved report with current source files.
The trigger preview mirrors the current Dart defaults; it is not the proposed router.
"""

import argparse
import collections
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUTS = (
    'app/assets/data/advice.json',
    'app/assets/data/detail.json',
    'app/assets/data/taxonomy_tree.json',
    'docs/HowToLiveBetter.md',
    'app/lib/models/advice.dart',
    'app/lib/state/app_store.dart',
    'app/lib/data/catalog.dart',
    'app/lib/ui/emergency/emergency_sheet.dart',
)
FREQUENCIES = {'每天', '每周', '每月', '每年', '单次', '偶发', '每次', '每日多次'}
SOURCE_FIELDS = ('成本', '说人话', '收益', '证据等级', '来源', '备注')
EMERGENCY_WORDS = (
    '中暑', '海姆立克', '心肺复苏', '触电', '溺水', '毒蛇咬伤',
    '骨折制动', '破水', '洗胃', '催吐',
)


def emergency_reasons(item):
    reasons = []
    tags = set(item['tags'])
    if item['c'] == '紧急情况：先做什么':
        reasons.append('chapter')
    if item['act_type'] == 'emergency-action':
        reasons.append('act_type')
    if tags & {'急救', '速查'}:
        reasons.append('tag:急救/速查')
    if {'事中', '突发事件'} <= tags:
        reasons.append('tag:事中+突发事件')
    if any(word in item['timing_badge'] for word in ('黄金救治', '紧急')):
        reasons.append('badge')
    reasons.extend('title:' + word for word in EMERGENCY_WORDS if word in item['t'])
    return reasons


def default_mode(item, reasons):
    tags = set(item['tags'])
    if reasons:
        return 'dormant'
    if tags & {'每天', '每日多次'}:
        return 'daily'
    if '每周' in tags:
        return 'weekly'
    if '每月' in tags:
        return 'monthly'
    if tags & {'每年', '筛查', '日历时点'}:
        return 'yearly'
    return 'dormant'


def build(root):
    load = lambda name: json.loads((root / name).read_text(encoding='utf-8'))
    advice = load(INPUTS[0])['list']
    details = load(INPUTS[1])
    tree = load(INPUTS[2])
    source = (root / INPUTS[3]).read_text(encoding='utf-8')
    headings = list(re.finditer(r'^#### \d+\. (.+)$', source, re.M))
    # Source numbering restarts per chapter. Align by global order AND exact title;
    # fail closed if order, length or content changes rather than misattribute evidence.
    if len(headings) != len(advice):
        raise ValueError('Original section count and application advice count differ')
    ids = [item['id'] for item in advice]
    if len(ids) != len(set(ids)):
        raise ValueError('Duplicate advice IDs')
    leaves = {
        f'{domain}/{branch}/{leaf}'
        for domain, entry in tree.items()
        for branch, node in entry['sub'].items()
        for leaf in node['sub']
    }
    tag_counts = collections.Counter(tag for item in advice for tag in item['tags'])
    source_counts = collections.Counter()
    rows = []
    issue_counts = collections.Counter()
    for index, (item, heading) in enumerate(zip(advice, headings)):
        if heading.group(1).strip() != item['t']:
            raise ValueError(f"Source title mismatch for advice {item['id']}")
        end = headings[index + 1].start() if index + 1 < len(headings) else len(source)
        body = source[heading.end():end]
        fields = [field for field in SOURCE_FIELDS
                  if re.search(r'^- ' + field + r'[：:]', body, re.M)]
        source_counts.update(fields)
        has_link = bool(re.search(r'https?://', body))
        source_counts['has_http_link'] += int(has_link)
        title_numbers = collections.Counter(re.findall(r'\d+(?:\.\d+)?', item['t']))
        part_numbers = collections.Counter(re.findall(r'\d+(?:\.\d+)?', ' '.join(item['parts'])))
        missing_numbers = title_numbers - part_numbers
        reasons = emergency_reasons(item)
        mode = default_mode(item, reasons)
        issues = []
        if missing_numbers:
            issues.append('numeric_token_loss')
        if str(item['id']) not in details:
            issues.append('runtime_detail_missing')
        if not has_link:
            issues.append('source_http_link_missing')
        if not (set(item['tags']) & FREQUENCIES):
            issues.append('legacy_frequency_missing')
        if item['tree_path'] not in leaves:
            issues.append('invalid_tree_path')
        if reasons and set(item['tags']) & {'每天', '每日多次'}:
            issues.append('emergency_predicate_with_daily_tag_review')
        issue_counts.update(issues)
        rows.append({
            'id': item['id'], 'chapter': item['c'], 'title': item['t'],
            'source_line': source.count('\n', 0, heading.start()) + 1,
            'source_fields': fields, 'source_has_http_link': has_link,
            'runtime_detail_present': str(item['id']) in details,
            'tree_path': item['tree_path'], 'legacy_act_type': item['act_type'],
            'legacy_default_mode_preview': mode, 'legacy_emergency_reasons': reasons,
            'numbers_missing_from_parts': dict(missing_numbers), 'issues': issues,
            'v2_semantic_review': 'pending',
        })
    return {
        'report_version': 1,
        'scope': 'Current working files, structural audit and legacy routing preview only',
        'limitations': [
            'Does not verify medical, legal or financial claims',
            'Legacy mode preview is before persona, exclusions and user trigger overrides',
            'Legacy emergency predicate is not a semantic emergency classification',
            'Source HTTP link presence does not establish validity or currency',
            'Numeric token comparison detects omissions, not all semantic corruption',
            'All v2 goal assignments require separate semantic review',
        ],
        'inputs_sha256': {name: hashlib.sha256((root / name).read_bytes()).hexdigest()
                          for name in INPUTS},
        'summary': {
            'advice_count': len(advice), 'chapter_count': len({a['c'] for a in advice}),
            'action_type_counts': dict(sorted(collections.Counter(a['act_type'] for a in advice).items())),
            'unique_tags': len(tag_counts), 'singleton_tags': sum(n == 1 for n in tag_counts.values()),
            'generic_tag_counts': {tag: tag_counts[tag] for tag in
                                   ('自身', '泛指', '全民', '通用', '不限场景', '长期有效')},
            'source_section_count': len(headings), 'source_title_matches': len(rows),
            'source_field_coverage': dict(source_counts),
            'runtime_detail_count': len(details),
            'runtime_details_with_sources': sum(bool(d.get('sources')) for d in details.values()),
            'tree_leaf_count': len(leaves),
            'used_tree_leaf_count': len({a['tree_path'] for a in advice}),
            'legacy_default_mode_counts': dict(sorted(collections.Counter(
                row['legacy_default_mode_preview'] for row in rows).items())),
            'legacy_emergency_predicate_count': sum(bool(row['legacy_emergency_reasons']) for row in rows),
            'issue_counts': dict(sorted(issue_counts.items())),
            'numeric_loss_ids': [row['id'] for row in rows if row['numbers_missing_from_parts']],
        },
        'items': rows,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--output', type=Path, default=Path('docs/optimization/advice-audit.json'))
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    root = args.root.resolve()
    report = build(root)
    target = args.output if args.output.is_absolute() else root / args.output
    serialized = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if args.check:
        if not target.exists() or target.read_text(encoding='utf-8') != serialized:
            raise SystemExit('Audit report is missing or stale; regenerate it')
        print(f'PASS: {len(report["items"])} rows and source fingerprints match')
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(serialized, encoding='utf-8')
        print(json.dumps(report['summary'], ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
