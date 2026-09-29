"""SIMD scan for CSV reader.

Everything here is parameterised on a **runtime** separator byte: the
`CsvReader` delimiter is a plain `UInt8`, passed into every comparison, so
the comptime-generic separator the writer uses is not required for reads.
On x86 with AVX-512BW a 64-lane compare lands in a mask register and one
`kmovq` takes it out; with only AVX2 two 32-lane halves join into one
`UInt64`; anything else gets the portable sixteen-lane path.
"""

from std.bit import count_trailing_zeros
from std.collections import Span
from std.math import iota
from std.memory import pack_bits
from std.sys.info import CompilationTarget
from std.sys.intrinsics import llvm_intrinsic

comptime QUOTE = UInt8(ord('"'))
comptime LF = UInt8(ord("\n"))
comptime CR = UInt8(ord("\r"))
comptime DEFAULT_SEPARATOR = UInt8(ord(","))

comptime CHUNK_SIZE = 64

comptime AVX512_CHUNK = 64
comptime AVX_CHUNK = 32
comptime SMALL_CHUNK = 16

comptime _WIDE_COMPARE = CompilationTarget._has_feature["avx512bw"]()
"""Whether to compare all sixty-four bytes of a chunk in one vector."""

comptime _HALF_COMPARE = CompilationTarget.has_avx2()
"""Whether to compare a chunk thirty-two bytes at a time."""

comptime _LANES = iota[DType.uint8, CHUNK_SIZE]()
"""Every lane index of a chunk, for the compress to pick from."""


@always_inline
def _unpack_bits(bits: UInt64) -> SIMD[DType.bool, CHUNK_SIZE]:
    """The inverse of `pack_bits`: one lane per bit."""
    return SIMD[DType.bool, CHUNK_SIZE](
        mlir_value=__mlir_op.`pop.bitcast`[
            _type=SIMD[DType.bool, CHUNK_SIZE]._mlir_type
        ](bits._mlir_value)
    )


@always_inline
def _join(lo: SIMD[DType.bool, AVX_CHUNK], hi: SIMD[DType.bool, AVX_CHUNK]) -> UInt64:
    """Packs two thirty-two lane comparisons into one `UInt64`."""
    return UInt64(pack_bits[DType.uint32](lo)) | (
        UInt64(pack_bits[DType.uint32](hi)) << AVX_CHUNK
    )


@always_inline
def _prefix_xor(var bits: UInt64) -> UInt64:
    """Returns, for each bit, the XOR of every bit at or below it.

    Applied to the positions of the quote characters, this answers "is this
    byte inside a quoted region?" for all sixty-four bytes at once. The
    carry-less multiply does it in one instruction where `pclmul` exists;
    the six shift-XORs are the portable fallback.
    """
    comptime if CompilationTarget._has_feature["pclmul"]():
        var product = llvm_intrinsic["llvm.x86.pclmulqdq", SIMD[DType.uint64, 2]](
            SIMD[DType.uint64, 2](bits, 0),
            SIMD[DType.uint64, 2](UInt64.MAX, 0),
            Int8(0),
        )
        return product[0]
    else:
        bits ^= bits << 1
        bits ^= bits << 2
        bits ^= bits << 4
        bits ^= bits << 8
        bits ^= bits << 16
        bits ^= bits << 32
        return bits


