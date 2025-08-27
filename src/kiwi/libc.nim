## libc functions that kiwi requires
##
## Copyright (C) 2025 Trayambak Rai (xtrayambak at disroot dot org)

proc sendfile*(
  outFd: int32, inFd: int32, offset: uint, count: uint
): uint64 {.importc, header: "<sys/sendfile.h>".}
