# Refactoring Reference Catalog

Full patterns and examples for the `/refactor` skill.

---

## 10 Common Code Smells & Fixes

### 1. Long Method/Function

```diff
# BAD: 200-line function that does everything
- async function processOrder(orderId) {
-   // 50 lines: fetch order
-   // 30 lines: validate order
-   // 40 lines: calculate pricing
-   // 30 lines: update inventory
-   // 20 lines: create shipment
-   // 30 lines: send notifications
- }

# GOOD: Broken into focused functions
+ async function processOrder(orderId) {
+   const order = await fetchOrder(orderId);
+   validateOrder(order);
+   const pricing = calculatePricing(order);
+   await updateInventory(order);
+   const shipment = await createShipment(order);
+   await sendNotifications(order, pricing, shipment);
+   return { order, pricing, shipment };
+ }
```

### 2. Duplicated Code

```diff
# BAD: Same logic in multiple places
- function calculateUserDiscount(user) {
-   if (user.membership === 'gold') return user.total * 0.2;
-   if (user.membership === 'silver') return user.total * 0.1;
-   return 0;
- }
-
- function calculateOrderDiscount(order) {
-   if (order.user.membership === 'gold') return order.total * 0.2;
-   if (order.user.membership === 'silver') return order.total * 0.1;
-   return 0;
- }

# GOOD: Extract common logic
+ function getMembershipDiscountRate(membership) {
+   const rates = { gold: 0.2, silver: 0.1 };
+   return rates[membership] || 0;
+ }
+
+ function calculateUserDiscount(user) {
+   return user.total * getMembershipDiscountRate(user.membership);
+ }
+
+ function calculateOrderDiscount(order) {
+   return order.total * getMembershipDiscountRate(order.user.membership);
+ }
```

### 3. Large Class/Module (God Object)

```diff
# BAD: One class that knows too much
- class UserManager {
-   createUser() { /* ... */ }
-   updateUser() { /* ... */ }
-   deleteUser() { /* ... */ }
-   sendEmail() { /* ... */ }
-   generateReport() { /* ... */ }
-   handlePayment() { /* ... */ }
-   validateAddress() { /* ... */ }
-   // 50 more methods...
- }

# GOOD: Single responsibility per class
+ class UserService {
+   create(data) { /* ... */ }
+   update(id, data) { /* ... */ }
+   delete(id) { /* ... */ }
+ }
+
+ class EmailService {
+   send(to, subject, body) { /* ... */ }
+ }
+
+ class ReportService {
+   generate(type, params) { /* ... */ }
+ }
+
+ class PaymentService {
+   process(amount, method) { /* ... */ }
+ }
```

### 4. Long Parameter List

```diff
# BAD: Too many parameters
- function createUser(email, password, name, age, address, city, country, phone) {
-   /* ... */
- }

# GOOD: Group related parameters into an object
+ interface UserData {
+   email: string;
+   password: string;
+   name: string;
+   age?: number;
+   address?: Address;
+   phone?: string;
+ }
+
+ function createUser(data: UserData) {
+   /* ... */
+ }

# EVEN BETTER: Use builder pattern for complex construction
+ const user = UserBuilder
+   .email('test@example.com')
+   .password('secure123')
+   .name('Test User')
+   .address(address)
+   .build();
```

### 5. Feature Envy

```diff
# BAD: Method that uses another object's data more than its own
- class Order {
-   calculateDiscount(user) {
-     if (user.membershipLevel === 'gold') {
+       return this.total * 0.2;
+     }
+     if (user.accountAge > 365) {
+       return this.total * 0.1;
+     }
+     return 0;
+   }
+ }

# GOOD: Move logic to the object that owns the data
+ class User {
+   getDiscountRate(orderTotal) {
+     if (this.membershipLevel === 'gold') return 0.2;
+     if (this.accountAge > 365) return 0.1;
+     return 0;
+   }
+ }
+
+ class Order {
+   calculateDiscount(user) {
+     return this.total * user.getDiscountRate(this.total);
+   }
+ }
```

### 6. Primitive Obsession