@always_inline
def _masks_for(
    bytes_vec: SIMD[DType.uint8, CHUNK_SIZE],
    quote: UInt8,
    separator: UInt8,
) -> Tuple[UInt64, UInt64, UInt64, UInt64]:
    """Turns sixty-four bytes into the four structural masks.

    Returns:
        (quotes, separators, line_feeds, carriage_returns), one bit per byte.
    """
    comptime if _WIDE_COMPARE:
        var quotes = pack_bits[DType.uint64](
            bytes_vec.eq(SIMD[DType.uint8, AVX512_CHUNK](quote))
        )
        var separators = pack_bits[DType.uint64](
            bytes_vec.eq(SIMD[DType.uint8, AVX512_CHUNK](separator))
        )
        var line_feeds = pack_bits[DType.uint64](
            bytes_vec.eq(SIMD[DType.uint8, AVX512_CHUNK](LF))
        )
        var carriage_returns = pack_bits[DType.uint64](
            bytes_vec.eq(SIMD[DType.uint8, AVX512_CHUNK](CR))
        )
        return (quotes, separators, line_feeds, carriage_returns)
    elif _HALF_COMPARE:
        var lo = bytes_vec.slice[AVX_CHUNK]()
        var hi = bytes_vec.slice[AVX_CHUNK, offset=AVX_CHUNK]()
        return (
            _join(
                lo.eq(SIMD[DType.uint8, AVX_CHUNK](quote)),
                hi.eq(SIMD[DType.uint8, AVX_CHUNK](quote)),
            ),
            _join(
                lo.eq(SIMD[DType.uint8, AVX_CHUNK](separator)),
                hi.eq(SIMD[DType.uint8, AVX_CHUNK](separator)),
            ),
            _join(
                lo.eq(SIMD[DType.uint8, AVX_CHUNK](LF)),
                hi.eq(SIMD[DType.uint8, AVX_CHUNK](LF)),
            ),
            _join(
                lo.eq(SIMD[DType.uint8, AVX_CHUNK](CR)),
                hi.eq(SIMD[DType.uint8, AVX_CHUNK](CR)),
            ),
        )
    else:
        # Portable fallback: four sixteen-lane packs per mask.

        @always_inline
        def pack4(v: SIMD[DType.uint8, CHUNK_SIZE], target: UInt8) -> UInt64:
            var m0 = v.slice[SMALL_CHUNK]().eq(SIMD[DType.uint8, SMALL_CHUNK](target))
            var m1 = v.slice[SMALL_CHUNK, offset=SMALL_CHUNK]().eq(
                SIMD[DType.uint8, SMALL_CHUNK](target)
            )
            var m2 = v.slice[SMALL_CHUNK, offset=SMALL_CHUNK * 2]().eq(
                SIMD[DType.uint8, SMALL_CHUNK](target)
            )
            var m3 = v.slice[SMALL_CHUNK, offset=SMALL_CHUNK * 3]().eq(
                SIMD[DType.uint8, SMALL_CHUNK](target)
            )
            return (
                UInt64(pack_bits[DType.uint16](m0))
                | (UInt64(pack_bits[DType.uint16](m1)) << SMALL_CHUNK)
                | (UInt64(pack_bits[DType.uint16](m2)) << SMALL_CHUNK * 2)
                | (UInt64(pack_bits[DType.uint16](m3)) << SMALL_CHUNK * 3)
            )

        return (
            pack4(bytes_vec, quote),
            pack4(bytes_vec, separator),
            pack4(bytes_vec, LF),
            pack4(bytes_vec, CR),
        )


@always_inline
def _scan_chunk_structural[
    origin: Origin
](
    bytes: Span[UInt8, origin],
    offset: Int,
    quote: UInt8,
    separator: UInt8,
    var carried_quote: UInt64,
    var carried_cr: UInt64,
) -> Tuple[UInt64, UInt64, UInt64, UInt64, UInt64, UInt64]:
    """Computes the structural masks for one 64-byte chunk.

    Args:
        bytes: The document bytes.
        offset: Where the chunk starts.
        quote: The quote byte.
        separator: The delimiter byte.
        carried_quote: Quote state entering the chunk (0 or all-ones).
        carried_cr: Whether the byte before the chunk was a CR.

    Returns:
        (delimiters, crlf, row_ends, quotes, next_carried_quote, next_carried_cr)
        -- the structural delimiter mask, the CRLF flag mask, the row-end
        mask, the raw quote mask, and the state to carry into the next chunk.
    """
    # The bounds-checked slice proves the wide load stays inside the chunk.
    var chunk = bytes[offset : offset + CHUNK_SIZE]
    var b = chunk.as_ref().unsafe_load[width=CHUNK_SIZE]()
    var quotes, separators, line_feeds, carriage_returns = _masks_for(
        b, quote, separator
    )

    # Nothing structural and no quote state to carry: an inert chunk.
    if (
        quotes | separators | line_feeds | carriage_returns
    ) == 0 and carried_quote == 0:
        return (0, 0, 0, 0, 0, 0)

    var inside = _prefix_xor(quotes) ^ carried_quote
    # Sign-extending bit 63 carries the state into the next chunk.
    var next_carried_quote = UInt64(Int64(inside) >> 63)

    var cr_shifted = (carriage_returns << 1) | carried_cr
    var next_carried_cr = carriage_returns >> 63

    var crlf = line_feeds & cr_shifted
    var delimiters = (separators | line_feeds) & ~inside
    var row_ends = line_feeds & ~inside
    return (
        delimiters,
        crlf,
        row_ends,
        quotes,
        next_carried_quote,
        next_carried_cr,
    )
