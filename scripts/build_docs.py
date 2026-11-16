#!/usr/bin/env python3
"""Build manifest.json, docs/coverage.md and docs/formats/*.md from scripts/formats.py and the verification logs.

usage (repo root): python3 -I scripts/build_docs.py
Inputs : scripts/formats.py, docs/verification/*/*.jsonl (scripts/verify.py output), docs/verification/*/*.txt
         (scripts/verify_special_ubuntu.sh and scripts/verify_macos.sh output), defaultArchiveContent/.
Outputs: manifest.json, docs/coverage.md, docs/formats/<id>.md. Hand-written docs (docs/README.md,
         docs/existing-fixtures-audit.md, docs/migration.md) are not touched.
"""
import fnmatch, glob, hashlib, json, os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from formats import FORMATS, CUSTOM_EXPECTED, SPECIAL_PURPOSE  # noqa: E402

def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()

# known file versions of the standard content, by sha256 prefix
KNOWN = {}
for rel in ('hello world.txt', 'folder/README.md', 'folder/NestedArchive.zip'):
    KNOWN[sha(os.path.join(ROOT, 'defaultArchiveContent', rel))[:16]] = (rel, 'current')
KNOWN['fa52ae6c8424ff23'] = ('folder/NestedArchive.zip', 'NestedArchive.zip before 9283a00 (2025-12-09), 53236 bytes')
KNOWN['11397df50c2d6834'] = ('folder/README.md', 'README.md with CRLF line ends, 455 bytes')
KNOWN['cfce4e2952591e79'] = ('hello world.txt', 'hello world.txt with CRLF line end, 14 bytes')

STANDARD = [dict(path=rel, size=os.path.getsize(os.path.join(ROOT, 'defaultArchiveContent', rel)),
                 sha256=sha(os.path.join(ROOT, 'defaultArchiveContent', rel)))
            for rel in ('hello world.txt', 'folder/README.md', 'folder/NestedArchive.zip')]

SKIP_DIRS = ('scripts/', 'docs/', 'defaultArchiveContent/', '.git/')
SKIP_EXT = ('.md', '.sh', '.py', '.txt.md')

def fixtures():
    out = subprocess.run(['git', '-c', 'core.quotePath=false', 'ls-files', '--cached', '--others', '--exclude-standard'], cwd=ROOT, capture_output=True, text=True).stdout.splitlines()
    res = []
    for p in sorted(set(out)):
        if p.startswith(SKIP_DIRS) or p.endswith(SKIP_EXT) or p in ('.gitignore', 'manifest.json') or '/' not in p:
            continue
        if p.endswith('.pem') or p.endswith('.pub.hex'):
            continue
        res.append(p)
    return res

def load_logs():
    runs = {}
    for j in sorted(glob.glob(os.path.join(ROOT, 'docs/verification/*/*.jsonl'))):
        date = os.path.basename(os.path.dirname(j)); src = os.path.relpath(j, ROOT)
        for line in open(j):
            try:
                r = json.loads(line)
            except Exception:
                continue
            p = r['fixture'][2:] if r['fixture'].startswith('./') else r['fixture']
            runs.setdefault(p, []).append((src, r))
    special = {}
    for t in sorted(glob.glob(os.path.join(ROOT, 'docs/verification/*/*.txt'))):
        src = os.path.relpath(t, ROOT); cur = None
        for line in open(t, errors='replace'):
            m = re.match(r'^== (\S.*)$', line.rstrip())
            if m:
                cur = m.group(1).strip(); special.setdefault(cur, []).append([src]); continue
            if cur and line.strip():
                special[cur][-1].append(line.rstrip())
    # a fixture regenerated later is described only by the newest verification directory that mentions it
    d = lambda src: src.split('/')[2]
    newest = {}
    for store in (runs, special):
        for p, items in store.items():
            newest[p] = max([newest.get(p, '')] + [d(i[0]) for i in items])
    for store in (runs, special):
        for p in list(store):
            store[p] = [i for i in store[p] if d(i[0]) == newest[p]]
    return runs, special

def classify(files):
    """files: {path: sha16} from a reader -> (label, entries)"""
    entries, labels = [], set()
    for p, h in sorted(files.items()):
        k = KNOWN.get(h)
        entries.append(dict(path=p, sha256_prefix=h, note=(k[1] if k else 'not part of defaultArchiveContent')))
        if k:
            labels.add('current' if k[1] == 'current' else k[1])
    return entries, labels

