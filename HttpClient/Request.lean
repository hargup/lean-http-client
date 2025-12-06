/-
  HttpClient/Request.lean
  HTTP Request type and builder pattern
-/

import HttpClient.Basic
import HttpClient.Url

namespace HttpClient

/-- HTTP Request -/
structure Request where
  method : Method
  url : Url
  headers : Headers
  body : Option HttpBody
  responsePath : Option System.FilePath
  deriving Repr, Inhabited

namespace Request
  /-- Create a new request with the given method and URL -/
  def new (method : Method) (url : Url) : Request :=
    { method := method
      url := url
      headers := Headers.empty
      body := none
      responsePath := none }

  /-- Create a GET request -/
  def get (url : Url) : Request := new .GET url

  /-- Create a POST request -/
  def post (url : Url) : Request := new .POST url

  /-- Create a PUT request -/
  def put (url : Url) : Request := new .PUT url

  /-- Create a DELETE request -/
  def delete (url : Url) : Request := new .DELETE url

  /-- Create a HEAD request -/
  def head (url : Url) : Request := new .HEAD url

  /-- Create a PATCH request -/
  def patch (url : Url) : Request := new .PATCH url

  /-- Create an OPTIONS request -/
  def options (url : Url) : Request := new .OPTIONS url

  /-- Add a header to the request -/
  def withHeader (r : Request) (name value : String) : Request :=
    { r with headers := r.headers.add name value }

  /-- Set a header (replaces existing) -/
  def setHeader (r : Request) (name value : String) : Request :=
    { r with headers := r.headers.set name value }

  /-- Add multiple headers -/
  def withHeaders (r : Request) (headers : Headers) : Request :=
    { r with headers := headers ++ r.headers }

  /-- Set the request body -/
  def withBody (r : Request) (body : HttpBody) : Request :=
    let r := { r with body := some body }
    match body with
    | .Text s => r.setHeader "Content-Length" (toString s.length)
    | .Binary b => r.setHeader "Content-Length" (toString b.size)
    | .Stream _ => r

  /-- Set JSON body with appropriate content type -/
  def withJson (r : Request) (json : String) : Request :=
    r.withBody (.Text json)
    |>.setHeader "Content-Type" "application/json"

  /-- Set form-urlencoded body with appropriate content type -/
  def withForm (r : Request) (form : String) : Request :=
    r.withBody (.Text form)
    |>.setHeader "Content-Type" "application/x-www-form-urlencoded"

  /-- Set plain text body -/
  def withText (r : Request) (text : String) : Request :=
    r.withBody (.Text text)
    |>.setHeader "Content-Type" "text/plain"

  /-- Set binary body -/
  def withBinary (r : Request) (data : Bytes) : Request :=
    r.withBody (.Binary data)
    |>.setHeader "Content-Type" "application/octet-stream"

  /-- Set stream body -/
  def withStream (r : Request) (path : System.FilePath) : Request :=
    r.withBody (.Stream path)
    |>.setHeader "Content-Type" "application/octet-stream"

  /-- Stream response to a file -/
  def streamTo (r : Request) (path : System.FilePath) : Request :=
    { r with responsePath := some path }

  /-- Add Accept header -/
  def accept (r : Request) (contentType : String) : Request :=
    r.setHeader "Accept" contentType

  /-- Add Accept: application/json -/
  def acceptJson (r : Request) : Request :=
    r.accept "application/json"

  /-- Add Authorization header -/
  def withAuth (r : Request) (value : String) : Request :=
    r.setHeader "Authorization" value

  /-- Add Bearer token authorization -/
  def withBearerToken (r : Request) (token : String) : Request :=
    r.withAuth s!"Bearer {token}"

  /-- Add Basic authorization -/
  def withBasicAuth (r : Request) (username password : String) : Request :=
    -- Note: In production, this should base64-encode credentials
    r.withAuth s!"Basic {username}:{password}"

  /-- Add User-Agent header -/
  def withUserAgent (r : Request) (agent : String) : Request :=
    r.setHeader "User-Agent" agent

  /-- Get the Host header value (from URL) -/
  def hostHeader (r : Request) : String := r.url.authority

  /-- Get the request line (e.g., "GET /path HTTP/1.1") -/
  def requestLine (r : Request) : String :=
    s!"{r.method} {r.url.pathWithQuery} HTTP/1.1"

  /-- Serialize the request to HTTP/1.1 wire format -/
  def serialize (r : Request) : String :=
    let crlf := "\r\n"
    let requestLine := r.requestLine
    -- Add Host header if not present
    let headers := if r.headers.contains "Host" then r.headers
                   else r.headers.add "Host" r.url.authority
    let headerLines := headers.toLines
    let headerBlock := crlf.intercalate headerLines
    let body := match r.body with
      | some (.Text s) => s
      | some (.Binary _) => "<binary>"
      | some (.Stream p) => s!"<stream {p}>"
      | none => ""
    s!"{requestLine}{crlf}{headerBlock}{crlf}{crlf}{body}"

  instance : ToString Request where
    toString r := s!"Request({r.method} {r.url})"

end Request

end HttpClient
