from pathlib import Path, cwd
from sys import argv, exit
from testing import assert_true

from src import CsvReader, DictCsvReader, CsvWriter


fn main():
    try:
        var in_csv: Path = cwd().joinpath("tests/test.csv")
        var rd = CsvReader(in_csv, num_threads=2)
        t_parse(rd)
        print("----------")
        t_methods(rd)
        print("----------")
        t_dict_reader(in_csv)
        print("----------")
        t_csv_writer(rd)
    except:
        print("invalid path")


fn t_parse(read rd: CsvReader):
    var VALID = List[String]()
    VALID.append("item1")
    VALID.append("item2")
    VALID.append('"ite,em3"')
    VALID.append('"p""ic"')
    VALID.append(" pi c")
    VALID.append("pic")
    VALID.append("r_i_1")
    VALID.append('"r_i_2"""')
    VALID.append("r_i_3")
    print("parsing:", rd)
    print("----------")
    try:
        assert_true(rd.col_count == 3)
        for x in range(len(rd)):
            print(rd.elements[x])
            assert_true(
                rd.elements[x] == VALID[x],
                String("[{0}] != expected [{1}] at index {2}").format(
                    rd.elements[x], VALID[x], x
                ),
            )
        print("----------")
        print("columns:", rd.col_count, "of 3")
        print("rows:", rd.row_count, "of 3")
        assert_true(rd.row_count == 3)
        print("elements:", rd.__len__(), "of 9")
        assert_true(len(rd.elements) == 9)
    except AssertionError:
        print("error in parse")
    print("----------")
    print("parse successful")


fn t_methods(read rd: CsvReader) raises:
    try:
        print(String("repr: {}").format(repr(rd)))
        print(String("len: {}").format(len(rd)))
        print(String("print: {}").format(rd))
        print(String("slice: {}").format(rd[0]))
        print(String("slice repr: {}").format(repr(rd[0])))
        print("iter: ...")
        print("----")
        for x in rd:
            print(x)
        print("----")
    except:
        print("error in methods")


fn t_dict_reader(read in_csv: Path):
    try:
        var dr = DictCsvReader(in_csv)
        print("DictCsvReader headers:")
        for h in dr.headers:
            print(" -", h)
        var max_rows = min(3, len(dr))
        print("First", max_rows, "data rows as dictionaries:")
        for r in range(1, max_rows + 1):
            var row = dr[r]
            print("Row", r, ":")
            for i in range(dr.col_count):
                var key = dr.headers[i]
                var val = row.get(key)
                print("  ", key, ":", val)
    except:
        print("error in dict reader")


fn t_csv_writer(read rd: CsvReader):
    try:
        var writer = CsvWriter(rd.elements)
        var out_path = cwd().joinpath("tests/writer-dev.csv")
        writer.write(out_path, rd.col_count, include_trailing_newline=True)
        print("CsvWriter output (tests/writer-dev.csv):")
        var text = out_path.read_text()
        print(text)
    except:
        print("error in writer")