def main():
    runs, special = load_logs()
    fx = fixtures()
    fmt_of = {}
    for f in FORMATS:
        for g in f.get('fixtures', []):
            for p in fx:
                if fnmatch.fnmatch(p, g):
                    fmt_of.setdefault(p, [])
                    if f['id'] not in fmt_of[p]:
                        fmt_of[p].append(f['id'])
    manifest = []
    for p in fx:
        e = dict(path=p, formats=fmt_of.get(p, []), role='baseline' if p.startswith('defaultArchives/') else 'variant',
                 size=os.path.getsize(os.path.join(ROOT, p)), sha256=sha(os.path.join(ROOT, p)))
        if any(fnmatch.fnmatch(p, g) for g in SPECIAL_PURPOSE):
            e['role'] = 'special-purpose'
        if re.search(r'\.7z\.00[2-9]$|[2-9]\.swm$|\.z0[1-9]$|\.zip\.00[2-9]$|\.r\d\d$|\.part[2-9]\.rar$|spanned[2-9]\.cab$', p) or '.sparsebundle/' in p:
            e['role'] = 'part'
        ev, status, content = [], 'not-checked', None
        for src, r in runs.get(p, []):
            ok = [k for k, v in r['readers'].items() if v['result'] in ('exact', 'content', 'superset')]
            desc = []
            if r.get('7z_type'): desc.append('7z Type=%s%s' % (r['7z_type'], (' Methods=' + ','.join(m for m in r['7z_methods'] if m)) if r.get('7z_methods') else ''))
            if r.get('lsar_format'): desc.append('lsar format=%s' % r['lsar_format'])
            desc.append('file: ' + r['file'][:90])
            ev.append('%s: magic %s; %s; readers matching standard content: %s' % (src, r['magic'][:16], '; '.join(desc), ', '.join(ok) or 'none'))
            if ok:
                status = 'verified'; content = content or 'standard'
            else:
                for k in ('bsdtar', 'unar', '7z'):
                    v = r['readers'][k]
                    if isinstance(v['files'], dict) and v['files']:
                        entries, labels = classify(v['files'])
                        if labels and v['result'] in ('partial', 'fail'):
                            content = entries; status = 'verified-other-content' if labels != {'current'} else status
                            break
        for blk in special.get(p, []):
            lines = blk[1:]
            ev.append('%s: %s' % (blk[0], ' | '.join(l.strip() for l in lines)[:400]))
            if any('content: MATCH' in l or 'Images are identical' in l or ('==' in l and 'simg2img' in l) for l in lines):
                status = 'verified'; content = content if isinstance(content, list) else 'standard'
            hl = dict((m.group(2), m.group(1)) for m in (re.match(r'^\s*([0-9a-f]{16})[0-9a-f]*\s+\./(.+)$', l) for l in lines) if m)
            if hl and classify(hl)[1]:
                entries, labels = classify(hl)
                content = entries; status = 'verified' if labels == {'current'} else 'verified-other-content'
            if any('UNVERIFIED' in l for l in lines):
                status = 'unverified'
            elif any('CREATOR-ONLY' in l for l in lines) and status == 'verified' and not any(
                    v['result'] in ('exact', 'content', 'superset') for _, r in runs.get(p, []) for v in r['readers'].values()):
                status = 'verified-creator-only'
            elif status == 'not-checked' and any(re.search(r'data: 68656c6c|sha256: |TOC TYPE|WARC-Target-URI|Overall SHA1 verification successful|simg2img ==|byte-identical', l) for l in lines):
                status = 'verified'
        cx = next((v for g, v in CUSTOM_EXPECTED.items() if fnmatch.fnmatch(p, g)), None)
        if cx:
            e['expected'] = cx
        elif content == 'standard':
            e['expected'] = 'standard'
        elif isinstance(content, list):
            e['expected'] = content
        e['verification'] = dict(status=status, evidence=ev)
        manifest.append(e)
    by_sha = {}
    for m in manifest:
        if m['verification']['status'] != 'not-checked':
            by_sha.setdefault(m['sha256'], m)
    for m in manifest:
        if m['verification']['status'] == 'not-checked':
            o = by_sha.get(m['sha256'])
            if o and o is not m:
                m['verification'] = dict(status=o['verification']['status'], evidence=['byte-identical to %s (same sha256)' % o['path']])
                m.setdefault('expected', o.get('expected'))
            elif m['role'] == 'part':
                m['verification'] = dict(status='part', evidence=['part of a multi-file fixture; verified through its first part'])
    json.dump(dict(
        schema=1,
        password='password (see password/README.md; AEA uses passwordpasswordpassword, docs/formats/aea.md)',
        standard_content=STANDARD,
        statuses={'verified': 'an independent reader or the format tool extracted content that matches `expected` (sha256)',
                  'verified-other-content': 'opens and extracts, but holds an older version of the standard content (see docs/existing-fixtures-audit.md); `expected` lists what it holds',
                  'part': 'a later volume or a member file of a bundle; checked through the first part',
                  'verified-creator-only': 'content matches, but only the tool that wrote it could read it back (no independent reader available)',
                  'unverified': 'made by the stated tool, but no reader could confirm its content (see evidence)',
                  'not-checked': 'not checked by this work (special-purpose fixture with its own README, or no reader available); see docs/formats'},
        fixtures=manifest), open(os.path.join(ROOT, 'manifest.json'), 'w'), indent=1, ensure_ascii=False)

    # coverage.md
    by_id = {f['id']: f for f in FORMATS}
    os.makedirs(os.path.join(ROOT, 'docs/formats'), exist_ok=True)
    rows = []
    for f in FORMATS:
        fx_f = [m for m in manifest if f['id'] in m['formats']]
        base = [m['path'] for m in fx_f if m['role'] == 'baseline']
        ver = sum(1 for m in fx_f if m['verification']['status'].startswith('verified'))
        link = '[%s](formats/%s.md)' % (f['name'], f['id']) if (fx_f or f.get('blocked') or f.get('covered')) else f['name']
        rows.append('| %s | %s | %s | %s | %s | %d/%d | %s |' % (f['status'], link, '1.2' if f['v12'] else '', f.get('ext', ''),
                    ', '.join('`%s`' % b.split('/', 1)[1] for b in base[:4]) + (' …' if len(base) > 4 else ''), ver, len(fx_f),
                    (f.get('outstanding') or f.get('blocked') or '').replace('|', '/')[:140]))
        if fx_f or f.get('blocked') or f.get('covered'):
            md = ['# %s' % f['name'], '', '_Generated by scripts/build_docs.py from scripts/formats.py and docs/verification/. Edit those, not this file._', '',
                  '| | |', '|---|---|', '| Task status | **%s** (fixture work only; not a statement about MacPacker) |' % f['status'],
                  '| MacPacker 1.2 | %s |' % ('yes' if f['v12'] else 'no'), '| Extensions | %s |' % f.get('ext', ''),
                  '| MIME type (reference, unverified) | %s |' % f.get('mime', '?'), '| UTI (reference, unverified) | %s |' % f.get('uti', '?'),
                  '| Magic (seen in fixtures) | %s |' % f.get('magic', '?'), '| Used with tar | %s |' % f.get('tar', '?'),
                  '| Variants covered | %s |' % f.get('covered', '-'), '| Outstanding | %s |' % f.get('outstanding', '-')]
            if f.get('blocked'):
                md.append('| BLOCKED | %s |' % f['blocked'])
            if f.get('notes'):
                md += ['', '## Notes', '', f['notes']]
            md += ['', '## Fixtures', '', '| Path | Role | Size | Status | Expected |', '|---|---|---|---|---|']
            for m in fx_f:
                exp = m.get('expected')
                exp = 'standard content' if exp == 'standard' else ('; '.join('%s (%s)' % (x['path'], x['note']) for x in exp) if isinstance(exp, list) else (exp or '-'))
                md.append('| `%s` | %s | %d | %s | %s |' % (m['path'], m['role'], m['size'], m['verification']['status'], exp.replace('|', '/')))
            md += ['', '## Verification evidence', '']
            for m in fx_f:
                if m['verification']['evidence']:
                    md.append('- `%s`' % m['path'])
                    md += ['  - %s' % x.replace('|', '/') for x in m['verification']['evidence']]
            md += ['', 'Creation scripts: see docs/README.md (scripts/ubuntu_v12.sh, scripts/ubuntu_next.sh, scripts/macos_fixtures.sh, or the format directory\'s own make_*.sh).', '']
            open(os.path.join(ROOT, 'docs/formats/%s.md' % f['id']), 'w').write('\n'.join(md))
    hdr = ['# Fixture coverage', '', '_Generated by scripts/build_docs.py. Status tracks fixture work only, not MacPacker support._', '',
           'DONE = baseline (or substitute) exists and verified · PARTIAL = listed variants or baseline outstanding · BLOCKED = cannot be made now · TODO = not started · SKIP/WONTDO as in the Confluence overview.', '',
           '| Status | Format | 1.2 | Extensions | Baseline in defaultArchives/ | Verified fixtures | Outstanding / blocked |', '|---|---|---|---|---|---|---|']
    open(os.path.join(ROOT, 'docs/coverage.md'), 'w').write('\n'.join(hdr + rows) + '\n')
    print('fixtures:', len(manifest), 'verified:', sum(m['verification']['status'] == 'verified' for m in manifest),
          'other-content:', sum(m['verification']['status'] == 'verified-other-content' for m in manifest),
          'not-checked:', sum(m['verification']['status'] == 'not-checked' for m in manifest))
    nc = [m['path'] for m in manifest if m['verification']['status'] == 'not-checked' and m['role'] != 'special-purpose']
    print('not-checked (non special):', nc)
    print('no format:', [m['path'] for m in manifest if not m['formats']][:50])

main()
