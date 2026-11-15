#!/usr/bin/env python3
"""Cross-check fixtures with independent readers and compare against defaultArchiveContent.

Runs on Ubuntu 24.04 (Bob HQ "ubuntu" VM) with: 7zip (7z 23.01), unar/lsar (The Unarchiver 1.10),
libarchive-tools (bsdtar 3.7), file 5.45. Run with `python3 -I`.

usage: verify.py <expected content dir> <fixture>... [--password P]
Prints one JSON object per fixture: magic, `file` output, and for every reader whether it opened the
fixture, the regular files it produced (path, size, sha256), and how they compare with the expected
content ("exact" = same paths and hashes, "content" = same hashes under other paths, "partial", "fail").
"""
import hashlib, json, os, subprocess, sys, tempfile

def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 16), b''):
            h.update(b)
    return h.hexdigest()

def tree(root):
    out = {}
    for d, _, fs in os.walk(root):
        for n in fs:
            p = os.path.join(d, n)
            if os.path.islink(p) or not os.path.isfile(p):
                continue
            out[os.path.relpath(p, root)] = (os.path.getsize(p), sha(p))
    return out

def compare(exp, got):
    if not got:
        return 'fail'
    if {k: v[1] for k, v in got.items()} == {k: v[1] for k, v in exp.items()}:
        return 'exact'
    eh = sorted(v[1] for v in exp.values())
    gh = sorted(v[1] for v in got.values())
    if eh == gh:
        return 'content'
    if set(eh) <= set(gh):
        return 'superset'
    if set(eh) & set(gh):
        return 'partial'
    return 'fail'

def run(cmd, cwd=None, timeout=300):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).decode('utf-8', 'replace')
    except Exception as e:  # noqa
        return -1, str(e)

READERS = {
    '7z': lambda f, d, pw: ['7z', 'x', '-y', '-bd', '-p' + (pw or ''), '-o' + d, f],
    'unar': lambda f, d, pw: ['unar', '-q', '-f', '-D', '-o', d] + (['-p', pw] if pw else []) + [f],
    'bsdtar': lambda f, d, pw: ['bsdtar', '-x', '-f', f, '-C', d] + (['--passphrase', pw] if pw else []),
}

def main():
    args = sys.argv[1:]
    pw = None
    if '--password' in args:
        i = args.index('--password'); pw = args[i + 1]; del args[i:i + 2]
    exp = tree(args[0])
    for f in args[1:]:
        res = {'fixture': f, 'size': os.path.getsize(f), 'sha256': sha(f)}
        with open(f, 'rb') as fh:
            res['magic'] = fh.read(16).hex()
        res['file'] = run(['file', '-b', f])[1].strip()
        rc, o = run(['7z', 'l', '-slt', '-p' + (pw or ''), f])
        res['7z_type'] = next((l.split('=', 1)[1].strip() for l in o.splitlines() if l.startswith('Type =')), None)
        res['7z_methods'] = sorted({l.split('=', 1)[1].strip() for l in o.splitlines() if l.startswith('Method =')})
        res['7z_solid'] = next((l.split('=', 1)[1].strip() for l in o.splitlines() if l.startswith('Solid =')), None)
        rc, o = run(['lsar', '-j', f] + (['-p', pw] if pw else []))
        try:
            j = json.loads(o)
            res['lsar_format'] = j.get('lsarFormatName')
        except Exception:
            res['lsar_format'] = None
        res['readers'] = {}
        for name, mk in READERS.items():
            with tempfile.TemporaryDirectory() as d:
                rc, o = run(mk(os.path.abspath(f), d, pw))
                got = tree(d)
                res['readers'][name] = {
                    'rc': rc, 'result': compare(exp, got),
                    'files': {k: v[1][:16] for k, v in sorted(got.items())} if compare(exp, got) not in ('exact',) else 'as expected',
                }
        print(json.dumps(res))

main()
