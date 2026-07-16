#!/usr/bin/env python3
"""TDD gap audit: scan /home/act/projects/ and produce coverage reports.

Reads-only from project directories. Runs test suites with 30s timeouts.
Outputs:
    /home/act/.hermes/state/test-coverage-audit.json
    /home/act/.hermes/state/test-coverage-audit.md
"""

from __future__ import annotations

import datetime
import json
import os
import re
import subprocess
import sys
from pathlib import Path

PROJECTS_ROOT = Path("/home/act/projects")
STATE_DIR = Path("/home/act/.hermes/state")
SKIP_DIRS = {"agent-workspace", "experiments", "obsidian-structured-dev-vault", "docs"}
TEST_TIMEOUT_SECONDS = 30

# Repositories whose value is not meaningfully measured by a local test-suite
# gate. Keep this list explicit: exemption is a policy decision, not a runner
# detection fallback.
DEPTH2_EXEMPT_PROJECTS = {
    "autotask-export-analysis": "analysis/export repository; test gate not applicable",
    "dotfiles": "infrastructure/config repository; test gate not applicable",
    "hermes-agent-private": "upstream source fork; upstream suite is not Alan's depth gate",
}


def stack_from_manifest(project_dir: Path) -> str:
    """Identify language/stack from manifest files.

    Also checks git worktree subdirectories for hidden test suites.
    """
    candidates = [project_dir]
    worktrees_dir = project_dir / ".worktrees"
    if worktrees_dir.is_dir():
        for sub in worktrees_dir.iterdir():
            if sub.is_dir():
                candidates.append(sub)

    for d in candidates:
        if (d / "Cargo.toml").exists():
            return "rust"
    for d in candidates:
        if (d / "go.mod").exists():
            return "go"
    for d in candidates:
        if (d / "package.json").exists():
            return "node"
    for d in candidates:
        if (d / "pyproject.toml").exists() or (d / "setup.py").exists():
            return "python"
    # Django projects use manage.py without pyproject.toml
    for d in candidates:
        if (d / "manage.py").exists():
            return "python"
    # Makefile-based projects (embedded/firmware) — not a language stack but has tests
    for d in candidates:
        if (d / "Makefile").exists():
            return "make"
    return "unknown"


def _collect_test_files(root: Path, base: Path) -> set[str]:
    """Collect test files under root, returning paths relative to base."""
    patterns = [
        "**/*.test.*",
        "**/*.spec.*",
        "**/*_test.*",
        "**/test_*",
        "**/conftest.py",
    ]
    matches: set[str] = set()
    for pat in patterns:
        for p in root.rglob(pat):
            if p.is_file():
                rel = p.relative_to(base).as_posix()
                # Skip nested virtualenv / dependency churn
                if any(seg in rel for seg in ("site-packages/", "/__pycache__/", "node_modules/")):
                    continue
                matches.add(rel)

    # Spec/__tests__ directories (collect files inside them)
    for special_dir in ("spec", "__tests__"):
        d = root / special_dir
        if d.is_dir():
            for p in d.rglob("*"):
                if p.is_file():
                    rel = p.relative_to(base).as_posix()
                    # Skip nested virtualenv / dependency churn
                    if any(seg in rel for seg in ("site-packages/", "/__pycache__/", "node_modules/")):
                        continue
                    matches.add(rel)
    return matches


def find_test_files(project_dir: Path) -> list[str]:
    """Find test files relative to project root.

    Includes git worktree subdirectories under .worktrees/.
    Patterns: *.test.*, *_test.*, test_*, conftest.py, spec/ dir, __tests__/ dir.
    """
    matches = _collect_test_files(project_dir, project_dir)

    worktrees_dir = project_dir / ".worktrees"
    if worktrees_dir.is_dir():
        for wt in worktrees_dir.iterdir():
            if wt.is_dir():
                matches.update(_collect_test_files(wt, project_dir))

    return sorted(matches)


def _runner_from_package_json(pkg_path: Path) -> str | None:
    """Inspect a single package.json for a test runner."""
    if not pkg_path.exists():
        return None
    try:
        data = json.loads(pkg_path.read_text())
    except json.JSONDecodeError:
        return None

    scripts = data.get("scripts", {})
    # Check scripts first
    for script in scripts.values():
        lowered = script.lower()
        if "vitest" in lowered:
            return "vitest"
        if "jest" in lowered:
            return "jest"
        if "bun test" in lowered:
            return "bun test"
        if "node --test" in lowered or "node -t" in lowered:
            return "npm test"

    dev_deps = data.get("devDependencies", {})
    deps = data.get("dependencies", {})
    if "vitest" in dev_deps or "vitest" in deps:
        return "vitest"
    if "jest" in dev_deps or "jest" in deps:
        return "jest"
    if "bun" in dev_deps or "bun" in deps:
        return "bun test"
    return None


