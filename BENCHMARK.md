### Performance

- average times over 100-1k iterations
- AMD 7950x@5.8ghz
- single-threaded

micro file benchmark (3 rows) 
mini (100 rows) 
small (1k rows) 
medium file benchmark (100k rows) 
large file benchmark (2m rows) 

```log
✨ Pixi task (bench): mojo bench.mojo                                                                                                                                                      running benchmark for micro csv:
average time in ms for micro file:
0.0094 ms
-------------------------
running benchmark for mini csv:
average time in ms for mini file:
0.0657 ms
-------------------------
running benchmark for small csv:
average time in ms for small file:
0.317 ms
-------------------------
running benchmark for medium csv:
average time in ms for medium file:
24.62 ms
-------------------------
running benchmark for large csv:
average time in ms for large file:
878.6 ms
```

#### CSV Reader Performance Comparison
```
Small file benchmark (1,000 rows): 
Single-threaded: 
Average time: 0.455 ms 
Multi-threaded: 
Average time: 0.3744 ms 
Speedup: 1.22 x 

Medium file benchmark (100,000 rows): 
Single-threaded: 
Average time: 37.37 ms 
Multi-threaded: 
Average time: 24.46 ms 
Speedup: 1.53 x 

Large file benchmark (2,000,000 rows): 
Single-threaded: 
Average time: 1210.3 ms 
Multi-threaded: 
Average time: 863.9 ms 
Speedup: 1.4 x 

Summary:
Small file speedup: 1.22 x
Medium file speedup: 1.53 x
Large file speedup: 1.4 x
```