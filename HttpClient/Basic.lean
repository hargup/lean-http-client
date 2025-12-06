/-
  HttpClient/Basic.lean
  Core HTTP types: Method, Status, Headers
-/

namespace HttpClient

/-- HTTP request methods as defined in RFC 7231 -/
inductive Method where
  | GET
  | POST
  | PUT
  | DELETE
  | HEAD
  | OPTIONS
  | PATCH
  | TRACE
  | CONNECT
  deriving Repr, BEq, Hashable, Inhabited

namespace Method
  def toString : Method → String
    | GET     => "GET"
    | POST    => "POST"
    | PUT     => "PUT"
    | DELETE  => "DELETE"
    | HEAD    => "HEAD"
    | OPTIONS => "OPTIONS"
    | PATCH   => "PATCH"
    | TRACE   => "TRACE"
    | CONNECT => "CONNECT"

  def fromString (s : String) : Option Method :=
    match s.toUpper with
    | "GET"     => some GET
    | "POST"    => some POST
    | "PUT"     => some PUT
    | "DELETE"  => some DELETE
    | "HEAD"    => some HEAD
    | "OPTIONS" => some OPTIONS
    | "PATCH"   => some PATCH
    | "TRACE"   => some TRACE
    | "CONNECT" => some CONNECT
    | _         => none

  instance : ToString Method where
    toString := Method.toString
end Method

/-- HTTP response status code with reason phrase -/
structure Status where
  code : Nat
  reason : String
  deriving Repr, BEq, Inhabited

namespace Status
  -- 1xx Informational
  def continue_ : Status := ⟨100, "Continue"⟩
  def switchingProtocols : Status := ⟨101, "Switching Protocols"⟩

  -- 2xx Success
  def ok : Status := ⟨200, "OK"⟩
  def created : Status := ⟨201, "Created"⟩
  def accepted : Status := ⟨202, "Accepted"⟩
  def noContent : Status := ⟨204, "No Content"⟩

  -- 3xx Redirection
  def movedPermanently : Status := ⟨301, "Moved Permanently"⟩
  def found : Status := ⟨302, "Found"⟩
  def seeOther : Status := ⟨303, "See Other"⟩
  def notModified : Status := ⟨304, "Not Modified"⟩
  def temporaryRedirect : Status := ⟨307, "Temporary Redirect"⟩
  def permanentRedirect : Status := ⟨308, "Permanent Redirect"⟩

  -- 4xx Client Errors
  def badRequest : Status := ⟨400, "Bad Request"⟩
  def unauthorized : Status := ⟨401, "Unauthorized"⟩
  def forbidden : Status := ⟨403, "Forbidden"⟩
  def notFound : Status := ⟨404, "Not Found"⟩
  def methodNotAllowed : Status := ⟨405, "Method Not Allowed"⟩
  def conflict : Status := ⟨409, "Conflict"⟩
  def gone : Status := ⟨410, "Gone"⟩
  def unprocessableEntity : Status := ⟨422, "Unprocessable Entity"⟩
  def tooManyRequests : Status := ⟨429, "Too Many Requests"⟩

  -- 5xx Server Errors
  def internalServerError : Status := ⟨500, "Internal Server Error"⟩
  def notImplemented : Status := ⟨501, "Not Implemented"⟩
  def badGateway : Status := ⟨502, "Bad Gateway"⟩
  def serviceUnavailable : Status := ⟨503, "Service Unavailable"⟩
  def gatewayTimeout : Status := ⟨504, "Gateway Timeout"⟩

  /-- Is this a 1xx informational status? -/
  def isInformational (s : Status) : Bool := s.code >= 100 && s.code < 200

  /-- Is this a 2xx success status? -/
  def isSuccess (s : Status) : Bool := s.code >= 200 && s.code < 300

  /-- Is this a 3xx redirect status? -/
  def isRedirect (s : Status) : Bool := s.code >= 300 && s.code < 400

  /-- Is this a 4xx client error status? -/
  def isClientError (s : Status) : Bool := s.code >= 400 && s.code < 500

  /-- Is this a 5xx server error status? -/
  def isServerError (s : Status) : Bool := s.code >= 500 && s.code < 600

  /-- Is this an error status (4xx or 5xx)? -/
  def isError (s : Status) : Bool := s.isClientError || s.isServerError

  /-- Get the reason phrase for a status code -/
  def reasonForCode (code : Nat) : String :=
    match code with
    | 100 => "Continue"
    | 101 => "Switching Protocols"
    | 200 => "OK"
    | 201 => "Created"
    | 202 => "Accepted"
    | 204 => "No Content"
    | 301 => "Moved Permanently"
    | 302 => "Found"
    | 303 => "See Other"
    | 304 => "Not Modified"
    | 307 => "Temporary Redirect"
    | 308 => "Permanent Redirect"
    | 400 => "Bad Request"
    | 401 => "Unauthorized"
    | 403 => "Forbidden"
    | 404 => "Not Found"
    | 405 => "Method Not Allowed"
    | 409 => "Conflict"
    | 410 => "Gone"
    | 422 => "Unprocessable Entity"
    | 429 => "Too Many Requests"
    | 500 => "Internal Server Error"
    | 501 => "Not Implemented"
    | 502 => "Bad Gateway"
    | 503 => "Service Unavailable"
    | 504 => "Gateway Timeout"
    | _   => "Unknown"

  /-- Create a status from just a code -/
  def fromCode (code : Nat) : Status :=
    ⟨code, reasonForCode code⟩

  def toString (s : Status) : String := s!"{s.code} {s.reason}"

  instance : ToString Status where
    toString := Status.toString