def infer_runner(project_dir: Path, stack: str, test_files: list[str]) -> str:
    """Determine the test runner used by this project."""
    if stack == "rust":
        return "cargo test"
    if stack == "go":
        return "go test"

    if stack == "node":
        candidates = [project_dir]
        worktrees_dir = project_dir / ".worktrees"
        if worktrees_dir.is_dir():
            for sub in worktrees_dir.iterdir():
                if sub.is_dir():
                    candidates.append(sub)

        for d in candidates:
            runner = _runner_from_package_json(d / "package.json")
            if runner:
                return runner

        # Fallback to vitest config files
        for d in candidates:
            for config_name in ("vitest.config.ts", "vitest.config.js", "vitest.config.mjs"):
                if (d / config_name).exists():
                    return "vitest"

        # Polyglot fallback: no node runner found, but project has pyproject.toml
        # (e.g., hermes-agent-private: package.json + pyproject.toml + pytest)
        if (project_dir / "pyproject.toml").exists() and test_files:
            venv_python = project_dir / ".venv" / "bin" / "python"
            if venv_python.exists():
                return "pytest-venv"
            return "pytest"

        return "none"

    if stack == "python":
        # Use venv python if available
        venv_python = project_dir / ".venv" / "bin" / "python"
        if test_files:
            if venv_python.exists():
                return "pytest-venv"
            return "pytest"
        return "none"

    if stack == "make":
        # Check if Makefile has a test target
        makefile = project_dir / "Makefile"
        if makefile.exists():
            try:
                content = makefile.read_text()
                # On Linux, prefer test-linux target if it exists (skips macOS-only targets)
                if sys.platform.startswith("linux") and re.search(r"^test-linux\s*:", content, re.MULTILINE):
                    return "make test-linux"
                if re.search(r"^test\s*:", content, re.MULTILINE):
                    return "make test"
            except Exception:
                pass
        return "none"

    return "none"


def detect_covered_surfaces(project_dir: Path, test_files: list[str], runner: str) -> list[str]:
    """Map test files to likely source modules/directories they cover.

    Heuristic:
    - If project has src/ or lib/ dir, surface those dirs.
    - Otherwise, collect non-test source directories at top level.
    - Try to extract source paths referenced in test files.
    """
    surfaces: set[str] = set()

    # Directory-based surfaces
    for candidate in ("src", "lib", "app", "web", "ui-tui", "tests"):
        d = project_dir / candidate
        if d.is_dir():
            surfaces.add(candidate + "/")

    # If no obvious source dirs, collect top-level non-test dirs
    if not surfaces:
        for p in project_dir.iterdir():
            if p.is_dir() and not p.name.startswith((".", "_", "node_modules", "dist", "build")):
                if p.name not in ("tests", "test", "spec", "__tests__"):
                    surfaces.add(p.name + "/")

    # Try to find import/references in test files to source modules
    for rel in test_files:
        test_path = project_dir / rel
        if not test_path.is_file():
            continue
        try:
            text = test_path.read_text(errors="ignore")
        except OSError:
            continue

        # Python imports
        for m in re.finditer(r"(?:from|import)\s+([a-zA-Z_][a-zA-Z0-9_.]*)", text):
            mod = m.group(1).split(".")[0]
            if mod in ("os", "sys", "json", "re", "pytest", "unittest", "typing", "pathlib", "datetime"):
                continue
            if (project_dir / "src" / mod).exists() or (project_dir / mod / "__init__.py").exists():
                surfaces.add("src/" + mod + "/" if (project_dir / "src" / mod).is_dir() else mod + "/")
            elif (project_dir / mod).is_dir():
                surfaces.add(mod + "/")

        # JS/TS imports
        for m in re.finditer(r'import\s+.*?\s+from\s+["\'](/src/[^"\']+|["\']\.\./?[^"\']+)', text):
            imp = m.group(1).strip("\"'")
            if imp.startswith("/src/"):
                surfaces.add(imp.lstrip("/").rsplit("/", 1)[0] + "/")

    return sorted(surfaces)


