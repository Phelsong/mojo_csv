"""`CsvReader` tokenises a document into one `String` per cell.

Trailing commas: a delimiter immediately before a line break or the end of
the document opens no field. `a,b,` is two fields, not three with the last
empty -- the comma at the end of the line is structure, not a separator.
"""

from std.bit import count_trailing_zeros
from std.collections import List
from std.memory import ArcPointer
from std.pathlib import Path
from std.sys import num_logical_cores
from max.algorithm import parallelize

from .csv_scan import (
    CHUNK_SIZE,
    LF,
    QUOTE,
    _scan_chunk_structural,
)


@fieldwise_init
struct ChunkResult(Copyable, Movable):
    var elements: List[String]
    var row_count: Int
    var col_count: Int

    def __init__(out self):
        self.elements = List[String]()
        self.row_count = 0
        self.col_count = 0


struct CellStore(Copyable, Movable):
    # Immutable snapshot of the parsed cells shared with row views; the
    # reader never mutates it after construction
    var elements: List[String]
    var col_count: Int

    def __init__(out self, var elements: List[String], col_count: Int):
        self.elements = elements^
        self.col_count = col_count


struct CsvRowView(Boolable, Copyable, Movable, Sized, Writable):
    # A view of one row of a CsvReader: shares the cell store via a
    # refcounted pointer so cell access reads the shared storage directly
    var store_ptr: ArcPointer[CellStore]
    var row: Int

    def __init__(out self, store_ptr: ArcPointer[CellStore], row: Int):
        self.store_ptr = store_ptr
        self.row = row

    def col_count(imm self) -> Int:
        ref store = self.store_ptr[]
        return store.col_count

    def __getitem__(imm self, col: Int) raises -> String:
        ref store = self.store_ptr[]
        if col < 0 or col >= store.col_count:
            raise Error("Column index out of range")
        return store.elements[self.row * store.col_count + col]

    def __len__(imm self) -> Int:
        ref store = self.store_ptr[]
        return store.col_count

    def write_repr_to[W: Writer](imm self, mut writer: W) -> None:
        ref store = self.store_ptr[]
        writer.write("[")
        var first = True
        for c in range(store.col_count):
            if not first:
                writer.write(", ")
            first = False
            writer.write("'", store.elements[self.row * store.col_count + c], "'")
        writer.write("]")

    def write_to[W: Writer](imm self, mut writer: W) -> None:
        self.write_repr_to(writer)

    def __bool__(imm self) -> Bool:
        ref store = self.store_ptr[]
        return store.col_count > 0


