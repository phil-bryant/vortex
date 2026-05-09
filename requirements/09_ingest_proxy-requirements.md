# Ingest Proxy Requirements

## Scope

Applies to `09_ingest_proxy.py`.

R001 Statement: The proxy forwards POST ingest payloads with the configured ingest-key header.
Design: Forward request bodies to the target URL while setting `X-Manifold-Ingest-Key` and preserving content type semantics.

R005 Statement: The proxy exposes a local health endpoint for startup checks.
Design: Respond to `GET /healthz` with HTTP 200 and reject unsupported routes with HTTP 404.