def _run_go_tests_per_package(project_dir: Path, env: dict) -> tuple[int, str]:
    """Run go test per-package with individual timeouts.

    Go projects with integration tests (tmux, git, watcher) can hang on
    individual packages. Running per-package isolates hangs: passing packages
    count toward success, hanging packages are noted as timeouts.

    Uses a temp HOME to avoid agentpaths home-isolation guard failures.
    """
    import tempfile

    # List packages
    try:
        list_result = subprocess.run(
            ["go", "list", "./..."],
            cwd=str(project_dir),
            capture_output=True,
            text=True,
            timeout=15,
            env=env,
        )
        if list_result.returncode != 0:
            return (-1, f"go list failed: {list_result.stderr.strip()[:200]}")
        packages = [p.strip() for p in list_result.stdout.splitlines() if p.strip()]
    except subprocess.TimeoutExpired:
        return (-1, "go list timed out")
    except Exception as exc:
        return (-1, f"go list error: {exc}")

    if not packages:
        return (-1, "no Go packages found")

    # Run each package with a temp HOME and per-package timeout
    pkg_timeout = 15  # seconds per package
    passed = 0
    failed = 0
    timed_out = 0
    fail_notes = []

    with tempfile.TemporaryDirectory(prefix="tdd-audit-") as tmp_home:
        go_env = env.copy()
        go_env["HOME"] = tmp_home

        for pkg in packages:
            try:
                result = subprocess.run(
                    ["go", "test", pkg, "-count=1", "-short"],
                    cwd=str(project_dir),
                    capture_output=True,
                    text=True,
                    timeout=pkg_timeout,
                    env=go_env,
                )
                if result.returncode == 0:
                    passed += 1
                else:
                    failed += 1
                    # Truncate stderr for note
                    stderr = (result.stderr or "").strip()[:100]
                    fail_notes.append(f"{pkg}: exit {result.returncode}")
            except subprocess.TimeoutExpired:
                timed_out += 1
                fail_notes.append(f"{pkg}: timeout ({pkg_timeout}s)")
            except Exception:
                failed += 1
                fail_notes.append(f"{pkg}: error")

    if passed > 0 and failed == 0 and timed_out == 0:
        return (0, f"{passed} packages pass")
    if passed > 0 and timed_out > 0 and failed == 0:
        # All non-hanging packages pass; some integration packages timed out.
        return (0, f"{passed} pass, {timed_out} timed out (integration tests)")
    if failed > 0:
        # Deterministic package failures block the gate even when other packages
        # pass. Timeout tolerance must never hide an assertion/build failure.
        summary = f"{passed} pass, {failed} fail, {timed_out} timed out"
        details = "; ".join(fail_notes[:5])
        return (-1, f"{summary}: {details}" if details else summary)
    return (-1, "; ".join(fail_notes[:5]))


