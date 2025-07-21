from collections import List
from pathlib import Path
from sys import exit, num_physical_cores
from testing import assert_true
from algorithm import parallelize


@value
struct ChunkResult:
    var elements: List[String]
    var row_count: Int
    var col_count: Int

    fn __init__(out self):
        self.elements = List[String]()
        self.row_count = 0
        self.col_count = 0


@value
struct ThreadedCsvReader(Copyable, Representable, Sized, Stringable, Writable):
    var raw: String
    var raw_length: Int
    var index: Int
    var length: Int
    var row_count: Int
    var col_count: Int
    var elements: List[String]
    var delimiter: String
    var delimiter_byte: Int
    var QM: String
    var delimiter_byte: Int
    var quote_byte: Int
    var newline_byte: Int
    var carriage_return_byte: Int
    var headers: List[String]
    var num_threads: Int

    fn __init__(
        out self,
        owned in_csv: Path,
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
        self.delimiter_byte = ord(self.delimiter)
        self.quote_byte = ord(self.QM)
        self.newline_byte = ord("\n")
        self.carriage_return_byte = ord("\r")

        # Use all available cores if not specified
        if num_threads == 0:
            self.num_threads = num_physical_cores() * 2
        else:
            # Also limit user-specified thread count to half the cores
            self.num_threads = num_threads

        self._open(in_csv)

        self._create_threaded_reader()
        self.length = self.elements.__len__()

        # Set headers from first row
        if self.col_count > 0:
            self.headers = self.elements[0 : self.col_count]

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

    fn _create_threaded_reader(mut self) raises:
        """Main entry point for threaded CSV parsing"""
        # For small files, use single-threaded approach
        if self.raw_length < 20 or self.num_threads == 1:
            self._create_single_threaded_reader()
            return

        # Find safe split points (newlines outside quotes)
        var split_points = self._find_split_points()

        if len(split_points) < 2:
            # Fallback to single-threaded if no safe splits found
            self._create_single_threaded_reader()
            return

        # Create chunks for parallel processing
        var chunks = self._create_chunks(split_points)

        # Process chunks in parallel
        var chunk_results = List[ChunkResult]()
        for _ in range(len(chunks)):
            chunk_results.append(ChunkResult())

        # Process each chunk in parallel using parallelize with error handling
        try:
            @parameter
            fn process_chunk_parallel(chunk_idx: Int):
                var chunk = chunks[chunk_idx]
                chunk_results[chunk_idx] = self._process_chunk(
                    chunk[0], chunk[1], chunk_idx == 0
                )

            # Use limited worker count to avoid runtime conflicts
            parallelize[process_chunk_parallel](len(chunks), self.num_threads)
        except:
            # Fallback to single-threaded processing if parallelization fails
            print(
                "Warning: Parallel processing failed, falling back to"
                " single-threaded"
            self._create_single_threaded_reader()
            return

        # Merge results
        self._merge_results(chunk_results)

    fn _create_single_threaded_reader(mut self):
        """Fallback to original single-threaded implementation"""
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

    fn _find_split_points(self) -> List[Int]:
        """Find safe positions to split the file (newlines outside quotes)"""
        var split_points = List[Int]()
        split_points.append(0)  # Start of file

        var in_quotes = False
        var skip = False

        for pos in range(self.raw_length):
            var char = self.raw[pos]

            if skip:
                skip = False
                continue

            if char == self.QM:
                in_quotes = not in_quotes
                continue

            if not in_quotes and (char == "\r\n" or char == "\n"):
                # This is a safe split point
                var next_pos = pos + 1
                if next_pos < self.raw_length and (
                    self.raw[next_pos] == "\n" or self.raw[next_pos] == "\r\n"
                ):
                    next_pos += 1
                    skip = True
                split_points.append(next_pos)

        return split_points

    fn _create_chunks(self, split_points: List[Int]) -> List[Tuple[Int, Int]]:
        """Create roughly equal chunks for parallel processing"""
        var chunks = List[Tuple[Int, Int]]()
        var num_splits = len(split_points) - 1

        if num_splits <= self.num_threads:
            # Fewer splits than threads, use all splits
            for i in range(num_splits):
                chunks.append((split_points[i], split_points[i + 1]))
        else:
            # More splits than threads, distribute evenly
            var chunk_size = num_splits // self.num_threads
            var remainder = num_splits % self.num_threads

            var current_split = 0
            for thread_id in range(self.num_threads):
                var start_split = current_split
                var splits_in_chunk = chunk_size
                if thread_id < remainder:
                    splits_in_chunk += 1

                var end_split = start_split + splits_in_chunk
                if end_split > num_splits:
                    end_split = num_splits

                if start_split < end_split:
                    chunks.append(
                        (split_points[start_split], split_points[end_split])
                    )

                current_split = end_split
        return chunks

    fn _process_chunk(
        self, start_pos: Int, end_pos: Int, is_first_chunk: Bool
    ) -> ChunkResult:
        """Process a single chunk of the CSV file"""
        var result = ChunkResult()
        var col_start = start_pos
        var in_quotes = False
        var skip = False

        # raw_bytes = self.raw.__getitem__(Slice(start_pos, end_pos)).as_bytes()
        raw_bytes = self.raw.as_bytes()
        for pos in range(start_pos, end_pos):
            var current_byte: UInt8 = raw_bytes[pos]

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

            if current_byte == self.delimiter_byte:
                result.elements.append(self.raw[col_start:pos])
                col_start = pos + 1

                if is_first_chunk and result.row_count == 0:
                    result.col_count += 1

                if pos + 1 <= end_pos:
                    if (
                        raw_bytes[pos + 1] == self.newline_byte
                        or raw_bytes[pos + 1] == self.carriage_return_byte
                    ):
                        skip = True
                        col_start = pos + 2
                        result.row_count += 1

            elif (
                current_byte == self.newline_byte
                or current_byte == self.carriage_return_byte
            ):
                result.elements.append(self.raw[col_start:pos])

                if is_first_chunk and result.row_count == 0:
                    result.col_count += 1

                if pos + 1 < end_pos:
                    result.row_count += 1
                    col_start = pos + 1
        
        result.row_count +=1
        return result

    fn _merge_results(mut self, chunk_results: List[ChunkResult]):
        """Merge results from all chunks"""
        # Get column count from first chunk
        if len(chunk_results) > 0:
            self.col_count = chunk_results[0].col_count

        # Merge all elements and count rows
        for chunk_result in chunk_results:
            for element in chunk_result.elements:
                self.elements.append(element)
            self.row_count += chunk_result.row_count

    # Standard interface methods (same as original CsvReader)
    fn __getitem__(self, index: Int) raises -> String:
        if index < 0 or index >= self.length:
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
        writer.write(String("ThreadedCsvReader" + repr(self)))

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
