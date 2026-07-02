# Hexagonal Architecture

## Core idea

Model the system around ports and adapters so the domain does not depend on external technologies.

## Best fit

Use when databases, queues, APIs, or delivery channels may change and the domain should stay isolated.

## Watch for

- too many ports for trivial systems,
- interface sprawl with no clear ownership,
- fake abstraction where infrastructure churn is not actually a problem.
