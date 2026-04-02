#!/usr/bin/env python3
"""Progress report generator for claude-code-auto-research.

Reads results.tsv and prints a summary of the optimization run.
"""

import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()


def load_results() -> list[dict]:
    results_path = SCRIPT_DIR / "results.tsv"
    if not results_path.exists():
        return []

    results = []
    with open(results_path) as f:
        header = f.readline()
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


def print_progress(results: list[dict]) -> None:
    if not results:
        print("No results yet. Run 'python prepare.py' then 'python run.py' to start.")
        return

    baseline = next((r for r in results if r["status"] == "BASELINE"), None)
    kept = [r for r in results if r["status"] == "KEPT"]
    discarded = [r for r in results if r["status"] == "DISCARDED"]
    errors = [r for r in results if r["status"] == "ERROR"]
    kept_or_baseline = [r for r in results if r["status"] in ("KEPT", "BASELINE")]
    best = max(kept_or_baseline, key=lambda r: r["score"]) if kept_or_baseline else None

    print("=" * 70)
    print("Claude Code Auto-Research — Progress Report")
    print("=" * 70)

    # Score progression
    print("\n## Score Progression\n")
    print(f"{'Iter':>4}  {'Score':>7}  {'Delta':>7}  {'Status':>10}  Change")
    print("-" * 70)
    for r in results:
        status_icon = {
            "BASELINE": "BASE",
            "KEPT": "KEPT",
            "DISCARDED": "DROP",
            "ERROR": "ERR!",
        }.get(r["status"], r["status"])

        print(f"{r['iteration']:>4}  {r['score']:>7.1f}  {r['delta']:>7}  {status_icon:>10}  {r['change_summary'][:40]}")

    # ASCII chart
    if len(results) > 1:
        print("\n## Score Chart\n")
        scores = [r["score"] for r in results]
        min_s = min(scores)
        max_s = max(scores)
        chart_width = 50

        if max_s > min_s:
            for r in results:
                bar_len = int((r["score"] - min_s) / (max_s - min_s) * chart_width)
                bar = "█" * bar_len
                marker = " ◄ best" if r["score"] == best["score"] and r["status"] != "DISCARDED" else ""
                status_char = "✓" if r["status"] in ("KEPT", "BASELINE") else "✗" if r["status"] == "DISCARDED" else "!"
                print(f"  {r['iteration']:>3} {status_char} |{bar} {r['score']:.1f}{marker}")
        else:
            print(f"  All scores are {scores[0]:.1f}")

    # Summary stats
    print("\n## Summary\n")
    if baseline:
        print(f"  Baseline score:    {baseline['score']:.1f}")
    if best:
        print(f"  Best score:        {best['score']:.1f} (iteration {best['iteration']})")
    if baseline and best:
        improvement = best["score"] - baseline["score"]
        print(f"  Total improvement: {improvement:+.1f}")
    print(f"  Iterations run:    {len(results) - (1 if baseline else 0)}")
    print(f"  Changes kept:      {len(kept)}")
    print(f"  Changes discarded: {len(discarded)}")
    if errors:
        print(f"  Errors:            {len(errors)}")
    if results:
        acceptance_rate = len(kept) / max(len(kept) + len(discarded), 1) * 100
        print(f"  Acceptance rate:   {acceptance_rate:.0f}%")

    # Best version info
    best_dir = SCRIPT_DIR / "snapshots" / "best"
    best_files = list(best_dir.glob("*.md")) if best_dir.exists() else []
    if best_files:
        print(f"\n  Best version saved: {best_files[0]}")
        print(f"  Apply with: python run.py --apply-best")

    print()


def main() -> None:
    results = load_results()
    print_progress(results)


if __name__ == "__main__":
    main()
