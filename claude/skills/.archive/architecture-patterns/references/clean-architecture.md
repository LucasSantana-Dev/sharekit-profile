# Clean Architecture

## Core idea

Dependencies point inward. Frameworks and delivery mechanisms should not own the business rules.

## Boundary reminder

- entities or domain models at the core,
- use cases or application services around them,
- adapters and frameworks outside.

## Best fit

Use when testable business workflows and framework independence are more important than raw implementation speed.
