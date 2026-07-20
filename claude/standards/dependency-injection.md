# Dependency Injection

## Principle

Dependencies flow in, not out. A function or class receives what it needs rather than reaching out to create or import it. This makes units testable in isolation and replaces implicit coupling with explicit contracts.

## Constructor injection (preferred)

```ts
// Good — dependencies declared upfront, easy to stub in tests
class NotificationService {
  constructor(
    private readonly mailer: Mailer,
    private readonly db: Database,
  ) {}

  async notify(userId: string, message: string) {
    const user = await this.db.findUser(userId);
    await this.mailer.send(user.email, message);
  }
}

// Bad — hidden coupling, untestable without mocking the module
class NotificationService {
  async notify(userId: string, message: string) {
    const mailer = new SendgridMailer(process.env.SENDGRID_KEY!); // hidden dep
    const user = await prisma.user.findUnique({ where: { id: userId } }); // global
    await mailer.send(user!.email, message);
  }
}
```

## Function-level injection

For simple cases, pass dependencies as arguments:

```ts
async function sendWelcome(
  userId: string,
  deps: { db: Database; mailer: Mailer },
) { ... }
```

Avoid a single god `deps` object that grows unbounded — keep it scoped to what the function actually uses.

## Container pattern

Use a DI container (e.g. `tsyringe`, `inversify`, FastAPI's `Depends`, Python's `dependency_injector`) only when the dependency graph is large enough that manual wiring becomes a maintenance burden. Container overhead is not justified for small services.

## What to inject

- External I/O: database clients, HTTP clients, mailers, queue publishers
- Configuration that varies by environment
- Clocks and random sources in code that needs deterministic tests (`now()`, `uuid()`)

## What NOT to inject

- Pure utility functions (they have no side effects, just import them)
- Framework internals (React context, Express `req`/`res` — those are already injected by the framework)
- Constants that never change

## Testing benefit

```ts
const svc = new NotificationService(
  { send: jest.fn() },   // fake mailer
  { findUser: async () => ({ email: 'a@b.com' }) }, // fake db
);
await svc.notify('123', 'hello');
// no network, no database, deterministic
```
