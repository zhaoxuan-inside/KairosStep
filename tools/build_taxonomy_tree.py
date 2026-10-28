#!/usr/bin/env python3
"""Compile topic memberships from the maintained tree and explicit semantic overrides.

No topic infers a schedule or persona predicate. Existing advice wording, tags,
legacy cron, and untouched prerequisites are preserved. --check never writes.
"""
import argparse
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def compile_assets(root):
    tree = json.loads((root / 'app/assets/data/taxonomy_tree.json').read_text())
    overrides = json.loads((root / 'tools/taxonomy_overrides.json').read_text())
    data = json.loads((root / 'app/assets/data/advice.json').read_text())
    result = copy.deepcopy(data)
    nodes = {}
    def visit(entries, parent='', names=()):
        for key, value in entries.items():
            path = parent + '/' + key if parent else key
            if 'cron' in value or 'prerequisites' in value:
                raise ValueError('Topics must not infer scheduling or applicability: ' + path)
            labels = (*names, value['name'])
            nodes[path] = (value, labels)
            visit(value.get('sub', {}), path, labels)
    visit(tree)
    ids = {str(a['id']) for a in result['list']}
    if len(ids) != len(result['list']) or set(overrides) - ids:
        raise ValueError('Duplicate IDs or overrides for unknown advice')
    for item in result['list']:
        override = overrides.get(str(item['id']), {})
        paths = override.get('paths', item.get('tree_paths', [item['tree_path']]))
        if not paths or len(set(paths)) != len(paths):
            raise ValueError('Empty or duplicate membership: ' + str(item['id']))
        for path in paths:
            if path not in nodes or nodes[path][0].get('sub'):
                raise ValueError('Unknown/nonleaf membership: ' + str(item['id']) + ' ' + path)
        item['tree_paths'] = paths
        item['tree_path'] = paths[0]
        item['tree_display'] = ' > '.join(nodes[paths[0]][1])
        for key in override.get('remove_prerequisites', []):
            item['prerequisites'].pop(key, None)
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    output = ROOT / 'app/assets/data/advice.json'
    data = compile_assets(ROOT)
    if args.check:
        if json.loads(output.read_text()) != data:
            raise SystemExit('Topic assets are stale; run tools/build_taxonomy_tree.py')
    else:
        output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    crosslisted = sum(len(a['tree_paths']) > 1 for a in data['list'])
    print(f"{'PASS' if args.check else 'Compiled'}: {len(data['list'])} advice, {crosslisted} cross-listed")

if __name__ == '__main__':
    main()
