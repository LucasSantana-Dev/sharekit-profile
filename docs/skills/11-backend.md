# Backend Skills

Reference skills — load on demand when working in that layer. `docker-expert` for container and compose questions; `typescript-advanced-types` for complex type problems; `supabase` any time Supabase is involved.

---

## /nodejs-backend-patterns

Production-focused Node.js backend guidance — frameworks, service patterns, error handling.

**Coverage:**
- Framework choice (Express, Fastify, NestJS, etc.)
- Middleware patterns (logging, auth, error handling)
- Service layer architecture
- Repository pattern (data access)
- Error handling (expected vs. unexpected errors)
- Async/concurrency (promises, async/await, workers)
- Rate limiting + throttling

**When to use:** Node.js backend development

**Output:** Backend patterns reference + implementation guide

---

## /docker-expert

Production-focused Docker guidance for image design, multi-stage builds, and orchestration.

**Topics:**
- Image design (layers, caching, security)
- Multi-stage builds (build → runtime separation)
- Security hardening (non-root user, minimal base images)
- Health checks + signal handling
- Container composition (Docker Compose)
- Orchestration (Kubernetes basics)
- Volumes + networking

**When to use:** Docker image design; container architecture

**Output:** Docker reference + best practices

---

## /monorepo-dockerfile

Reference checklist for npm-workspaces + Prisma monorepo Dockerfiles.

**Checklist:**
- Multi-stage build (build + runtime stages)
- Install dependencies (npm ci, copy package-lock)
- Build step (tsc, prisma generate, etc.)
- Prisma migration container
- App container (production image)
- Environment variables + secrets

**When to use:** Dockerizing npm monorepo with Prisma

**Output:** Dockerfile template + checklist

---

## /turborepo

Turborepo monorepo guidance for task modeling, caching, filtering, and CI integration.

**Topics:**
- Task definition (turbo.json)
- Caching strategy (outputs, deps tracking)
- Filtering (--filter, --scope flags)
- Running tasks (build, test, lint in parallel)
- CI integration (GitHub Actions, etc.)
- Dependency graph visualization

**When to use:** Monorepo task orchestration; Turborepo configuration

**Output:** Turborepo reference + configuration guide

---

## /typescript-advanced-types

Guide advanced TypeScript type-system design — generics, conditional types, branded types, and more.

**Topics:**
- Generics (type parameters, constraints, variance)
- Conditional types (extends, ternary types)
- Mapped types (transform objects, Partial, Readonly)
- Utility types (Pick, Omit, Record, etc.)
- Branded types (type safety for primitive strings/numbers)
- Type inference (infer keyword)
- Union discrimination (discriminated unions)

**When to use:** Advanced type system design; complex type problems

**Output:** Type system reference + patterns

---

## /supabase-postgres-best-practices

Postgres performance optimization and best practices from Supabase.

**Topics:**
- Indexing strategy (B-tree, GiST, BRIN)
- Query optimization (EXPLAIN ANALYZE)
- Connection pooling (PgBouncer)
- Row-Level Security (RLS) patterns
- Realtime subscriptions (pglogical)
- Full-text search (FTS)
- JSON operations (JSONB queries)

**When to use:** Postgres performance tuning; RLS design

**Output:** Postgres best practices reference

---

## /supabase

Use when doing ANY task involving Supabase — Database, Auth, Edge Functions, Realtime, Storage, RLS, migrations.

**Covers:**
- **Database:** Tables, migrations, indexes, RLS
- **Auth:** User management, authentication flows, permissions
- **Edge Functions:** Serverless compute (Deno)
- **Realtime:** Real-time subscriptions + channels
- **Storage:** File uploads + management
- **Vector:** pgvector integration for embeddings
- **CLI:** Supabase CLI for local development

**When to use:** Any Supabase-related task

**Output:** Supabase guidance + implementation

---

**Last updated:** 2026-06-25
