from std.collections import List
from std.pathlib import Path
from std.memory import Pointer, OwnedPointer, ArcPointer, UnsafePointer

from .csv_reader import CsvReader


@fieldwise_init
struct CsvRow(Copyable, Movable, Writable):
    # var headers: UnsafePointer[
    #     mut=True, type = List[String], origin=MutableAnyOrigin
    # ]
    # var headers: List[String]
    var headers: List[String]
    var values: List[String]

    # Overloaded constructor to initialize with headers and values
    fn __init__(
        out self,
        mut headers: List[String],
        mut values: List[String],
    ):
        # Convert to Pointers
        self.headers = headers.copy()
        self.values = values.copy()

    @parameter
    fn col_count(read self) -> Int:
        return len(self.headers)

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

    fn keys(
        mut self,
    ) -> List[String]:
        return self.headers.copy()

    fn vals(mut self) -> List[String]:
        return self.values.copy()

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
struct DictCsvReader(Copyable, Movable, Sized, Writable):
    var reader: CsvReader
    var headers: List[String]
    var row_count: Int
    var col_count: Int
    var index: Int  # current row index in "row space" (1..row_count-1)
    var length: Int  # number of data rows (excludes header row)

    fn __init__(
        out self,
        var in_csv: Path,
        delimiter: String = ",",
        quotation_mark: String = '"',
        num_threads: Int = 0,
    ) raises:
        self.reader = CsvReader(in_csv, delimiter, quotation_mark, num_threads)
        self.headers = self.reader.headers.copy()
        self.row_count = self.reader.row_count
        self.col_count = self.reader.col_count
        # self.rows =
        # Data rows exclude the header row at index 0
        self.length = 0
        if self.row_count > 0:
            self.length = self.row_count - 1
        self.index = 1  # start at first data row

    fn _row_values(mut self, row: Int) raises -> List[String]:
        values = List[String]()
        if row <= 0 or row >= self.row_count:
            raise Error("Row index out of range")
        var base = row * self.col_count
        for c in range(self.col_count):
            var element_idx = base + c
            if element_idx < len(self.reader):
                values.append(self.reader[element_idx])
        return values^

    fn __getitem__(mut self, row: Int) raises -> CsvRow:
        try:
            return CsvRow(self.headers.copy(), self._row_values(row))
        except:
            raise Error("Row index of of range")

    fn __len__(
        read self,
    ) -> Int:
        return self.length

    fn __repr__(read self) -> String:
        return String(
            "DictCsvReader(rows="
            + String(self.length)
            + ", cols="
            + String(self.col_count)
            + ")"
        )

    fn __str__(read self) -> String:
        return String.write(self)

    fn write_to[W: Writer](read self, mut writer: W) -> None:
        writer.write(String(self.__repr__()))

    @parameter
    fn __next_ref__(mut self) raises -> CsvRow:
        if not self.__has_next__():
            raise Error("StopIteration")
        self.index += 1
        return CsvRow(self.headers.copy(), self._row_values(self.index - 1))

    @always_inline
    fn __next__(mut self) raises -> CsvRow:
        return self.__next_ref__()

    @always_inline
    fn __has_next__(read self) -> Bool:
        return self.index < self.row_count

    @always_inline
    fn __iter__(mut self) -> Self:
        return self.copy()
