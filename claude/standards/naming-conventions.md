# Naming Conventions

## Case by role

| Context | Convention | Example |
|---------|-----------|---------|
| Variables, functions, methods | camelCase | `fetchUserData`, `isLoading` |
| Classes, types, interfaces | PascalCase | `UserProfile`, `AuthService` |
| Constants (truly immutable) | SCREAMING_SNAKE | `MAX_RETRY_COUNT`, `API_BASE_URL` |
| File names (JS/TS) | kebab-case | `user-profile.ts`, `auth-service.ts` |
| File names (Python) | snake_case | `user_profile.py`, `auth_service.py` |
| Python variables/functions | snake_case | `fetch_user_data`, `is_loading` |
| Database columns | snake_case | `created_at`, `user_id` |
| Environment variables | SCREAMING_SNAKE | `DATABASE_URL`, `JWT_SECRET` |
| CSS classes | kebab-case | `nav-bar`, `btn-primary` |

## Rules

- Name by what it **is or does**, not by its type — `userList` not `arrayOfUsers`, `fetchUser` not `getUserFunction`.
- Boolean names start with `is`, `has`, `can`, `should` — `isAuthenticated`, `hasPermission`.
- Avoid abbreviations unless universally known (`id`, `url`, `api`, `db`, `ctx`). Write `configuration` not `cfg`, `request` not `req` (unless it's an Express callback by convention).
- Event handlers: prefix with `on` or `handle` — `onSubmit`, `handleKeyDown`.
- Private class members: prefix with `_` only when the language lacks access modifiers; prefer `private` keyword.
- Generic parameter names: single uppercase letter is fine for trivial generics (`T`, `K`, `V`); use descriptive names for non-obvious ones (`TEntity`, `TResponse`).
- Avoid noise words: `data`, `info`, `manager`, `helper`, `util` as standalone suffixes add no meaning. `UserData` → `User`; `DataHelper` → name what it actually does.

## Consistency over perfection

If an existing file uses a convention that differs from the above, match the file — don't mix styles within a module. Refactor separately if needed.
