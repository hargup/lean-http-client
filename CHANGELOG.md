# Changelog

## [Unreleased]

### Added
- **Streaming Support**: Introduced `HttpBody` type with `Text`, `Binary`, and `Stream` variants to handle large payloads efficiently.
- **Request Streaming**: Added `Request.withStream` to stream request body from a file.
- **Binary Support**: Added `Request.withBinary` for sending `ByteArray` data.
- **Response Streaming**: Added `Request.streamTo` to stream response body directly to a file, avoiding memory issues with large downloads.
- **Connection**: Updated `curl` transport to use `--data-binary` for streams and `--output` for file downloads.

### Changed
- **Breaking**: `Request.body` type changed from `Option String` to `Option HttpBody`.
- **Breaking**: `Response.body` type changed from `String` to `HttpBody`.
- **Refactor**: `Request.withBody` now takes `HttpBody`.