```diff
# BAD: Using primitives for domain concepts
- function sendEmail(to, subject, body) { /* ... */ }
- sendEmail('user@example.com', 'Hello', '...');
-
- function createPhone(country, number) {
-   return `${country}-${number}`;
- }

# GOOD: Use domain types
+ class Email {
+   private constructor(public readonly value: string) {
+     if (!Email.isValid(value)) throw new Error('Invalid email');
+   }
+   static create(value: string) { return new Email(value); }
+   static isValid(email: string) { return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email); }
+ }
+
+ class PhoneNumber {
+   constructor(
+     public readonly country: string,
+     public readonly number: string
+   ) {
+     if (!PhoneNumber.isValid(country, number)) throw new Error('Invalid phone');
+   }
+   toString() { return `${this.country}-${this.number}`; }
+ }
+
+ const email = Email.create('user@example.com');
+ const phone = new PhoneNumber('1', '555-1234');
```

### 7. Magic Numbers/Strings

```diff
# BAD: Unexplained values
- if (user.status === 2) { /* ... */ }
- const discount = total * 0.15;
- setTimeout(callback, 86400000);

# GOOD: Named constants
+ const UserStatus = {
+   ACTIVE: 1,
+   INACTIVE: 2,
+   SUSPENDED: 3
+ } as const;
+
+ const DISCOUNT_RATES = {
+   STANDARD: 0.1,
+   PREMIUM: 0.15,
+   VIP: 0.2
+ } as const;
+
+ const ONE_DAY_MS = 24 * 60 * 60 * 1000;
+
+ if (user.status === UserStatus.INACTIVE) { /* ... */ }
+ const discount = total * DISCOUNT_RATES.PREMIUM;
+ setTimeout(callback, ONE_DAY_MS);
```

### 8. Nested Conditionals (Arrow Code)

```diff
# BAD: Deep nesting
- function process(order) {
-   if (order) {
-     if (order.user) {
-       if (order.user.isActive) {
-         if (order.total > 0) {
-           return processOrder(order);
+         } else {
+           return { error: 'Invalid total' };
+         }
+       } else {
+         return { error: 'User inactive' };
+       }
+     } else {
+       return { error: 'No user' };
+     }
+   } else {
+     return { error: 'No order' };
+   }
+ }

# GOOD: Guard clauses / early returns
+ function process(order) {
+   if (!order) return { error: 'No order' };
+   if (!order.user) return { error: 'No user' };
+   if (!order.user.isActive) return { error: 'User inactive' };
+   if (order.total <= 0) return { error: 'Invalid total' };
+   return processOrder(order);
+ }

# EVEN BETTER: Result type for composable validation
+ function process(order): Result<ProcessedOrder, Error> {
+   return Result.combine([
+     validateOrderExists(order),
+     validateUserExists(order),
+     validateUserActive(order.user),
+     validateOrderTotal(order)
+   ]).flatMap(() => processOrder(order));
+ }
```

### 9. Dead Code

```diff
# BAD: Unused code lingers
- function oldImplementation() { /* ... */ }
- const DEPRECATED_VALUE = 5;
- import { unusedThing } from './somewhere';
- // Commented out code

# GOOD: Remove it
+ // Delete unused functions, imports, and commented code
+ // If you need it again, git history has it
```

### 10. Inappropriate Intimacy

```diff
# BAD: One class reaches deep into another
- class OrderProcessor {
-   process(order) {
-     order.user.profile.address.street;  // Too intimate
-     order.repository.connection.config;  // Breaking encapsulation
+   }
+ }

# GOOD: Ask, don't tell (Law of Demeter)
+ class OrderProcessor {
+   process(order) {
+     order.getShippingAddress();  // Order knows how to get it
+     order.save();                // Order knows how to save itself
+   }
+ }
```

---

## Design Pattern Refactorings

### Strategy Pattern (Replace Conditional Logic)

