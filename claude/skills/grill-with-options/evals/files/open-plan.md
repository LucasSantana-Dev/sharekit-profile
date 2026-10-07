# Plan: Move invoice export to a background queue

Today the "Export invoices" button in the admin panel builds a CSV in the request and times out for large accounts (over 50k invoices). We will move the export to a background job.

- Click Export, job is queued, user gets an email with a download link when done.
- Use the existing Redis instance as the queue.
- Links expire after some time.
- Roll out to all customers next sprint.
