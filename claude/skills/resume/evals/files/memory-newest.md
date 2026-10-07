---
name: Redis service container gotcha
type: gotcha
---
GitHub Actions `redis:latest` now ships with a changed default. Service container fails its health check.
Fix: pin `redis:7.2` in the workflow services block. Seen in billing-svc on 2026-10-05.
