#!/usr/bin/env python3
"""Scoring engine for claude-code-auto-research.

Runs the target subagent against test fixtures, grades output against
expectations, and computes a composite quality score.

Output: JSON to stdout with total_score, breakdown, and failures.
"""

import json
import os
import subprocess
import sys
import re
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()


def load_config() -> dict:
    with open(SCRIPT_DIR / "config.json") as f:
        return json.load(f)


def load_expectations(config: dict) -> dict:
    expectations_path = SCRIPT_DIR / config.get("expectations_file", "evals/subagent-expectations.json")
    with open(expectations_path) as f:
        return json.load(f)


def resolve_path(relative_path: str) -> Path:
    return (SCRIPT_DIR / relative_path).resolve()


def get_target_name(config: dict) -> str:
    """Extract the subagent name from the target file path."""
    target_path = Path(config["target_file"])
    return target_path.stem  # e.g., "quality-reviewer"


def get_fixture_name(fixture_path: str) -> str:
    """Extract fixture name from path."""
    return Path(fixture_path).name  # e.g., "nextjs-app"


def read_target_file(config: dict) -> str:
    """Read the current content of the target subagent file."""
    target = resolve_path(config["target_file"])
    with open(target) as f:
        return f.read()


def read_fixture_context(fixture_path: str) -> str:
    """Read key files from a fixture to provide context."""
    fixture_dir = resolve_path(fixture_path)
    context_parts = []

    # Read key manifest files
    for name in ["package.json", "pyproject.toml", "Cargo.toml", "go.mod"]:
        manifest = fixture_dir / name
        if manifest.exists():
            with open(manifest) as f:
                context_parts.append(f"### {name}\n```\n{f.read()}\n```")

    # Read docker-compose if present
    for name in ["docker-compose.yml", "docker-compose.yaml"]:
        dc = fixture_dir / name
        if dc.exists():
            with open(dc) as f:
                context_parts.append(f"### {name}\n```\n{f.read()}\n```")

    # List all files
    all_files = []
    for root, dirs, files in os.walk(fixture_dir):
        dirs[:] = [d for d in dirs if d not in {"node_modules", ".git", "__pycache__"}]
        for fname in files:
            rel = os.path.relpath(os.path.join(root, fname), fixture_dir)
            all_files.append(rel)

    context_parts.append(f"### File listing\n```\n" + "\n".join(sorted(all_files)) + "\n```")

    return "\n\n".join(context_parts)


def grade_with_claude(subagent_output: str, expectations: list[str], model: str) -> dict:
    """Use Claude to grade whether output meets expectations."""
    prompt = f"""You are a grading agent. Given an output from a subagent and a list of expectations,
determine which expectations are MET and which are NOT MET.

## Subagent Output
{subagent_output}

## Expectations
{chr(10).join(f'{i+1}. {e}' for i, e in enumerate(expectations))}

## Instructions
For each expectation, output EXACTLY one line in this format:
EXPECTATION [number]: MET | NOT_MET | UNCLEAR — [brief reason]

Then output a final line:
SCORE: [number of MET] / [total expectations]

Be strict. If you cannot clearly see evidence that an expectation is met, mark it NOT_MET.
"""

    try:
        result = subprocess.run(
            ["claude", "-p", prompt, "--model", model, "--output-format", "text"],
            capture_output=True, text=True, timeout=120
        )

        if result.returncode != 0:
            return {"met": 0, "total": len(expectations), "details": [], "error": result.stderr[:200]}

        output = result.stdout
        met_count = 0
        details = []

        for i, expectation in enumerate(expectations):
            pattern = rf"EXPECTATION\s+{i+1}\s*:\s*[`*]*(MET|NOT_MET|UNCLEAR)[`*]*"
            match = re.search(pattern, output)
            status = match.group(1) if match else "UNCLEAR"
            if status == "MET":
                met_count += 1
            details.append({"expectation": expectation, "status": status})

        return {"met": met_count, "total": len(expectations), "details": details}

    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        return {"met": 0, "total": len(expectations), "details": [], "error": str(e)}


