from collections import Dict, List
from pathlib import Path
from sys import exit
from testing import assert_true


# https://www.rfc-editor.org/rfc/rfc4180
#
@value
struct STCsvReader(Copyable, Representable, Sized, Stringable, Writable):
    var raw: String
    # var raw_bytes: SIMD[UInt8,1]
    var raw_length: Int
    var index: Int
    var length: Int
    var row_count: Int
    var col_count: Int
    var elements: List[String]
    var delimiter: String
    var delimiter_byte: Int
    var QM: String
    var quote_byte: Int
    var newline_byte: Int
    var carriage_return_byte: Int
    var headers: List[String]

    fn __init__(
        out self,
        owned in_csv: Path,
        owned delimiter: String = ",",
        owned quotation_mark: String = '"',
    ) raises:
        self.raw = ""
        self.raw_length = 0
        self.index = 0
        self.length = 0
        self.row_count = 0
        self.col_count = 0
        self.elements = List[String]()
        self.headers = List[String]()
        self.delimiter = delimiter
        self.QM = quotation_mark
        self.delimiter_byte = ord(self.delimiter)
        self.quote_byte = ord(self.QM)
        self.newline_byte = ord("\n")
        self.carriage_return_byte = ord("\r")
        self._open(in_csv)
        self._create_reader()
        self.length = self.elements.__len__()
        # Just always treat the first row as optional headers
        self.headers = self.elements[0 : self.col_count]

    fn _create_reader(mut self):
        var col_start: Int = 0
        var in_quotes: Bool = False
        var skip: Bool = False

        # Get byte representation for efficient character comparison
        raw_bytes = self.raw.as_bytes()

        for pos in range(self.raw_length):
            var current_byte: UInt8 = raw_bytes[pos]
            # var char: String

            # Handle bypasses/escapes
            if skip:
                skip = False
                continue

            if in_quotes:
                if current_byte != self.quote_byte:
                    continue
                else:
                    in_quotes = False
                    continue

            # if in QM, ignore any cases
            if current_byte == self.quote_byte:
                in_quotes = True
                continue

            # --------
            # Delimiter
            if current_byte == self.delimiter_byte:
                self.elements.append(self.raw[col_start:pos])
                col_start = pos + 1

                if self.row_count == 0:
                    self.col_count += 1

                # handle trailing delimiter
                if pos + 1 < self.raw_length:
                    var next_byte = raw_bytes[pos + 1]
                    if (
                        next_byte == self.newline_byte
                        or next_byte == self.carriage_return_byte
                    ):
                        skip = True
                        col_start = (
                            pos + 2 if next_byte
                            == self.carriage_return_byte else pos + 2
                        )
                        self.row_count += 1
                elif pos + 1 == self.raw_length:
                    break

            # --------
            # end of row no trailing delimiter
            elif current_byte == self.newline_byte:
                self.elements.append(self.raw[col_start:pos])

                if self.row_count == 0:
                    self.col_count += 1

                if pos + 1 <= self.raw_length:
                    self.row_count += 1
                    col_start = pos + 1

            elif (
                current_byte == self.carriage_return_byte
                and pos + 1 < self.raw_length
                and raw_bytes[pos + 1] == self.newline_byte
            ):
                # Handle \r\n
                self.elements.append(self.raw[col_start:pos])

                if self.row_count == 0:
                    self.col_count += 1

                if pos + 2 <= self.raw_length:
                    self.row_count += 1
                    col_start = pos + 2
                    skip = True  # Skip the \n in next iteration

    fn _open(mut self, in_csv: Path) raises:
        try:
            assert_true(in_csv.exists())
            self.raw = in_csv.read_text()
            # self.raw_bytes = in_csv.read_bytes()
            assert_true(self.raw != "")
            self.raw_length = len(self.raw)
        except AssertionError:
            print("Error opening file:", in_csv)
            raise AssertionError

    fn __getitem__(self, index: Int) raises -> String:
        if index < 0 or index >= self.row_count:
            raise Error("Index out of range")
        return self.elements[index]

    fn __len__(self) -> Int:
        return self.length

    fn __repr__(self) -> String:
        var out: String = "["

        for el in self.elements:
            out += "'"
            out += String(el)
            out += "', "
        out += "]"
        return out

    fn __str__(self) -> String:
        return String.write(self)

    fn write_to[W: Writer](self, mut writer: W) -> None:
        writer.write(String("CsvReader" + repr(self)))

    @parameter
    fn __next_ref__(mut self) -> String:
        self.index += 1
        return self.elements[self.index - 1]

    @always_inline
    fn __next__(mut self) -> String:
        return self.__next_ref__()

    @always_inline
    fn __has_next__(self) -> Bool:
        return self.length > self.index

    @always_inline
    fn __iter__(self) -> Self:
        return self