end Status

/-- HTTP headers as a list of name-value pairs -/
abbrev Headers := List (String × String)

namespace Headers
  /-- Empty headers -/
  def empty : Headers := []

  /-- Add a header (prepends, so last added is first) -/
  def add (h : Headers) (name value : String) : Headers :=
    (name, value) :: h

  /-- Get the first value for a header name (case-insensitive) -/
  def get (h : Headers) (name : String) : Option String :=
    let nameLower := name.toLower
    h.find? (fun (n, _) => n.toLower == nameLower) |>.map (·.2)

  /-- Get all values for a header name (case-insensitive) -/
  def getAll (h : Headers) (name : String) : List String :=
    let nameLower := name.toLower
    h.filter (fun (n, _) => n.toLower == nameLower) |>.map (·.2)

  /-- Check if a header exists (case-insensitive) -/
  def contains (h : Headers) (name : String) : Bool :=
    let nameLower := name.toLower
    h.any (fun (n, _) => n.toLower == nameLower)

  /-- Remove all occurrences of a header (case-insensitive) -/
  def remove (h : Headers) (name : String) : Headers :=
    let nameLower := name.toLower
    h.filter (fun (n, _) => n.toLower != nameLower)

  /-- Set a header value, replacing any existing values -/
  def set (h : Headers) (name value : String) : Headers :=
    h.remove name |>.add name value

  /-- Get Content-Type header -/
  def contentType (h : Headers) : Option String := h.get "Content-Type"

  /-- Get Content-Length header as a number -/
  def contentLength (h : Headers) : Option Nat :=
    h.get "Content-Length" >>= String.toNat?

  /-- Get Location header (for redirects) -/
  def location (h : Headers) : Option String := h.get "Location"

  /-- Convert headers to a list of "Name: Value" strings -/
  def toLines (h : Headers) : List String :=
    h.map (fun (n, v) => s!"{n}: {v}")

  /-- Parse headers from lines -/
  def fromLines (lines : List String) : Headers :=
    lines.filterMap fun line =>
      match line.splitOn ": " with
      | [name, value] => some (name, value.trimRight)
      | name :: rest => some (name, (": ".intercalate rest).trimRight)
      | _ => none

  instance : ToString Headers where
    toString h := "\n".intercalate h.toLines
end Headers

abbrev Bytes := ByteArray

inductive HttpBody where
  | Text (s : String)
  | Binary (b : Bytes)
  | Stream (path : System.FilePath)
  deriving Inhabited

namespace HttpBody
  def toString : HttpBody → String
    | Text s => s
    | Binary b => s!"<Binary {b.size} bytes>"
    | Stream p => s!"<Stream {p}>"

  instance : ToString HttpBody where
    toString := HttpBody.toString

  instance : Repr HttpBody where
    reprPrec b _ :=
      match b with
      | .Text s => "HttpBody.Text " ++ repr s
      | .Binary b => "HttpBody.Binary <" ++ repr b.size ++ " bytes>"
      | .Stream p => "HttpBody.Stream " ++ repr p
    
  def length : HttpBody → Nat
    | Text s => s.length
    | Binary b => b.size
    | Stream _ => 0 -- Unknown without IO
end HttpBody

end HttpClient
