# ARTIFACT: Tallyboard datastore decision
Tallyboard is a small B2B SaaS (invoice reminders). Team: 3 engineers, no dedicated ops. ~2,100 customers, ~40 writes/sec peak, 9 GB data, growth ~15%/quarter.
Current: single SQLite file on one VM, nightly backup by cron to object storage. Two data-loss scares in 6 months (one disk full, one bad deploy).
Options on the table:
  A) Keep SQLite and add Litestream continuous replication to object storage.
  B) Move to managed Postgres (cost estimate 140 USD/month, 2 weeks migration).
Known: the largest customer (Brightmoor, 18% of revenue) has a security questionnaire asking for "point-in-time recovery and a documented RTO under 1 hour".
Unknown: whether Brightmoor will accept Litestream-based restore as PITR; whether write volume will outgrow single-node SQLite within 18 months.
Constraint: the founder wants the decision this week; migration work would pause the invoicing-templates feature.
