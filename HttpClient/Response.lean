/-
  HttpClient/Response.lean
  HTTP Response type and parser
-/

import HttpClient.Basic

namespace HttpClient

/-- HTTP Response -/
structure Response where
  status : Status
  headers : Headers
  body : HttpBody
  deriving Repr, Inhabited

namespace Response

  /-- Helper: find substring -/
  private partial def findSubstr? (s : String) (pattern : String) : Option (String.Pos.Raw × String.Pos.Raw) :=
    if pattern.isEmpty then some (String.Pos.Raw.mk 0, String.Pos.Raw.mk 0)
    else
      let pLen := pattern.toSubstring.bsize
      let rec loop (pos : String.Pos.Raw) : Option (String.Pos.Raw × String.Pos.Raw) :=
        if String.Pos.Raw.atEnd s pos then none
        else
          -- String.Pos.Raw is a wrapper around Nat, we can construct it
          let endPos : String.Pos.Raw := String.Pos.Raw.mk (pos.byteIdx + pLen)
          -- Check if match
          if (String.Pos.Raw.extract s pos endPos) == pattern then
            some (pos, endPos)
          else
            loop (String.Pos.Raw.next s pos)
      loop (String.Pos.Raw.mk 0)

  /-- Helper: contains substring -/
  private def containsSubstr (s : String) (pattern : String) : Bool :=
    (findSubstr? s pattern).isSome

  /-- Is this a successful response (2xx)? -/
  def isSuccess (r : Response) : Bool := r.status.isSuccess

  /-- Is this a redirect response (3xx)? -/
  def isRedirect (r : Response) : Bool := r.status.isRedirect

  /-- Is this an error response (4xx or 5xx)? -/
  def isError (r : Response) : Bool := r.status.isError

  /-- Is this a client error (4xx)? -/
  def isClientError (r : Response) : Bool := r.status.isClientError

  /-- Is this a server error (5xx)? -/
  def isServerError (r : Response) : Bool := r.status.isServerError

  /-- Get the Content-Type header -/
  def contentType (r : Response) : Option String := r.headers.contentType

  /-- Get the Content-Length header -/
  def contentLength (r : Response) : Option Nat := r.headers.contentLength

  /-- Get the Location header (for redirects) -/
  def location (r : Response) : Option String := r.headers.location

  /-- Is this a JSON response? -/
  def isJson (r : Response) : Bool :=
    match r.contentType with
    | some ct => containsSubstr ct "application/json"
    | none => false

  /-- Helper: split string on first CRLF -/
  def splitOnCRLF (s : String) : Option (String × String) :=
    let crlf := "\r\n"
    match findSubstr? s crlf with
    | some ⟨startPos, endPos⟩ =>
      let first := String.Pos.Raw.extract s (String.Pos.Raw.mk 0) startPos
      let rest := String.Pos.Raw.extract s endPos (String.endPos s)
      some (first, rest)
    | none => none

  /-- Helper: find double CRLF (end of headers) -/
  def findHeaderEnd (s : String) : Option (String × String) :=
    let doubleCrlf := "\r\n\r\n"
    match findSubstr? s doubleCrlf with
    | some ⟨startPos, endPos⟩ =>
      let headers := String.Pos.Raw.extract s (String.Pos.Raw.mk 0) startPos
      let body := String.Pos.Raw.extract s endPos (String.endPos s)
      some (headers, body)
    | none => none

  /-- Parse the status line: "HTTP/1.1 200 OK" -/
  def parseStatusLine (line : String) : Option Status := do
    -- Split on spaces
    let parts := line.splitOn " "
    guard (parts.length >= 2)
    -- First part should be HTTP version
    let version := parts.getD 0 ""
    guard (version.startsWith "HTTP/")
    -- Second part is status code
    let codeStr := parts.getD 1 ""
    let code ← codeStr.toNat?
    -- Rest is reason phrase (may contain spaces)
    let reason := " ".intercalate (parts.drop 2)
    some ⟨code, if reason.isEmpty then Status.reasonForCode code else reason⟩

  /-- Parse header lines into Headers -/
  def parseHeaders (headerBlock : String) : Headers :=
    let lines := headerBlock.splitOn "\r\n"
    lines.filterMap fun line =>
      match line.splitOn ": " with
      | [name, value] => some (name, value.trimRight)
      | name :: rest =>
        if rest.isEmpty then none
        else some (name, (": ".intercalate rest).trimRight)
      | _ => none

  /--
  Parse an HTTP response from raw wire format.

  Format:
  ```
  HTTP/1.1 200 OK\r\n
  Content-Type: text/html\r\n
  Content-Length: 13\r\n
  \r\n
  Hello, World!
  ```
  -/
  def parse (raw : String) : Option Response := do
    -- Split headers from body
    let (headerSection, body) ← findHeaderEnd raw

    -- Split status line from header lines
    let (statusLine, headerLines) ← splitOnCRLF headerSection

    -- Parse status line
    let status ← parseStatusLine statusLine

    -- Parse headers
    let headers := parseHeaders headerLines

    some {
      status := status
      headers := headers
      body := .Text body
    }

  /-- Create a simple OK response (for testing) -/
  def ok (body : String := "") : Response :=
    { status := Status.ok
      headers := if body.isEmpty then []
                 else [("Content-Length", toString body.length)]
      body := .Text body }

  /-- Create a simple error response (for testing) -/
  def error (status : Status) (message : String := "") : Response :=
    { status := status
      headers := if message.isEmpty then []
                 else [("Content-Length", toString message.length)]
      body := .Text message }

  instance : ToString Response where
    toString r := s!"Response({r.status}, body={r.body})"

end Response

end HttpClient
