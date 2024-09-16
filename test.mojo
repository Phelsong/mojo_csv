from collections import Dict, List
from pathlib import Path, cwd
from sys import argv

from src.csv_reader import CsvReader
# from src.open_csv import open_csv

def main():
    try:
        in_csv = Path(argv()[1])
        # print(in_csv)
        with open(in_csv, "r") as fi:
            var rd = CsvReader(fi.read())
            # print(rd.col_count)
            for x in range(len(rd.elements)):
                print(rd.elements[x])
        # -------------
        # var rd: CsvReader = open_csv(in_csv)
        # print(rd.col_count)
        # for x in range(len(rd.elements)):
        #     print(rd.elements[x])


    except Exception:
        print("error: ", Exception)

# def main():
#     in_csv = Path(argv()[1])
#     var rd = CsvReader(in_csv)
#     for x in range(len(rd.elements)):
#         print(rd.elements[x])
