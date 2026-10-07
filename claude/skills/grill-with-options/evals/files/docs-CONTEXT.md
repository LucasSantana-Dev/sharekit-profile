# Ordering

Receives and tracks customer orders for a wholesale marketplace.

## Language

**Order**:
A confirmed request from a Customer to buy one or more Line Items. Created only after payment authorization.
_Avoid_: Purchase, cart

**Cart**:
A draft set of Line Items a Customer has not yet paid for. Never becomes an Order until authorization.
_Avoid_: Basket, draft order

**Cancellation**:
Voiding an entire Order before shipment. Partial removal of Line Items is an Order Amendment, not a Cancellation.
_Avoid_: Refund, return

**Customer**:
A business that places Orders.
_Avoid_: Client, user, account
