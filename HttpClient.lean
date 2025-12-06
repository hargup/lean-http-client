/-
  HttpClient.lean
  Main entry point for the HTTP Client library
-/

import HttpClient.Basic
import HttpClient.Url
import HttpClient.Request
import HttpClient.Response
import HttpClient.Connection
import HttpClient.Client

namespace HttpClient

/-- Perform a GET request using the default client configuration -/
def get (url : String) : IO (HttpResult Response) := do
  match Url.parse url with
  | some u =>
    let client ← Client.new
    client.send (Request.get u)
  | none => return .error (.parseError s!"Invalid URL: {url}")

/-- Perform a POST request using the default client configuration -/
def post (url : String) (body : String) : IO (HttpResult Response) := do
  match Url.parse url with
  | some u =>
    let client ← Client.new
    let req := Request.post u |>.withBody body
    client.send req
  | none => return .error (.parseError s!"Invalid URL: {url}")

/-- Perform a POST request with JSON body -/
def postJson (url : String) (json : String) : IO (HttpResult Response) := do
  match Url.parse url with
  | some u =>
    let client ← Client.new
    let req := Request.post u |>.withJson json
    client.send req
  | none => return .error (.parseError s!"Invalid URL: {url}")

end HttpClient
