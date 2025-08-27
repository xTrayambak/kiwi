## Kiwi store reader
##
## Copyright (C) 2025 Trayambak Rai
import std/[importutils, tables]
import pkg/kiwi/[common, types]
import pkg/flatty/binny

privateAccess(types.Store)

type
  ReaderError* = object of ValueError
  InvalidMagic* = object of ReaderError

  InvalidVersion* = object of ReaderError
  UnsupportedVersion* = object of ReaderError

  InvalidNumPairs* = object of ReaderError

proc hasEnoughRoom(data: string, offset: int, length: int): bool =
  (data.len - offset) > length

proc verifyMagicHeader*(data: string): int {.raises: [InvalidMagic].} =
  if data.len < 2:
    raise
      newException(InvalidMagic, "Data is not long enough to contain the magic header.")

  if data.readUint16(0) != KiwiMagicHeader:
    raise newException(InvalidMagic, "Data does not start with magic header.")

  sizeof(uint16)

proc loadFormatVersion*(
    data: string, offset: int, dest: out uint32
): int {.raises: [InvalidVersion, UnsupportedVersion].} =
  if not data.hasEnoughRoom(offset, sizeof(uint32)):
    raise newException(
      InvalidVersion, "Data is not long enough to contain the format version."
    )

  dest = data.readUint32(offset)

  if dest notin SupportedVersions:
    raise newException(
      UnsupportedVersion,
      "This file uses Kiwi format version " & $dest &
        " - this version of the library does not support reading it.",
    )

  sizeof(uint32)

proc loadNumPairs*(
    data: string, offset: int, numPairs: out uint
): int {.raises: [InvalidNumPairs].} =
  if not data.hasEnoughRoom(offset, sizeof(uint)):
    raise newException(
      InvalidNumPairs, "Data is not long enough to contain the pair count integer."
    )

  numPairs = data.readUint64(offset).uint()

  sizeof(uint)

proc readKVPairs*(data: string, store: Store, numPairs: uint, offset: int) =
  var ioff = offset
  for n in 0 ..< numPairs:
    var key, value: string

    while true:
      let c = cast[char](data.readUint8(ioff))
      if c == '\0':
        inc ioff
        break

      key &= c
      inc ioff

    while true:
      let c = cast[char](data.readUint8(ioff))
      if c == '\0':
        inc ioff
        break

      value &= c
      inc ioff

    store.state[move(key)] = move(value)

proc readStore*(data: string): Store =
  var store = Store() # cast[Store](alloc(sizeof(StoreObj)))

  var
    offset: int
    numPairs: uint

  # offset = 0
  offset += verifyMagicHeader(data) # uint16 - 2
  offset += loadFormatVersion(data, offset, store.formatVersion) # uint32 - 4
  offset += loadNumPairs(data, offset, numPairs) # uint64 - 8

  readKVPairs(data, store, numPairs, offset)

  move(store)
