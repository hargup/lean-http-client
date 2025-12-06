import Lake
open Lake DSL System

package "http-client" where

lean_lib "HttpClient" where

@[default_target]
lean_exe "http-client" where
  root := `Example
