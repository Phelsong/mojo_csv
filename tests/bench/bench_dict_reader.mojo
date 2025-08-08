from pathlib import Path, cwd
from time import time_function
from sys import exit

from mojo_csv import DictCsvReader


# Bench helpers: construct and iterate a DictCsvReader to simulate realistic usage
fn bench_dict_reader_small_single() capturing:
    try:
        var in_csv: Path = cwd().joinpath("tests/datablist/organizations-1000.csv")
        var dr = DictCsvReader(in_csv, num_threads=1)
        var rows = 0
        for _ in dr:
            rows += 1
    except:
        print("error in small/single")
        exit()


fn bench_dict_reader_small() capturing:
    try:
        var in_csv: Path = cwd().joinpath("tests/datablist/organizations-1000.csv")
        var dr = DictCsvReader(in_csv)  # default threading
        var rows = 0
        for _ in dr:
            rows += 1
    except:
        print("error in small/single")
        exit()


fn bench_dict_reader_medium() capturing:
    try:
        var in_csv: Path = cwd().joinpath("tests/datablist/people-100000.csv")
        var dr = DictCsvReader(in_csv)
        var rows = 0
        for _ in dr:
            rows += 1
    except:
        print("error in small/single")
        exit()


fn bench_dict_reader_large() capturing:
    try:
        var in_csv: Path = cwd().joinpath("tests/datablist/products-2000000.csv")
        var dr = DictCsvReader(in_csv)
        var rows = 0
        for _ in dr:
            rows += 1
    except:
        print("error in small/single")
        exit()


fn main():
    print("=== DictCsvReader Performance ===")

    # Small file
    print("-----------------------------------")
    print("Small file benchmark (1,000 rows):")
    var time_single_small: Float64 = 0
    for _ in range(10):
        var elapsed = time_function[bench_dict_reader_small_single]()
        time_single_small += elapsed / 1000000
    var avg_single_small = time_single_small / 10
    print("Small Single-threaded:", round(avg_single_small, 4), "ms")

    # Threaded
    var time_multi_small: Float64 = 0
    for _ in range(10):
        var elapsed = time_function[bench_dict_reader_small]()
        time_multi_small += elapsed / 1000000
    var avg_multi_small = time_multi_small / 10
    print("Small Threaded:", round(avg_multi_small, 4), "ms")

    # Medium file
    print("-----------------------------------")
    print("Medium file benchmark (100,000 rows):")
    var time_single_medium: Float64 = 0
    for _ in range(10):
        var elapsed = time_function[bench_dict_reader_medium]()
        time_single_medium += elapsed / 1000000
    var avg_single_medium = time_single_medium / 10
    print("Medium:", round(avg_single_medium, 2), "ms")

    # Large file (fewer iterations)
    print("-----------------------------------")
    print("Large file benchmark (2,000,000 rows):")
    var time_single_large: Float64 = 0
    for _ in range(10):
        var elapsed = time_function[bench_dict_reader_large]()
        time_single_large += elapsed / 1000000
    var avg_single_large = time_single_large / 10
    print("Large:", round(avg_single_large, 1), "ms")
