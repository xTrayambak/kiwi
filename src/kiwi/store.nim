## Store logic
##
## Copyright (C) 2025 Trayambak Rai
import std/[atomics, importutils, locks, os, posix, tables, times]
import pkg/kiwi/[libc, reader, types, writer]

privateAccess(types.Store)

proc commitDataToFile(store: Store, data: seq[uint8]) =
  ## This routine accepts a seq of bytes and writes it to
  ## the disk. It is guaranteed to either perform a full
  ## successful write, or fail. It will never* perform
  ## a partial write.
  acquire(store.writeLock)

  let
    stagingPath = store.path & ".staged"
    stagingFd = open(stagingPath, O_RDWR or O_CREAT, 0o644)

  if stagingFd == -1:
    raise newException(
      WriteError,
      "Cannot create staging file for commit (path `" & stagingPath & "`): " &
        $strerror(errno),
    )

  # We'll need to ensure that every single one of the bytes
  # in `data` is written to the file properly. If we don't,
  # then crap hits the fan.
  var written: uint64
  let total = uint64(data.len)

  while written < total:
    let writtenThisCycle = write(stagingFd, data[written].addr, int(total - written))
    if writtenThisCycle < 0:
      case errno
      of {EINTR, EAGAIN, EWOULDBLOCK}:
        # In these cases, we retry the write cycle next time.
        continue
      else:
        # In all other cases, we abort immediately.
        raise newException(
          WriteError,
          "Cannot commit data from memory to disk (staging file `" & stagingPath & "`): " &
            $strerror(errno),
        )

    written += uint64(writtenThisCycle)

  discard lseek(stagingFd, 0, SEEK_SET)
  discard lseek(store.fd, 0, SEEK_SET)

  # We can then transfer the staging file's contents to the main file.
  if sendfile(store.fd, stagingFd, 0, total) < 0:
    raise newException(
      WriteError,
      "Cannot transfer data from staging store to main store (file `" & store.path &
        "`): " & $strerror(errno),
    )

  discard close(stagingFd)
  release(store.writeLock)
  removeFile(stagingPath)

proc checkAndSynchronize(store: Store) =
  let lastFlushTime = store.lastFlushTime.load()
  let currTime = epochTime()

  if (currTime - lastFlushTime) > store.flushFrequency:
    # It's time to flush again.
    let data = cast[seq[uint8]](writeStore(store))
    commitDataToFile(store, data)
  else:
    return

  store.lastFlushTime.store(currTime, moRelaxed)

proc flushWorker(store: Store) {.thread.} =
  while true:
    let (available, cmd) = store.flushChannel.tryRecv()
    if available:
      case cmd
      of FlushingThreadCommand.Sync:
        let data = cast[seq[uint8]](writeStore(store))
        commitDataToFile(store, data)
      of FlushingThreadCommand.Die:
        break

    checkAndSynchronize(store)

proc loadStore*(
    file: string
): Store {.
    raises: [
      ReaderError, InvalidMagic, InvalidVersion, UnsupportedVersion, InvalidNumPairs,
      IOError, ResourceExhaustedError, OSError,
    ],
    sideEffect
.} =
  ## Given a file `file`, load a Kiwi store from it.
  ## It follows the following logic:
  ##
  ## - If the file exists, open it and parse its contents in the Kiwi binary format.
  ## - If it does not exist, then simply create it. Any future changes will be saved to that destination.
  var fd = open(file.cstring(), O_RDWR or O_CREAT, 0o644)
  if fd == -1:
    raise newException(
      OSError, "Cannot open Kiwi store `" & file & "`: " & $strerror(errno)
    )

  var stat: Stat
  if fstat(fd, stat) == -1:
    raise newException(
      OSError, "Cannot check size of Kiwi store `" & file & "`: " & $strerror(errno)
    )

  let size = stat.st_size
  var store: Store

  if size > 0:
    var content = newSeq[uint8](size)
    if read(fd, content[0].addr, size) < 0:
      raise newException(
        IOError,
        "Cannot read contents of Kiwi store `" & file & "`: " & $strerror(errno),
      )

    store = readStore(cast[string](ensureMove(content)))
  else:
    store = Store()

  store.path = file
  store.writeLock.initLock()
  store.flushChannel.open(1)
  store.fd = fd
  store.flushWorker.createThread(flushWorker, param = store)

  move(store)

proc `[]=`*(store: Store, key, value: string) {.sideEffect.} =
  acquire(store.writeLock)
  store.state[key] = value
  release(store.writeLock)

proc del*(store: Store, key: string): bool {.sideEffect, discardable, raises: [].} =
  ## Delete an item `key` from the store.
  ##
  ## If `key` was found in the store, `true` is returned. Otherwise, `false` is returned.
  if key in store.state:
    acquire(store.writeLock)
    store.state.del(key)
    release(store.writeLock)

    return true
  else:
    return false

iterator items*(store: Store): string =
  ## Get all keys in the store.
  for key, _ in store.state:
    yield key

iterator pairs*(store: Store): (string, string) =
  ## Get all key-value pairs in the store.
  for key, value in store.state:
    yield (key, value)

func `[]`*(store: Store, key: string): string =
  store.state[key]

func state*(store: Store): Table[string, string] {.inline, raises: [], gcsafe.} =
  ## Get a copy of the underlying key-value store state.
  store.state
