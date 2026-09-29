# Mojo Csv

<!-- ![mojo_csv_logo](./mojo_csv_logo.png) -->
<image src='./mojo_csv_logo.png' width='900'/>

![language](https://img.shields.io/badge/language-mojo-orange)
![license](https://badgen.net/static/license/MIT/red)

Csv parsing library written in pure Mojo
- Note: temporarily dependent on Max for parrellelize

### Install

Add the Modular community channel (https://repo.prefix.dev/modular-community) to your pixi.toml file in the channels section.

```toml title:pixi.toml
channels = ["conda-forge", "https://conda.modular.com/max", "https://repo.prefix.dev/modular-community"]
```

```sh
pixi add mojo_csv
```

## CsvReader

By default uses all logical cores - 2
```mojo
 CsvReader(
    in_csv: Path,
    delimiter: String = ",",
    quotation_mark: String = '"',
    num_threads: Int = 0, # default = 0 = use all available cores - 2
 )
```

A reader can also be built from already-split cells -- a flat row-major
list, the same shape `CsvWriter` writes from. No scan runs; `col_count`
fixes the row layout, and `has_header` (default True) controls whether the
first row is treated as headers.

```mojo
from mojo_csv import CsvReader

def main() raises:
    var cells: List[String] = ["name", "note", "Ada", "first"]
    var reader = CsvReader(cells, col_count=2)
    print(reader.row_count, reader.col_count) # 2 2
```

```mojo
from mojo_csv import CsvReader
from std.pathlib import Path

def main() raises:
    var csv_path = Path("path/to/csv/file.csv")
    var reader = CsvReader(csv_path)
    print(len(reader)) # total element count
```

### 2D indexing

The grid is row-major: `reader[row, col]` returns the cell at that position.

```mojo
reader[0, 0]          # first cell
reader[2, 5]          # third row, sixth column
```

### Iterating rows

`for row in reader:` yields row views. A row view shares the reader's parsed
cells (cheap to copy) and can be indexed by column.

```mojo
for row in reader:
    print(row[0], row[1])  # cells by column
```

Row views are also available explicitly:

```mojo
var row = reader.row(2)     # third row
print(len(row))             # number of columns in the row
print(repr(row))            # ['a', 'b', 'c']
print(row[0])               # first cell of row 2
```

Out-of-bounds row/col access raises an `Error`.

### Attributes

```mojo
reader.raw : String # raw csv string
reader.raw_length : Int # total number of bytes
reader.headers : List[String] # first row of csv file
reader.row_count : Int  # total number of rows T->B
reader.col_count : Int # total number of columns L->R
reader.elements : List[String] # all delimited elements
reader.length : Int # total number of elements
```

### Delimiters

```mojo
    CsvReader(csv_path, delimiter=";", quotation_mark='|')
```

### Threads
__force single threaded__
```mojo
CsvReader(csv_path, num_threads = 1)
```
__use all the threads__
```mojo
from std.sys import num_logical_cores

var reader = CsvReader(
    csv_path, num_threads = num_logical_cores()
)
```

## DictCsvReader

Reads a CSV as rows of dicts keyed by the header row. All rows share one
refcounted header list, so rows are cheap to copy.

```mojo
from mojo_csv import DictCsvReader
from std.pathlib import Path

def main() raises:
    var dr = DictCsvReader(
        in_csv: Path,
        delimiter: String = ",",
        quotation_mark: String = '"',
        num_threads: Int = 0,
    )

    for row in dr:
        print(row.get("name"), row.get("score"))
```

```mojo
row.get(key : String) raises -> String # value for a header key
row.get_at(idx : Int) raises -> String # value by column position
row.keys() -> List[String] # header names (copy)
row.vals() -> List[String] # row values (copy)
row.col_count() -> Int
```

## CsvWriter

Encodes cells per CSV rules (quotes doubled, fields quoted when they contain
the delimiter, quotes, or newlines). Fields that are already quoted are left
as-is. Threaded by default (uses logical cores - 2).

```mojo
CsvWriter(
    frame: List[String],       # flat cells: row-major, col_count per row
    delimiter: String = ",",
    quotation_mark: String = '"',
    num_threads: Int = 0,
) raises

writer.write(
    out_csv: Path,
    col_count: Int,
    include_trailing_newline: Bool = False,
) raises
```

```mojo
from mojo_csv import CsvWriter
from std.pathlib import Path

def main() raises:
    var cells: List[String] = ["name", "score", "alice", "95", "bob", "87"]
    var writer = CsvWriter(cells)
    writer.write(Path("out.csv"), col_count=2, include_trailing_newline=True)
```

## Python interop

Build the compiled bindings, then use `mojo_csv` from Python:
(Currently this is slower the python's stdlib csv parser with the ffi translation)

```sh
pixi run build-python-bindings
pixi run test-python        # runs the binding tests
pixi run example-python     # runs the example below
```

`python/mojo_csv_bind.mojo` exposes a small CPython extension module
(`python/mojo_csv_bind.so`) built with `mojo build --emit shared-lib`:

```python
import mojo_csv_bind as mojo_csv

# one-shot helpers (each parses the file)
cells = mojo_csv.parse_csv("data.csv")          # flat list[str]
rows = mojo_csv.row_count("data.csv")           # int
cols = mojo_csv.col_count("data.csv")           # int
cell = mojo_csv.cell("data.csv", 1, 2)          # reader[row, col]
headers = mojo_csv.headers("data.csv")          # list[str]
data = mojo_csv.dict_rows("data.csv")           # list[dict[str, str]]
rows = mojo_csv.write_csv(cells, cols, "out.csv")  # returns row count

# Reader type: parse once, then reuse the grid (recommended for repeated access)
reader = mojo_csv.Reader("data.csv")
reader = mojo_csv.Reader("data.csv", 8)         # optional thread count
reader.row_count()                              # int
reader.col_count()                              # int
reader.length()                                 # total cells
reader.cell(1, 2)                               # cell at row, col
reader.get_row(3)                               # list[str] for one row
reader.headers()                                # list[str]
reader.all_cells()                              # flat list[str]
```

Compare against Python's `csv` module:

```sh
pixi run bench-python
```

Missing files raise `File not found: <path>` (Mojo errors propagate as Python
exceptions).

## Performance
__See BENCHMARK.md__


## Development

```sh
pixi run test              # reader correctness + methods (2D, iteration)
pixi run test-dict         # DictCsvReader
pixi run test-writer       # CsvWriter (quoting, threaded vs single, roundtrip)
pixi run test-parser-edge  # CRLF, quoted fields, no trailing newline, custom delimiters
pixi run test-2d           # 2D indexing + row views + iteration
pixi run test-python       # Python bindings
pixi run bench             # size benchmarks (see BENCHMARK.md)
pixi run pack              # precompile src into dist/mojo_csv.mojoc
```

## Future Improvements

- [x] 2D indexing
- [x] CsvWriter
- [x] CsvDictReader
- [x] Python bindings
- [x] SIMD optimization within each thread
- [ ] Async Chunking (waiting for language support)
- [ ] Streaming support for very large files
- [ ] Memory pool for reduced allocations
- [ ] Progress callbacks for long-running operation
