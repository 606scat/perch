#!/usr/bin/env python3
"""Real installer integration checks, with isolated app/data destinations only."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SOURCE_INFO = plistlib.loads((ROOT / "Resources/Info.plist").read_bytes())
BASE_BUILD = int(SOURCE_INFO["CFBundleVersion"])
RELEASE = ROOT / "dist" / ("v" + SOURCE_INFO["CFBundleShortVersionString"])

def command(*args, expect=0):
    result = subprocess.run([str(a) for a in args], text=True, capture_output=True)
    if result.returncode != expect:
        raise AssertionError(f"{args}: exit {result.returncode}\n{result.stdout}\n{result.stderr}")
    return result.stdout + result.stderr

def package(folder, build):
    folder.mkdir()
    app = folder / "Perch.app"
    command("/usr/bin/ditto", ROOT / "build/distribution/Perch.app", app)
    info = app / "Contents/Info.plist"
    data = plistlib.loads(info.read_bytes())
    data["CFBundleVersion"] = str(build)
    data["CFBundleShortVersionString"] = f"0.1.{build - 1}"
    info.write_bytes(plistlib.dumps(data))
    command("/usr/bin/codesign", "--force", "--sign", "-", app)
    archive = folder / "Perch-macOS-universal.zip"
    command("/usr/bin/ditto", "-c", "-k", "--keepParent", app, archive)
    (folder / "SHA256SUMS").write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + "  " + archive.name + "\n")
    return folder

with tempfile.TemporaryDirectory(prefix="perch-update-test.with space 日本語.") as temp:
    home = Path(temp)
    data_dir = home / "Library/Application Support/Perch"
    data_dir.mkdir(parents=True)
    saved = data_dir / "data.json"
    original = json.dumps({"version": 1, "notes": ["Existing note 日本語"], "snippets": ["Saved reply"], "preferences": {"theme": "light", "accent": "green"}}).encode()
    saved.write_bytes(original)
    (data_dir / "future-attachment.txt").write_text("Preserve all local files")
    install = ["/bin/bash", ROOT / "scripts/install.sh", "--no-open", "--test-root", home, "--local-dir"]
    app = home / "Applications/Perch.app"
    backups = home / "Library/Application Support/Perch Backups"

    command(*install, RELEASE)
    assert app.exists() and saved.read_bytes() == original
    assert len(list(backups.iterdir())) == 1
    print("PASS: first install retains existing data")

    output = command(*install, RELEASE)
    assert "already installed" in output and len(list(backups.iterdir())) == 1
    print("PASS: repeated same-version install is a no-op")

    earlier_backups = set(backups.iterdir())
    upgrade = package(home / "upgrade", BASE_BUILD + 1)
    command(*install, upgrade)
    assert saved.read_bytes() == original
    latest = (set(backups.iterdir()) - earlier_backups).pop()
    assert (latest / "Data/data.json").read_bytes() == original
    assert (latest / "Data/future-attachment.txt").read_text() == "Preserve all local files"
    assert (latest / "Perch.app").exists()
    assert plistlib.loads((app / "Contents/Info.plist").read_bytes())["CFBundleVersion"] == str(BASE_BUILD + 1)
    print("PASS: upgrade preserves data byte-for-byte and backs up data plus previous app")

    output = command(*install, RELEASE, expect=1)
    assert "Refusing downgrade" in output and saved.read_bytes() == original
    print("PASS: older builds cannot replace a newer installation")

    corrupt = home / "corrupt"
    corrupt.mkdir()
    shutil.copy(upgrade / "SHA256SUMS", corrupt)
    (corrupt / "Perch-macOS-universal.zip").write_bytes(b"interrupted download")
    output = command(*install, corrupt, expect=1)
    assert "checksum failed" in output and saved.read_bytes() == original
    print("PASS: damaged download leaves app and data untouched")

    update3 = package(home / "upgrade3", BASE_BUILD + 2)
    lock = data_dir / ".update-lock"
    lock.mkdir(); (lock / "pid").write_text(str(os.getpid()))
    output = command(*install, update3, expect=1)
    assert "update lock exists" in output and saved.read_bytes() == original
    shutil.rmtree(lock)
    print("PASS: concurrent installer is rejected without modifying data")

    output = command(*install, home / "missing-download", expect=1)
    assert saved.read_bytes() == original
    assert plistlib.loads((app / "Contents/Info.plist").read_bytes())["CFBundleVersion"] == str(BASE_BUILD + 1)
    print("PASS: unavailable download does not disturb the installed app")

    fresh = home / "perch-update-test.fresh"
    fresh.mkdir()
    command("/bin/bash", ROOT / "scripts/install.sh", "--no-open", "--test-root", fresh, "--local-dir", RELEASE)
    assert (fresh / "Applications/Perch.app").exists()
    assert not (fresh / "Library/Application Support/Perch/data.json").exists()
    print("PASS: fresh Mac install creates no sample or owner data")

print("8 installer scenarios passed. All test files were isolated and removed.")