struct CsvReader(Copyable, Movable, Sized, Writable):
    var raw: String
    var raw_length: Int
    var index: Int
    var length: Int
    var row_count: Int
    var col_count: Int
    var elements: List[String]
    var delimiter: String
    var delimiter_byte: UInt8
    var QM: String
    var quote_byte: UInt8
    var newline_byte: UInt8
    var carriage_return_byte: UInt8
    var headers: List[String]
    var num_threads: Int
    var store_ptr: ArcPointer[CellStore]

    def __init__(
        out self,
        var in_csv: Path,
        delimiter: String = ",",
        quotation_mark: String = '"',
        num_threads: Int = 0,
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
        # Get byte representation for efficient character comparison
        self.delimiter_byte = UInt8(ord(self.delimiter))
        self.quote_byte = UInt8(ord(self.QM))
        self.newline_byte = UInt8(ord("\n"))
        self.carriage_return_byte = UInt8(ord("\r"))

        # Use all available cores if not specified
        if num_threads == 0:
            var cores = num_logical_cores()
            if cores > 2:
                self.num_threads = cores - 2
            else:
                self.num_threads = 1
        else:
            self.num_threads = num_threads

        # Shared cell store for row views (populated lazily by row())
        self.store_ptr = ArcPointer(CellStore(List[String](), 0))

        self._open(in_csv)

        self._create_threaded_reader()
        self.length = self.elements.__len__()

        # Set headers from first row
        if self.col_count > 0:
            var header_slice = self.elements[0 : self.col_count]
            self.headers = List[String](header_slice)

    def __init__(
        out self,
        var cells: List[String],
        *,
        col_count: Int,
        has_header: Bool = True,
        delimiter: String = ",",
        quotation_mark: String = '"',
        num_threads: Int = 0,
    ) raises:
        """Creates a reader from already-split cells.

        The cells are taken as a flat row-major list -- the same shape
        `CsvWriter` writes from: `cells[row * col_count + col]`. No scan
        runs at all; every field is the string it was given.

        This is the inverse of reading a file whose rows were already
        split: `CsvReader(elements)`, then `writer.write(path, col_count)`
        round-trips a document through the reader untouched.

        Args:
            cells: The flat cell list. Taken by value and kept.
            col_count: Cells per row. `len(cells)` must divide by it.
            has_header: Whether `cells[0:col_count]` is a header row. When
                False, `row_count` counts every row including the first
                and `headers` stays empty.
            delimiter: Recorded for symmetry with the parsing
                constructors; nothing is parsed.
            quotation_mark: Recorded alongside the delimiter.
            num_threads: Ignored (there is no parse); kept for signature
                compatibility.

        Raises:
            Error: If `cells` is empty, `col_count` is not positive, or
                `len(cells)` is not a whole number of rows.
        """
        self.raw = ""
        self.raw_length = 0
        self.index = 0
        self.length = 0
        self.row_count = 0
        self.col_count = 0
        self.elements = cells^
        self.headers = List[String]()
        self.delimiter = delimiter
        self.QM = quotation_mark
        # Get byte representation for efficient character comparison
        self.delimiter_byte = UInt8(ord(self.delimiter))
        self.quote_byte = UInt8(ord(self.QM))
        self.newline_byte = UInt8(ord("\n"))
        self.carriage_return_byte = UInt8(ord("\r"))

        # Use all available cores if not specified
        if num_threads == 0:
            var cores = num_logical_cores()
            if cores > 2:
                self.num_threads = cores - 2
            else:
                self.num_threads = 1
        else:
            self.num_threads = num_threads

        # Shared cell store for row views (populated lazily by row())
        self.store_ptr = ArcPointer(CellStore(List[String](), 0))

        self.length = self.elements.__len__()
        if self.length == 0:
            return
        if col_count <= 0:
            raise Error("col_count must be positive, got ", col_count)
        if self.length % col_count != 0:
            raise Error(
                "cells length ",
                self.length,
                " is not a whole number of rows of ",
                col_count,
            )
        self.col_count = col_count
        self.row_count = self.length // col_count
        if has_header and self.row_count > 0:
            var header_slice = self.elements[0 : self.col_count]
            self.headers = List[String](header_slice)

    def _open(mut self, in_csv: Path) raises:
        if not in_csv.exists():
            raise Error("File not found: " + String(in_csv))
        self.raw = in_csv.read_text()
        self.raw_length = self.raw.byte_length()

    def _create_threaded_reader(mut self):
        """Main entry point for threaded CSV parsing"""
        # For small files, use single-threaded approach
        if self.raw_length < 500000 or self.num_threads == 1:
            self._create_single_threaded_reader()
            return

        var raw_bytes = self.raw.as_bytes()
        var num_threads = self.num_threads
        if num_threads > num_logical_cores():
            num_threads = num_logical_cores()
        # Pass 1 (parallel): compute quote parity at each chunk boundary so
        # chunk starts are always outside quoted fields
        var parities = List[Int]()
        parities.reserve(num_threads)
        for _ in range(num_threads):
            parities.append(0)

        @always_inline
        def scan_chunk(
            chunk_idx: Int,
        ) {mut parities, imm raw_bytes, imm self, imm num_threads} -> None:
            var start = chunk_idx * self.raw_length // num_threads
            var end = (chunk_idx + 1) * self.raw_length // num_threads
            var in_quotes = False
            for pos in range(start, end):
                if raw_bytes[pos] == self.quote_byte:
                    in_quotes = not in_quotes
            parities[chunk_idx] = 1 if in_quotes else 0

        parallelize(scan_chunk, num_threads, num_threads)
        # prefix parity: quote state before each chunk
        var prefix = List[Int]()
        prefix.reserve(num_threads)
        var running = 0
        for i in range(num_threads):
            prefix.append(running)
            running ^= parities[i]

        # Pass 2 (parallel): each chunk finds its first safe split at/after
        # its sample offset using the known entry quote state
        var splits = List[Int]()
        splits.reserve(num_threads + 1)
        splits.append(0)
        for _ in range(num_threads):
            splits.append(-1)

        @always_inline
        def find_split(
            chunk_idx: Int,
        ) {mut splits, imm raw_bytes, imm prefix, imm self, imm num_threads} -> None:
            var start = chunk_idx * self.raw_length // num_threads
            var end = (chunk_idx + 1) * self.raw_length // num_threads
            var in_quotes = prefix[chunk_idx] == 1
            for pos in range(start, end):
                var cb = raw_bytes[pos]
                if cb == self.quote_byte:
                    in_quotes = not in_quotes
                    continue
                if not in_quotes and (
                    cb == self.newline_byte or cb == self.carriage_return_byte
                ):
                    var next_pos = pos + 1
                    if next_pos < self.raw_length and (
                        raw_bytes[next_pos] == self.newline_byte
                        or raw_bytes[next_pos] == self.carriage_return_byte
                    ):
                        next_pos += 1
                    splits[chunk_idx + 1] = next_pos
                    break
            if splits[chunk_idx + 1] < 0:
                splits[chunk_idx + 1] = end

        parallelize(find_split, num_threads, num_threads)
        splits[num_threads] = self.raw_length

        # Pass 3 (parallel): parse each chunk independently
        var chunk_results = List[ChunkResult]()
        chunk_results.reserve(num_threads)
        for _ in range(num_threads):
            chunk_results.append(ChunkResult())

        def process_chunk_parallel(
            chunk_idx: Int,
        ) {mut chunk_results, imm raw_bytes, imm splits, imm self} -> None:
            var start = splits[chunk_idx]
            var end = splits[chunk_idx + 1]
            chunk_results[chunk_idx] = self._process_chunk(start, end, chunk_idx == 0)

        parallelize(process_chunk_parallel, num_threads, num_threads)

        # Merge results, consuming chunk storage progressively
        self._merge_results(chunk_results^)

    @always_inline
    def _materialise_cells(
        self,
        start_pos: Int,
        end_pos: Int,
        is_first_chunk: Bool,
        mut elements: List[String],
        mut row_count: Int,
        mut col_count: Int,
    ) -> None:
        """The scan-and-cut core.

        Walks `[start_pos, end_pos)` in 64-byte chunks with the SIMD scan and
        cuts the cells straight from each chunk's delimiter mask -- no
        intermediate offsets array, nothing else allocated. Appends to
        `elements`, updating `row_count` and `col_count`; the caller owns the
        list, so the single-threaded path fills its own storage with no
        intermediate copy.

        The scalar state machine handles the short tail after the last full
        chunk, carrying in the quote state the chunks left behind.
        """
        var range_length = end_pos - start_pos
        if range_length == 0:
            return

        var raw_bytes = self.raw.as_bytes()
        var quote = self.quote_byte
        var separator = self.delimiter_byte

        # reserve reasonable average size
        elements.reserve(range_length // 40)

        var carried_quote: UInt64 = 0
        var carried_cr: UInt64 = 0
        # var in_quotes: Bool = False
        var skip = False
        var tail_col_start = start_pos
        var cells_in_row = 0

        var offset = start_pos
        while offset + CHUNK_SIZE <= end_pos:
            var res = _scan_chunk_structural(
                raw_bytes, offset, quote, separator, carried_quote, carried_cr
            )
            var delimiters = res[0]
            var crlf = res[1]
            carried_quote = res[4]
            carried_cr = res[5]

            # Cut the cells this chunk closes, straight from the mask: one
            # count-trailing-zeros per delimiter, no intermediate array.
            while delimiters != 0:
                var lane = Int(count_trailing_zeros(delimiters))
                var pos = offset + lane
                var is_crlf = ((crlf >> UInt64(lane)) & 1) != 0
                var is_row_end = is_crlf or (raw_bytes[pos] == LF)
                if is_row_end:
                    # Field before the break, less the CR the flag names. A
                    # delimiter immediately before the break opens no field:
                    # the trailing comma is structure, not a separator.
                    var end = pos - (1 if is_crlf else 0)
                    if pos > tail_col_start:
                        elements.append(String(self.raw[byte=tail_col_start:end]))
                    # pos == tail_col_start is a trailing comma: no field
                    cells_in_row += 1
                    if is_first_chunk and row_count == 0:
                        col_count = cells_in_row
                    row_count += 1
                    cells_in_row = 0
                    tail_col_start = pos + 1
                    # CRLF: the next field starts after the LF half
                    if is_crlf and pos + 1 < end_pos and (raw_bytes[pos + 1] == LF):
                        tail_col_start = pos + 2
                else:
                    elements.append(String(self.raw[byte=tail_col_start:pos]))
                    cells_in_row += 1
                    if is_first_chunk and row_count == 0:
                        col_count = cells_in_row
                    tail_col_start = pos + 1
                delimiters &= delimiters - 1
            offset += CHUNK_SIZE

        var in_quotes: Bool = carried_quote != 0
        var scan_end = offset

        # The tail: scalar walk from `scan_end` to `end_pos`.
        var position = scan_end
        if scan_end < end_pos:
            while position < end_pos:
                var byte = raw_bytes[position]
                if skip:
                    skip = False
                    position += 1
                    continue
                if byte == quote:
                    in_quotes = not in_quotes
                elif in_quotes:
                    pass
                elif byte == separator:
                    elements.append(String(self.raw[byte=tail_col_start:position]))
                    cells_in_row += 1
                    if is_first_chunk and row_count == 0:
                        col_count = cells_in_row
                    tail_col_start = position + 1
                elif byte == LF:
                    var trim = (
                        1 if position > start_pos
                        and (
                            raw_bytes[position - 1] == self.carriage_return_byte
                        ) else 0
                    )
                    var end = position - trim
                    elements.append(String(self.raw[byte=tail_col_start:end]))
                    cells_in_row += 1
                    if is_first_chunk and row_count == 0:
                        col_count = cells_in_row
                    row_count += 1
                    cells_in_row = 0
                    tail_col_start = position + 1
                    if trim == 1:
                        skip = True
                        tail_col_start = position + 2
                elif byte == self.carriage_return_byte:
                    var end = position
                    if position + 1 < end_pos and raw_bytes[position + 1] == LF:
                        elements.append(String(self.raw[byte=tail_col_start:end]))
                        cells_in_row += 1
                        if is_first_chunk and row_count == 0:
                            col_count = cells_in_row
                        row_count += 1
                        cells_in_row = 0
                        skip = True
                        tail_col_start = position + 2
                position += 1

            # A last field with no delimiter after it, when anything was open
            if tail_col_start < end_pos:
                elements.append(String(self.raw[byte=tail_col_start:end_pos]))
                cells_in_row += 1
                if is_first_chunk and row_count == 0:
                    col_count = cells_in_row
                row_count += 1

    def _create_single_threaded_reader(mut self):
        """Parses the whole document with the SIMD scan."""
        var elements = List[String]()
        var rows = 0
        var cols = 0
        self._materialise_cells(0, self.raw_length, True, elements, rows, cols)
        self.elements = elements^
        self.row_count = rows
        self.col_count = cols

    def _process_chunk(
        imm self, start_pos: Int, end_pos: Int, is_first_chunk: Bool
    ) -> ChunkResult:
        """Process a single chunk of the CSV file"""
        var result = ChunkResult()
        self._materialise_cells(
            start_pos,
            end_pos,
            is_first_chunk,
            result.elements,
            result.row_count,
            result.col_count,
        )
        return result^

    def _merge_results(mut self, var chunk_results: List[ChunkResult]):
        """Merge results from all chunks, consuming the chunk storage"""
        # Get column count from first chunk
        if len(chunk_results) > 0:
            self.col_count = chunk_results[0].col_count

        # Pre-reserve to avoid repeated reallocation during merge
        var total_elements: Int = 0
        for chunk_result in chunk_results:
            total_elements += len(chunk_result.elements)
        self.elements.reserve(total_elements)

        # Merge all elements and count rows; pop chunks to keep order and
        # release each chunk's storage as it is consumed
        while len(chunk_results) > 0:
            var chunk_result = chunk_results.pop(0)
            for element in chunk_result.elements:
                self.elements.append(element)
            self.row_count += chunk_result.row_count

    # Standard interface methods (same as original CsvReader)
    def __getitem__(ref self, index: Int) raises -> String:
        if index < 0 or index >= self.length:
            raise Error("Index out of range")
        return self.elements[index]

    def __getitem__(imm self, row: Int, col: Int) raises -> String:
        if row < 0 or row >= self.row_count:
            raise Error("Row index out of range")
        if col < 0 or col >= self.col_count:
            raise Error("Column index out of range")
        return self.elements[row * self.col_count + col]

    def row(mut self, index: Int) raises -> CsvRowView:
        if index < 0 or index >= self.row_count:
            raise Error("Row index out of range")
        ref store = self.store_ptr[]
        if store.col_count == 0 and len(self.elements) > 0:
            self.store_ptr = ArcPointer(CellStore(self.elements.copy(), self.col_count))
        return CsvRowView(self.store_ptr, index)

    def __len__(imm self) -> Int:
        return self.length

    def write_repr_to[W: Writer](imm self, mut writer: W) -> None:
        writer.write("CsvReader[")
        var first = True
        for el in self.elements:
            if not first:
                writer.write(", ")
            first = False
            writer.write("'", el, "'")
        writer.write("]")

    def write_to[W: Writer](imm self, mut writer: W) -> None:
        writer.write("ThreadedCsvReader")
        self.write_repr_to(writer)

    def __next_ref__(mut self) raises -> CsvRowView:
        if self.index >= self.row_count:
            raise Error("StopIteration")
        self.index += 1
        ref store = self.store_ptr[]
        if store.col_count == 0 and self.length > 0:
            self.store_ptr = ArcPointer(CellStore(self.elements.copy(), self.col_count))
        return CsvRowView(self.store_ptr, self.index - 1)

    @always_inline
    def __next__(mut self) raises -> CsvRowView:
        return self.__next_ref__()

    @always_inline
    def __has_next__(imm self) -> Bool:
        return self.row_count > self.index

    @always_inline
    def __iter__(ref self) -> Self:
        return self.copy()
