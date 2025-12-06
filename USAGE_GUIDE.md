# HTTP Client Usage Guide for Other Lean Projects

Author Note: This was vibe coded using Cursor and Claude-Code. No garuntees.

This guide explains how to integrate the HTTP Client library into your own Lean 4 projects.

## Table of Contents

1. [Setup](#setup)
2. [Basic Integration](#basic-integration)
3. [Common Patterns](#common-patterns)
4. [Error Handling](#error-handling)
5. [Testing](#testing)
6. [Troubleshooting](#troubleshooting)

## Setup

### Step 1: Add Dependency to lakefile.lean

Edit your project's `lakefile.lean` and add:

```lean
require http-client from git "https://github.com/yourusername/http-client.git"
```

For a specific version/branch:

```lean
require http-client from git "https://github.com/yourusername/http-client.git" @ "v1.0.0"
```

### Step 2: Update Lake Dependencies

```bash
lake update
```

### Step 3: Verify Installation

Create a simple test file to verify it works:

```lean
import HttpClient

def main : IO Unit := do
  IO.println "HttpClient library loaded successfully"
```

Build and run:

```bash
lake build
```

## Basic Integration

### Example 1: Simple GET Request

```lean
import HttpClient

def fetchData (url : String) : IO Unit := do
  match ← HttpClient.get url with
  | .ok res =>
    IO.println s!"Status: {res.status.code}"
    IO.println res.body
  | .error err =>
    IO.eprintln s!"Error: {err}"

def main : IO Unit := do
  ← fetchData "https://api.example.com/users"
```

### Example 2: Extracting Information from Response

```lean
import HttpClient

def getJsonData (url : String) : IO (Option String) := do
  match ← HttpClient.get url with
  | .ok res =>
    if res.status.isSuccess then
      return some res.body
    else
      IO.eprintln s!"HTTP {res.status.code}: {res.status.reason}"
      return none
  | .error err =>
    IO.eprintln s!"Request failed: {err}"
    return none

def main : IO Unit := do
  let json? ← getJsonData "https://jsonplaceholder.typicode.com/posts/1"
  match json? with
  | some json => IO.println s!"Got data: {json.take 100}..."
  | none => IO.println "Failed to get data"
```

### Example 3: POST Request with Payload

```lean
import HttpClient

def createUser (name age : String) : IO (Option String) := do
  let json := s!"""{{\"name\": \"{name}\", \"age\": {age}}}"""
  match ← HttpClient.postJson "https://api.example.com/users" json with
  | .ok res => return some res.body
  | .error err =>
    IO.eprintln s!"Error: {err}"
    return none

def main : IO Unit := do
  let result? ← createUser "Alice" "30"
  match result? with
  | some res => IO.println s!"User created: {res}"
  | none => IO.println "Failed to create user"
```

## Common Patterns

### Pattern 1: Wrapping with Error Types

Define custom error types for your application:

```lean
import HttpClient

inductive ApiError where
  | httpError (err : HttpClient.HttpError)
  | parseError (msg : String)
  | invalidResponse (msg : String)
  deriving Repr

def ApiResult (α : Type) := Except ApiError α

def toApiError : HttpClient.HttpError → ApiError
  | .parseError msg => .parseError msg
  | .connectionError msg => .httpError (.connectionError msg)
  | .timeoutError => .httpError .timeoutError
  | .protocolError msg => .httpError (.protocolError msg)
  | .systemError msg => .httpError (.systemError msg)

def getJson (url : String) : IO (ApiResult String) := do
  match ← HttpClient.get url with
  | .ok res =>
    if res.status.isSuccess then
      return .ok res.body
    else
      return .error (.invalidResponse s!"HTTP {res.status.code}")
  | .error err => return .error (toApiError err)
```

### Pattern 2: Reusable HTTP Functions

Create a module with common HTTP operations:

```lean
import HttpClient

namespace MyApp

def httpGet (url : String) : IO (Except String String) := do
  match ← HttpClient.get url with
  | .ok res =>
    if res.status.isSuccess then .ok res.body else .error s!"HTTP {res.status.code}"
  | .error err => .error s!"{err}"

def httpPost (url : String) (body : String) : IO (Except String String) := do
  match ← HttpClient.post url body with
  | .ok res =>
    if res.status.isSuccess then .ok res.body else .error s!"HTTP {res.status.code}"
  | .error err => .error s!"{err}"

def httpPostJson (url : String) (json : String) : IO (Except String String) := do
  match ← HttpClient.postJson url json with
  | .ok res =>
    if res.status.isSuccess then .ok res.body else .error s!"HTTP {res.status.code}"
  | .error err => .error s!"{err}"

end MyApp
```

### Pattern 3: Custom Client Configuration

```lean
import HttpClient

namespace MyApp

def createApiClient (apiKey : String) : IO HttpClient.Client := do
  let config : HttpClient.Config := {
    defaultHeaders := [
      ("Authorization", s!"Bearer {apiKey}"),
      ("User-Agent", "MyApp/1.0")
    ]
    followRedirects := true
    maxRedirects := 5
    timeout := 30
  }
  HttpClient.Client.new config

def sendRequest (client : HttpClient.Client) (method : HttpClient.Method) (path : String) (body? : Option String) : IO (Except String String) := do
  let url := HttpClient.Url.https "api.example.com" path
  let req := match method with
    | .GET => HttpClient.Request.get url
    | .POST =>
      let r := HttpClient.Request.post url
      match body? with
      | some b => r.withBody b
      | none => r
    | _ => HttpClient.Request.get url  -- simplified

  match ← client.send req with
  | .ok res => .ok res.body
  | .error err => .error s!"{err}"

end MyApp
```

### Pattern 4: Testing with Mock Transport

```lean
import HttpClient

namespace Tests

def mockTransport : HttpClient.Transport := {
  send := fun req _ => do
    if req.url.path == "/users" && req.method == .GET then
      let response := HttpClient.Response.ok """[{"id": 1, "name": "Alice"}]"""
      return .ok response
    else if req.url.path == "/users" && req.method == .POST then
      let response := HttpClient.Response.ok """{"id": 2, "name": "Bob"}"""
      return .ok { response with status := { code := 201, reason := "Created" } }
    else
      return .error (.connectionError "Unknown path")
}

def testClient : HttpClient.Client := {
  config := {}
  transport := mockTransport
}

def testGetUsers : IO Unit := do
  let url := HttpClient.Url.http "api.test" "/users"
  let req := HttpClient.Request.get url
  match ← testClient.send req with
  | .ok res =>
    assert "Status 200" (res.status.code == 200)
    assert "Has users" (res.body.contains "Alice")
  | .error _ => assert "Request failed" false

def testCreateUser : IO Unit := do
  let url := HttpClient.Url.http "api.test" "/users"
  let req := HttpClient.Request.post url |>.withJson """{"name": "Bob"}"""
  match ← testClient.send req with
  | .ok res =>
    assert "Status 201" (res.status.code == 201)
    assert "Has user id" (res.body.contains "id")
  | .error _ => assert "Request failed" false

def runTests : IO Unit := do
  testGetUsers
  testCreateUser
  IO.println "All tests passed!"

end Tests

def main : IO Unit := Tests.runTests
```

## Error Handling

### Comprehensive Error Handling

```lean
import HttpClient

def robustRequest (url : String) : IO Unit := do
  match ← HttpClient.get url with
  | .ok res =>
    if res.status.isSuccess then
      IO.println "Success!"
      IO.println res.body
    else if res.status.isRedirect then
      IO.println s!"Redirect to: {res.headers.location.getD "unknown"}"
    else if res.status.isClientError then
      IO.eprintln s!"Client error: {res.status.code} {res.status.reason}"
    else
      IO.eprintln s!"Server error: {res.status.code}"

  | .error err =>
    match err with
    | .parseError msg =>
      IO.eprintln s!"Invalid URL or response format: {msg}"
    | .connectionError msg =>
      IO.eprintln s!"Network error: {msg}"
    | .timeoutError =>
      IO.eprintln "Request timed out (exceeded timeout limit)"
    | .protocolError msg =>
      IO.eprintln s!"HTTP protocol error: {msg}"
    | .systemError msg =>
      IO.eprintln s!"System error: {msg}"
```

### Retry Logic

```lean
import HttpClient

def retryRequest (url : String) (maxAttempts : Nat := 3) : IO (Except String String) := do
  let rec loop (attempts : Nat) : IO (Except String String) := do
    if attempts >= maxAttempts then
      return .error "Max retries exceeded"

    match ← HttpClient.get url with
    | .ok res =>
      if res.status.isSuccess then
        return .ok res.body
      else if res.status.code >= 500 && attempts < maxAttempts - 1 then
        -- Retry on server errors
        IO.println s!"Server error, retrying... (attempt {attempts + 1})"
        loop (attempts + 1)
      else
        return .error s!"HTTP {res.status.code}"

    | .error (.connectionError msg) if attempts < maxAttempts - 1 =>
      -- Retry on connection errors
      IO.println s!"Connection error, retrying... (attempt {attempts + 1})"
      loop (attempts + 1)

    | .error err =>
      return .error s!"{err}"

  loop 0
```

## Testing

### Unit Testing with Mock Transport

```lean
import HttpClient

-- Set up mock responses
def mockApiClient : IO HttpClient.Client := do
  let transport : HttpClient.Transport := {
    send := fun req timeout => do
      if req.url.host == "api.test" then
        let mockResponse := HttpClient.Response.ok "mock data"
        return .ok mockResponse
      else
        return .error (.connectionError "Invalid host")
  }
  return { config := {}, transport := transport }

-- Test function
def testMyHttpCode : IO Unit := do
  let client ← mockApiClient
  let url := HttpClient.Url.http "api.test" "/data"
  let req := HttpClient.Request.get url

  match ← client.send req with
  | .ok res =>
    assert res.body == "mock data"
    IO.println "Test passed!"
  | .error _ =>
    IO.println "Test failed!"
```

## Troubleshooting

### Issue: "curl: command not found"

**Solution**: Make sure curl is installed:
- macOS: `brew install curl`
- Ubuntu: `sudo apt-get install curl`
- Fedora: `sudo dnf install curl`

### Issue: URL parsing fails

Ensure the URL is properly formatted:

```lean
-- Good
HttpClient.Url.parse "https://example.com/api"

-- Bad (missing scheme)
HttpClient.Url.parse "example.com/api"

-- Check with pattern match
match HttpClient.Url.parse "..." with
| some url => -- use url
| none => IO.eprintln "Invalid URL format"
```

### Issue: Timeout errors during slow requests

Increase the timeout in config:

```lean
let config : HttpClient.Config := {
  timeout := 60  -- 60 seconds instead of default 30
}
let client ← HttpClient.Client.new config
```

### Issue: TLS/SSL certificate errors

The curl backend handles these. Ensure:
1. System certificates are up to date
2. You're connecting to valid HTTPS endpoints
3. For self-signed certificates, use custom curl flags (advanced)

### Issue: Response parsing fails

Debug by checking raw response:

```lean
match ← HttpClient.get url with
| .ok res =>
  IO.println s!"Raw body: {res.body}"
  IO.println s!"Status: {res.status}"
  IO.println s!"Headers: {res.headers}"
| .error err =>
  IO.eprintln s!"Error: {err}"
```

### Issue: Large response bodies cause memory issues

The library loads entire responses into memory as strings. For large files:
1. Use streaming (future enhancement)
2. Store to file via external tool
3. Split requests with range headers

## Next Steps

- Check out [API Documentation](./README.md) for complete API reference
- See `Example.lean` for working examples
- Review `Tests.lean` for test patterns
- Explore `HttpClient/` module directory for implementation details
