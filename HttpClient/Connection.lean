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
    let mut tmpBodyFile : Option System.FilePath := none
    
    match req.body with
    | some (.Text s) =>
      args := args.push "--data-raw"
      args := args.push s
    | some (.Binary b) =>
      -- Write to temp file
      let tmp : System.FilePath := s!"req-body-{← IO.monoMsNow}.tmp"
      IO.FS.writeBinFile tmp b
      tmpBodyFile := some tmp
      args := args.push "--data-binary"
      args := args.push s!"@{tmp}"
    | some (.Stream p) =>
      args := args.push "--data-binary"
      args := args.push s!"@{p}"
    | none => pure ()

    -- Handle Response Destination
    let result ← match req.responsePath with
    | none =>
      -- Standard stdout capture
      args := args.push "--include" -- Include headers
      args := args.push req.url.toString
      
      IO.Process.output {
        cmd := "curl"
        args := args
      }

    | some path =>
      -- Stream to file
      let headerFile : System.FilePath := s!"{path}.headers"
      args := args.push "--dump-header"; args := args.push headerFile.toString
      args := args.push "--output"; args := args.push path.toString
      args := args.push req.url.toString
      
      IO.Process.output {
        cmd := "curl"
        args := args
      }

    -- Cleanup temp body file
    if let some tmp := tmpBodyFile then
      try IO.FS.removeFile tmp catch _ => pure ()

    -- Handle timeouts (curl exit code 28)
    if result.exitCode == 28 then
      return .error .timeoutError

    -- Handle other curl errors
    if result.exitCode != 0 then
      return .error (.systemError s!"curl exited with {result.exitCode}: {result.stderr}")

    -- Parse Response
    match req.responsePath with
    | none =>
      -- Parse stdout (headers + body)
      match Response.parse result.stdout with
      | some response => return .ok response
      | none => return .error (.parseError "Failed to parse HTTP response")
    
    | some path =>
      -- Read headers from file
      let headerFile : System.FilePath := s!"{path}.headers"
      if ← System.FilePath.pathExists headerFile then
        let headerRaw ← IO.FS.readFile headerFile
        -- Cleanup
        try IO.FS.removeFile headerFile catch _ => pure ()
        
        -- Parse headers
        match Response.splitOnCRLF headerRaw with
        | some (statusLine, headerRest) =>
             match Response.parseStatusLine statusLine with
             | some status =>
                 let headers := Response.parseHeaders headerRest
                 return .ok {
                   status := status
                   headers := headers
                   body := .Stream path
                 }
             | none => return .error (.parseError "Failed to parse status line from dump-header")
        | none => return .error (.parseError "Empty header file")

      else
        return .error (.systemError "Header file missing after curl success")
}

end Transport

end HttpClient

