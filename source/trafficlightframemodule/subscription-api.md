# Subscription API (WebSocket)

## Connection

Connect via WebSocket upgrade to the service URL.

## Message Format

All messages follow a space-separated format:

```
command authCode [argument]
```

- `authCode` — a valid access token (same as used for HTTP endpoints)
- All commands require a valid `authCode`, otherwise the response is silent (connection stays open)

## Commands

### subscribe

Subscribe to live price updates for a symbol.

```
subscribe <authCode> <symbol>
```

**Responses:**
```
subscribe success <symbol>
subscribe error <symbol>
```

Error occurs when the symbol is not in the allowed symbols list.

Once subscribed, you will receive price updates whenever the price changes:
```
liveDataUpdate <symbol> <price>
```

### unsubscribe

Unsubscribe from a previously subscribed symbol.

```
unsubscribe <authCode> <symbol>
```

**Responses:**
```
unsubscribe success <symbol>
unsubscribe error <symbol>
```

Error occurs when you are not subscribed to that symbol.

### viewSubscriptions

List all symbols you are currently subscribed to.

```
viewSubscriptions <authCode>
```

**Response:**
```
viewSubscriptions <symbol1> <symbol2> ...
```

Returns an empty `viewSubscriptions` (no symbols after it) if you have no active subscriptions.

## Notes

- All subscriptions are automatically cleaned up on disconnect
- Price updates (`liveDataUpdate`) are only sent when the price actually changes
- Available symbols are configured server-side (currently: `HYG`)
