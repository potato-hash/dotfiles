#!/usr/bin/env python3
"""Build and inspect fixture-driven apple-build protocol-v1 archives."""

from __future__ import annotations

import argparse
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
from typing import Any

BUNDLE_REF = "refs/apple-build/request"
REQUEST_MEMBERS = {"manifest.json", "repository.bundle"}
RESULT_MEMBERS = {
    "manifest.json",
    "metadata.json",
    "xcodebuild.log",
    "Result.xcresult",
    "Result.xcresult/Info.json",
}
VARIANTS = (
    "valid",
    "extra-member",
    "duplicate-member",
    "traversal-member",
    "nonregular-member",
    "malformed-json",
    "duplicate-json-key",
    "unknown-key",
    "wrong-type",
    "missing-key",
    "empty-scheme",
    "both-selectors",
    "no-selector",
    "protocol-mismatch",
    "bundle-manifest-sha-mismatch",
)


def git(*args: str, cwd: Path | None = None) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    return result.stdout.strip()


def regular_member(output: tarfile.TarFile, name: str, content: bytes) -> None:
    info = tarfile.TarInfo(name)
    info.size = len(content)
    info.mode = 0o600
    info.uid = info.gid = 0
    info.uname = info.gname = ""
    output.addfile(info, io.BytesIO(content))


def symlink_member(output: tarfile.TarFile, name: str, target: str) -> None:
    info = tarfile.TarInfo(name)
    info.type = tarfile.SYMTYPE
    info.linkname = target
    info.mode = 0o777
    info.uid = info.gid = 0
    info.uname = info.gname = ""
    output.addfile(info)


