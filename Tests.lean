import HttpClient

open HttpClient

def assert (msg : String) (cond : Bool) : IO Unit := do
  if !cond then
    throw $ IO.userError s!"Assertion failed: {msg}"
  else
    IO.println s!"PASS: {msg}"

def testUrlParsing : IO Unit := do
  IO.println "Testing URL Parsing..."
  match Url.parse "http://example.com" with
  | some u =>
    assert "scheme is http" (u.scheme == "http")
    assert "host is example.com" (u.host == "example.com")
    assert "path is /" (u.path == "/")
  | none => assert "Parse failed" false

  match Url.parse "https://api.example.com:8080/v1/users?q=lean#frag" with
  | some u =>
    assert "scheme is https" (u.scheme == "https")
    assert "port is 8080" (u.port == some 8080)
    assert "query is q=lean" (u.query == some "q=lean")
    assert "fragment is frag" (u.fragment == some "frag")
  | none => assert "Complex parse failed" false

def testRequestBuilding : IO Unit := do
  IO.println "Testing Request Building..."
  let u := Url.http "example.com"
  let req := Request.post u |>.withHeader "X-Test" "Value" |>.withJson "{\"a\":1}"
  assert "Method is POST" (req.method == Method.POST)
  assert "Header present" (req.headers.get "X-Test" == some "Value")
  assert "Content-Type json" (req.headers.contentType == some "application/json")

def testResponseParsing : IO Unit := do
  IO.println "Testing Response Parsing..."
  let raw := "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nBody"
  match Response.parse raw with
  | some res =>
    assert "Status 200" (res.status.code == 200)
    assert "Body correct" (res.body == "Body")
  | none => assert "Response parse failed" false

def testMockTransport : IO Unit := do
  IO.println "Testing Client with Mock Transport..."
  -- Define a mock transport
  let mockTransport : Transport := {
    send := fun req _ => do
      if req.url.host == "mock.local" then
        return .ok (Response.ok "Mock Response")
      else
        return .error (.connectionError "Unknown host")
  }

  -- Construct client directly with mock transport
  let client : Client := { config := {}, transport := mockTransport }

  match Url.parse "http://mock.local/test" with
  | some u =>
    match ← client.send (Request.get u) with
    | .ok res => assert "Mock response received" (res.body == "Mock Response")
    | .error e => assert s!"Mock failed: {e}" false
  | none => assert "Url parse failed" false

def main : IO Unit := do
  testUrlParsing
  testRequestBuilding
  testResponseParsing
  testMockTransport
  IO.println "All tests passed!"

