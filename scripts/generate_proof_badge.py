#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


TOTAL_LINE_RE = re.compile(
    r"^Total\s+(\d+)\s+(\d+)\s+\([^)]*\)\s+(\d+)\s+\([^)]*\)\s+(\S+)\s+(\S+)\s*$"
)


def parse_summary(summary_text: str) -> tuple[int, int, int, int, int]:
    for raw_line in summary_text.splitlines():
        line = raw_line.strip()
        if not line.startswith("Total"):
            continue

        match = TOTAL_LINE_RE.match(line)
        if match:
            total = int(match.group(1))
            flow = int(match.group(2))
            prover = int(match.group(3))
            justified_token = match.group(4)
            unproved_token = match.group(5)
        else:
            tokens = line.split()
            if len(tokens) < 8:
                continue
            total = int(tokens[1])
            flow = int(tokens[2])
            prover = int(tokens[4])
            justified_token = tokens[-2]
            unproved_token = tokens[-1]

        justified = 0 if justified_token == "." else int(justified_token)
        unproved = 0 if unproved_token == "." else int(unproved_token)
        return total, flow, prover, justified, unproved

    raise ValueError("Could not parse 'Total' line from gnatprove summary")


def coverage_message(proved: int, total: int) -> str:
    if total == 0:
        return "n/a"

    ratio = (proved * 100.0) / total
    if ratio.is_integer():
        ratio_str = f"{int(ratio)}%"
    else:
        ratio_str = f"{ratio:.1f}%"

    return f"{ratio_str} ({proved}/{total})"


def coverage_color(proved: int, total: int, unproved: int) -> str:
    if total == 0:
        return "lightgrey"
    if unproved == 0:
        return "brightgreen"
    if proved * 100 >= total * 95:
        return "yellow"
    return "red"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate Shields endpoint JSON from gnatprove summary"
    )
    parser.add_argument("--input", required=True, help="Path to gnatprove.out")
    parser.add_argument("--output", required=True, help="Path to proof badge JSON")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    total, flow, prover, justified, unproved = parse_summary(
        input_path.read_text(encoding="utf-8")
    )
    proved = total - unproved

    badge = {
        "schemaVersion": 1,
        "label": "proof",
        "message": coverage_message(proved, total),
        "color": coverage_color(proved, total, unproved),
        "cacheSeconds": 300,
        "isError": unproved > 0,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(badge, indent=2) + "\n", encoding="utf-8")

    print(
        f"Generated proof badge: total={total}, flow={flow}, prover={prover}, justified={justified}, unproved={unproved}"
    )


if __name__ == "__main__":
    main()
