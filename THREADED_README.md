# Multi-threaded CSV Reader

The `ThreadedCsvReader` provides parallel CSV parsing capabilities for improved performance on large files.

## Quick Start

```mojo
from src.threaded_csv_reader import ThreadedCsvReader
from pathlib import Path

fn main():
    var csv_path = Path("data.csv")
    var reader = ThreadedCsvReader(csv_path)  # Uses all available CPU cores
    
    print("Rows:", reader.row_count)
    print("Columns:", reader.col_count)
    
    # Access data same as regular CsvReader
    for i in range(len(reader)):
        print(reader[i])
```

## Constructor Options

```mojo
ThreadedCsvReader(
    file_path: Path,
    delimiter: String = ",",
    quotation_mark: String = '"',
    num_threads: Int = 0  # 0 = use all available cores
)
```

### Parameters

- **file_path**: Path to the CSV file
- **delimiter**: Column separator (default: comma)
- **quotation_mark**: Quote character for escaping (default: double quote)
- **num_threads**: Number of threads to use:
  - `0`: Use all available CPU cores (default)
  - `1`: Force single-threaded execution
  - `N`: Use exactly N threads

## Performance

### Benchmarks

Performance comparison on various file sizes (average of multiple runs):

| File Size | Single-threaded | Multi-threaded | Speedup |
|-----------|----------------|----------------|---------|
| 1,000 rows | 1.42ms | 1.30ms | 1.09x |
| 100,000 rows | 125ms | 105ms | 1.19x |

*Tested on AMD 7950x (16 cores) @ 5.8GHz*

### When to Use Multi-threading

- **Recommended**: Files > 10KB
- **Automatic fallback**: Small files automatically use single-threaded parsing
- **Best performance**: Files with many rows (>1000 rows)

## Implementation Details

### Parallel Strategy

1. **File Analysis**: Scan for safe split points (newlines outside quoted fields)
2. **Chunk Creation**: Divide file into roughly equal chunks per thread
3. **Parallel Processing**: Each thread processes its chunk independently
4. **Result Merging**: Combine results while preserving order

### Thread Safety

- ✅ **Safe**: Reading from multiple threads after construction
- ❌ **Unsafe**: Modifying the reader from multiple threads
- ✅ **Safe**: Multiple `ThreadedCsvReader` instances in different threads

### Correctness

The threaded implementation produces identical results to the single-threaded version:
- Same element count and ordering
- Same row/column counts
- Same header extraction
- Proper handling of quoted fields spanning multiple lines

## API Compatibility

`ThreadedCsvReader` is a drop-in replacement for `CsvReader` with identical interface:

```mojo
// All these work the same way
reader[index]           // Access elements by index
reader.headers         // Column headers
reader.row_count       // Number of rows
reader.col_count       // Number of columns
len(reader)           // Total elements
for element in reader  // Iteration support
```

## Usage Examples

### Example 1: Default (All Cores)
```mojo
var reader = ThreadedCsvReader(Path("large_file.csv"))
// Uses all 16 cores on a 16-core system
```

### Example 2: Custom Thread Count
```mojo
var reader = ThreadedCsvReader(Path("data.csv"), num_threads=4)
// Uses exactly 4 threads
```

### Example 3: Single-threaded
```mojo
var reader = ThreadedCsvReader(Path("data.csv"), num_threads=1)
// Forces single-threaded execution (same as CsvReader)
```

### Example 4: Custom Delimiter
```mojo
var reader = ThreadedCsvReader(
    Path("pipe_separated.csv"),
    delimiter="|",
    num_threads=8
)
```

## Error Handling

The threaded reader handles the same error conditions as the single-threaded version:
- File not found
- Empty files
- Malformed CSV (unmatched quotes)
- Memory allocation errors

## Testing

Run the included tests to verify correctness and performance:

```bash
# Correctness test
mojo test_threaded.mojo

# Performance comparison
mojo bench_threaded.mojo

# Usage example
mojo example_threaded.mojo
```

## Limitations

1. **Memory Usage**: Each thread requires additional working memory
2. **Small Files**: No benefit for files < 10KB (automatic fallback)
3. **I/O Bound**: Limited speedup if storage is the bottleneck
4. **Complex Quoting**: Very complex quoted fields may reduce parallelization efficiency

## Future Improvements

- [ ] SIMD optimization within each thread
- [ ] Streaming support for very large files
- [ ] Memory pool for reduced allocations
- [ ] Adaptive thread count based on file characteristics
- [ ] Progress callbacks for long-running operations

## Contributing

The multi-threaded CSV reader is part of the mojo_csv project. See the main README for contribution guidelines.
