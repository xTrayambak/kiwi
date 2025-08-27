## http server test using mummy to simulate a long running process

import std/[atomics, tables]
import pkg/kiwi, pkg/mummy, pkg/mummy/routers

var store = loadStore("test.kw")
var pStore = store.addr # silly hack
store["hi"] = "hello"

var i: Atomic[int]
proc addTodo(req: Request) {.gcsafe.} =
  let num = i.load()
  let msg = req.queryParams["msg"]
  pStore[][$num] = msg
  i.store(num + 1)

  req.respond(200, body = "Success :D")

proc getTodos(req: Request) {.gcsafe.} =
  # karax? never heard of her. vdom? what's that?

  var src =
    """
<!--Copyright (C) 2025 Trayware Corporation. If you copy my precious code, you can expect to see my lawyers the next day.-->
<!DOCTYPE html>
<html>
  <head><title>Todo List</title></head>
  <body>
    <h1>Revolutionary Todo List Viewer</h1>
  """
  for key, value in pStore[].state:
    src &= "<h2>Todo #<bold>" & key & "</bold></h2>"
    src &= "<h3>" & value & "</h3><br><br>"

  src &=
    """
    <footer>Want to license this revolutionary technology for your own startup? Contact us at: +91 092890 88156</footer>
    <footer>If you attempt to <bold>ILLEGALLY</bold> copy this, my lawyers will revoke your inalienable human rights<footer>
  </body>
</html>
  """
  req.respond(200, body = move src)

var router: Router
router.get("/addtodo", addTodo)
router.get("/gettodos", getTodos)
  # i know, GET isn't appropriate here... wanna fight me about it?
var server = newServer(router)
server.serve(Port(8080))

store.close()
