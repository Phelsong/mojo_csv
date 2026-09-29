### Performance

- average times over ~100 iterations
- AMD 7950x@5.8ghz

micro file benchmark (3 rows) 
mini (100 rows) 
small (1k rows) 
medium file benchmark (100k rows) 
large file benchmark (2m rows) 

default threading config:
```log
✨ Pixi task (bench): mojo run -I dist tests/bench/bench.mojo
running benchmark for micro csv:
average time in ms for micro file:
0.0063 ms
-------------------------
running benchmark for mini csv:
average time in ms for mini file:
0.0359 ms
-------------------------
running benchmark for small csv:
average time in ms for small file:
0.187 ms
-------------------------
running benchmark for medium csv:
average time in ms for medium file:
14.33 ms
-------------------------
running benchmark for large csv:
average time in ms for large file:
750.2 ms
```

#### CSV Reader Performance Comparison
```log
Small file benchmark (1,000 rows):
Single-threaded:
Average time: 0.524 ms
Multi-threaded:
Average time: 0.4443 ms
Speedup: 1.18 x
-------------------------
Medium file benchmark (100,000 rows):
Single-threaded:
Average time: 49.26 ms
Multi-threaded:
Average time: 17.6 ms
Speedup: 2.8 x
-------------------------
Large file benchmark (2,000,000 rows):
Single-threaded:
Average time: 1632.6 ms
Multi-threaded:
Average time: 723.1 ms
Speedup: 2.26 x
-------------------------
Summary:
Small file speedup: 1.18 x
Medium file speedup: 2.8 x
Large file speedup: 2.26 x
```

#### DictCsvReader Performance
```log
-----------------------------------
Small file benchmark (1,000 rows):
Small Single-threaded: 0.6392 ms
Small Threaded: 0.5206 ms
-----------------------------------
Medium file benchmark (100,000 rows):
Medium: 31.79 ms
-----------------------------------
Large file benchmark (2,000,000 rows):
Large: 1125.3 ms
```
#### CsvWriter Performance (100k rows, 11.5MB output)
```
Write (threads=1):   29.2 ms
Write (threads=30):   7.5 ms   (3.9x speedup)
```

#### Python Bindings
Same native performance after the single FFI boundary call per operation
(see python/ for bindings, tests, and an example).

#### python csv module vs mojo_csv bindings (5-iteration averages)
```log
size      py stream    py bulk   mojo row-iter    mojo bulk              speedup
mini           0.16ms       0.16ms          0.34ms       0.28ms     0.6x (stream) /  0.6x (bulk)
small          0.97ms       1.09ms          1.92ms       1.49ms     0.7x (stream) /  0.7x (bulk)
medium        83.92ms     152.80ms        155.73ms     142.23ms     0.6x (stream) /  1.1x (bulk)
large       2340.01ms    5517.85ms       4696.30ms    4651.89ms     0.5x (stream) /  1.2x (bulk)

"py stream"  = csv.reader, streaming row iteration (C-accelerated)
"py bulk"    = csv.reader materialized into a list of lists
"mojo row-iter" = Reader + per-row get_row() FFI calls
"mojo bulk"  = parse_csv(), one FFI call returning a flat list

The Mojo parse itself runs at native speed (medium ~15ms, large ~750ms);
the gap in these numbers is Python-object materialization across the FFI
boundary. Use the Reader type and avoid materializing full-cell lists in
Python for the best throughput.
```