def run_subagent_on_fixture(config: dict, fixture_path: str) -> str:
    """Run the target subagent against a fixture and capture output."""
    target = resolve_path(config["target_file"])
    fixture_dir = resolve_path(fixture_path)
    fixture_context = read_fixture_context(fixture_path)

    # Read the subagent prompt
    with open(target) as f:
        subagent_prompt = f.read()

    # Build the test prompt
    test_prompt = f"""You are being tested as a subagent. Here is your system prompt:

---BEGIN SUBAGENT PROMPT---
{subagent_prompt}
---END SUBAGENT PROMPT---

Now, act according to the subagent prompt above. Here is the project context for a test fixture:

## Project: {get_fixture_name(fixture_path)}

{fixture_context}

## Generated Files to Review

Assume a scaffold run has produced the following files for this project. Generate a realistic review output as if you had received these generated files. Apply all your checks and produce your verdict.
"""

    model = config.get("model", "sonnet")

    try:
        result = subprocess.run(
            ["claude", "-p", test_prompt, "--model", model, "--output-format", "text"],
            capture_output=True, text=True, timeout=180
        )

        if result.returncode != 0:
            return f"ERROR: {result.stderr[:500]}"

        return result.stdout

    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        return f"ERROR: {e}"


def compute_structural_score(subagent_output: str) -> float:
    """Score structural quality of the subagent output (0-100)."""
    score = 0.0
    max_score = 100.0

    # Has a verdict
    if re.search(r"\*\*Verdict\*\*\s*:\s*(PASS|FAIL)", subagent_output):
        score += 20

    # Has quality score
    if re.search(r"\*\*Quality Score\*\*\s*:\s*\d+", subagent_output):
        score += 15

    # Has dimension scores table
    if re.search(r"Format Compliance|Specificity|Completeness|Structural Quality", subagent_output):
        score += 15

    # Has per-file results
    if re.search(r"Per-File Results|Status.*PASS|Status.*FAIL", subagent_output):
        score += 15

    # Has summary section
    if re.search(r"### Summary|Total files|Passed:|Failed:", subagent_output):
        score += 10

    # Reasonable length (not too short, not absurdly long)
    length = len(subagent_output)
    if 500 < length < 10000:
        score += 15
    elif 200 < length <= 500 or 10000 <= length < 20000:
        score += 8

    # Check references
    if re.search(r"Check \d+|Check \d+:", subagent_output):
        score += 10

    return min(score, max_score)


def compute_hallucination_score(subagent_output: str, fixture_name: str) -> float:
    """Score how well the output avoids hallucination (0-100)."""
    score = 100.0
    penalties = []

    # Penalize if it mentions frameworks not in the fixture
    fixture_frameworks = {
        "nextjs-app": {"next", "react", "prisma", "tailwind", "typescript"},
        "python-api": {"fastapi", "python", "pytest", "uvicorn"},
        "minimal": {"javascript", "node"},
    }

    wrong_frameworks = {
        "nextjs-app": {"django", "flask", "spring", "rails", "laravel"},
        "python-api": {"react", "next", "vue", "angular", "svelte"},
        "minimal": {"prisma", "django", "spring", "kubernetes"},
    }

    expected = fixture_frameworks.get(fixture_name, set())
    wrong = wrong_frameworks.get(fixture_name, set())

    output_lower = subagent_output.lower()
    for fw in wrong:
        if fw in output_lower:
            score -= 15
            penalties.append(f"Mentioned wrong framework: {fw}")

    # Penalize placeholder content
    if re.search(r"\[PROJECT_NAME\]|PLACEHOLDER|TODO:", subagent_output):
        score -= 20
        penalties.append("Contains placeholder text")

    return max(score, 0.0)


