/-
  HttpClient/Connection.lean
  Transport layer abstraction and default implementation
-/

import HttpClient.Request
import HttpClient.Response

namespace HttpClient

/-- Errors that can occur during HTTP requests -/
inductive HttpError where
  | parseError (msg : String)      -- URL or response parsing failed
  | connectionError (msg : String) -- Network connection failed
  | timeoutError                   -- Request timed out
  | protocolError (msg : String)   -- Invalid HTTP protocol
  | systemError (msg : String)     -- Implementation specific error (e.g. curl failure)
  deriving Repr, Inhabited

namespace HttpError
  def toString : HttpError → String
    | parseError msg => s!"Parse error: {msg}"
    | connectionError msg => s!"Connection error: {msg}"
    | timeoutError => "Request timeout"
    | protocolError msg => s!"Protocol error: {msg}"
    | systemError msg => s!"System error: {msg}"

  instance : ToString HttpError where
    toString := HttpError.toString
end HttpError

/-- Result type for HTTP operations -/
abbrev HttpResult (α : Type) := Except HttpError α

/--
Transport interface for sending HTTP requests.
Abstracts the underlying implementation (curl, FFI, etc.)
-/
structure Transport where
  /-- Send a request with a timeout in milliseconds -/
  send : Request → Nat → IO (HttpResult Response)

namespace Transport

/--
Default implementation using curl via IO.Process.spawn
-/
def curl : Transport := {
  send := fun req timeoutMs => do
    -- Convert timeout to seconds (curl --max-time supports decimals)
    let timeoutSec := (timeoutMs.toFloat / 1000.0).toString

    let mut args := #[
      "--silent",           -- Suppress progress meter
      "--show-error",       -- Show errors if they occur
      "--include",          -- Include headers in output
      "--no-buffer",        -- Disable buffering
      "--max-time", timeoutSec,
      "--max-redirs", "0"   -- Do not auto-follow redirects
    ]

    -- Method
    args := args.push "--request"
    args := args.push (toString req.method)

    -- Headers
    for (name, value) in req.headers do
      args := args.push "--header"
      args := args.push s!"{name}: {value}"

    -- Host (if missing)
    if !req.headers.contains "Host" then
      args := args.push "--header"
      args := args.push s!"Host: {req.url.authority}"

    -- Body
    match req.body with
    | some body =>
      args := args.push "--data-raw" -- Use data-raw to avoid @file processing
      args := args.push body
    | none => pure ()

    -- URL (last argument)
    args := args.push req.url.toString

    let result ← IO.Process.output {
      cmd := "curl"
      args := args
    }

    -- Handle timeouts (curl exit code 28)
    if result.exitCode == 28 then
      return .error .timeoutError

    -- Handle other curl errors
    if result.exitCode != 0 then
      return .error (.systemError s!"curl exited with {result.exitCode}: {result.stderr}")

    -- Parse the response
    match Response.parse result.stdout with
    | some response => return .ok response
    | none => return .error (.parseError "Failed to parse HTTP response")
}

end Transport

end HttpClient

