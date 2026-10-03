#!/usr/bin/env python3
"""Create original DAR test data with the official dar CLI; verify restored bytes."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

DAR = os.environ.get("DAR", "dar")
HERE = Path(__file__).resolve().parent
PASSWORD = "macpacker-dar-test"


def run(*args, expect_success=True):
    result = subprocess.run([DAR, "-Q", *args], capture_output=True, text=True, timeout=30)
    if expect_success and result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result


def digest(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(root.rglob("*")) if p.is_file()}


def main():
    with tempfile.TemporaryDirectory(prefix="macpacker-dar-") as temporary:
        root = Path(temporary)
        source = root / "input"
        (source / "nested" / "empty").mkdir(parents=True)
        (source / "hello.txt").write_bytes(b"Original MacPacker DAR fixture.\n")
        (source / "nested" / "café.txt").write_text("DAR Unicode filename test.\n", encoding="utf-8")
        # Deterministic original data large enough to span multiple small slices.
        (source / "payload.bin").write_bytes(b"".join(
            hashlib.sha256(str(i).encode()).digest() for i in range(256)))
        (source / "nested" / "repeated.txt").write_bytes(b"Compressible original DAR test content.\n" * 512)
        expected = digest(source)
        variants = {
            "plain": [],
            "gzip": ["-z"],
            "encrypted": ["-K", "aes:" + PASSWORD],
            "split": ["-s", "8k"],
            "split-padded": ["-s", "8k", "-9", "3"],
        }
        for name, options in variants.items():
            base = root / name
            run("-c", str(base), "-R", str(source), *options)
            key = ["-K", "aes:" + PASSWORD] if name == "encrypted" else []
            run("-t", str(base), *key)
            output = root / (name + "-restored")
            output.mkdir()
            run("-x", str(base), "-R", str(output), *key)
            assert digest(output) == expected, name
            assert (output / "nested" / "empty").is_dir(), name
            if name == "encrypted":
                assert run("-t", str(base), "-K", "aes:wrong", expect_success=False).returncode != 0
            for archive in root.glob(name + ".*.dar"):
                shutil.copyfile(archive, HERE / archive.name)
        assert (root / "gzip.1.dar").stat().st_size < (root / "plain.1.dar").stat().st_size
        missing = root / "missing"
        missing.mkdir()
        for archive in root.glob("split.*.dar"):
            if archive.name != "split.2.dar":
                shutil.copyfile(archive, missing / archive.name)
        assert run("-t", str(missing / "split"), expect_success=False).returncode != 0
        (HERE / "expected-files.json").write_text(json.dumps(expected, ensure_ascii=False, indent=2) + "\n")
        print("Five DAR variants passed integrity checks and byte-for-byte extraction; wrong password and missing middle slice rejected.")


if __name__ == "__main__":
    main()
