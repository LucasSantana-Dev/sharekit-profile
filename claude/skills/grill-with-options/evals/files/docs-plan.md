# Plan: Self-service order changes

Let customers cancel part of an order from the portal until it ships.

- A customer can open their order and cancel individual items. The order stays active with the remaining items.
- When the last item is cancelled, the whole cart is closed.
- Cancellations over $5,000 need approval from the account manager.
- We will store each cancellation as a row in a new `cancellations` table and refund the card automatically.
- Users get an email for every cancellation.
