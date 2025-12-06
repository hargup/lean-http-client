/-
  HttpClient/Url.lean
  URL parsing and representation
-/

namespace HttpClient

/-- Represents a parsed URL -/
structure Url where
  scheme : String           -- "http" or "https"
  host : String             -- hostname or IP address
  port : Option Nat         -- explicit port (None = use default)
  path : String             -- path starting with "/" (default "/")
  query : Option String     -- query string without "?"
  fragment : Option String  -- fragment without "#"
  deriving Repr, BEq, Inhabited

namespace Url
  /-- Get the effective port (default 80 for http, 443 for https) -/
  def effectivePort (u : Url) : Nat :=
    u.port.getD (if u.scheme == "https" then 443 else 80)

  /-- Get the path with query string if present -/
  def pathWithQuery (u : Url) : String :=
    match u.query with
    | some q => s!"{u.path}?{q}"
    | none => u.path

  /-- Get the authority component (host:port) -/
  def authority (u : Url) : String :=
    match u.port with
    | some p => s!"{u.host}:{p}"
    | none => u.host

  /-- Is this an HTTPS URL? -/
  def isSecure (u : Url) : Bool := u.scheme == "https"

  /-- Convert URL back to string -/
  def toString (u : Url) : String :=
    let portStr := match u.port with
      | some p => s!":{p}"
      | none => ""
    let queryStr := match u.query with
      | some q => s!"?{q}"
      | none => ""
    let fragmentStr := match u.fragment with
      | some f => s!"#{f}"
      | none => ""
    s!"{u.scheme}://{u.host}{portStr}{u.path}{queryStr}{fragmentStr}"

  instance : ToString Url where
    toString := Url.toString

  /-- Helper: check if character is a digit -/
  private def isDigit (c : Char) : Bool :=
    c >= '0' && c <= '9'

  /-- Helper: check if all characters are digits -/
  private def allDigits (s : String) : Bool :=
    s.all isDigit && !s.isEmpty

  /-- Helper: parse port number -/
  private def parsePort (s : String) : Option Nat :=
    if allDigits s then s.toNat? else none

  /-- Helper: split string on first occurrence of character -/
  private def splitOnFirst (s : String) (c : Char) : Option (String × String) :=
    match s.posOf c with
    | ⟨pos⟩ =>
      if pos < s.length then
        some (s.take pos, s.drop (pos + 1))
      else
        none

  /-- Helper: split string on last occurrence of character -/
  private def splitOnLast (s : String) (c : Char) : Option (String × String) :=
    let chars := s.toList
    let reversed := chars.reverse
    match reversed.findIdx? (· == c) with
    | some idx =>
      let splitPos := chars.length - 1 - idx
      some (s.take splitPos, s.drop (splitPos + 1))
    | none => none

  /--
  Parse a URL string into a Url structure.

  Supports: http://host[:port][/path][?query][#fragment]

  Examples:
  - "http://example.com" → scheme=http, host=example.com, port=none, path=/
  - "http://example.com:8080/api" → port=8080, path=/api
  - "http://example.com/search?q=lean" → path=/search, query=q=lean
  -/
  def parse (s : String) : Option Url := do
    -- Extract scheme
    let (scheme, rest) ← splitOnFirst s ':'
    guard (scheme == "http" || scheme == "https")

    -- Check for "://"
    guard (rest.startsWith "//")
    let afterScheme := rest.drop 2

    -- Split off fragment (if any)
    let (beforeFragment, fragment) :=
      match splitOnFirst afterScheme '#' with
      | some (before, frag) => (before, some frag)
      | none => (afterScheme, none)

    -- Split off query (if any)
    let (beforeQuery, query) :=
      match splitOnFirst beforeFragment '?' with
      | some (before, q) => (before, some q)
      | none => (beforeFragment, none)

    -- Split authority from path
    let (authority, path) :=
      match beforeQuery.posOf '/' with
      | ⟨pos⟩ =>
        if pos < beforeQuery.length then
          (beforeQuery.take pos, beforeQuery.drop pos)
        else
          (beforeQuery, "/")

    -- Parse authority (host[:port])
    let (host, port) :=
      -- Check if there's a colon followed by digits (port)
      match splitOnLast authority ':' with
      | some (h, p) =>
        if allDigits p && !p.isEmpty then
          (h, parsePort p)
        else
          -- Colon but no valid port (might be IPv6 or invalid)
          (authority, none)
      | none => (authority, none)

    -- Validate host is not empty
    guard (!host.isEmpty)

    -- Ensure path starts with /
    let normalizedPath := if path.isEmpty || !path.startsWith "/" then "/" else path

    some {
      scheme := scheme
      host := host
      port := port
      path := normalizedPath
      query := query
      fragment := fragment
    }

  /-- Create a simple HTTP URL from host and path -/
  def http (host : String) (path : String := "/") : Url :=
    { scheme := "http"
      host := host
      port := none
      path := if path.startsWith "/" then path else "/" ++ path
      query := none
      fragment := none }

  /-- Create a simple HTTPS URL from host and path -/
  def https (host : String) (path : String := "/") : Url :=
    { scheme := "https"
      host := host
      port := none
      path := if path.startsWith "/" then path else "/" ++ path
      query := none
      fragment := none }

  /-- Add or replace the query string -/
  def withQuery (u : Url) (query : String) : Url :=
    { u with query := some query }

  /-- Add a query parameter -/
  def addQueryParam (u : Url) (key value : String) : Url :=
    let param := s!"{key}={value}"  -- Note: should URL-encode in production
    let newQuery := match u.query with
      | some q => s!"{q}&{param}"
      | none => param
    { u with query := some newQuery }

  /-- Add or replace the path -/
  def withPath (u : Url) (path : String) : Url :=
    { u with path := if path.startsWith "/" then path else "/" ++ path }

  /-- Add or replace the port -/
  def withPort (u : Url) (port : Nat) : Url :=
    { u with port := some port }

end Url

end HttpClient
