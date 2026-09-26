"""Example: using mojo_csv from Python through the compiled bindings.

Requires python/mojo_csv_bind.so:
    pixi run build-python-bindings

Run:
    pixi run python python/example.py
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

import mojo_csv_bind as mojo_csv  # noqa: E402


def main():
    fixture = os.path.join("tests", "datablist", "organizations-1000.csv")

    # 1. Dimensions
    rows = mojo_csv.row_count(fixture)
    cols = mojo_csv.col_count(fixture)
    print(f"=== mojo_csv from Python ===")
    print(f"{fixture}: {rows} rows x {cols} cols")
    print()

    # 2. Headers
    headers = mojo_csv.headers(fixture)
    print("headers:")
    for i, h in enumerate(headers):
        print(f"  {i}: {h}")
    print()

    # 3. Reader type: parse once, then reuse the grid
    reader = mojo_csv.Reader(fixture)
    print("Reader 2D cells (parse once, reuse):")
    print("  reader.cell(1, 2) =", reader.cell(1, 2))
    print("  reader.get_row(3) =", reader.get_row(3))
    print()

    # 4. Dictionary rows (keyed by header)
    data = mojo_csv.dict_rows(fixture)
    print("first 2 dict rows:")
    for row in data[:2]:
        print(" ", row)
    print()

    # 5. Write cells to CSV, then read them back
    out_path = os.path.join("python", "example-out.csv")
    cells = ["name", "score", "alice", "95", "bob", "87"]
    written = mojo_csv.write_csv(cells, 2, out_path)
    print(f"wrote {written} rows to {out_path}:")
    with open(out_path) as f:
        print(" ", f.read().replace("\n", " | "))
    print("read back:", mojo_csv.parse_csv(out_path))
    os.remove(out_path)


if __name__ == "__main__":
    main()
