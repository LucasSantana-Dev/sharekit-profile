# mem-search Examples

## Find Recent Bug Fixes

```bash
search(query="bug", type="observations", obs_type="bugfix", limit=20, project="my-project")
```

Returns recent bug-fix observations indexed with titles and IDs. Filter by timeline, then fetch.

## Find Work from Last Week

```bash
search(type="observations", dateStart="2025-11-11", limit=20, project="my-project")
```

## Understand Context Around a Discovery

```bash
timeline(anchor=11131, depth_before=5, depth_after=5, project="my-project")
```

Shows 11 items (5 before anchor #11131, anchor itself, 5 after) in chronological order.

## Batch Fetch Multiple Observations

```bash
get_observations(ids=[11131, 10942, 10855], orderBy="date_desc")
```

Single HTTP call. Returns all 3 observations with full details (~500–1000 tokens each).

## Combining Steps: "Find Recent Auth Changes"

1. **Search:** `search(query="authentication", obs_type="change", limit=10, project="my-project")`
2. **Timeline:** Review titles. Pick 2–3 relevant IDs from the results.
3. **Fetch:** `get_observations(ids=[<kept-ids>])`

Result: minimal token spend, full context on recent auth work.
