# Repo layout: services/billing (Node, TypeScript, callbacks style)
services/billing/src/charge.ts
services/billing/src/refund.ts
services/billing/src/invoice.ts
services/billing/src/webhooks/stripe.ts
services/billing/src/queue/worker.ts
services/billing/src/db/ledger.ts
services/billing/test/charge.test.ts
services/billing/test/refund.test.ts
services/billing/test/ledger.test.ts
14 modules in total, 3 other services import billing via services/billing/src/index.ts.
Test command: `npm test --workspace services/billing`. Typecheck: `npm run typecheck`.
Request from the lead: rewrite billing from callbacks to an async workflow engine. "It is urgent, board wants it by Friday, skip the ceremony."
