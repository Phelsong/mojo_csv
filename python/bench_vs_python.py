"""Benchmark: Python csv module vs mojo_csv (regular CsvReader).

5-iteration averages. Run: pixi run bench-python
Requires python/mojo_csv_bind.so (pixi run build-python-bindings).
"""

import csv
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

import mojo_csv_bind as mojo_csv  # noqa: E402

SIZES = [
    ("mini", os.path.join("tests", "datablist", "leads-100.csv")),
    ("small", os.path.join("tests", "datablist", "organizations-1000.csv")),
    ("medium", os.path.join("tests", "datablist", "people-100000.csv")),
    ("large", os.path.join("tests", "datablist", "products-2000000.csv")),
]
ITERATIONS = 5


def bench_python_csv(path: str, materialize: bool = False) -> float:
    """Read + iterate every cell with the stdlib csv module (ms).

    materialize=True collects all rows into a list of lists, matching the
    bulk Mojo call which returns a fully materialized Python list.
    """
    total = 0.0
    for _ in range(ITERATIONS):
        t0 = time.perf_counter()
        if materialize:
            with open(path, newline="") as f:
                rows = list(csv.reader(f))
            count = sum(len(r) for r in rows)
        else:
            count = 0
            with open(path, newline="") as f:
                for row in csv.reader(f):
                    for _cell in row:
                        count += 1
        t1 = time.perf_counter()
        assert count > 0
        total += (t1 - t0) * 1000
    return total / ITERATIONS


def bench_mojo_csv_bulk(path: str) -> float:
    """Read + collect every cell in one Mojo call (ms)."""
    total = 0.0
    for _ in range(ITERATIONS):
        t0 = time.perf_counter()
        cells = mojo_csv.parse_csv(path)
        t1 = time.perf_counter()
        assert len(cells) > 0
        total += (t1 - t0) * 1000
    return total / ITERATIONS


def bench_mojo_csv_rows(path: str) -> float:
    """Read once, then iterate rows via per-row FFI calls (ms)."""
    total = 0.0
    for _ in range(ITERATIONS):
        t0 = time.perf_counter()
        reader = mojo_csv.Reader(path)
        count = 0
        for r in range(reader.row_count()):
            for _c in reader.get_row(r):
                count += 1
        t1 = time.perf_counter()
        assert count > 0
        total += (t1 - t0) * 1000
    return total / ITERATIONS


def main():
    print("=== python csv vs mojo_csv (regular reader) ===")
    print(f"{ITERATIONS} iterations per measurement, average ms")
    print("mojo_csv parse itself is native-speed (medium ~15ms, large ~750ms;")
    print("see BENCHMARK.md); the columns below include Python-side overhead")
    print("for materializing/iterating Python objects across the FFI boundary.")
    print()
    print(
        f"{'size':<8} {'py stream':>10} {'py bulk':>10} {'mojo row-iter':>15} "
        f"{'mojo bulk':>12} {'speedup':>20}"
    )
    for name, path in SIZES:
        if not os.path.exists(path):
            print(f"{name:<8} (missing fixture: {path})")
            continue
        py_stream = bench_python_csv(path)
        py_bulk = bench_python_csv(path, materialize=True)
        mojo_rows = bench_mojo_csv_rows(path)
        mojo_bulk = bench_mojo_csv_bulk(path)
        print(
            f"{name:<8} {py_stream:>10.2f}ms {py_bulk:>10.2f}ms "
            f"{mojo_rows:>13.2f}ms {mojo_bulk:>10.2f}ms "
            f"{py_stream / mojo_bulk:>7.1f}x (stream) / "
            f"{py_bulk / mojo_bulk:>4.1f}x (bulk)"
        )


if __name__ == "__main__":
    main()
