"""Run every repository-owned release check in one deterministic local command.

This script never opens Studio or downloads dependencies. It compiles Luau, runs the
standalone suites and service harness, audits content/assets, regenerates derived
artifacts, and asks Rojo to build the place.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path
import os
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "docs" / "RELEASE_CHECK_REPORT.md"


def find_tool(explicit: str | None, name: str, candidates: list[Path]) -> str:
    """Resolve one local tool from an argument, PATH, or known project-runtime locations."""
    if explicit:
        path = Path(explicit)
        if path.is_file():
            return str(path)
        raise SystemExit(f"{name} was not found at {explicit}")
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    located = shutil.which(name)
    if located:
        return located
    raise SystemExit(f"{name} was not found. Install the pinned tools or pass its explicit path.")


def run_step(title: str, command: list[str], details: list[str]) -> None:
    """Runs a check, captures routine output, and stops on the first actionable failure."""
    started = time.perf_counter()
    environment = os.environ.copy()
    environment["HOME"] = str(Path.home())
    result = subprocess.run(command, cwd=ROOT, text=True, encoding="utf-8", errors="replace", capture_output=True, env=environment)
    elapsed = time.perf_counter() - started
    if result.returncode != 0:
        print(f"[FAIL] {title}")
        if result.stdout.strip():
            print(result.stdout.rstrip())
        if result.stderr.strip():
            print(result.stderr.rstrip())
        raise SystemExit(result.returncode)
    summary = result.stdout.strip().splitlines()
    suffix = f" - {summary[-1]}" if summary else ""
    print(f"[PASS] {title} ({elapsed:.2f}s){suffix}")
    details.append(f"- PASS: {title} ({elapsed:.2f}s){suffix}")


def compile_sources(compiler: str, details: list[str]) -> int:
    """Compiles every Luau source independently so one syntax error identifies its file."""
    files = sorted(ROOT.rglob("*.luau"))
    started = time.perf_counter()
    for path in files:
        result = subprocess.run([compiler, str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
        if result.returncode != 0:
            print(f"[FAIL] Luau compile: {path.relative_to(ROOT)}")
            print((result.stdout + result.stderr).rstrip())
            raise SystemExit(result.returncode)
    elapsed = time.perf_counter() - started
    print(f"[PASS] Luau compile ({elapsed:.2f}s) - {len(files)} files")
    details.append(f"- PASS: Luau compile ({elapsed:.2f}s) - {len(files)} files")
    return len(files)


def write_report(details: list[str], source_count: int, suite_count: int, elapsed: float) -> None:
    """Writes a small reviewable receipt for the last fully successful local release check."""
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    lines = [
        "# Release Check Report",
        "",
        f"Generated {timestamp} by tools/release_check.py.",
        "",
        f"Status: PASS",
        f"Elapsed: {elapsed:.2f} seconds",
        f"Luau sources compiled: {source_count}",
        f"Standalone suites: {suite_count}",
        "",
        "## Checks",
        "",
        *details,
        "",
        "Roblox Studio runtime, multiplayer, device, and published-place checks remain manual.",
        "",
    ]
    REPORT.write_text(chr(10).join(lines), encoding="utf-8")


def main() -> None:
    """Resolves local tools and runs the complete pre-Studio release gate."""
    parser = argparse.ArgumentParser(description="Compile, validate, audit, regenerate, and build the Roblox project.")
    parser.add_argument("--luau")
    parser.add_argument("--luau-compile")
    parser.add_argument("--rojo")
    args = parser.parse_args()

    local_temp = Path(os.environ.get("LOCALAPPDATA", "")) / "Temp" / "pet-rescue-luau-check"
    home = Path.home()
    os.environ.setdefault("HOME", str(home))
    luau = find_tool(args.luau, "luau", [local_temp / "luau.exe"])
    compiler = find_tool(args.luau_compile, "luau-compile", [local_temp / "luau-compile.exe"])
    rojo = find_tool(
        args.rojo,
        "rojo",
        [
            home / ".rokit" / "tool-storage" / "rojo-rbx" / "rojo" / "7.7.0" / "rojo.exe",
            home / ".rokit" / "bin" / "rojo.exe",
        ],
    )

    details: list[str] = []
    overall = time.perf_counter()
    source_count = compile_sources(compiler, details)

    suites = sorted((ROOT / "tests").glob("*.spec.luau"))
    for suite in suites:
        run_step(f"Standalone suite {suite.name}", [luau, str(suite)], details)

    run_step("Actual service regression harness", [sys.executable, str(ROOT / "tools" / "run_service_tests.py"), luau], details)
    run_step("Static pet asset audit", [sys.executable, str(ROOT / "tools" / "audit_pet_assets.py")], details)
    run_step("Balance report", [sys.executable, str(ROOT / "tools" / "simulate_balance.py")], details)
    run_step("World preview regeneration", [sys.executable, str(ROOT / "tools" / "build_world_preview.py"), luau], details)
    run_step("Rojo place build", [rojo, "build", "-o", str(ROOT / "Pet Rescue Shelter Tycoon.rbxlx")], details)
    run_step("World floor audit", [sys.executable, str(ROOT / "tools" / "audit_world.py")], details)

    elapsed = time.perf_counter() - overall
    write_report(details, source_count, len(suites), elapsed)
    print(f"[PASS] RELEASE READY FOR STUDIO QA ({elapsed:.2f}s)")
    print(f"Report: {REPORT}")


if __name__ == "__main__":
    main()


