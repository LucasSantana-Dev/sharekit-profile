# Observability & Monitoring Skills

`observe` routes to the right sub-skill automatically. `observability-bootstrap` for a new service with no instrumentation. `observability-audit` for an existing service with gaps. `sentry` when investigating a production error.

---

## /observe

Unified entry point for observability + monitoring work — routes to the right family member.

**Routes to:**
- `observability-bootstrap` (new service, no instrumentation)
- `observability-audit` (existing service, audit gaps)
- `observability-analyze` (investigate anomalies)
- `observability-debug` (diagnose broken signals)
- `observability-tune` (reduce cost, maintain signal)
- `monitoring-setup` (alerts, SLOs, dashboards)

**When to use:** Any observability work; let router choose the right path

**Output:** Routed to appropriate sub-skill

---

## /observability-bootstrap ⭐⭐ **Composite**

Set up complete observability for a new service: implement all 4 pillars → SLOs + alerts → smoke-test.

**Phases:**
1. **Pillars:** Logs, metrics, traces, errors (OTEL, Prometheus, Sentry)
2. **SLOs/SLIs:** Define service-level objectives + indicators
3. **Alerts:** Configure alert rules for critical signals
4. **Smoke-test:** Verify all signals working end-to-end

**When to use:** New service with no instrumentation

**Output:** Service with complete observability

---

## /observability-audit ⭐⭐ **Composite**

Audit observability of an existing service: analyze → debug → tune → implement-gaps → monitoring-setup.

**Phases:**
1. **Analyze:** Read dashboards, correlate signals
2. **Debug:** Diagnose broken or missing signals
3. **Tune:** Reduce cost without losing signal
4. **Implement:** Add missing observability
5. **Setup:** Configure alerts + SLOs

**When to use:** Existing service with observability gaps

**Output:** Improved observability + cost optimization

---

## /observability-implement

Add observability to code that lacks it — structured logs, metrics, traces, error reporting.

**Technologies:**
- **Logs:** Winston, Pino, structlog (structured JSON)
- **Metrics:** Prometheus, StatsD (gauge, counter, histogram)
- **Traces:** OpenTelemetry (OTEL, distributed tracing)
- **Errors:** Sentry, Datadog (error reporting + context)

**When to use:** Code needs instrumentation

**Output:** Instrumented code with all 4 pillars

---

## /observability-debug

Diagnose broken observability — flapping alerts, missing signals, broken trace propagation.

**Diagnoses:**
- Alerts firing too often (flapping)
- Metrics missing or delayed
- Trace context not propagating
- Error aggregation not working
- Dashboard queries returning wrong data

**When to use:** Observability not working as expected

**Output:** Root cause + fix

---

## /observability-analyze

Investigate anomalies — read dashboards, build queries, correlate signals, surface root-cause hypotheses.

**Process:**
1. Read dashboard + identify anomaly
2. Build queries to isolate scope
3. Correlate with other signals (logs, traces, errors)
4. Generate competing root-cause hypotheses
5. Rank by evidence

**When to use:** Production anomaly detected; need investigation

**Output:** Anomaly analysis + hypotheses

---

## /observability-tune

Reduce observability cost without losing signal — cardinality caps, sample-rate tuning, retention adjustments.

**Optimizations:**
- **Cardinality:** Limit high-cardinality labels (user IDs, request IDs)
- **Sampling:** Trace sampling (10% vs. 100%), log sampling
- **Retention:** Keep hot data (7 days), archive cold data (90 days)
- **Aggregation:** Pre-aggregate metrics, reduce raw metric cardinality

**When to use:** Observability costs rising without benefit

**Output:** Optimized observability configuration + cost reduction

---

## /monitoring-setup

Set up the monitoring practice layer — alert rules, SLOs/SLIs, dashboards, on-call, synthetics.

**Components:**
- **Alerts:** Alert rules + severity (page, warn, info)
- **SLOs/SLIs:** Service-level objectives (99.9% uptime) + indicators
- **Dashboards:** Operational dashboards (key metrics overview)
- **On-call:** Escalation rules, notification routing
- **Synthetics:** Periodic health checks (uptime monitoring)

**When to use:** Setting up monitoring practice

**Output:** Monitoring infrastructure configured

---

## /langfuse-observe

Set up Langfuse LLM observability to trace Claude API calls with costs, tokens, and latency.

**Tracks:**
- API calls (model, input tokens, output tokens)
- Latency (time to first token, total time)
- Cost (input cost + output cost)
- Error rates
- Token usage trends

**When to use:** Claude API usage + cost tracking

**Output:** Langfuse integration + dashboards

---

## /sentry

Inspect Sentry issues or events, summarize errors, correlate with recent deploys.

**Operations:**
- View issue + stack trace
- Check event context (user, environment, tags)
- Correlate with recent deploys
- Group related errors
- Resolve issue

**When to use:** Production error investigation

**Output:** Error analysis + context

---

**Last updated:** 2026-06-25
