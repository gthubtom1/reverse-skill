import argparse
import contextlib
import errno
import os
import re
import stat
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


EVIDENCE_ID = re.compile(r"^E-[A-Za-z0-9][A-Za-z0-9_-]*$")
FINDING_ID = re.compile(r"^F-[A-Za-z0-9][A-Za-z0-9_-]*$")
SEVERITIES = {"critical", "high", "medium", "low", "info", "n/a", "n/a_re"}
STATUSES = {"candidate", "validated", "false_positive", "accepted_risk", "superseded"}
CONFIDENCES = {"high", "medium", "low"}
STRUCTURAL_DESCRIPTION = re.compile(r"(?m)^\s*(?:#{1,6}[ \t]+|-[ \t]+[A-Za-z0-9_]+:)")


@contextlib.contextmanager
def report_lock(report_dir):
    lock_path = report_dir / ".report.md.lock"
    if lock_path.is_symlink():
        raise ValueError(f"report lock is a symlink: {lock_path}")
    handle = open(lock_path, "a+b")
    acquired = False
    try:
        handle.seek(0, os.SEEK_END)
        if handle.tell() == 0:
            handle.write(b"0")
            handle.flush()
        handle.seek(0)
        deadline = time.monotonic() + 5
        if os.name == "nt":
            import msvcrt
            def try_lock():
                handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            def unlock():
                handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl
            def try_lock():
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            def unlock():
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        acquired = False
        while not acquired:
            try:
                try_lock()
                acquired = True
            except OSError as exc:
                if exc.errno not in (errno.EACCES, errno.EAGAIN, errno.EDEADLK):
                    raise
                if time.monotonic() >= deadline:
                    raise ValueError(f"timed out waiting for report lock: {lock_path}") from exc
                time.sleep(0.025)
        yield
    finally:
        if acquired:
            unlock()
        handle.close()


def single_line(value):
    return re.sub(r"[\x00-\x1f\s]+", " ", str(value)).strip()


def safe_description(value):
    description = str(value).replace("\r\n", "\n").replace("\r", "\n")
    if "\x00" in description or STRUCTURAL_DESCRIPTION.search(description):
        raise ValueError("description must not contain Markdown headings or field lines")
    return description.strip("\n")


def case_directory(raw):
    case_root = Path(raw).expanduser().resolve()
    if not case_root.is_dir():
        raise ValueError(f"case root is not a directory: {case_root}")
    evidence_dir = case_root / "evidence"
    if evidence_dir.is_symlink() or not evidence_dir.is_dir():
        raise ValueError(f"case evidence directory is missing or a symlink: {evidence_dir}")
    report_dir = case_root / "report"
    if report_dir.exists() and report_dir.is_symlink():
        raise ValueError(f"case report directory is a symlink: {report_dir}")
    report_dir.mkdir(exist_ok=True)
    if not report_dir.is_dir():
        raise ValueError(f"case report path is not a directory: {report_dir}")
    return case_root, evidence_dir, report_dir


def regular_file(path):
    try:
        return stat.S_ISREG(path.stat(follow_symlinks=False).st_mode) and not path.is_symlink()
    except OSError:
        return False


def append_bytes(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
    try:
        view = memoryview(data)
        while view:
            view = view[os.write(fd, view):]
    finally:
        os.close(fd)


def finding_block(finding_id, title, severity, status, confidence, location, ids, description, ts):
    return (
        f"### {finding_id}\n"
        f"- title: {title}\n"
        f"- severity: {severity}\n"
        f"- status: {status}\n"
        f"- confidence: {confidence}\n"
        f"- location: {location}\n"
        f"- evidence_ids: {', '.join(ids)}\n"
        f"- consolidated_at: {ts}\n\n"
        f"{description}\n"
    )


def append_report(report_file, report_dir, block, finding_id):
    with report_lock(report_dir):
        if report_file.is_symlink():
            raise ValueError(f"report file is a symlink: {report_file}")
        if report_file.exists() and not regular_file(report_file):
            raise ValueError(f"report path is not a regular file: {report_file}")
        if report_file.exists():
            content = report_file.read_text(encoding="utf-8-sig")
            if re.search(r"(?m)^###\s+" + re.escape(finding_id) + r"\s*$", content):
                raise ValueError(f"finding already exists: {finding_id}")
            prefix = ""
            if not re.search(r"(?m)^##[ \t]+Findings[ \t]*\r?$", content):
                prefix = content.rstrip() + "\n\n## Findings\n"
                # Replacing while holding the lock keeps a legacy report coherent.
                report_file.write_text(prefix, encoding="utf-8-sig")
                content = prefix
            append_bytes(report_file, b"\n\n" + block.encode("utf-8"))
        else:
            append_bytes(report_file, ("# Case Report\n\n## Findings\n\n" + block).encode("utf-8-sig"))


def main():
    parser = argparse.ArgumentParser(description="Consolidate Evidence into Finding")
    parser.add_argument("--case-root", required=True)
    parser.add_argument("--evidence-ids", required=True, help="Comma-separated E-xxx")
    parser.add_argument("--finding-id", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--description", required=True)
    parser.add_argument("--severity", default="medium")
    parser.add_argument("--status", default="validated")
    parser.add_argument("--confidence", default="medium")
    parser.add_argument("--location", default="see evidence_ids")
    args = parser.parse_args()

    try:
        _case_root, evidence_dir, report_dir = case_directory(args.case_root)
        ids = [item.strip() for item in args.evidence_ids.split(",") if item.strip()]
        if not ids:
            raise ValueError("no Evidence IDs provided")
        if len(ids) != len(set(ids)) or any(not EVIDENCE_ID.fullmatch(item) for item in ids):
            raise ValueError("Evidence IDs must be unique and match E-<alphanumeric-or-_>-...")
        if not FINDING_ID.fullmatch(args.finding_id):
            raise ValueError("Finding ID must match F-<alphanumeric-or-_>-...")
        severity = single_line(args.severity).lower()
        status = single_line(args.status).lower()
        confidence = single_line(args.confidence).lower()
        if severity not in SEVERITIES or status not in STATUSES or confidence not in CONFIDENCES:
            raise ValueError("invalid severity, status, or confidence")
        if status == "validated" and confidence == "low":
            raise ValueError("a validated Finding cannot have low confidence")
        title = single_line(args.title)
        location = single_line(args.location)
        description = safe_description(args.description)
        if not title or not location:
            raise ValueError("title and location must be non-empty single-line values")
        for evidence_id in ids:
            evidence_file = evidence_dir / f"{evidence_id}.md"
            if not regular_file(evidence_file):
                raise ValueError(f"immutable Evidence file missing or is not a regular file: {evidence_file}")

        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        block = finding_block(args.finding_id, title, severity, status, confidence, location, ids, description, timestamp)
        append_report(report_dir / "report.md", report_dir, block, args.finding_id)
    except (OSError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    for evidence_id in ids:
        print(f"Referenced {evidence_id} without modifying immutable Evidence")
    print(f"Successfully consolidated {len(ids)} evidence items into {args.finding_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