def manifest_bytes(base: dict[str, Any], variant: str) -> bytes:
    manifest = dict(base)
    if variant == "malformed-json":
        return b'{"protocol_version":1'
    if variant == "duplicate-json-key":
        return (
            b'{"protocol_version":1,"commit":"'
            + base["commit"].encode()
            + b'","action":"build","scheme":"Fixture Scheme",'
            b'"scheme":"Duplicate Scheme","project":"App.xcodeproj"}\n'
        )
    if variant == "unknown-key":
        manifest["unexpected"] = True
    elif variant == "wrong-type":
        manifest["scheme"] = 7
    elif variant == "missing-key":
        del manifest["commit"]
    elif variant == "empty-scheme":
        manifest["scheme"] = ""
    elif variant == "both-selectors":
        manifest["workspace"] = "App.xcworkspace"
    elif variant == "no-selector":
        del manifest["project"]
    elif variant == "protocol-mismatch":
        manifest["protocol_version"] = 2
    elif variant == "bundle-manifest-sha-mismatch":
        manifest["commit"] = "0" * 40
    return (json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n").encode()


def write_request(
    path: Path,
    manifest: bytes,
    bundle: bytes,
    variant: str,
) -> None:
    with tarfile.open(path, "w:gz", format=tarfile.USTAR_FORMAT) as output:
        if variant == "duplicate-member":
            regular_member(output, "manifest.json", manifest)
            regular_member(output, "manifest.json", manifest)
            return
        regular_member(output, "manifest.json", manifest)
        if variant == "traversal-member":
            regular_member(output, "../repository.bundle", bundle)
            return
        if variant == "nonregular-member":
            symlink_member(output, "repository.bundle", "manifest.json")
            return
        regular_member(output, "repository.bundle", bundle)
        if variant == "extra-member":
            regular_member(output, "extra.txt", b"unexpected\n")


def prepare(root: Path) -> None:
    root.mkdir(parents=True, exist_ok=True)
    repo = root / "repo"
    origin = root / "origin.git"
    fixtures = root / "requests"
    fixtures.mkdir()
    git("init", "-q", "--bare", str(origin))
    git("init", "-q", str(repo))
    git("config", "user.email", "fixture@example.invalid", cwd=repo)
    git("config", "user.name", "Apple Fixture", cwd=repo)
    project = repo / "App.xcodeproj"
    project.mkdir()
    (project / "project.pbxproj").write_text("fixture project\n", encoding="utf-8")
    git("add", ".", cwd=repo)
    git("commit", "-qm", "fixture commit", cwd=repo)
    git("branch", "-M", "main", cwd=repo)
    git("remote", "add", "origin", str(origin), cwd=repo)
    git("push", "-q", "-u", "origin", "main", cwd=repo)
    commit = git("rev-parse", "HEAD", cwd=repo)
    git("update-ref", BUNDLE_REF, commit, cwd=repo)
    bundle_path = root / "repository.bundle"
    git("bundle", "create", "--version=2", str(bundle_path), BUNDLE_REF, cwd=repo)
    bundle = bundle_path.read_bytes()
    base: dict[str, Any] = {
        "protocol_version": 1,
        "commit": commit,
        "action": "build",
        "scheme": "Fixture Scheme ; $() `quoted`",
        "project": "App.xcodeproj",
        "destination": (
            "platform=iOS Simulator,name=Literal ; "
            f"$(touch {root / 'injection-sentinel'})"
        ),
        "configuration": "Debug Fixture",
    }
    for variant in VARIANTS:
        write_request(
            fixtures / f"{variant}.tar.gz",
            manifest_bytes(base, variant),
            bundle,
            variant,
        )
    state = {
        "sha": commit,
        "repo": str(repo),
        "destination": base["destination"],
        "manifest": base,
    }
    (root / "fixture.json").write_text(
        json.dumps(state, sort_keys=True) + "\n", encoding="utf-8"
    )


def fixture_value(root: Path, key: str) -> None:
    state = json.loads((root / "fixture.json").read_text(encoding="utf-8"))
    value = state[key]
    if not isinstance(value, str):
        raise SystemExit(f"fixture value {key!r} is not text")
    print(value)


def request_manifest(path: Path) -> dict[str, Any]:
    with tarfile.open(path, "r:gz") as archive:
        names = [member.name for member in archive.getmembers()]
        if set(names) != REQUEST_MEMBERS or len(names) != len(REQUEST_MEMBERS):
            raise AssertionError(f"unexpected valid request members: {names}")
        stream = archive.extractfile("manifest.json")
        if stream is None:
            raise AssertionError("valid request manifest is unreadable")
        value = json.load(stream)
    if not isinstance(value, dict):
        raise AssertionError("valid request manifest is not an object")
    return value


def assert_result(
    archive_path: Path,
    request_path: Path,
    expected_sha: str,
    expected_status: int,
) -> None:
    expected_manifest = request_manifest(request_path)
    with tarfile.open(archive_path, "r:gz") as archive:
        members = archive.getmembers()
        names = [member.name.rstrip("/") for member in members]
        if set(names) != RESULT_MEMBERS or len(names) != len(RESULT_MEMBERS):
            raise AssertionError(f"unexpected result members: {names}")
        returned_manifest_file = archive.extractfile("manifest.json")
        metadata_file = archive.extractfile("metadata.json")
        log_file = archive.extractfile("xcodebuild.log")
        result_file = archive.extractfile("Result.xcresult/Info.json")
        if None in (returned_manifest_file, metadata_file, log_file, result_file):
            raise AssertionError("result archive contains unreadable required content")
        returned_manifest = json.load(returned_manifest_file)
        metadata = json.load(metadata_file)
        build_log = log_file.read().decode("utf-8")
        result_content = result_file.read().decode("utf-8")
    if returned_manifest != expected_manifest:
        raise AssertionError("returned manifest differs from request manifest")
    expected_metadata = {
        "protocol_version": 1,
        "commit": expected_sha,
        "action": expected_manifest["action"],
        "xcodebuild_exit_status": expected_status,
        "result_bundle_present": True,
    }
    if metadata != expected_metadata:
        raise AssertionError(f"unexpected metadata: {metadata!r}")
    if type(metadata["protocol_version"]) is not int:
        raise AssertionError("metadata protocol type is not int")
    if type(metadata["xcodebuild_exit_status"]) is not int:
        raise AssertionError("metadata build status type is not int")
    if type(metadata["result_bundle_present"]) is not bool:
        raise AssertionError("metadata result-bundle flag type is not bool")
    if "fake-xcodebuild-output" not in build_log:
        raise AssertionError(f"fake xcodebuild output absent from log: {build_log!r}")
    if result_content != "fixture xcresult\n":
        raise AssertionError(f"unexpected xcresult content: {result_content!r}")


def write_result(root: Path, output_path: Path, variant: str, status: int = 0) -> None:
    state = json.loads((root / "fixture.json").read_text(encoding="utf-8"))
    manifest = state["manifest"]
    metadata = {
        "protocol_version": 1,
        "commit": state["sha"],
        "action": manifest["action"],
        "xcodebuild_exit_status": status,
        "result_bundle_present": True,
    }
    with tarfile.open(output_path, "w:gz", format=tarfile.USTAR_FORMAT) as output:
        regular_member(output, "manifest.json", manifest_bytes(manifest, "valid"))
        regular_member(output, "metadata.json", (json.dumps(metadata, separators=(",", ":")) + "\n").encode())
        regular_member(output, "xcodebuild.log", b"fixture log\n")
        regular_member(output, "Result.xcresult/Info.json", b"fixture xcresult\n")
        if variant == "result-member-count":
            for index in range(8):
                regular_member(output, f"Result.xcresult/member-{index}", b"x")
        elif variant == "result-large-member":
            regular_member(output, "Result.xcresult/large", b"x" * 128)
        elif variant == "result-expanded":
            regular_member(output, "Result.xcresult/expanded-a", b"a" * 64)
            regular_member(output, "Result.xcresult/expanded-b", b"b" * 64)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    prepare_parser = subparsers.add_parser("prepare")
    prepare_parser.add_argument("root", type=Path)
    value_parser = subparsers.add_parser("value")
    value_parser.add_argument("root", type=Path)
    value_parser.add_argument("key", choices=("sha", "repo", "destination"))
    result_parser = subparsers.add_parser("make-result")
    result_parser.add_argument("root", type=Path)
    result_parser.add_argument("archive", type=Path)
    result_parser.add_argument("variant", choices=("valid", "result-member-count", "result-large-member", "result-expanded"))
    result_parser.add_argument("--status", type=int, default=0)
    result_parser = subparsers.add_parser("assert-result")
    result_parser.add_argument("archive", type=Path)
    result_parser.add_argument("request", type=Path)
    result_parser.add_argument("sha")
    result_parser.add_argument("status", type=int)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.command == "prepare":
        prepare(args.root)
    elif args.command == "value":
        fixture_value(args.root, args.key)
    elif args.command == "make-result":
        write_result(args.root, args.archive, args.variant, args.status)
    else:
        assert_result(args.archive, args.request, args.sha, args.status)


if __name__ == "__main__":
    main()
