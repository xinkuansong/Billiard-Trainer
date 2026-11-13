#!/usr/bin/env python3
"""Protect or explicitly restore the observed r9 native App Data; never launch it.

Default: metadata-only dry plan (no tree hashing, copying or defaults export).
--execute-backup: only as a direct child of local_test_lifecycle with a hold.
--verify-backup: read-only verification of an existing held private backup;
                 does not read or compare the current App data.
--execute-restore: separate held lifecycle run, explicit --backup-work and
                   --expected-backup-manifest-sha; preserves research Data first.
--self-test: synthetic CPU fixtures only; never accesses the App container.

Example, AFTER the App is normally stopped and the dry-plan identity reviewed:
  python3 scripts/local_test_lifecycle.py run --task cloth-native-state-protection \
    --hold 'Only rollback copy; retain until independently verified restoration' -- \
    python3 scripts/research/cloth_lowdim_20261113/protect_native_state.py \
    --execute-backup --app-pid 2918 --expected-source-device DEVICE \
    --expected-source-inode INODE --work '{work}' --evidence '{evidence}'

The private envelope/work are 0700; their manifest/export files are 0600.
The copied Data tree retains its original modes, xattrs and links for rollback.
No backup content or preference keys/values are printed or put in evidence.
Restore never changes Keychain or a different domain/container. Do not release
either lifecycle hold until independent restoration review. cp -c requests APFS cloning;
cp may fall back to copying, so per-file physical clone sharing is not claimed.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import stat
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
SCRIPT = Path(__file__).resolve()
sys.path.insert(0, str(ROOT / "scripts"))
import local_test_lifecycle as lifecycle

SOURCE = Path("/Users/song/Library/Containers/B481DDB3-A63E-4377-94CE-9903386E626C/Data")
PREF_REL = "Library/Preferences/com.xinkuan.qiuji.plist"
PRIVATE_NAME = "native-state-private"
MAX_PLIST = 256 * 1024 * 1024
SAFE_ENV_KEYS = {"PATH", "HOME", "USER", "LOGNAME", "TMPDIR", "LANG"}


class ProtectionError(RuntimeError):
    """Messages are fixed codes, never exceptions containing user data."""


def need(condition, code):
    if not condition:
        raise ProtectionError(code)


def digest_bytes(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, sort_keys=True, ensure_ascii=True,
                       separators=(",", ":"), allow_nan=False) + "\n").encode()


def digest_json(value):
    return digest_bytes(json_bytes(value))


def safe_env():
    return {k: v for k, v in os.environ.items()
            if k in SAFE_ENV_KEYS or k.startswith("LC_")}


def exact_path(path):
    p = Path(os.path.abspath(path))
    need(p.resolve() == p, "symlinked-path")
    return p


def identity(path):
    s = path.lstat()
    need(stat.S_ISDIR(s.st_mode), "expected-directory")
    return [s.st_dev, s.st_ino]


def source_identity(path, expected=None):
    p = exact_path(path)
    need(p == SOURCE, "source-outside-reviewed-container")
    observed = identity(p)
    need(p.stat().st_uid == os.getuid(), "source-owner-mismatch")
    if expected is not None:
        need(observed == list(expected), "source-identity-mismatch")
    return observed


def pid_absent(pid, kill=os.kill):
    need(isinstance(pid, int) and pid > 1, "invalid-app-pid")
    try:
        kill(pid, 0)
    except ProcessLookupError:
        return
    except PermissionError:
        raise ProtectionError("app-pid-exists-but-not-inspectable") from None
    raise ProtectionError("app-pid-still-alive")


def no_open_handles(source, runner=subprocess.run):
    # +D visits only this exact tree; -x L / -x f are intentionally absent.
    result = runner(["/usr/sbin/lsof", "-nP", "+D", str(source), "-Fpn"],
                    capture_output=True, timeout=60, env=safe_env())
    need(not result.stderr.strip(), "open-handles-inspection-warning")
    need(result.returncode in (0, 1), "open-handles-inspection-failed")
    need(result.returncode == 1 and not result.stdout.strip(), "source-has-open-handles")


def stopped_source(source, expected, pid):
    source_identity(source, expected)
    pid_absent(pid)
    no_open_handles(source)
    source_identity(source, expected)
    pid_absent(pid)


def managed_work(work, evidence=None, executing=False):
    need(work is not None, "managed-work-required")
    work = exact_path(work)
    run = work.parent
    need(work.name == "work" and run.parent == lifecycle.DEFAULT_ROOT,
         "outside-local-lifecycle-root")
    need(re.fullmatch(r"[0-9a-f]{32}", run.name) is not None, "invalid-run-id")
    r = lifecycle.record(run)
    need(r.get("state") in ("running", "complete", "failed"), "invalid-run-state")
    need(isinstance(r.get("hold"), str) and r["hold"].strip(), "lifecycle-hold-required")
    need(r.get("work_identity") == identity(work), "work-identity-mismatch")
    need(run.stat().st_uid == work.stat().st_uid == os.getuid(), "work-owner-mismatch")
    if evidence is not None:
        evidence = exact_path(evidence)
        need(evidence == run / "evidence" and evidence.is_dir(), "evidence-path-mismatch")
        need(evidence.stat().st_uid == os.getuid(), "evidence-owner-mismatch")
    if executing:
        need(evidence is not None, "managed-evidence-required")
        need(r.get("state") == "running" and r.get("pid") == os.getppid(),
             "must-be-live-lifecycle-direct-child")
        need(os.environ.get("QIUJI_TEST_WORK") == str(work) and
             os.environ.get("QIUJI_TEST_EVIDENCE") == str(evidence) and
             os.environ.get("QIUJI_TEST_RUN_ID") == run.name,
             "lifecycle-environment-mismatch")
    return work, evidence, r


def private_write(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        raise


class MacXattrs:
    """Read attributes from already-open objects, including O_SYMLINK fds."""
    def __init__(self):
        need(sys.platform == "darwin", "macos-required")
        self.lib = ctypes.CDLL("/usr/lib/libSystem.B.dylib", use_errno=True)
        self.lib.flistxattr.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int]
        self.lib.flistxattr.restype = ctypes.c_ssize_t
        self.lib.fgetxattr.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_void_p,
                                    ctypes.c_size_t, ctypes.c_uint32, ctypes.c_int]
        self.lib.fgetxattr.restype = ctypes.c_ssize_t

    def hashes(self, fd):
        size = self.lib.flistxattr(fd, None, 0, 0)
        need(size >= 0, "cannot-list-xattrs")
        names = ctypes.create_string_buffer(size)
        copied = self.lib.flistxattr(fd, names, size, 0)
        need(copied == size, "xattrs-changed-during-list")
        result = {}
        for name in sorted(x for x in names.raw[:copied].split(b"\0") if x):
            n = self.lib.fgetxattr(fd, name, None, 0, 0, 0)
            need(n >= 0, "cannot-size-xattr")
            buf = ctypes.create_string_buffer(n)
            got = self.lib.fgetxattr(fd, name, buf, n, 0, 0)
            need(got == n, "xattr-changed-during-read")
            result[name.hex()] = {"size": n, "sha256": digest_bytes(buf.raw[:got])}
        return result


def stat_stamp(s):
    return [s.st_dev, s.st_ino, s.st_mode, s.st_uid, s.st_gid, s.st_size,
            s.st_mtime_ns, s.st_ctime_ns, getattr(s, "st_flags", 0)]


def tree_snapshot(root, xattrs=None):
    """Never traverse symlinks/mounts; hashes are private metadata, not payload."""
    root = exact_path(root)
    xattrs = xattrs or MacXattrs()
    root_fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    rows, stamps = {}, {}
    device = os.fstat(root_fd).st_dev

    def visit(fd, relative, before):
        need(before.st_dev == device, "mounted-source-entry")
        kind = ("directory" if stat.S_ISDIR(before.st_mode) else
                "file" if stat.S_ISREG(before.st_mode) else
                "symlink" if stat.S_ISLNK(before.st_mode) else "special")
        need(kind != "special", "unsupported-special-file")
        row = {"type": kind, "mode": stat.S_IMODE(before.st_mode), "uid": before.st_uid,
               "gid": before.st_gid, "flags": getattr(before, "st_flags", 0),
               "xattrs": xattrs.hashes(fd)}
        if kind == "file":
            h = hashlib.sha256()
            while True:
                data = os.read(fd, 1024 * 1024)
                if not data:
                    break
                h.update(data)
            row.update(bytes=before.st_size, sha256=h.hexdigest())
        elif kind == "directory":
            with os.scandir(fd) as stream:
                names = sorted(entry.name for entry in stream)
            for name in names:
                s = os.stat(name, dir_fd=fd, follow_symlinks=False)
                rel = name if relative == "." else relative + "/" + name
                if stat.S_ISLNK(s.st_mode):
                    flags = os.O_RDONLY | os.O_SYMLINK
                elif stat.S_ISDIR(s.st_mode):
                    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
                else:
                    need(stat.S_ISREG(s.st_mode), "unsupported-special-file")
                    flags = os.O_RDONLY | os.O_NOFOLLOW
                child = os.open(name, flags, dir_fd=fd)
                try:
                    need(stat_stamp(os.fstat(child)) == stat_stamp(s), "entry-changed-before-open")
                    visit(child, rel, s)
                    if stat.S_ISLNK(s.st_mode):
                        rows[rel]["target"] = os.readlink(name, dir_fd=fd)
                    need(stat_stamp(os.stat(name, dir_fd=fd, follow_symlinks=False)) == stat_stamp(s),
                         "entry-replaced-during-snapshot")
                finally:
                    os.close(child)
            with os.scandir(fd) as stream:
                need(sorted(entry.name for entry in stream) == names, "directory-changed-during-snapshot")
        need(stat_stamp(os.fstat(fd)) == stat_stamp(before), "entry-changed-during-read")
        rows[relative] = row
        stamps[relative] = stat_stamp(before)

    try:
        visit(root_fd, ".", os.fstat(root_fd))
    finally:
        os.close(root_fd)
    return {"entries": rows, "sourceStamps": stamps}


def canonical_plist(data):
    need(len(data) <= MAX_PLIST, "preferences-too-large")
    try:
        value = plistlib.loads(data)
        need(isinstance(value, dict), "preferences-not-a-dictionary")
        encoded = plistlib.dumps(value, fmt=plistlib.FMT_BINARY, sort_keys=True)
        return {"sha256": digest_bytes(encoded), "keyCount": len(value)}
    except ProtectionError:
        raise
    except Exception:
        raise ProtectionError("preferences-cannot-be-decoded") from None


def read_regular(path, limit=None):
    p = exact_path(path)
    fd = os.open(p, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        s = os.fstat(fd)
        need(stat.S_ISREG(s.st_mode), "expected-regular-file")
        need(limit is None or s.st_size <= limit, "file-exceeds-read-limit")
        with os.fdopen(os.dup(fd), "rb") as stream:
            data = stream.read()
        need(stat_stamp(os.fstat(fd)) == stat_stamp(s), "file-changed-during-read")
        return data
    finally:
        os.close(fd)


def run_private(command, private, log_name, timeout):
    with (private / log_name).open("xb") as log:
        os.chmod(private / log_name, 0o600)
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                timeout=timeout, env=safe_env())
    need(result.returncode == 0, "private-command-failed:" + log_name)


def count_entries(rows):
    return {kind: sum(row["type"] == kind for row in rows.values())
            for kind in ("file", "directory", "symlink")}


def new_private(work, name):
    private = work / name
    need(not private.exists() and not private.is_symlink(), "private-destination-already-exists")
    os.chmod(work, 0o700)
    subprocess.run(["/bin/chmod", "-N", str(work)], check=True, capture_output=True)
    private.mkdir(mode=0o700)
    subprocess.run(["/bin/chmod", "-N", str(private)], check=True, capture_output=True)
    return private


def backup(args):
    work, evidence, run = managed_work(args.work, args.evidence, executing=True)
    need(args.expected_source_device is not None and args.expected_source_inode is not None,
         "reviewed-source-identity-required")
    expected = [args.expected_source_device, args.expected_source_inode]
    stopped_source(SOURCE, expected, args.app_pid)
    need(work.stat().st_dev == SOURCE.stat().st_dev, "backup-must-share-source-volume")
    private = new_private(work, PRIVATE_NAME)
    report = {"schema": 1, "status": "failed", "readyForFixture": False,
              "restoreRequiresSeparateExplicitInvocation": True, "sourceIdentity": expected,
              "privateBackup": str(private), "lifecycleRun": run["id"],
              "cloneRequested": True, "perFileCloneSharingProven": False}
    try:
        before = tree_snapshot(SOURCE)
        private_write(private / "source-before.json", json_bytes(before))
        stopped_source(SOURCE, expected, args.app_pid)
        run_private(["/bin/cp", "-c", "-p", "-R", "-P", "-x", str(SOURCE), str(private / "Data")],
                    private, "copy.log", 600)
        copied = tree_snapshot(private / "Data")
        need(before["entries"] == copied["entries"], "backup-tree-mismatch")
        private_write(private / "backup-tree.json", json_bytes(copied))
        stopped_source(SOURCE, expected, args.app_pid)
        pref = read_regular(SOURCE / PREF_REL, MAX_PLIST)
        need(digest_bytes(pref) == before["entries"][PREF_REL]["sha256"], "preferences-changed-before-export")
        exported = private / "defaults-export.plist"
        run_private(["/usr/bin/defaults", "export", str((SOURCE / PREF_REL).with_suffix("")), str(exported)],
                    private, "defaults-export.log", 30)
        need(exported.exists(), "defaults-export-missing")
        os.chmod(exported, 0o600)
        export_bytes = read_regular(exported, MAX_PLIST)
        pref_summary = canonical_plist(pref)
        need(pref_summary == canonical_plist(export_bytes), "physical-exported-preferences-mismatch")
        need(pref_summary == canonical_plist(read_regular(private / "Data" / PREF_REL, MAX_PLIST)),
             "backup-preferences-mismatch")
        stopped_source(SOURCE, expected, args.app_pid)
        after = tree_snapshot(SOURCE)
        need(before == after, "source-changed-during-backup")
        stopped_source(SOURCE, expected, args.app_pid)
        managed_work(work, evidence, executing=True)
        manifest = {"schema": 1, "status": "verified", "sourceIdentity": expected,
                    "sourcePath": str(SOURCE), "appPIDRequiredAbsent": args.app_pid,
                    "treeSHA256": digest_json(before["entries"]),
                    "sourceBeforeSHA256": digest_json(before), "counts": count_entries(before["entries"]),
                    "preferenceSummary": pref_summary, "defaultsExportSHA256": digest_bytes(export_bytes),
                    "sourceManifestSHA256": digest_bytes(read_regular(private / "source-before.json")),
                    "backupManifestSHA256": digest_bytes(read_regular(private / "backup-tree.json")),
                    "scriptSHA256": digest_bytes(SCRIPT.read_bytes()), "createdAtUnix": time.time()}
        private_write(private / "manifest.json", json_bytes(manifest))
        report.update(status="backup-verified", readyForFixture=True, counts=manifest["counts"],
                      treeSHA256=manifest["treeSHA256"], preferenceSummary=pref_summary,
                      manifestSHA256=digest_bytes(read_regular(private / "manifest.json")))
    except Exception as error:
        report["failureCode"] = str(error) if isinstance(error, ProtectionError) else type(error).__name__
        raise
    finally:
        # Public report contains hashes/counts, no file listing, prefs or raw tool logs.
        private_write(evidence / "native-state-protection.json", json_bytes(report))
        print(json.dumps(report, sort_keys=True))
    return 0


def verify_backup(work):
    work, _, run = managed_work(work)
    need(run.get("state") == "complete", "backup-run-not-complete")
    private = exact_path(work / PRIVATE_NAME)
    need(private.is_dir() and stat.S_IMODE(private.stat().st_mode) == 0o700,
         "private-envelope-mode-mismatch")
    need(stat.S_IMODE(work.stat().st_mode) == 0o700, "work-not-private")
    manifest_bytes = read_regular(private / "manifest.json")
    report_bytes = read_regular(work.parent / "evidence" / "native-state-protection.json")
    need(run.get("evidence_sha256", {}).get("native-state-protection.json") == digest_bytes(report_bytes),
         "sealed-report-changed")
    report = json.loads(report_bytes)
    need(report.get("status") == "backup-verified" and report.get("readyForFixture") is True,
         "sealed-report-not-verified")
    need(report.get("manifestSHA256") == digest_bytes(manifest_bytes), "private-manifest-changed")
    manifest = json.loads(manifest_bytes)
    need(manifest.get("schema") == 1 and manifest.get("status") == "verified", "backup-not-verified")
    need(manifest.get("sourcePath") == str(SOURCE), "backup-source-mismatch")
    expected_bytes = read_regular(private / "backup-tree.json")
    need(digest_bytes(expected_bytes) == manifest["backupManifestSHA256"], "backup-manifest-changed")
    before_bytes = read_regular(private / "source-before.json")
    need(digest_bytes(before_bytes) == manifest["sourceManifestSHA256"], "source-manifest-changed")
    expected = json.loads(expected_bytes)["entries"]
    need(json.loads(before_bytes)["entries"] == expected, "source-backup-manifest-mismatch")
    actual = tree_snapshot(private / "Data")["entries"]
    need(actual == expected and digest_json(actual) == manifest["treeSHA256"], "backup-content-changed")
    exported = read_regular(private / "defaults-export.plist", MAX_PLIST)
    need(digest_bytes(exported) == manifest["defaultsExportSHA256"], "defaults-export-changed")
    need(canonical_plist(exported) == manifest["preferenceSummary"], "defaults-summary-mismatch")
    need(canonical_plist(read_regular(private / "Data" / PREF_REL, MAX_PLIST)) == manifest["preferenceSummary"],
         "backup-preferences-changed")
    return {"status": "backup-integrity-verified", "lifecycleRun": run["id"],
            "manifestSHA256": digest_bytes(manifest_bytes), "treeSHA256": manifest["treeSHA256"],
            "counts": count_entries(actual), "preferenceSummary": manifest["preferenceSummary"],
            "currentAppDataRead": False, "restoreExecuted": False}


def preferences_export(private, filename, log_name):
    path = private / filename
    need(not path.exists(), "preferences-export-already-exists")
    domain = str((SOURCE / PREF_REL).with_suffix(""))
    run_private(["/usr/bin/defaults", "export", domain, str(path)], private, log_name, 30)
    os.chmod(path, 0o600)
    exported = canonical_plist(read_regular(path, MAX_PLIST))
    need(exported == canonical_plist(read_regular(SOURCE / PREF_REL, MAX_PLIST)),
         "physical-exported-preferences-mismatch")
    return exported


def normalized_restore_entries(entries):
    # defaults may serialize an equivalent plist differently. Every other file,
    # and this file's mode/owner/flags/xattrs, must still match the frozen tree.
    need(PREF_REL in entries and entries[PREF_REL]["type"] == "file", "preferences-entry-missing")
    rows = {name: dict(row) for name, row in entries.items()}
    rows[PREF_REL].pop("sha256", None)
    rows[PREF_REL].pop("bytes", None)
    return rows


def restore(args):
    """Explicit, separate transaction. On failure retain both trees for review."""
    work, evidence, run = managed_work(args.work, args.evidence, executing=True)
    need(args.backup_work is not None, "explicit-backup-work-required")
    backup_work = exact_path(args.backup_work)
    need(backup_work != work, "restore-requires-separate-lifecycle-run")
    need(re.fullmatch(r"[0-9a-f]{64}", args.expected_backup_manifest_sha or "") is not None,
         "explicit-backup-manifest-sha-required")
    checked = verify_backup(backup_work)
    need(checked["manifestSHA256"] == args.expected_backup_manifest_sha, "selected-backup-sha-mismatch")
    need(args.expected_source_device is not None and args.expected_source_inode is not None,
         "reviewed-source-identity-required")
    expected = [args.expected_source_device, args.expected_source_inode]
    stopped_source(SOURCE, expected, args.app_pid)
    need(work.stat().st_dev == SOURCE.stat().st_dev == backup_work.stat().st_dev,
         "restore-must-share-source-volume")
    private = new_private(work, "native-state-restore-private")
    protected = backup_work / PRIVATE_NAME
    staged = private / "prepared-Data"
    research = private / "research-Data"
    report = {"schema": 1, "status": "failed", "restoreCompleted": False,
              "readyForFixture": False, "phase": "preparing", "lifecycleRun": run["id"],
              "backupManifestSHA256": checked["manifestSHA256"], "sourceIdentityBefore": expected,
              "privateRollback": str(private), "keychainTouched": False,
              "coldLaunchVerificationPending": True}
    try:
        expected_rows = json.loads(read_regular(protected / "backup-tree.json"))["entries"]
        run_private(["/bin/cp", "-c", "-p", "-R", "-P", "-x", str(protected / "Data"), str(staged)],
                    private, "prepare-copy.log", 600)
        need(tree_snapshot(staged)["entries"] == expected_rows, "prepared-restore-tree-mismatch")
        stopped_source(SOURCE, expected, args.app_pid)
        research_before = tree_snapshot(SOURCE)
        private_write(private / "research-before.json", json_bytes(research_before))
        preferences_export(private, "research-defaults.plist", "research-defaults-export.log")
        need(tree_snapshot(SOURCE) == research_before, "research-state-changed-before-preservation")
        # Check lifecycle holds, both identities and writer absence at the switch.
        managed_work(work, evidence, executing=True)
        need(verify_backup(backup_work)["manifestSHA256"] == args.expected_backup_manifest_sha,
             "selected-backup-changed")
        stopped_source(SOURCE, expected, args.app_pid)
        os.rename(SOURCE, research)  # Preserve exact research inode/tree, never delete it.
        report["phase"] = "research-preserved"
        need(not SOURCE.exists() and not SOURCE.is_symlink(), "source-reappeared-during-restore")
        os.rename(staged, SOURCE)
        restored_identity = identity(SOURCE)
        report.update(phase="backup-installed", sourceIdentityAfter=restored_identity)
        # rename may update the directory ctime; logical contents/modes/links and
        # the original Data inode must remain exact.
        need(identity(research) == expected and tree_snapshot(research)["entries"] == research_before["entries"],
             "preserved-research-tree-mismatch")
        # Exact absolute-path domain only. No global/bundle-only delete, no daemon kill.
        stopped_source(SOURCE, restored_identity, args.app_pid)
        domain = str((SOURCE / PREF_REL).with_suffix(""))
        run_private(["/usr/bin/defaults", "import", domain, str(protected / "defaults-export.plist")],
                    private, "restore-defaults-import.log", 30)
        exported = preferences_export(private, "restored-defaults.plist", "restored-defaults-export.log")
        need(exported == checked["preferenceSummary"], "restored-preferences-not-exact")
        restored_rows = tree_snapshot(SOURCE)["entries"]
        need(normalized_restore_entries(restored_rows) == normalized_restore_entries(expected_rows),
             "restored-tree-mismatch")
        stopped_source(SOURCE, restored_identity, args.app_pid)
        managed_work(work, evidence, executing=True)
        managed_work(backup_work)
        private_write(private / "restored-tree.json", json_bytes({"entries": restored_rows}))
        report.update(status="restored-data-verified", restoreCompleted=True, phase="verified",
                      counts=count_entries(restored_rows), restoredTreeSHA256=digest_json(restored_rows),
                      researchTreeSHA256=digest_json(research_before["entries"]),
                      preferenceSummary=exported, automaticRollbackAttempted=False)
    except Exception as error:
        report["failureCode"] = str(error) if isinstance(error, ProtectionError) else type(error).__name__
        # Never guess which live tree to remove after an interrupted/partial switch.
        # The phase and preserved research tree let the controller recover explicitly.
        raise
    finally:
        private_write(evidence / "native-state-restoration.json", json_bytes(report))
        print(json.dumps(report, sort_keys=True))
    return 0


def dry_plan(args):
    blockers = []
    observed = None
    try:
        observed = source_identity(SOURCE)
        pid_absent(args.app_pid)
    except Exception as error:
        blockers.append(str(error) if isinstance(error, ProtectionError) else type(error).__name__)
    if args.work:
        try:
            managed_work(args.work, args.evidence)
        except Exception as error:
            blockers.append(str(error) if isinstance(error, ProtectionError) else type(error).__name__)
    else:
        blockers.append("execute-requires-new-held-local-lifecycle-work")
    return {"mode": "dry-plan", "source": str(SOURCE), "observedSourceIdentity": observed,
            "appPIDMustBeAbsent": args.app_pid, "blockers": blockers,
            "backupExecuted": False, "defaultsExported": False, "sourceTreeRead": False,
            "readyForFixture": False, "restoreExecuted": False,
            "requestedBackupWork": str(args.backup_work) if args.backup_work else None,
            "next": "Review device/inode, then use lifecycle run --hold and --execute-backup after App exit"}


def self_test():
    """Pure validation plus synthetic tmp trees; never invokes defaults or cp."""
    cases = []

    def rejects(name, fn, code):
        try:
            fn()
        except ProtectionError as error:
            need(str(error) == code, "self-test-wrong-rejection:" + name)
            cases.append(name)
        else:
            raise ProtectionError("self-test-accepted:" + name)

    rejects("live PID", lambda: pid_absent(42, lambda *_: None), "app-pid-still-alive")
    def denied(*_):
        raise PermissionError
    rejects("inaccessible PID", lambda: pid_absent(42, denied), "app-pid-exists-but-not-inspectable")
    rejects("invalid PID", lambda: pid_absent(1), "invalid-app-pid")
    def gone(*_):
        raise ProcessLookupError
    pid_absent(42, gone)
    class Fake:
        def __init__(self, code, out=b"", err=b""):
            self.returncode, self.stdout, self.stderr = code, out, err
    for name, response, code in [
        ("open handle", Fake(0, b"p42\nn/protected/default.store\n"), "source-has-open-handles"),
        ("lsof warning", Fake(1, b"", b"denied"), "open-handles-inspection-warning"),
        ("lsof failure", Fake(2), "open-handles-inspection-failed"),
        ("ambiguous empty success", Fake(0), "source-has-open-handles")]:
        rejects(name, lambda r=response: no_open_handles(Path("/synthetic"), lambda *a, **k: r), code)
    no_open_handles(Path("/synthetic"), lambda *a, **k: Fake(1))
    rejects("bad plist", lambda: canonical_plist(b"invalid"), "preferences-cannot-be-decoded")
    rejects("plist array", lambda: canonical_plist(plistlib.dumps([])), "preferences-not-a-dictionary")
    need(canonical_plist(plistlib.dumps({"synthetic": True})) !=
         canonical_plist(plistlib.dumps({"synthetic": 1})), "plist-type-test-failed")
    with tempfile.TemporaryDirectory(prefix="cloth-protection-synthetic-") as temp:
        base = Path(temp).resolve()
        rejects("wrong source", lambda: source_identity(base), "source-outside-reviewed-container")
        link = base / "alias"; link.symlink_to(base)
        rejects("symlink source", lambda: exact_path(link), "symlinked-path")
        rejects("unmanaged work", lambda: managed_work(base), "outside-local-lifecycle-root")
        previous_root = lifecycle.DEFAULT_ROOT
        lifecycle.DEFAULT_ROOT = base / "runs"
        try:
            run_path = lifecycle.DEFAULT_ROOT / ("a" * 32)
            work_path, evidence_path = run_path / "work", run_path / "evidence"
            work_path.mkdir(parents=True, mode=0o700); evidence_path.mkdir()
            record = {"id": run_path.name, "run_identity": identity(run_path),
                      "work_identity": identity(work_path), "state": "running",
                      "pid": os.getppid(), "hold": "synthetic-only"}
            def save_record():
                (run_path / "run.json").write_bytes(json_bytes(record))
            save_record()
            managed_work(work_path, evidence_path)
            record["hold"] = None; save_record()
            rejects("missing lifecycle hold", lambda: managed_work(work_path), "lifecycle-hold-required")
            record["hold"] = "synthetic-only"
            record["work_identity"] = [0, 0]; save_record()
            rejects("replaced work", lambda: managed_work(work_path), "work-identity-mismatch")
            record["work_identity"] = identity(work_path)
            record["pid"] = -1; save_record()
            rejects("not lifecycle child", lambda: managed_work(work_path, evidence_path, True),
                    "must-be-live-lifecycle-direct-child")
            record["pid"] = os.getppid(); save_record()
            rejects("lifecycle env mismatch", lambda: managed_work(work_path, evidence_path, True),
                    "lifecycle-environment-mismatch")
            record["state"] = "reclaimed"; save_record()
            rejects("reclaimed workspace", lambda: managed_work(work_path), "invalid-run-state")
            record["state"] = "complete"
            private = work_path / PRIVATE_NAME; private.mkdir(mode=0o700)
            data = private / "Data"; data.mkdir()
            pref_file = data / PREF_REL; pref_file.parent.mkdir(parents=True)
            pref_bytes = plistlib.dumps({"synthetic-only": True})
            pref_file.write_bytes(pref_bytes)
            (data / "outside-link").symlink_to("/nonexistent-outside-tree")
            snap = tree_snapshot(data)
            source_bytes = json_bytes(snap)
            (private / "source-before.json").write_bytes(source_bytes)
            (private / "backup-tree.json").write_bytes(source_bytes)
            (private / "defaults-export.plist").write_bytes(pref_bytes)
            manifest = {"schema": 1, "status": "verified", "sourcePath": str(SOURCE),
                        "backupManifestSHA256": digest_bytes(source_bytes),
                        "sourceManifestSHA256": digest_bytes(source_bytes),
                        "treeSHA256": digest_json(snap["entries"]),
                        "defaultsExportSHA256": digest_bytes(pref_bytes),
                        "preferenceSummary": canonical_plist(pref_bytes)}
            manifest_bytes = json_bytes(manifest)
            (private / "manifest.json").write_bytes(manifest_bytes)
            report_bytes = json_bytes({"status": "backup-verified", "readyForFixture": True,
                                       "manifestSHA256": digest_bytes(manifest_bytes)})
            (evidence_path / "native-state-protection.json").write_bytes(report_bytes)
            record["evidence_sha256"] = {"native-state-protection.json": digest_bytes(report_bytes)}
            save_record()
            need(verify_backup(work_path)["status"] == "backup-integrity-verified", "synthetic-seal-test-failed")
            (private / "manifest.json").write_bytes(manifest_bytes + b" ")
            rejects("private manifest tamper", lambda: verify_backup(work_path), "private-manifest-changed")
            (private / "manifest.json").write_bytes(manifest_bytes)
            (evidence_path / "native-state-protection.json").write_bytes(report_bytes + b" ")
            rejects("sealed report tamper", lambda: verify_backup(work_path), "sealed-report-changed")
            (evidence_path / "native-state-protection.json").write_bytes(report_bytes)
            pref_file.write_bytes(plistlib.dumps({"synthetic-only": False}))
            rejects("sealed backup content tamper", lambda: verify_backup(work_path), "backup-content-changed")
            pref_file.write_bytes(pref_bytes)
            (private / "defaults-export.plist").write_bytes(plistlib.dumps({"synthetic-only": False}))
            rejects("export tamper", lambda: verify_backup(work_path), "defaults-export-changed")
            (private / "defaults-export.plist").write_bytes(pref_bytes)
            alternative = {name: dict(row) for name, row in snap["entries"].items()}
            alternative[PREF_REL]["sha256"] = "different-serialization"
            alternative[PREF_REL]["bytes"] += 1
            need(normalized_restore_entries(alternative) == normalized_restore_entries(snap["entries"]),
                 "restore-serialization-normalization-failed")
            alternative[PREF_REL]["mode"] ^= 0o040
            need(normalized_restore_entries(alternative) != normalized_restore_entries(snap["entries"]),
                 "restore-mode-normalization-too-broad")
        finally:
            lifecycle.DEFAULT_ROOT = previous_root
        tree = base / "tree"; tree.mkdir()
        (tree / "payload").write_bytes(b"synthetic-only")
        (tree / "external-link").symlink_to("/not-a-real-target/no-follow")
        one = tree_snapshot(tree)
        need(one["entries"]["external-link"]["target"] == "/not-a-real-target/no-follow", "symlink-test-failed")
        two = tree_snapshot(tree)
        need(one == two, "snapshot-not-stable")
        (tree / "external-link").unlink()
        (tree / "external-link").symlink_to("/different-nonexistent-target")
        need(tree_snapshot(tree)["entries"] != one["entries"], "symlink-change-not-detected")
        attr = MacXattrs()
        attr.lib.fsetxattr.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_void_p,
                                     ctypes.c_size_t, ctypes.c_uint32, ctypes.c_int]
        attr.lib.fsetxattr.restype = ctypes.c_int
        attr_fd = os.open(tree / "payload", os.O_RDONLY | os.O_NOFOLLOW)
        try:
            before_attr = tree_snapshot(tree)["entries"]["payload"]
            buf = ctypes.create_string_buffer(b"synthetic")
            need(attr.lib.fsetxattr(attr_fd, b"com.qiuji.research.synthetic", buf, 9, 0, 0) == 0,
                 "synthetic-xattr-write-failed")
            need(tree_snapshot(tree)["entries"]["payload"] != before_attr, "xattr-change-not-detected")
        finally:
            os.close(attr_fd)
        (tree / "payload").write_bytes(b"changed")
        need(tree_snapshot(tree)["entries"] != one["entries"], "content-change-not-detected")
        os.chmod(tree / "payload", 0o600)
        need(tree_snapshot(tree)["entries"]["payload"]["mode"] == 0o600, "mode-not-detected")
        os.mkfifo(tree / "pipe")
        rejects("special file", lambda: tree_snapshot(tree), "unsupported-special-file")
    return {"status": "passed", "rejectionCount": len(cases), "rejections": cases,
            "positiveChecks": ["absent PID", "no handles", "plist type distinction", "external symlink not followed",
                               "held synthetic lifecycle", "sealed backup verification", "stable synthetic tree",
                               "content tamper", "mode capture", "symlink target tamper", "xattr tamper",
                               "restore normalization preserves non-content metadata"],
            "realContainerRead": False, "realBackupExecuted": False, "defaultsInvoked": False}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--execute-backup", action="store_true")
    action.add_argument("--execute-restore", action="store_true")
    action.add_argument("--verify-backup", action="store_true")
    action.add_argument("--self-test", action="store_true")
    parser.add_argument("--work", type=Path, default=os.environ.get("QIUJI_TEST_WORK"))
    parser.add_argument("--evidence", type=Path, default=os.environ.get("QIUJI_TEST_EVIDENCE"))
    parser.add_argument("--app-pid", type=int, default=2918)
    parser.add_argument("--expected-source-device", type=int)
    parser.add_argument("--expected-source-inode", type=int)
    parser.add_argument("--backup-work", type=Path)
    parser.add_argument("--expected-backup-manifest-sha")
    args = parser.parse_args(argv)
    os.umask(0o077)
    try:
        if args.execute_backup:
            return backup(args)
        if args.execute_restore:
            return restore(args)
        result = self_test() if args.self_test else verify_backup(args.work) if args.verify_backup else dry_plan(args)
        print(json.dumps(result, ensure_ascii=True, sort_keys=True))
        return 0
    except Exception as error:
        # Do not stringify arbitrary tool/plist exceptions: their payload may be private.
        print(json.dumps({"status": "failed", "readyForFixture": False,
                          "failureCode": str(error) if isinstance(error, ProtectionError) else type(error).__name__}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
