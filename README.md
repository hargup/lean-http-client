# HTTP Client for Lean 4

A type-safe, composable HTTP/1.1 client library for Lean 4. Built on top of `curl` via FFI, providing a clean, idiomatic Lean interface for making HTTP requests.

## Features

- **Type Safety**: Leverages Lean's type system to prevent invalid HTTP constructs
- **Pure API**: Separates pure HTTP logic from IO operations
- **Composability**: Build complex requests from simple, composable parts
- **Correct**: Follows HTTP/1.1 specification (RFC 7230-7235)
- **Curl Transport**: Uses the battle-tested `curl` library under the hood
- **Redirect Support**: Automatic HTTP redirect following (configurable)
- **JSON Support**: Convenient builders for JSON requests
- **Custom Headers**: Flexible header management with case-insensitive lookups

## Installation

### Prerequisites

- **Lean 4** (v4.25.2 or later)
- **curl** (usually pre-installed on macOS/Linux)
  - macOS: `brew install curl` or use system curl
  - Ubuntu/Debian: `sudo apt-get install curl`
  - Fedora/RHEL: `sudo dnf install curl`

### Add to Your Project

Add this to your `lakefile.lean`:

```lean
require http-client from git "https://github.com/hargup/lean-http-client.git"
```

Then run:

```bash
lake update
```

## Quick Start

### Simple GET Request

```lean
import HttpClient

def main : IO Unit := do
  match ← HttpClient.get "https://api.example.com/data" with
  | .ok res =>
    IO.println s!"Status: {res.status.code}"
    IO.println res.body
  | .error err =>
    IO.eprintln s!"Error: {err}"
```

### POST Request with JSON

```lean
import HttpClient

def main : IO Unit := do
  let json := """{"name": "John", "age": 30}"""
  match ← HttpClient.postJson "https://api.example.com/users" json with
  | .ok res => IO.println res.body
  | .error err => IO.eprintln s!"Error: {err}"
```

### Custom Client with Configuration

```lean
import HttpClient

def main : IO Unit := do
  let config : HttpClient.Config := {
    followRedirects := true
    maxRedirects := 5
    timeout := 30  -- seconds
  }
  let client ← HttpClient.Client.new config

  let url := HttpClient.Url.parse "https://api.example.com/data" |>.get!
  let req := HttpClient.Request.get url
                |>.withHeader "Authorization" "Bearer token123"

  match ← client.send req with
  | .ok res => IO.println res.body
  | .error err => IO.eprintln s!"Error: {err}"
```

## Core API

### Creating URLs

```lean
-- Parse from string
let url? := HttpClient.Url.parse "https://example.com/api?key=value"

-- Create manually
let url := HttpClient.Url.http "example.com" "/api"
let url := HttpClient.Url.https "example.com" "/api"

-- Modify URLs
let url := HttpClient.Url.http "example.com"
  |>.withPort 8080
  |>.withPath "/api/v1"
  |>.withQuery "key=value"
```

### Building Requests

```lean
let req := HttpClient.Request.get url
  |>.withHeader "User-Agent" "MyApp/1.0"
  |>.withHeader "Accept" "application/json"

let req := HttpClient.Request.post url
  |>.withBody "raw body content"

let req := HttpClient.Request.post url
  |>.withJson "{\"key\": \"value\"}"
  -- Automatically sets Content-Type: application/json

let req := HttpClient.Request.put url
  |>.withBody "updated data"

let req := HttpClient.Request.delete url
```

### Accessing Response Data

```lean
let res : HttpClient.Response := ...

-- Status information
let code : Nat := res.status.code
let reason : String := res.status.reason
let isSuccess := res.status.isSuccess  -- 2xx responses

-- Headers
let contentType := res.headers.contentType
let contentLength := res.headers.contentLength
let customHeader := res.headers.get "X-Custom-Header"

-- Body
let body : String := res.body
```

## Error Handling

All HTTP operations return `IO (HttpResult Response)` where `HttpResult` is `Except HttpError`.

```lean
inductive HttpError where
  | parseError (msg : String)      -- URL or response parsing failed
  | connectionError (msg : String) -- Network error
  | timeoutError                   -- Request timeout
  | protocolError (msg : String)   -- HTTP protocol violation
  | systemError (msg : String)     -- curl or system error
```

