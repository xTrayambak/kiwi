## kiwiopen: a tool to read Kiwi stores
##
## Copyright (C) 2025 Trayambak Rai
import std/[os, options, parseopt, terminal]
import pkg/kiwi

proc dumpKVTable(path: string) =
  try:
    let store = loadStore(path)
    store.close()

    styledWriteLine(stdout, styleBright, path, resetStyle)
    for key, value in store:
      styledWriteLine(
        stdout, fgGreen, key, resetStyle, styleBright, ":", resetStyle, " ", value
      )
  except OSError as exc:
    quit exc.msg

proc main() {.inline.} =
  var opt = initOptParser(commandLineParams())
  var target: Option[string]

  while true:
    opt.next()

    case opt.kind
    of cmdEnd:
      break
    of cmdShortOption, cmdLongOption:
      quit "Unknown option: " & opt.key
    of cmdArgument:
      if target.isSome:
        quit "Cannot operate on two stores at once; choose either of the two:\n* " &
          target.get() & "\n* " & opt.key

      target = some(opt.key)

  if target.isSome:
    dumpKVTable(target.get())

when isMainModule:
  main()
