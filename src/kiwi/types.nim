## All core types used by Kiwi
##
## Copyright (C) 2025 Trayambak Rai
import std/[atomics, locks, tables, posix]

type
  WriteError* = object of IOError

  FlushingThreadCommand* {.size: sizeof(uint8), pure.} = enum
    Sync
    Die

  StoreObj* = object
    state: Table[string, string]
    path: string
    fd: int32

    writeLock: Lock

    flushChannel: Channel[FlushingThreadCommand]
    flushWorker: Thread[Store]
    lastFlushTime: Atomic[float]
    flushFrequency*: float = 60f

    formatVersion: uint32

  Store* = ref StoreObj

proc close*(store: Store) =
  store.flushChannel.send(FlushingThreadCommand.Sync)
  store.flushChannel.send(FlushingThreadCommand.Die)
    # Tell the flushing worker to flush the database for the last time.
  store.flushWorker.joinThread()
  discard store.fd.close()
  store.writeLock.deinitLock()
