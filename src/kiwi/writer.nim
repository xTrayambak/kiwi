## Kiwi store writer
##
## Copyright (C) 2025 Trayambak Rai
import std/[importutils, tables]
import pkg/kiwi/[common, types]
import pkg/flatty/binny

privateAccess(types.Store)

proc writeStore*(store: StoreObj | Store): string =
  var output = newString(7)
  output.writeUint16(0, KiwiMagicHeader)
  output.writeUint32(2, FormatVersion)
  output.writeUint64(6, uint64(store.state.len))

  var offset = 14
  for key, value in store.state:
    output.setLen(offset + key.len + 2)
    for c in key:
      output.writeUint8(offset, cast[uint8](c))
      inc offset

    offset += 1
    output.writeUint8(offset, 0'u8)

    output.setLen(offset + value.len + 2)
    for c in value:
      output.writeUint8(offset, cast[uint8](c))
      inc offset

    offset += 1
    output.writeUint8(offset, 0'u8)

  move(output)
