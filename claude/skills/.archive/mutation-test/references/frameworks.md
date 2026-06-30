# Mutation Testing Frameworks by Language

| Language | Framework | Install |
|---|---|---|
| TypeScript / JavaScript | Stryker | `npm i -D @stryker-mutator/core @stryker-mutator/jest-runner` (or `vitest-runner`) |
| Python | mutmut | `pip install mutmut` |
| Go | go-mutesting | `go install github.com/zimmski/go-mutesting/...@latest` |
| Rust | cargo-mutants | `cargo install cargo-mutants` |
| Java / Kotlin | PIT | maven/gradle plugin |
| Ruby | mutant | `gem install mutant-rspec` |

**Detect what's already configured:**
```bash
ls stryker.conf.* .stryker* mutmut_config.py cargo-mutants.toml 2>/dev/null
```
