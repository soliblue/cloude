---
name: manifold
description: Browse and analyze Manifold prediction markets.
user-invocable: true
metadata:
  icon: chart.line.uptrend.xyaxis
  aliases: [predict, bet, markets]
---

# Manifold

Browse and analyze Manifold Markets.

## Rules

- Read-only by default.
- Never bet, sell, create, or comment without explicit permission.
- This is the user's account.

## Auth

```bash
MANIFOLD_KEY=$(cat ~/.config/manifold/credentials.json | jq -r '.api_key')
```

Use `Authorization: Key $MANIFOLD_KEY` for authenticated requests.

## Common Tasks

### Profile

```bash
curl -sL -H "Authorization: Key $MANIFOLD_KEY"   "https://api.manifold.markets/v0/me" | jq '{username, balance, totalDeposits, profit}'
```

### Search markets

```bash
curl -sL "https://api.manifold.markets/v0/search-markets?term=AI+agents&sort=score&filter=open&limit=10" | jq '[.[] | {id, question, probability: .prob, volume: .volume, url}]'
```

### Market details

```bash
curl -sL "https://api.manifold.markets/v0/market/{marketId}" | jq '{question, probability: .prob, volume, totalLiquidity, closeTime, description: .textDescription}'
```

### Bets and positions

```bash
curl -sL -H "Authorization: Key $MANIFOLD_KEY"   "https://api.manifold.markets/v0/bets?username=$MANIFOLD_USERNAME&limit=20" | jq
```

```bash
curl -sL "https://api.manifold.markets/v0/market/{marketId}/positions?userId=$MANIFOLD_USER_ID" | jq
```

## Allowed actions with explicit permission only

- place a bet
- sell shares
- post a comment
- create a market

## Use

Use this skill to surface opportunities, analyze markets, or inspect the user's activity. The user decides what to do.
