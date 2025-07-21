from pathlib import Path, cwd
from sys import exit
from testing import assert_true
from time import time_function, perf_counter

from src.csv_reader import CsvReader

# from mojo_csv import CsvReader


fn bench_parse_micro() capturing:
    try:
        var in_csv: Path = cwd().joinpath("tests/test.csv")
        _ = CsvReader(in_csv)
    except:
        print("error in micro")
        # exit so we don't get false numbers
        exit()


fn bench_parse_mini() capturing:
    try:
        var in_csv: Path = cwd().joinpath("tests/datablist/leads-100.csv")
        _ = CsvReader(in_csv)
    except:
        print("error in micro")
        # exit so we don't get false numbers
        exit()


fn bench_parse_small() capturing:
    try:
        var in_csv: Path = cwd().joinpath(
            "tests/datablist/organizations-1000.csv"
        )
        _ = CsvReader(in_csv)
    except:
        print("error in micro")
        # exit so we don't get false numbers
        exit()


fn bench_parse_medium() capturing:
    try:
        var in_csv: Path = cwd().joinpath("tests/datablist/people-100000.csv")
        var _ = CsvReader(in_csv)
    except:
        print("error in medium")
        exit()


fn bench_parse_large() capturing:
    try:
        var in_csv: Path = cwd().joinpath(
            "tests/datablist/products-2000000.csv"
        )
        _ = CsvReader(in_csv)
    except:
        print("error in large")
        exit()


fn main():
    # var start = perf_counter()
    # var end = perf_counter()
    print("running benchmark for micro csv:")
    var time: Float64 = 0
    for _ in range(1000):
        var elapsed = time_function[bench_parse_micro]()
        time += elapsed / 1000000
    var avg: Float64 = time / 1000
    print("average time in ms for micro file:")
    print(round(avg, 6))
    print("-------------------------")
    print("running benchmark for mini csv:")
    time = 0
    for _ in range(1000):
        elapsed = time_function[bench_parse_mini]()
        time += elapsed / 1000000
    avg = time / 1000
    print("average time in ms for mini file:")
    print(round(avg, 6))
    print("-------------------------")
    print("running benchmark for small csv:")
    time = 0
    for _ in range(1000):
        elapsed = time_function[bench_parse_small]()
        time += elapsed / 1000000
    avg = time / 1000
    print("average time in ms for small file:")
    print(round(avg, 6))
    print("-------------------------")
    print("running benchmark for medium csv:")
    time = 0
    for _ in range(100):
        elapsed = time_function[bench_parse_medium]()
        time += elapsed / 1000000
    avg = time / 100
    print("average time in ms for medium file:")
    print(round(avg, 6))
    print("-------------------------")
    print("running benchmark for large csv:")
    time = 0
    for _ in range(100):
        elapsed = time_function[bench_parse_large]()
        time += elapsed / 1000000
    avg = time / 100
    print("average time in ms for large file:")
    print(round(avg, 6))
