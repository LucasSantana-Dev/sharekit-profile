# Pattern Selection

## Choose Clean Architecture when

- business rules should stay insulated from frameworks,
- testability and inward dependency flow matter most,
- use-case orchestration is the dominant concern.

## Choose Hexagonal Architecture when

- external integrations change often,
- ports and adapters are the clearest way to isolate infrastructure,
- swapping implementations cleanly is a major requirement.

## Choose DDD when

- domain language and model boundaries are the hard part,
- the system has multiple subdomains or bounded contexts,
- correctness depends on explicit domain concepts more than controller or repository shape.

## Avoid

Do not stack every pattern at full strength unless the system truly needs it.
