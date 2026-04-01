#!/usr/bin/env python3
"""Autonomous optimization loop for claude-code-auto-research.

The core autoresearch loop: read program → propose modification →
measure → keep/discard → repeat.

Usage:
    python run.py                    # Run the optimization loop
    python run.py --apply-best       # Copy best version back to target
    python run.py --dry-run          # Show what would happen without making changes
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()


def load_config():
    with open(SCRIPT_DIR / "config.json") as f:
        return json.load(f)


def resolve_path(relative_path: str) -> Path:
    return (SCRIPT_DIR / relative_path).resolve()


def read_file(path: Path) -> str:
    with open(path) as f:
        return f.read()


def write_file(path: Path, content: str):
    with open(path, "w") as f:
        f.write(content)


def load_results() -> list[dict]:
    """Load previous results from results.tsv."""
    results_path = SCRIPT_DIR / "results.tsv"
    if not results_path.exists():
        return []

    results = []
    with open(results_path) as f:
        header = f.readline()  # skip header
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) >= 6:
                results.append({
                    "iteration": int(parts[0]),
                    "timestamp": parts[1],
                    "score": float(parts[2]),
                    "delta": parts[3],
                    "change_summary": parts[4],
                    "status": parts[5],
                })
    return results


def append_result(iteration: int, score: float, delta: float, summary: str, status: str):
    """Append a result to results.tsv."""
    results_path = SCRIPT_DIR / "results.tsv"
    if not results_path.exists():
        with open(results_path, "w") as f:
            f.write("iteration\ttimestamp\tscore\tdelta\tchange_summary\tstatus\n")

    ts = datetime.now(timezone.utc).isoformat(timespec="seconds")
    delta_str = f"+{delta:.1f}" if delta >= 0 else f"{delta:.1f}"
    # Escape tabs/newlines in summary
    safe_summary = summary.replace("\t", " ").replace("\n", " ")[:200]

    with open(results_path, "a") as f:
        f.write(f"{iteration}\t{ts}\t{score:.1f}\t{delta_str}\t{safe_summary}\t{status}\n")


def get_best_score(results: list[dict]) -> float:
    """Get the best score from results history."""
    if not results:
        return 0.0
    kept = [r for r in results if r["status"] in ("KEPT", "BASELINE")]
    return max((r["score"] for r in kept), default=0.0)


def run_measure() -> dict:
    """Run measure.py and return the parsed result."""
    result = subprocess.run(
        [sys.executable, str(SCRIPT_DIR / "measure.py")],
        capture_output=True, text=True, timeout=600
    )

    if result.returncode != 0:
        raise RuntimeError(f"measure.py failed: {result.stderr[:500]}")

    return json.loads(result.stdout)


def propose_modification(config: dict, current_content: str, results: list[dict],
                         last_failures: list[dict], program: str) -> tuple[str, str]:
    """Ask Claude to propose a modification to the target file.

    Returns: (new_content, change_summary)
    """
    # Build context about what's been tried
    history_lines = []
    for r in results[-10:]:  # Last 10 results
        history_lines.append(f"  Iteration {r['iteration']}: {r['score']} ({r['status']}) — {r['change_summary']}")

    history_context = "\n".join(history_lines) if history_lines else "  No previous iterations."

    # Build failure context
    failure_lines = []
    for f in last_failures[:15]:
        if "expectation" in f:
            failure_lines.append(f"  - [{f.get('fixture', '?')}] {f['expectation']}")
    failure_context = "\n".join(failure_lines) if failure_lines else "  No specific failures recorded."

    prompt = f"""You are an autonomous research agent optimizing a subagent prompt.

## Optimization Program
{program}

## Current Version of the Target File
```markdown
{current_content}
```

## Experiment History
{history_context}

## Current Failures (expectations NOT met)
{failure_context}

## Your Task
Propose a MODIFICATION to the target file that will improve the score.

Rules:
1. Output the COMPLETE modified file content (not a diff)
2. Make ONE focused change per iteration (not a complete rewrite)
3. Don't repeat changes that were already tried and DISCARDED
4. Focus on fixing the specific failures listed above
5. Keep the overall structure and output format intact
6. The file must remain a valid markdown file with YAML frontmatter

## Output Format
First, write a one-line summary of what you're changing:
CHANGE: [summary]

