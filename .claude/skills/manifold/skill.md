---
name: manifold
description: Browse and bet on Manifold prediction markets. Use when asked about predictions, markets, bets, or Manifold.
user-invocable: true
icon: chart.line.uptrend.xyaxis
aliases: [predict, bet, markets]
---

# Manifold Skill

Participate in prediction markets on Manifold Markets.

## Account Info

- **Username**: Cloudio
- **Profile**: https://manifold.markets/Cloudio
- **Bio**: Autonomous Claude agent running on @Soli's laptop. I bet on markets I have informed opinions about. Built with Claude Code.
- **Scope**: Betting and market browsing only (no comments for now)

## API Authentication

```bash
MANIFOLD_KEY=$(cat ~/.config/manifold/credentials.json | jq -r '.api_key')
```

All authenticated requests use: `Authorization: Key $MANIFOLD_KEY`

## Check My Profile & Balance

```bash
curl -sL -H "Authorization: Key $MANIFOLD_KEY" \
  "https://api.manifold.markets/v0/me" | jq '{username, balance, totalDeposits, profit}'
```

## Search Markets

Find open markets by topic. Sort options: `score`, `most-popular`, `newest`, `24-hour-vol`, `liquidity`.

```bash
curl -sL "https://api.manifold.markets/v0/search-markets?term=AI+agents&sort=score&filter=open&limit=10" | jq '[.[] | {id, question, probability: .prob, volume: .volume, url}]'
```

## Get Market Details

```bash
curl -sL "https://api.manifold.markets/v0/market/{marketId}" | jq '{question, probability: .prob, volume, totalLiquidity, closeTime, description: .textDescription}'
```

By slug (the URL path):
```bash
curl -sL "https://api.manifold.markets/v0/slug/{slug}" | jq
```

## Place a Bet

```bash
curl -sL -X POST \
  -H "Authorization: Key $MANIFOLD_KEY" \
  -H "Content-Type: application/json" \
  -d '{"contractId": "MARKET_ID", "amount": 50, "outcome": "YES"}' \
  "https://api.manifold.markets/v0/bet" | jq
```

Parameters:
- `contractId` (required) - Market ID
- `amount` (required) - Mana to bet
- `outcome` - `YES` or `NO` (default: YES)
- `limitProb` - Limit order at this probability (0.01-0.99)
- `dryRun` - Set true to simulate without placing

## Sell Shares

```bash
curl -sL -X POST \
  -H "Authorization: Key $MANIFOLD_KEY" \
  -H "Content-Type: application/json" \
  -d '{"outcome": "YES", "shares": 100}' \
  "https://api.manifold.markets/v0/market/{marketId}/sell" | jq
```

## Check My Bets

```bash
curl -sL -H "Authorization: Key $MANIFOLD_KEY" \
  "https://api.manifold.markets/v0/bets?username=Cloudio&limit=20" | jq '[.[] | {contractId, outcome, amount, shares, probBefore, probAfter, createdTime}]'
```

## Check My Positions on a Market

```bash
curl -sL "https://api.manifold.markets/v0/market/{marketId}/positions?userId=MY_USER_ID" | jq
```

## Betting Strategy

- Only bet on markets where I have genuine signal (AI, software, tech trends, prediction markets themselves)
- Start with small bets (10-50 mana) to calibrate
- Track accuracy over time - the whole point is accountability
- No degenerate gambling on random sports/politics markets without edge
- Record reasoning for each bet in CLAUDE.local.md so future sessions can evaluate
- Prefer markets with good liquidity (higher volume = more meaningful prices)

## Rate Limits

- 500 requests per minute per IP
- No daily limit, but be reasonable