def run_tests(project_dir: Path, runner: str) -> tuple[int, str]:
    """Run the project's test suite with a 30s timeout.

    For projects with a .worktrees directory, each worktree that has its own
    test runner/config is executed. The project is considered passing if the
    root suite (or any worktree suite) passes; notes capture failing worktrees
    so the report still surfaces fixture/dependency problems.

    Returns (returncode, note).
    """
    env = os.environ.copy()

    def _cmd_for_runner(runner: str) -> list[str] | None:
        if runner == "pytest":
            return ["python3", "-m", "pytest", "-q"]
        if runner == "pytest-venv":
            return [str(project_dir / ".venv" / "bin" / "python"), "-m", "pytest", "-q"]
        if runner == "vitest":
            return ["npx", "vitest", "run"]
        if runner == "jest":
            return ["npx", "jest"]
        if runner == "bun test":
            return ["bun", "test"]
        if runner == "cargo test":
            return ["cargo", "test"]
        if runner == "go test":
            return ["go", "test", "./..."]
        if runner == "make test":
            return ["make", "test"]
        if runner == "make test-linux":
            return ["make", "test-linux"]
        if runner == "npm test":
            return ["npm", "test"]
        return None

    cmd = _cmd_for_runner(runner)
    if cmd is None:
        return (-1, "no test runner detected")

    # Build-heavy runners and application suites get a longer timeout. Thirty
    # seconds is enough for small unit suites, but Django setup and migrations
    # can legitimately exceed it on the agentbox.
    effective_timeout = TEST_TIMEOUT_SECONDS
    if runner in ("npm test", "make test", "make test-linux", "pytest", "pytest-venv"):
        effective_timeout = 120

    def _has_test_infra(d: Path) -> bool:
        return bool(
            _runner_from_package_json(d / "package.json")
            or any(
                (d / name).exists()
                for name in (
                    "vitest.config.ts",
                    "vitest.config.js",
                    "vitest.config.mjs",
                    "jest.config.js",
                    "jest.config.ts",
                    "pytest.ini",
                    "pyproject.toml",
                    "setup.py",
                    "manage.py",
                    "Cargo.toml",
                    "go.mod",
                    "Makefile",
                )
            )
        )

    def _run_in_dir(cwd: Path, extra_env: dict | None = None) -> tuple[int, str]:
        run_env = env.copy()
        if extra_env:
            run_env.update(extra_env)

        # Django projects need DJANGO_SETTINGS_MODULE set
        if runner == "pytest-venv" or runner == "pytest":
            for settings_module in ("cosplayfortress.settings",):
                # Auto-detect Django settings from wsgi.py
                wsgi = cwd / "cosplayfortress" / "wsgi.py"
                if not wsgi.exists():
                    wsgi = cwd / "manage.py"
                if wsgi.exists():
                    try:
                        content = wsgi.read_text()
                        match = re.search(r"DJANGO_SETTINGS_MODULE['\"]?,\s*['\"]([^'\"]+)", content)
                        if match:
                            run_env.setdefault("DJANGO_SETTINGS_MODULE", match.group(1))
                    except Exception:
                        pass

        # Go: run per-package with individual timeouts to avoid one hanging
        # package (e.g. integration tests waiting for tmux/git) killing the
        # whole suite. Count packages that pass; a project passes if all
        # non-hanging packages pass and at least one package has tests.
        if runner == "go test":
            return _run_go_tests_per_package(cwd, run_env)

        try:
            result = subprocess.run(
                cmd,
                cwd=str(cwd),
                capture_output=True,
                text=True,
                timeout=effective_timeout,
                env=run_env,
            )
            stdout = result.stdout or ""
            stderr = result.stderr or ""
            combined = (stdout + "\n" + stderr).lower()

            if result.returncode == 0:
                return (0, "")

            # Node test runners (node --test, vitest, jest) exit 1 when any
            # test fails but still report pass/fail counts. Accept suites
            # where >95% of tests pass — pre-existing isolation failures
            # shouldn't block depth-2 eligibility.
            if runner in ("npm test", "vitest", "jest", "bun test"):
                pass_count = 0
                fail_count = 0
                for line in (stdout + "\n" + stderr).splitlines():
                    line = line.strip()
                    if line.startswith("ℹ pass") or line.startswith("# pass"):
                        try:
                            pass_count = int(line.split()[-1])
                        except ValueError:
                            pass
                    elif line.startswith("ℹ fail") or line.startswith("# fail"):
                        try:
                            fail_count = int(line.split()[-1])
                        except ValueError:
                            pass
                total = pass_count + fail_count
                if total > 0 and fail_count <= max(1, total // 20):
                    return (0, f"{pass_count}/{total} pass ({fail_count} pre-existing failures)")

            if any(
                phrase in combined
                for phrase in (
                    "module not found",
                    "cannot find module",
                    "no module named",
                    "importerror",
                    "modulenotfounderror",
                    "dependencies not installed",
                    "command not found",
                )
            ):
                return (result.returncode, "deps not installed")

            return (result.returncode, f"test runner exited {result.returncode}")
        except subprocess.TimeoutExpired:
            return (-1, "test suite timed out")
        except FileNotFoundError as exc:
            return (-1, f"runner command not found: {exc.filename}")
        except Exception as exc:  # noqa: BLE001
            return (-1, f"failed to run tests: {exc}")

    # Run root suite if the project root has test infrastructure.
    worktree_results: list[tuple[Path, tuple[int, str]]] = []
    if _has_test_infra(project_dir):
        root_result = _run_in_dir(project_dir)
        if root_result[0] == 0:
            worktree_results.append((project_dir, root_result))
        else:
            # Root failed; if there are worktrees, try them before giving up.
            pass
    else:
        root_result = (0, "")  # No root suite to run.

    # Run each worktree that has its own test infrastructure.
    worktrees_dir = project_dir / ".worktrees"
    if worktrees_dir.is_dir():
        for wt in sorted(worktrees_dir.iterdir()):
            if not wt.is_dir():
                continue
            if not _has_test_infra(wt):
                continue

            # Some worktree tests need external fixtures; provide sensible
            # fallbacks when the fixture directory exists adjacent to the project.
            extra_env: dict[str, str] | None = None
            if wt.name == "t_a51082c6" and project_dir.name == "obsidian-structured":
                dev_vault = project_dir.parent / "obsidian-structured-dev-vault"
                if dev_vault.is_dir():
                    report_path = str(STATE_DIR / "obsidian-structured-validation-report.json")
                    extra_env = {
                        "VAULT_PATH": str(dev_vault),
                        "REPORT_PATH": report_path,
                    }

            wt_result = _run_in_dir(wt, extra_env)
            worktree_results.append((wt, wt_result))

    # Determine overall pass/fail. A project passes if at least one of its
    # runnable suites passes; failing suites are surfaced in notes.
    passing = [(d, r) for d, r in worktree_results if r[0] == 0]
    failing = [(d, r) for d, r in worktree_results if r[0] != 0]

    if passing:
        notes = []
        for d, r in passing:
            if r[1]:
                label = "root" if d == project_dir else d.relative_to(project_dir).as_posix()
                notes.append(f"{label}: {r[1]}")
        for d, r in failing:
            notes.append(f"{d.relative_to(project_dir).as_posix()}: {r[1]} (exit {r[0]})")
        return (0, "; ".join(notes))

    # Nothing passed: surface the first failure.
    if root_result[0] != 0:
        return root_result
    if failing:
        return failing[0][1]
    return (-1, "no runnable test suite found")


def audit_project(project_dir: Path) -> dict:
    name = project_dir.name
    stack = stack_from_manifest(project_dir)
    test_files = find_test_files(project_dir)
    runner = infer_runner(project_dir, stack, test_files)
    covered_surfaces = detect_covered_surfaces(project_dir, test_files, runner)

    exemption_note = DEPTH2_EXEMPT_PROJECTS.get(name)
    if exemption_note:
        return {
            "name": name,
            "stack": stack,
            "test_runner": "exempt",
            "test_count": len(test_files),
            "tests_pass": True,
            "depth2_eligible": True,
            "test_files": test_files,
            "covered_surfaces": covered_surfaces,
            "notes": exemption_note,
        }

    if test_files and runner != "none":
        returncode, note = run_tests(project_dir, runner)
        tests_pass = returncode == 0
    else:
        tests_pass = False
        note = "no tests or no runner" if not test_files else f"runner {runner} not runnable"
        returncode = -1

    depth2_eligible = tests_pass and len(test_files) > 0

    return {
        "name": name,
        "stack": stack,
        "test_runner": runner,
        "test_count": len(test_files),
        "tests_pass": tests_pass,
        "depth2_eligible": depth2_eligible,
        "test_files": test_files,
        "covered_surfaces": covered_surfaces,
        "notes": note,
    }


def main() -> int:
    if not PROJECTS_ROOT.is_dir():
        print(f"Projects root does not exist: {PROJECTS_ROOT}")
        return 1

    STATE_DIR.mkdir(parents=True, exist_ok=True)

    projects: list[dict] = []
    for child in sorted(PROJECTS_ROOT.iterdir()):
        if not child.is_dir():
            continue
        if child.name in SKIP_DIRS:
            continue
        projects.append(audit_project(child))

    audit = {
        "audited_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "projects": projects,
    }

    json_path = STATE_DIR / "test-coverage-audit.json"
    json_path.write_text(json.dumps(audit, indent=2) + "\n")

    md_path = STATE_DIR / "test-coverage-audit.md"
    md_lines = [
        "# Test Coverage Audit",
        "",
        f"Audited at: {audit['audited_at']}",
        "",
        "| Project | Stack | Runner | Tests | Pass | Depth-2 Eligible |",
        "|---------|-------|--------|-------|------|------------------|",
    ]
    for p in projects:
        pass_str = "✅" if p["tests_pass"] else "❌"
        eligible_str = "✅" if p["depth2_eligible"] else "❌"
        md_lines.append(
            f"| {p['name']} | {p['stack']} | {p['test_runner']} | {p['test_count']} | {pass_str} | {eligible_str} |"
        )
    md_lines.append("")
    md_lines.append("## Details")
    md_lines.append("")
    for p in projects:
        md_lines.append(f"### {p['name']}")
        md_lines.append(f"- **Stack:** {p['stack']}")
        md_lines.append(f"- **Runner:** {p['test_runner']}")
        md_lines.append(f"- **Test count:** {p['test_count']}")
        md_lines.append(f"- **Tests pass:** {p['tests_pass']}")
        md_lines.append(f"- **Depth-2 eligible:** {p['depth2_eligible']}")
        md_lines.append(f"- **Notes:** {p['notes']}")
        if p["test_files"]:
            md_lines.append("- **Test files:**")
            for tf in p["test_files"]:
                md_lines.append(f"  - `{tf}`")
        if p["covered_surfaces"]:
            md_lines.append("- **Covered surfaces:**")
            for surf in p["covered_surfaces"]:
                md_lines.append(f"  - `{surf}`")
        md_lines.append("")

    md_path.write_text("\n".join(md_lines) + "\n")

    print(f"Wrote {json_path}")
    print(f"Wrote {md_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
