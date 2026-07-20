# Async / Await Patterns

## Core rules

- Always `await` Promises — never fire-and-forget unless the failure is genuinely unobservable.
- Never mix `.then()` chains and `async/await` in the same function. Pick one.
- Always wrap `await` calls that can fail in `try/catch` at the appropriate boundary — not every single call, but every boundary where failure should be handled or reported.

## Error handling

```ts
// Good — handle at the boundary, not inline
async function loadUser(id: string): Promise<User> {
  const row = await db.query('SELECT * FROM users WHERE id = $1', [id]);
  if (!row) throw new NotFoundError(`User ${id} not found`);
  return row;
}

// Bad — swallowing errors silently
async function loadUser(id: string) {
  try {
    return await db.query(...);
  } catch {
    return null; // caller has no idea what went wrong
  }
}
```

## Promise.all vs sequential awaits

```ts
// Good — independent async ops run in parallel
const [user, posts] = await Promise.all([fetchUser(id), fetchPosts(id)]);

// Bad — sequential when they don't depend on each other
const user = await fetchUser(id);
const posts = await fetchPosts(id); // waits for user even though it doesn't need it
```

Use `Promise.allSettled` when you want all results regardless of failure; use `Promise.all` when any failure should abort the group.

## Common pitfalls

- **`forEach` with async**: `array.forEach(async () => {})` does not await — use `for...of` or `Promise.all(array.map(...))`.
- **Unhandled rejections**: always attach `.catch()` or `await` Promises that escape a function scope.
- **Timeout**: wrap long-running awaits in a race with a timeout signal when latency matters.

```ts
const result = await Promise.race([
  fetchData(),
  new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 5000)),
]);
```

## Python async

- Use `asyncio.gather()` for parallel coroutines (equivalent to `Promise.all`).
- Never call `asyncio.run()` inside an already-running event loop — use `await` instead.
- Mark every function that `await`s as `async` — don't mix sync and async callers without an explicit bridge.
