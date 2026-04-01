#!/usr/bin/env python3
"""One-time setup for claude-code-auto-research.

Validates configuration, snapshots the baseline version of the target file,
and runs an initial eval to establish a baseline score.
"""

import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()


def load_config():
    config_path = SCRIPT_DIR / "config.json"
    if not config_path.exists():
        print("ERROR: config.json not found")
        sys.exit(1)
    with open(config_path) as f:
        return json.load(f)


def resolve_path(relative_path: str) -> Path:
    """Resolve a path relative to the script directory."""
    return (SCRIPT_DIR / relative_path).resolve()


def validate_config(config: dict):
    """Validate that all referenced files and directories exist."""
    errors = []

    target = resolve_path(config["target_file"])
    if not target.exists():
        errors.append(f"Target file not found: {target}")

    for fixture in config["fixtures"]:
        fixture_path = resolve_path(fixture)
        if not fixture_path.exists():
            errors.append(f"Fixture not found: {fixture_path}")

    eval_source = resolve_path(config["eval_source"])
    if not eval_source.exists():
        errors.append(f"Eval source not found: {eval_source}")

    expectations = SCRIPT_DIR / config.get("expectations_file", "evals/subagent-expectations.json")
    if not expectations.exists():
        errors.append(f"Expectations file not found: {expectations}")

    if errors:
        print("Validation errors:")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)

    print("All paths validated successfully.")


def snapshot_baseline(config: dict):
    """Copy the target file to snapshots/baseline/."""
    target = resolve_path(config["target_file"])
    baseline_dir = SCRIPT_DIR / "snapshots" / "baseline"
    baseline_dir.mkdir(parents=True, exist_ok=True)

    dest = baseline_dir / target.name
    shutil.copy2(target, dest)
    print(f"Baseline snapshot saved: {dest}")

    # Also copy to best/ as initial best
    best_dir = SCRIPT_DIR / "snapshots" / "best"
    best_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(target, best_dir / target.name)
    print(f"Initial best snapshot saved: {best_dir / target.name}")


def check_claude_cli():
    """Verify that the claude CLI is available."""
    try:
        result = subprocess.run(
            ["claude", "--version"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            print(f"Claude CLI found: {result.stdout.strip()}")
            return True
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    print("WARNING: 'claude' CLI not found. The autonomous loop requires it.")
    print("Install it with: npm install -g @anthropic-ai/claude-code")
    return False


def run_baseline_eval(config: dict):
    """Run measure.py to get the baseline score."""
    print("\nRunning baseline evaluation...")
    result = subprocess.run(
        [sys.executable, str(SCRIPT_DIR / "measure.py")],
        capture_output=True, text=True, timeout=300
    )

    if result.returncode != 0:
        print(f"Baseline eval failed: {result.stderr}")
        print("You can run the baseline eval later with: python measure.py")
        return None

    try:
        scores = json.loads(result.stdout)
        total = scores.get("total_score", 0)
        print(f"Baseline score: {total:.1f}/100")

        # Write initial results.tsv
        results_path = SCRIPT_DIR / "results.tsv"
        with open(results_path, "w") as f:
            f.write("iteration\ttimestamp\tscore\tdelta\tchange_summary\tstatus\n")
            ts = datetime.now(timezone.utc).isoformat(timespec="seconds")
            f.write(f"0\t{ts}\t{total:.1f}\t0\tbaseline\tBASELINE\n")

        print(f"Results log initialized: {results_path}")
        return total
    except (json.JSONDecodeError, KeyError) as e:
        print(f"Could not parse baseline score: {e}")
        print(f"Raw output: {result.stdout[:500]}")
        return None


def read_program():
    """Read and display the optimization program."""
    program_path = SCRIPT_DIR / "program.md"
    if not program_path.exists():
        print("WARNING: program.md not found. Create it to define your optimization strategy.")
        return

    with open(program_path) as f:
        content = f.read()

    print("\n" + "=" * 60)
    print("OPTIMIZATION PROGRAM")
    print("=" * 60)
    print(content)
    print("=" * 60)


def main():
    print("=" * 60)
    print("Claude Code Auto-Research — Setup")
    print("=" * 60)
    print()

    config = load_config()

    # Step 1: Validate
    print("Step 1: Validating configuration...")
    validate_config(config)
    print()

    # Step 2: Check CLI
    print("Step 2: Checking claude CLI...")
    check_claude_cli()
    print()

    # Step 3: Snapshot baseline
    print("Step 3: Snapshotting baseline...")
    snapshot_baseline(config)
    print()

    # Step 4: Show program
    print("Step 4: Reading optimization program...")
    read_program()
    print()

    # Step 5: Baseline eval
    print("Step 5: Running baseline evaluation...")
    baseline_score = run_baseline_eval(config)
    print()

    # Summary
    print("=" * 60)
    print("SETUP COMPLETE")
    print("=" * 60)
    print()
    print("Next steps:")
    print("  1. Review/edit program.md with your optimization goals")
    print("  2. Review/edit config.json for loop settings")
    print("  3. Run: python run.py")
    print()
    if baseline_score is not None:
        print(f"Baseline score: {baseline_score:.1f}/100")
    else:
        print("Baseline score: not yet established (run python measure.py)")


if __name__ == "__main__":
    main()
