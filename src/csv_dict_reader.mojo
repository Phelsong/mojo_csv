from collections import List
from pathlib import Path

from .csv_reader import CsvReader


@fieldwise_init
struct CsvRow(Copyable, Movable, Representable, Stringable, Writable):
    var headers: List[String]
    var values: List[String]
    var col_count: Int

    fn __init__(out self):
        self.headers = List[String]()
        self.values = List[String]()
        self.col_count = 0

    # Overloaded constructor to initialize with headers and values
    fn __init__(out self, headers: List[String], values: List[String]):
        self.headers = headers
        self.values = values
        self.col_count = len(headers)

    fn get(self, key: String) raises -> String:
        var i: Int = 0
        for h in self.headers:
            if h == key:
                if i < len(self.values):
                    return self.values[i]
                else:
                    break
            i += 1
        raise Error("Key not found: " + key)

    fn get_at(self, idx: Int) raises -> String:
        if idx < 0 or idx >= len(self.values):
            raise Error("Index out of range")
        return self.values[idx]

    fn keys(self) -> List[String]:
        return self.headers

    fn vals(self) -> List[String]:
        return self.values

    fn __repr__(self) -> String:
        var out = String("{")
        var first = True
        var i: Int = 0
        for h in self.headers:
            if not first:
                out += ", "
            first = False
            out += "'" + h + "': '"
            if i < len(self.values):
                out += String(self.values[i])
            out += "'"
            i += 1
        out += "}"
        return out

    fn __str__(self) -> String:
        return String.write(self)

    fn write_to[W: Writer](self, mut writer: W) -> None:
        writer.write(String(repr(self)))


@fieldwise_init
struct DictCsvReader(Copyable, Representable, Sized, Stringable, Writable):
    var reader: CsvReader
    var headers: List[String]
    var row_count: Int
    var col_count: Int
    var index: Int  # current row index in "row space" (1..row_count-1)
    var length: Int  # number of data rows (excludes header row)

    fn __init__(
        out self,
        owned in_csv: Path,
        delimiter: String = ",",
        quotation_mark: String = '"',
        num_threads: Int = 0,
    ) raises:
        self.reader = CsvReader(in_csv, delimiter, quotation_mark, num_threads)
        self.headers = self.reader.headers
        self.row_count = self.reader.row_count
        self.col_count = self.reader.col_count
        # Data rows exclude the header row at index 0
        self.length = 0
        if self.row_count > 0:
            self.length = self.row_count - 1
        self.index = 1  # start at first data row

    fn _row_values(self, row: Int) raises -> List[String]:
        var values = List[String]()
        if row <= 0 or row >= self.row_count:
            raise Error("Row index out of range")
        var base = row * self.col_count
        for c in range(self.col_count):
            var element_idx = base + c
            if element_idx < len(self.reader):
                values.append(self.reader[element_idx])
        return values

    fn __getitem__(self, row: Int) raises -> CsvRow:
        var vals = self._row_values(row)
        return CsvRow(self.headers, vals)

    fn __len__(self) -> Int:
        return self.length

    fn __repr__(self) -> String:
        return String(
            "DictCsvReader(rows="
            + String(self.length)
            + ", cols="
            + String(self.col_count)
            + ")"
        )

    fn __str__(self) -> String:
        return String.write(self)

    fn write_to[W: Writer](self, mut writer: W) -> None:
        writer.write(String(repr(self)))

    @parameter
    fn __next_ref__(mut self) raises -> CsvRow:
        if not self.__has_next__():
            raise Error("StopIteration")
        var vals = self._row_values(self.index)
        self.index += 1
        var r = CsvRow(self.headers, vals)
        return r

    @always_inline
    fn __next__(mut self) raises -> CsvRow:
        return self.__next_ref__()

    @always_inline
    fn __has_next__(self) -> Bool:
        return self.index < self.row_count

    @always_inline
    fn __iter__(self) -> Self:
        return self
