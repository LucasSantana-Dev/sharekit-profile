# TDD Examples

Worked examples following the Red-Green-Refactor cycle.

## Example 1: Bug Fix

**Bug:** Empty email accepted

**RED**
```typescript
test('rejects empty email', async () => {
  const result = await submitForm({ email: '' });
  expect(result.error).toBe('Email required');
});
```

**Verify RED**
```bash
$ npm test
FAIL: expected 'Email required', got undefined
```

**GREEN**
```typescript
function submitForm(data: FormData) {
  if (!data.email?.trim()) {
    return { error: 'Email required' };
  }
  // ...
}
```

**Verify GREEN**
```bash
$ npm test
PASS
```

**REFACTOR**
Extract validation for multiple fields if needed.

## Integration: Bug Found In Production

Bug found? Write failing test reproducing it. Follow TDD cycle. Test proves fix and prevents regression.

Never fix bugs without a test.

**Step 1: Write the test**
```typescript
test('pagination resets to page 1 when filters change', () => {
  const { rerender } = render(<DataTable filters={{ search: 'alice' }} page={5} />);
  expect(screen.getByText('Page: 5')).toBeInTheDocument();

  rerender(<DataTable filters={{ search: 'bob' }} page={5} />);
  expect(screen.getByText('Page: 1')).toBeInTheDocument();
});
```

**Step 2: Watch it fail**
```bash
$ npm test -- pagination
FAIL: expected 'Page: 1', got 'Page: 5'
```

**Step 3: Implement minimal fix**
```typescript
useEffect(() => {
  setPage(1);
}, [filters]);
```

**Step 4: Verify green**
```bash
PASS
```

**Step 5: Check for regressions**
All other pagination tests still pass.

**Step 6: Refactor**
Extract to a hook if pagination-reset is used elsewhere.

## Retry Logic Example

**Feature:** Retry failed operations (from skill overview)

**RED**
```typescript
test('retries failed operations 3 times', async () => {
  let attempts = 0;
  const operation = () => {
    attempts++;
    if (attempts < 3) throw new Error('fail');
    return 'success';
  };

  const result = await retryOperation(operation);

  expect(result).toBe('success');
  expect(attempts).toBe(3);
});
```

**Verify RED**
```bash
npm test -- retry
FAIL: retryOperation is not defined
```

**GREEN**
```typescript
async function retryOperation<T>(fn: () => Promise<T>): Promise<T> {
  for (let i = 0; i < 3; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i === 2) throw e;
    }
  }
  throw new Error('unreachable');
}
```

**Verify GREEN**
```bash
PASS
```

**REFACTOR** (if needed)
Extract max retries to a parameter if other code reuses this.
