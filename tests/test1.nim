import std/tables
import pkg/kiwi, pkg/pretty

var store = loadStore("test.kw")
print store.state

store["hi"] = "hello"
store.close()