```diff
# Before: Conditional logic for variations
- function calculateShipping(order, method) {
-   if (method === 'standard') {
-     return order.total > 50 ? 0 : 5.99;
-   } else if (method === 'express') {
-     return order.total > 100 ? 9.99 : 14.99;
+   } else if (method === 'overnight') {
+     return 29.99;
+   }
+ }

# After: Strategy pattern
+ interface ShippingStrategy {
+   calculate(order: Order): number;
+ }
+
+ class StandardShipping implements ShippingStrategy {
+   calculate(order: Order) {
+     return order.total > 50 ? 0 : 5.99;
+   }
+ }
+
+ class ExpressShipping implements ShippingStrategy {
+   calculate(order: Order) {
+     return order.total > 100 ? 9.99 : 14.99;
+   }
+ }
+
+ class OvernightShipping implements ShippingStrategy {
+   calculate(order: Order) {
+     return 29.99;
+   }
+ }
+
+ function calculateShipping(order: Order, strategy: ShippingStrategy) {
+   return strategy.calculate(order);
+ }
```

### Chain of Responsibility (Validation)

```diff
# Before: Nested validation in one function
- function validate(user) {
-   const errors = [];
-   if (!user.email) errors.push('Email required');
-   else if (!isValidEmail(user.email)) errors.push('Invalid email');
-   if (!user.name) errors.push('Name required');
-   if (user.age < 18) errors.push('Must be 18+');
-   if (user.country === 'blocked') errors.push('Country not supported');
-   return errors;
- }

# After: Chain of responsibility
+ abstract class Validator {
+   protected next?: Validator;
+   setNext(validator: Validator): Validator {
+     this.next = validator;
+     return validator;
+   }
+   validate(user: User): string | null {
+     const error = this.doValidate(user);
+     if (error) return error;
+     return this.next?.validate(user) ?? null;
+   }
+   protected abstract doValidate(user: User): string | null;
+ }
+
+ class EmailRequiredValidator extends Validator {
+   protected doValidate(user: User) {
+     return !user.email ? 'Email required' : null;
+   }
+ }
+
+ class EmailFormatValidator extends Validator {
+   protected doValidate(user: User) {
+     return user.email && !isValidEmail(user.email) ? 'Invalid email' : null;
+   }
+ }
+
+ // Build and use the chain
+ const validator = new EmailRequiredValidator()
+   .setNext(new EmailFormatValidator())
+   .setNext(new NameRequiredValidator())
+   .setNext(new AgeValidator())
+   .setNext(new CountryValidator());
```

---

## Extract Method (Step-by-Step Example)

### Before: One Long Function

```typescript
function printReport(users) {
  console.log('USER REPORT');
  console.log('============');
  console.log('');
  console.log(`Total users: ${users.length}`);
  console.log('');
  console.log('ACTIVE USERS');
  console.log('------------');
  const active = users.filter(u => u.isActive);
  active.forEach(u => {
    console.log(`- ${u.name} (${u.email})`);
  });
  console.log('');
  console.log(`Active: ${active.length}`);
  console.log('');
  console.log('INACTIVE USERS');
  console.log('--------------');
  const inactive = users.filter(u => !u.isActive);
  inactive.forEach(u => {
    console.log(`- ${u.name} (${u.email})`);
  });
  console.log('');
  console.log(`Inactive: ${inactive.length}`);
}
```

### After: Extracted Methods

```typescript
function printReport(users) {
  printHeader('USER REPORT');
  console.log(`Total users: ${users.length}\n`);
  printUserSection('ACTIVE USERS', users.filter(u => u.isActive));
  printUserSection('INACTIVE USERS', users.filter(u => !u.isActive));
}

function printHeader(title: string) {
  const line = '='.repeat(title.length);
  console.log(title);
  console.log(line);
  console.log('');
}

function printUserSection(title: string, users: User[]) {
  console.log(title);
  console.log('-'.repeat(title.length));
  users.forEach(u => console.log(`- ${u.name} (${u.email})`));
  console.log('');
  const count = title.split(' ')[0];
  console.log(`${count}: ${users.length}`);
  console.log('');
}
```

**Steps taken:**
1. Identify repeated patterns (header, user list section)
2. Extract header logic to `printHeader()`
3. Extract user section logic to `printUserSection()`
4. Update `printReport()` to call helpers
5. Test after each extraction

---

## Introducing Type Safety

### From Untyped to Typed