Pattern match on errors:

```lean
match ← HttpClient.get url with
| .ok res => IO.println res.body
| .error (.parseError msg) => IO.eprintln s!"Parse error: {msg}"
| .error (.connectionError msg) => IO.eprintln s!"Connection failed: {msg}"
| .error .timeoutError => IO.eprintln "Request timed out"
| .error err => IO.eprintln s!"Error: {err}"
```

## Configuration

The `Config` structure allows customization:

```lean
structure Config where
  defaultHeaders : Headers := Headers.empty
  followRedirects : Bool := true
  maxRedirects : Nat := 5
  timeout : Nat := 30  -- seconds
```

Example:

```lean
let config : HttpClient.Config := {
  defaultHeaders := [("User-Agent", "MyApp/1.0")]
  followRedirects := false
  timeout := 60
}

let client ← HttpClient.Client.new config
```

## Advanced Usage

### Custom Headers

```lean
let req := HttpClient.Request.get url
  |>.withHeader "Authorization" "Bearer token"
  |>.withHeader "X-API-Key" "secret"

-- Access headers
let authHeader := req.headers.get "Authorization"

-- Case-insensitive header lookup
let contentType := req.headers.get "content-type"  -- matches "Content-Type"
```

### Testing with Mock Transport

For testing without network access, you can create a mock transport:

```lean
let mockTransport : HttpClient.Transport := {
  send := fun req _ => do
    if req.url.host == "mock.local" then
      return .ok (HttpClient.Response.ok "Mock response")
    else
      return .error (.connectionError "Unknown host")
}

let client : HttpClient.Client := {
  config := {}
  transport := mockTransport
}

let res ← client.send (HttpClient.Request.get testUrl)
```

## Module Structure

```
HttpClient/
├── Basic.lean          -- Core types (Method, Status, Headers)
├── Url.lean            -- URL parsing and representation
├── Request.lean        -- HTTP Request type and builder
├── Response.lean       -- HTTP Response type and parser
├── Message.lean        -- HTTP message serialization
├── Connection.lean     -- Transport interface and implementations
├── Client.lean         -- High-level Client struct and logic
└── HttpClient.lean     -- Main module (re-exports)
```

## Implementation Details

### Curl Transport

The default transport implementation uses `curl` via `IO.Process.spawn`:
- Maps configuration options to curl flags (`--max-time`, `--location`, etc.)
- Parses curl's output to construct Response objects
- Handles curl exit codes and maps them to `HttpError`

### Why Curl?

Using curl via FFI provides:
- **Battle-tested**: Curl is used by millions of applications
- **Feature-complete**: HTTP/2 support, advanced TLS options, proxy support
- **Portable**: Works across all major platforms
- **Minimal Dependencies**: No need for large Lean networking libraries

## Examples

See the `Example.lean` file for a working example:

```bash
lake build && .lake/build/bin/http-client
```

This fetches from `http://example.com` and displays the response status, headers, and body.

## Testing

The project includes comprehensive unit tests (Tests.lean):

```lean
-- URL parsing
-- Request building
-- Response parsing
-- Mock transport verification
```

Run tests with:

```bash
lake build Tests
```

## Performance Characteristics

- **Startup**: ~50-100ms (process spawn overhead for curl)
- **Request**: Depends on network latency (curl's performance)
- **Memory**: Minimal - responses stored entirely in memory as strings

For high-performance scenarios or streaming large files, consider native socket implementations (future work).

## Limitations

- **No HTTP/2 or HTTP/3**: Uses HTTP/1.1 only
- **In-memory only**: All request and response bodies are strings in memory
- **No connection pooling**: Each request spawns a new curl process
- **No streaming**: Cannot process large files without loading entirely into memory

## Contributing

Contributions welcome! Areas for improvement:
- Native socket implementation (no curl dependency)
- HTTP/2 support
- Streaming request/response bodies
- Connection pooling
- Cookie jar support

## License

MIT License. See LICENSE file for details.

## Related Resources

- [Curl Documentation](https://curl.se/docs/)
- [HTTP/1.1 Specification (RFC 7230-7235)](https://tools.ietf.org/html/rfc7230)
- [Lean 4 Documentation](https://lean-lang.org/lean4/doc/)
