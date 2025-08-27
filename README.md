# kiwi
Kiwi is a fast key-value store written in the Nim programming language. It aims to be a replacement for [LevelDB](https://github.com/google/leveldb).

## usage
Using kiwi is pretty much like using a `Table` from the standard library, only that this table is continually backed up to the disk.
```nim
import pkg/kiwi

var db = loadStore("users.kw")
db["user-1"] = "Mark"
db["user-2"] = "Another Mark"
db["user-3"] = "Yet Another Mark"
db["user-4"] = "To (nobody's) surprise, another Mark"
db["user-5"] = "...yet another Mark"

db.close() # You should ideally call this when your program is about to exit.
```
Even if you don't call `close()` on the store, it spawns a thread that continually writes the in-memory data to the disk. The default interval for this is 1 minute.

## production use
Kiwi was written in my school's computer lab in 3 hours, with an extra 2 hours of work dedicated to it at my house. That being said, I have used it in some places:

- A Discord bot 