def measure(config: dict = None) -> dict:
    """Run the full measurement pipeline."""
    if config is None:
        config = load_config()

    target_name = get_target_name(config)
    expectations = load_expectations(config)
    target_expectations = expectations.get(target_name, {})

    weights = config.get("score_weights", {
        "expectation_pass_rate": 0.5,
        "structural_score": 0.3,
        "no_hallucination_rate": 0.2,
    })

    grading_model = config.get("grading_model", "haiku")
    runs_per = config.get("runs_per_iteration", 1)

    all_fixture_results = []
    total_expectation_score = 0
    total_structural_score = 0
    total_hallucination_score = 0
    fixture_count = 0
    all_failures = []

    for fixture_path in config["fixtures"]:
        fixture_name = get_fixture_name(fixture_path)
        fixture_expectations = target_expectations.get(fixture_name, [])

        if not fixture_expectations:
            print(f"  Skipping {fixture_name}: no expectations defined for {target_name}", file=sys.stderr)
            continue

        fixture_count += 1
        best_run = None
        best_score = -1

        for run_idx in range(runs_per):
            print(f"  Running {target_name} on {fixture_name} (run {run_idx + 1}/{runs_per})...", file=sys.stderr)

            # Run subagent
            output = run_subagent_on_fixture(config, fixture_path)

            if output.startswith("ERROR:"):
                all_failures.append({"fixture": fixture_name, "run": run_idx, "error": output})
                continue

            # Grade against expectations
            grade_result = grade_with_claude(output, fixture_expectations, grading_model)

            # Compute structural score
            struct_score = compute_structural_score(output)

            # Compute hallucination score
            halluc_score = compute_hallucination_score(output, fixture_name)

            # Composite for this run
            exp_rate = (grade_result["met"] / grade_result["total"] * 100) if grade_result["total"] > 0 else 0
            run_score = (
                weights["expectation_pass_rate"] * exp_rate +
                weights["structural_score"] * struct_score +
                weights["no_hallucination_rate"] * halluc_score
            )

            if run_score > best_score:
                best_score = run_score
                best_run = {
                    "fixture": fixture_name,
                    "expectation_pass_rate": exp_rate,
                    "structural_score": struct_score,
                    "hallucination_score": halluc_score,
                    "composite_score": run_score,
                    "grade_details": grade_result.get("details", []),
                    "failures": [
                        d["expectation"] for d in grade_result.get("details", [])
                        if d.get("status") != "MET"
                    ],
                }

        if best_run:
            all_fixture_results.append(best_run)
            total_expectation_score += best_run["expectation_pass_rate"]
            total_structural_score += best_run["structural_score"]
            total_hallucination_score += best_run["hallucination_score"]
            all_failures.extend([
                {"fixture": fixture_name, "expectation": f} for f in best_run["failures"]
            ])

    # Average across fixtures
    if fixture_count > 0:
        avg_expectation = total_expectation_score / fixture_count
        avg_structural = total_structural_score / fixture_count
        avg_hallucination = total_hallucination_score / fixture_count
    else:
        avg_expectation = avg_structural = avg_hallucination = 0

    total_score = (
        weights["expectation_pass_rate"] * avg_expectation +
        weights["structural_score"] * avg_structural +
        weights["no_hallucination_rate"] * avg_hallucination
    )

    result = {
        "total_score": round(total_score, 1),
        "breakdown": {
            "expectation_pass_rate": round(avg_expectation, 1),
            "structural_score": round(avg_structural, 1),
            "no_hallucination_rate": round(avg_hallucination, 1),
        },
        "weights": weights,
        "fixture_results": all_fixture_results,
        "failures": all_failures,
        "fixtures_evaluated": fixture_count,
        "target": get_target_name(config),
    }

    return result


def main() -> None:
    config = load_config()
    print(f"Measuring {get_target_name(config)} across {len(config['fixtures'])} fixtures...", file=sys.stderr)

    result = measure(config)

    # Output JSON to stdout (for programmatic consumption)
    print(json.dumps(result, indent=2))

    # Summary to stderr (for human readability)
    print(f"\n{'=' * 40}", file=sys.stderr)
    print(f"Total Score: {result['total_score']}/100", file=sys.stderr)
    print(f"  Expectation Pass Rate: {result['breakdown']['expectation_pass_rate']:.1f}%", file=sys.stderr)
    print(f"  Structural Score: {result['breakdown']['structural_score']:.1f}/100", file=sys.stderr)
    print(f"  No-Hallucination Rate: {result['breakdown']['no_hallucination_rate']:.1f}/100", file=sys.stderr)
    if result["failures"]:
        print(f"\nFailed expectations ({len(result['failures'])}):", file=sys.stderr)
        for f in result["failures"][:10]:
            if "expectation" in f:
                print(f"  - [{f['fixture']}] {f['expectation']}", file=sys.stderr)
            elif "error" in f:
                print(f"  - [{f['fixture']}] ERROR: {f['error'][:100]}", file=sys.stderr)


if __name__ == "__main__":
    main()