```typescript
// Before: No types
function calculateDiscount(user, total, membership, date) {
  if (membership === 'gold' && date.getDay() === 5) {
    return total * 0.25;
  }
  if (membership === 'gold') return total * 0.2;
  return total * 0.1;
}

// After: Full type safety
type Membership = 'bronze' | 'silver' | 'gold';

interface User {
  id: string;
  name: string;
  membership: Membership;
}

interface DiscountResult {
  original: number;
  discount: number;
  final: number;
  rate: number;
}

function calculateDiscount(
  user: User,
  total: number,
  date: Date = new Date()
): DiscountResult {
  if (total < 0) throw new Error('Total cannot be negative');

  let rate = 0.1; // Default bronze

  if (user.membership === 'gold' && date.getDay() === 5) {
    rate = 0.25; // Friday bonus for gold
  } else if (user.membership === 'gold') {
    rate = 0.2;
  } else if (user.membership === 'silver') {
    rate = 0.15;
  }

  const discount = total * rate;

  return {
    original: total,
    discount,
    final: total - discount,
    rate
  };
}
```

---

## Safe Refactoring Process

### Step-by-Step Checklist

1. **PREPARE**
   - Ensure tests exist (write them if missing)
   - Run tests — must all pass
   - Commit current state
   - Create feature branch

2. **IDENTIFY**
   - Find the code smell to address
   - Understand what the code does
   - Plan the refactoring (document what and why)

3. **REFACTOR** (small steps)
   - Make one small change
   - Run tests
   - Commit if tests pass
   - Repeat step 3 until done

4. **VERIFY**
   - All tests still pass
   - Manual testing if user-facing
   - Performance unchanged or improved

5. **CLEAN UP**
   - Update comments/documentation
   - Final commit with summary message

### Code Quality Checklist

- [ ] Functions are small (< 50 lines)
- [ ] Functions do one thing
- [ ] No duplicated code
- [ ] Descriptive names (variables, functions, classes)
- [ ] No magic numbers/strings
- [ ] Dead code removed
- [ ] Related code is together
- [ ] Clear module boundaries
- [ ] Dependencies flow in one direction
- [ ] No circular dependencies

### Type Safety Checklist

- [ ] Types defined for all public APIs
- [ ] No `any` types without justification
- [ ] Nullable types explicitly marked
- [ ] Enums used instead of string codes

### Testing Checklist

- [ ] Refactored code is tested
- [ ] Tests cover edge cases
- [ ] All tests pass before and after

---

## Common Refactoring Operations

| Operation | Goal | Example |
|-----------|------|---------|
| Extract Method | Turn code fragment into named method | Extract `formatUserName()` from report logic |
| Extract Class | Move behavior to new class | Extract `EmailValidator` from User |
| Extract Interface | Create interface from implementation | Create `ShippingStrategy` interface |
| Inline Method | Move method body back to caller | Inline trivial `getTotal()` |
| Inline Class | Move class behavior to caller | Inline `PaymentAuthorizer` into `PaymentService` |
| Pull Up Method | Move method to superclass | Move common validation to base class |
| Push Down Method | Move method to subclass | Move specific logic to `PremiumUser` |
| Rename Method/Variable | Improve clarity | `get()` → `getUserByEmail()` |
| Introduce Parameter Object | Group related parameters | `(email, password, name)` → `(userData: UserData)` |
| Replace Conditional with Polymorphism | Use polymorphism instead of switch/if | Extract `DiscountStrategy` interface |
| Replace Magic Number with Constant | Named constants | `86400000` → `ONE_DAY_MS` |
| Decompose Conditional | Break complex conditions | Extract `isValidUser()` helper |
| Consolidate Conditional | Combine duplicate conditions | Merge similar `if` blocks |
| Replace Nested Conditional with Guard Clauses | Early returns | Replace 5-level indent with guard returns |
| Introduce Null Object | Eliminate null checks | `User.NotFound` instead of `null` |
| Replace Type Code with Class/Enum | Strong typing | `status: 1 | 2 | 3` → `status: UserStatus` enum |
| Replace Inheritance with Delegation | Composition over inheritance | `class OrderProcessor extends BaseProcessor` → `class OrderProcessor { processor }` |
