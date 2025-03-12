from collections import Dict, List
from pathlib import Path
from sys import exit
from testing import assert_true

# https://www.rfc-editor.org/rfc/rfc4180
#
@value
struct CsvReader:
    # var data: Dict[String,String]
    var headers: List[String]
    var elements: List[String]
    var raw: String
    var raw_length: Int
    var delimiter: String
    # var escape: String
    var CR: String
    var LFCR: String
    var QM: String
    var row_count: Int
    var col_count: Int
    var length: Int

    fn __init__(
        out self,
        owned in_csv: Path,
        owned delimiter: String = ",",
        owned quotation_mark: String = '"',
    ) raises:
        self.raw = ""
        self.raw_length = 0
        self.length = 0
        self.QM = quotation_mark
        self.delimiter = delimiter
        #self.escape = "\\"
        self.CR = "\n"
        self.LFCR = "\r\n"
        self.row_count = 0
        self.col_count = 0
        self.elements = List[String]()
        self.headers = List[String]()
        self._open(in_csv)
        self.raw_length = self.raw.__len__()
        self._create_reader()
        self.length = self.elements.__len__()
        # Just always treat the first row as optional headers
        self.headers = self.elements[0:self.col_count]

    fn _create_reader(mut self):
        var col_start: Int = 0
        var in_quotes: Bool = False
        var skip: Bool = False
        for pos in range(self.raw_length):
            # StringSlice is still not a Char
            var char: String = self.raw[pos]
            # --------
            # Handle bypasses/escapes
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
            # Delimiter
            if char == self.delimiter:
                self.elements.append(self.raw[col_start:pos])
                col_start = pos + 1

                if self.row_count == 0:
                    self.col_count += 1

                # handle trailing delimiter
                if pos + 1 <= self.raw_length:
                    if (
                        self.raw[pos + 1] == self.CR
                        or self.raw[pos + 1] == self.LFCR
                    ):
                        skip = True
                        col_start = pos + 2
                        self.row_count += 1
                else:
                    break

            # --------
            # end of row no trailing delimiter
            elif char == self.CR or char == self.LFCR:
                self.elements.append(self.raw[col_start:pos])

                if self.row_count == 0:
                    self.col_count += 1

                if pos + 1 <= self.raw_length:
                    self.row_count += 1
                    col_start = pos + 1
            # end of file, even if not CR :: Spec #2
            elif pos == self.raw_length:
                self.elements.append(self.raw[col_start:pos])
                self.row_count += 1
            # -------
        # -------------

    fn _open(mut self, in_csv: Path) raises:
        try:
            assert_true(in_csv.exists())
            self.raw = in_csv.read_text()
            assert_true(self.raw != "")
        except AssertionError:
            print("Error opening file:", in_csv)
            raise AssertionError

    fn __getitem__(self, index: Int) raises -> String:
        if index < 0 or index >= self.row_count:
            raise Error("Index out of range")
        return self.elements[index]


    fn __len__(self) -> Int:
        return self.length

    # fn __iter__(self) -> Iterator[String]:
    #     return self.elements.__iter__()

    # fn __repr__(self) -> String:
    #     var out = String("[")
    #     for el in self.elements:
    #         out.append(el)
    #     return out

    # fn __copyinit__(out self) -> CsvReader:
    #     self.raw = existing.raw
    #     self.delimiter = existing.delimiter
    #     self.QM = existing.QM
    #     self.elements = existing.elements
    #     self.col_count = existing.col_count
    #     self.row_count = existing.row_count
    #     return self
    # ---------------------
