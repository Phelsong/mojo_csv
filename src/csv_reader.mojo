from collections import Dict, List
from pathlib import Path, cwd
from sys import argv, exit
from testing import assert_true


struct CsvReader[]:
    # var data: Dict[String,String]
    var headers: List[String]
    var elements: List[String]
    var raw: String
    var length: Int
    var delimiter: String
    var escape: String
    var CR: String
    var LFCR: String
    var QM: String
    var row_count: Int
    var col_count: Int

    fn __init__(
        out self,
        owned in_csv: Path,
        owned delimiter: String = ",",
        owned quotation_mark: String = '"',
    ):
        self.raw = ""
        self.length = 0
        self.QM = quotation_mark
        self.delimiter = delimiter
        self.escape = "\\"
        self.CR = "\n"
        self.LFCR = "\r\n"
        self.row_count = 0
        self.col_count = 0
        self.elements = List[String]()
        self.headers = List[String]()
        self._open(in_csv)
        self.length = self.raw.__len__()
        self._create_reader()

    fn _create_reader(mut self):
        var col: Int = 0
        var col_start: Int = 0
        var in_quotes: Bool = False
        var skip: Bool = False
        for pos in range(self.length):
            var char: String = self.raw[pos]
            # --------

            if skip:
                skip = False
                continue
            if in_quotes:
                if char != self.QM:
                    continue
                else:
                    in_quotes = False
                    continue
            # if in QM, ignore any cases
            if char == self.QM:
                in_quotes = True
                continue
            # --------

            if char == self.delimiter:
                self.elements.append(self.raw[col_start:pos])
                col_start = pos + 1

                if self.row_count == 0:
                    self.col_count += 1

                if pos + 1 < self.length:
                    if (
                        self.raw[pos + 1] == self.CR
                        or self.raw[pos + 1] == self.LFCR
                    ):
                        skip = True
                        col_start = pos + 2
                else:
                    break

            # --------
            # case end of row
            elif char == self.CR or char == self.LFCR:
                self.elements.append(self.raw[col_start:pos])

                if self.row_count == 0:
                    self.col_count += 1

                if pos + 1 < self.length:
                    self.row_count += 1
                    col_start = pos + 1

            elif pos == self.length:
                self.elements.append(self.raw[col_start:pos])
            # -------
        # -------------

    fn _open(mut self, in_csv: Path):
        try:
            assert_true(in_csv.exists())
            self.raw = in_csv.read_text()
            assert_true(self.raw != "")
        except AssertionError:
            print("Error opening file:", in_csv)
            exit()

    # fn __copyinit__(mut self, existing: _Self) -> CsvReader:
    #     self.raw = existing.raw
    #     self.delimiter = existing.delimiter
    #     self.QM = existing.QM
    #     self.elements = existing.elements
    #     self.col_count = existing.col_count
    #     self.row_count = existing.row_count
    #     return self
    # ---------------------
