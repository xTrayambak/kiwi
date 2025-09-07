# Package

version = "0.1.0"
author = "Trayambak Rai"
description = "A high-performance key-value store written in pure Nim"
license = "MIT"
srcDir = "src"
installExt = @["nim"]
bin = @["kiwiopen"]

# Dependencies

requires "nim >= 2.2.0"
requires "flatty >= 0.3.4"
requires "pretty >= 0.2.0"
