# Code Standards

- Prefer clear, boring code over clever abstractions.
- Keep functions small enough to understand without scrolling forever.
- Avoid speculative features and premature generalization.
- Replace broken patterns instead of layering deprecations indefinitely.
- Keep comments for intent, invariants, and non-obvious trade-offs — not for narrating the code.
- Make edge cases explicit.
- Verify libraries before importing — never assume a package is in the project just because it's well-known. Check `package.json` / `pyproject.toml` / `Cargo.toml` / equivalent first; if missing, decide whether to add it (and which version line) or use what's already there. (From Devin's playbook — catches "imported chalk in a Bun project that doesn't ship it" class of bugs.)
