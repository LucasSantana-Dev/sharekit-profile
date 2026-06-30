# Review-Response Wrapper Pattern

Use this pattern for skills that help interpret or respond to review feedback without replacing the canonical review skills.

## Use the pattern when

- the public skill exists to evaluate incoming review comments,
- `code-review` still owns fresh code inspection,
- `requesting-code-review` still owns soliciting a new review.

## Contract

- Keep the public skill focused on evaluating feedback before implementation.
- Route fresh inspection work to `code-review`.
- Route pre-merge or self-requested review work to `requesting-code-review`.
- Keep examples, tone rules, and pushback patterns in `references/`.

## Avoid

- turning the wrapper into a second full code-review skill,
- mixing feedback-response behavior with review-request behavior,
- hiding when the user really needs one of the canonical review siblings.
