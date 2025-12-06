import HttpClient

open HttpClient

def main : IO Unit := do
  IO.println "Fetching http://example.com..."
  
  -- this uses the default Transport.curl
  match ← HttpClient.get "http://example.com" with
  | .ok res =>
    IO.println s!"Status: {res.status}"
    IO.println s!"Content-Type: {res.headers.contentType.getD "unknown"}"
    IO.println s!"Body length: {res.body.length} bytes"
    IO.println "--- Body Snippet ---"
    IO.println (res.body.take 200) 
    IO.println "..."
  | .error err =>
    IO.eprintln s!"Error: {err}"