Then output the complete modified file between these markers:
---BEGIN FILE---
[complete file content]
---END FILE---
"""

    model = config.get("model", "sonnet")

    result = subprocess.run(
        ["claude", "-p", prompt, "--model", model, "--output-format", "text"],
        capture_output=True, text=True, timeout=180
    )

    if result.returncode != 0:
        raise RuntimeError(f"Claude proposal failed: {result.stderr[:500]}")

    output = result.stdout

    # Extract change summary
    import re
    change_match = re.search(r"CHANGE:\s*(.+)", output)
    change_summary = change_match.group(1).strip() if change_match else "Unknown modification"

    # Extract file content
    file_match = re.search(r"---BEGIN FILE---\s*\n(.*?)---END FILE---", output, re.DOTALL)
    if not file_match:
        raise RuntimeError("Could not extract modified file from Claude's response")

    new_content = file_match.group(1).strip() + "\n"

    return new_content, change_summary


def apply_best(config: dict):
    """Copy the best version back to the target location."""
    target = resolve_path(config["target_file"])
    best_dir = SCRIPT_DIR / "snapshots" / "best"
    best_file = best_dir / target.name

    if not best_file.exists():
        print("ERROR: No best version found. Run the optimization loop first.")
        sys.exit(1)

    # Show diff
    print(f"Applying best version to: {target}")
    print()

    # Backup current
    backup = target.with_suffix(".md.bak")
    shutil.copy2(target, backup)
    print(f"Backup saved to: {backup}")

    # Copy best
    shutil.copy2(best_file, target)
    print(f"Best version applied successfully.")

    # Load results to show score
    results = load_results()
    if results:
        best = max((r for r in results if r["status"] in ("KEPT", "BASELINE")),
                    key=lambda r: r["score"], default=None)
        baseline = next((r for r in results if r["status"] == "BASELINE"), None)
        if best and baseline:
            print(f"\nScore improvement: {baseline['score']} → {best['score']} "
                  f"(+{best['score'] - baseline['score']:.1f})")


def run_loop(config: dict, dry_run: bool = False):
    """The main autonomous optimization loop."""
    target = resolve_path(config["target_file"])
    max_iterations = config.get("max_iterations", 10)
    max_no_improvement = config.get("max_no_improvement", 3)

    # Read program
    program_path = SCRIPT_DIR / "program.md"
    program = read_file(program_path) if program_path.exists() else "No optimization program defined."

    # Load history
    results = load_results()
    best_score = get_best_score(results)
    next_iteration = max((r["iteration"] for r in results), default=-1) + 1
    no_improvement_count = 0

    # Count consecutive non-improvements from history
    for r in reversed(results):
        if r["status"] == "DISCARDED":
            no_improvement_count += 1
        else:
            break

    print("=" * 60)
    print("Claude Code Auto-Research — Optimization Loop")
    print("=" * 60)
    print(f"Target: {target.name}")
    print(f"Best score so far: {best_score:.1f}")
    print(f"Starting at iteration: {next_iteration}")
    print(f"Max iterations: {max_iterations}")
    print(f"Stale limit: {max_no_improvement} consecutive non-improvements")
    print(f"No-improvement streak: {no_improvement_count}")
    if dry_run:
        print("\n*** DRY RUN — no changes will be made ***")
    print("=" * 60)

    last_failures = []

    for i in range(next_iteration, next_iteration + max_iterations):
        print(f"\n--- Iteration {i} ---")

        # Check stale limit
        if no_improvement_count >= max_no_improvement:
            print(f"\nStopping: no improvement for {no_improvement_count} consecutive iterations.")
            break

        # Read current content
        current_content = read_file(target)

        # Propose modification
        print("Proposing modification...")
        try:
            new_content, change_summary = propose_modification(
                config, current_content, results, last_failures, program
            )
        except RuntimeError as e:
            print(f"Proposal failed: {e}")
            append_result(i, best_score, 0, f"PROPOSAL_FAILED: {e}", "ERROR")
            continue

        print(f"Change: {change_summary}")

        if dry_run:
            print("[DRY RUN] Would apply modification and measure. Skipping.")
            continue

        # Apply modification
        write_file(target, new_content)

        # Measure
        print("Measuring...")
        try:
            measurement = run_measure()
            score = measurement["total_score"]
            last_failures = measurement.get("failures", [])
        except (RuntimeError, json.JSONDecodeError) as e:
            print(f"Measurement failed: {e}")
            # Restore previous version
            write_file(target, current_content)
            append_result(i, best_score, 0, f"MEASURE_FAILED: {change_summary}", "ERROR")
            continue

        delta = score - best_score
        print(f"Score: {score:.1f} (delta: {delta:+.1f})")

        # Keep or discard
        if score >= best_score:
            print(f"KEPT (score improved or maintained: {best_score:.1f} → {score:.1f})")
            best_score = score
            no_improvement_count = 0

            # Save to snapshots/best/
            best_dir = SCRIPT_DIR / "snapshots" / "best"
            best_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, best_dir / target.name)

            append_result(i, score, delta, change_summary, "KEPT")
            results.append({
                "iteration": i, "score": score, "delta": str(delta),
                "change_summary": change_summary, "status": "KEPT",
            })
        else:
            print(f"DISCARDED (score decreased: {best_score:.1f} → {score:.1f})")
            no_improvement_count += 1

            # Restore previous version
            write_file(target, current_content)

            append_result(i, score, delta, change_summary, "DISCARDED")
            results.append({
                "iteration": i, "score": score, "delta": str(delta),
                "change_summary": change_summary, "status": "DISCARDED",
            })

    # Final summary
    print("\n" + "=" * 60)
    print("OPTIMIZATION COMPLETE")
    print("=" * 60)
    baseline_score = next((r["score"] for r in results if r["status"] == "BASELINE"), 0)
    kept_count = sum(1 for r in results if r["status"] == "KEPT")
    discarded_count = sum(1 for r in results if r["status"] == "DISCARDED")

    print(f"Baseline score: {baseline_score:.1f}")
    print(f"Best score: {best_score:.1f}")
    print(f"Improvement: {best_score - baseline_score:+.1f}")
    print(f"Iterations: {kept_count} kept, {discarded_count} discarded")
    print(f"\nBest version saved in: snapshots/best/{target.name}")
    print(f"To apply: python run.py --apply-best")


def main():
    parser = argparse.ArgumentParser(description="Claude Code Auto-Research — Optimization Loop")
    parser.add_argument("--apply-best", action="store_true", help="Copy best version to target")
    parser.add_argument("--dry-run", action="store_true", help="Show what would happen without changes")
    args = parser.parse_args()

    config = load_config()

    if args.apply_best:
        apply_best(config)
    else:
        run_loop(config, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
