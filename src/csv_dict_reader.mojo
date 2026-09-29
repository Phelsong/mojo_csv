from std.collections import List
from std.pathlib import Path
from std.memory import ArcPointer

from .csv_reader import CsvReader


struct CsvRow(Copyable, Movable, Writable):
    # Headers are shared across all rows of a DictCsvReader: the arc pointer
    # makes row copies cheap (refcount bump) instead of deep-copying the list
    var headers_ptr: ArcPointer[List[String]]
    var values: List[String]

    # Constructor initializing with shared headers and owned values
    def __init__(
        out self,
        headers_ptr: ArcPointer[List[String]],
        var values: List[String],
    ):
        self.headers_ptr = headers_ptr
        self.values = values^

    def headers(imm self) -> List[String]:
        return self.headers_ptr[].copy()

    def col_count(imm self) -> Int:
        return len(self.headers_ptr[])

    def get(self, key: String) raises -> String:
        var i: Int = 0
        for h in self.headers_ptr[]:
            if h == key:
                if i < len(self.values):
                    return self.values[i]
                else:
                    break
            i += 1
        raise Error("Key not found: " + key)

    def get_at(self, idx: Int) raises -> String:
        if idx < 0 or idx >= len(self.values):
            raise Error("Index out of range")
        return self.values[idx]

    def keys(imm self) -> List[String]:
        return self.headers_ptr[].copy()

    def vals(imm self) -> List[String]:
        return self.values.copy()

    def write_repr_to[W: Writer](self, mut writer: W) -> None:
        writer.write("{")
        var first = True
        var i: Int = 0
        for h in self.headers_ptr[]:
            if not first:
                writer.write(", ")
            first = False
            writer.write("'", h, "': '")
            if i < len(self.values):
                writer.write(self.values[i])
            writer.write("'")
            i += 1
        writer.write("}")

    def write_to[W: Writer](self, mut writer: W) -> None:
        self.write_repr_to(writer)


@fieldwise_init
struct DictCsvReader(Copyable, Movable, Sized, Writable):
    var reader: CsvReader
    var headers: List[String]
    var headers_ptr: ArcPointer[List[String]]
    var row_count: Int
    var col_count: Int
    var index: Int  # current row index in "row space" (1..row_count-1)
    var length: Int  # number of data rows (excludes header row)

    def __init__(
        out self,
        var in_csv: Path,
        delimiter: String = ",",
        quotation_mark: String = '"',
        num_threads: Int = 0,
    ) raises:
        self.reader = CsvReader(in_csv, delimiter, quotation_mark, num_threads)
        self.headers = self.reader.headers.copy()
        self.headers_ptr = ArcPointer(self.headers.copy())
        self.row_count = self.reader.row_count
        self.col_count = self.reader.col_count
        # self.rows =
        # Data rows exclude the header row at index 0
        self.length = 0
        if self.row_count > 0:
            self.length = self.row_count - 1
        self.index = 1  # start at first data row

    def _row_values(mut self, row: Int) raises -> List[String]:
        if row <= 0 or row >= self.row_count:
            raise Error("Row index out of range")
        # Build the row's values directly from a slice of the flat element
        # list instead of per-element indexed appends
        var base = row * self.col_count
        var end = base + self.col_count
        if end > len(self.reader):
            end = len(self.reader)
        return List[String](self.reader.elements[base:end])

    def __getitem__(mut self, row: Int) raises -> CsvRow:
        return CsvRow(self.headers_ptr, self._row_values(row))

    def __len__(
        imm self,
    ) -> Int:
        return self.length

    def __repr__(imm self) -> String:
        return String(
            "DictCsvReader(rows="
            + String(self.length)
            + ", cols="
            + String(self.col_count)
            + ")"
        )

    def __str__(imm self) -> String:
        return String(self)

    def write_to[W: Writer](imm self, mut writer: W) -> None:
        writer.write(String(self.__repr__()))

    def __next_ref__(mut self) raises -> CsvRow:
        if not self.__has_next__():
            raise Error("StopIteration")
        self.index += 1
        return CsvRow(self.headers_ptr, self._row_values(self.index - 1))

    @always_inline
    def __next__(mut self) raises -> CsvRow:
        return self.__next_ref__()

    @always_inline
    def __has_next__(imm self) -> Bool:
        return self.index < self.row_count

    @always_inline
    def __iter__(mut self) -> Self:
        return self.copy()
