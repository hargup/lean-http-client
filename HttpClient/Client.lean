/-
  HttpClient/Client.lean
  High-level HTTP client interface
-/

import HttpClient.Basic
import HttpClient.Url
import HttpClient.Request
import HttpClient.Response
import HttpClient.Connection

namespace HttpClient

/-- Client configuration -/
structure Config where
  /-- Default headers included in every request -/
  defaultHeaders : Headers := Headers.empty
  /-- Whether to automatically follow redirects (3xx) -/
  followRedirects : Bool := true
  /-- Maximum number of redirects to follow -/
  maxRedirects : Nat := 5
  /-- Request timeout in milliseconds -/
  timeout : Nat := 30000
  deriving Repr, Inhabited

/-- HTTP Client structure holding configuration and transport -/
structure Client where
  config : Config
  transport : Transport

namespace Client

  /-- Create a new client with default configuration and curl transport -/
  def new (config : Config := {}) : IO Client := do
    return { config := config, transport := Transport.curl }

  /-- Helper to resolve a redirect location against the original URL -/
  private def resolveUrl (base : Url) (location : String) : Option Url :=
    if location.startsWith "http://" || location.startsWith "https://" then
      Url.parse location
    else if location.startsWith "/" then
      some { base with path := location, query := none, fragment := none }
    else
      -- Relative path handling (simplified: just append to current path's dir)
      -- This is not fully RFC compliant but handles common cases
      let dir := if base.path.endsWith "/" then base.path else
        match base.path.revPosOf '/' with
        | some pos => base.path.extract 0 (base.path.next pos)
        | none => "/"
      some { base with path := dir ++ location, query := none, fragment := none }

  /-- Internal loop for handling redirects -/
  private partial def sendLoop (c : Client) (req : Request) (redirectsRemaining : Nat) : IO (HttpResult Response) := do
    match ← c.transport.send req c.config.timeout with
    | .error e => return .error e
    | .ok res =>
      if c.config.followRedirects && res.status.isRedirect then
        if redirectsRemaining == 0 then
          return .error (.protocolError "Too many redirects")
        else
          match res.headers.location with
          | some loc =>
            match resolveUrl req.url loc with
            | some newUrl =>
              -- Determine new method (RFC 7231)
              -- 303 See Other -> GET
              -- 301/302 -> commonly changed to GET for non-GET/HEAD requests
              let newMethod :=
                if res.status.code == 303 then Method.GET
                else if (res.status.code == 301 || res.status.code == 302) && req.method == Method.POST then Method.GET
                else req.method

              let newReq := { req with url := newUrl, method := newMethod }
              -- If method changed to GET, remove body
              let newReq := if newMethod == Method.GET then { newReq with body := none } else newReq

              sendLoop c newReq (redirectsRemaining - 1)
            | none => return .error (.protocolError s!"Invalid redirect location: {loc}")
          | none => return .ok res -- Redirect status without Location
      else
        return .ok res

  /-- Send a request using the client's configuration -/
  def send (c : Client) (req : Request) : IO (HttpResult Response) := do
    -- Merge default headers (request headers take precedence? Usually defaults are overwritten by req)
    -- Let's prepend defaults, so req headers (added later) might shadow if implementation allows?
    -- Headers is List, so first match wins in `get`.
    -- So we should put `req.headers` BEFORE `c.config.defaultHeaders`.
    -- But `req` might already have headers.
    let effectiveHeaders := req.headers ++ c.config.defaultHeaders
    let reqWithDefaults := { req with headers := effectiveHeaders }
    sendLoop c reqWithDefaults c.config.maxRedirects

end Client

end HttpClient

