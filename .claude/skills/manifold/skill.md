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

- **Username**: Soli (this is Soli's personal account — NOT Cloude's)
- **User ID**: MANIFOLD_USER_ID_PLACEHOLDER
- **Profile**: https://manifold.markets/Soli
- **CRITICAL**: Never post, bet, comment, or create markets without explicit permission. This is Soli's account, not mine.

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

## Check Bets

```bash
curl -sL -H "Authorization: Key $MANIFOLD_KEY" \
  "https://api.manifold.markets/v0/bets?username=Soli&limit=20" | jq '[.[] | {contractId, outcome, amount, shares, probBefore, probAfter, createdTime}]'
```

## Check Positions on a Market

```bash
curl -sL "https://api.manifold.markets/v0/market/{marketId}/positions?userId=MANIFOLD_USER_ID_PLACEHOLDER" | jq
```

## Check Comments on My Markets

Get all open markets Soli created and check for new comments from other users. Use the helper script:

```bash
node /path/to/check_comments.js <marketId1> <marketId2> ...
```

To get all open market IDs:
```bash
curl -sL "https://api.manifold.markets/v0/search-markets?term=&sort=newest&filter=open&creatorId=MANIFOLD_USER_ID_PLACEHOLDER&limit=20" | jq -r '.[].id'
```

To check comments on a specific market:
```bash
curl -sL "https://api.manifold.markets/v0/comments?contractId={marketId}&limit=10" | jq '[.[] | {userName, date: (.createdTime / 1000 | todate), text: [(.content.content // [])[] | [(.content // [])[] | select(.type == "text" or .type == "mention") | (if .type == "mention" then "@" + .attrs.label else .text end)] | join("")] | join(" ")}]'
```

Filter to only show comments from the last N days by checking dates. When reporting, skip comments from "Soli" (that's us) and highlight any unanswered questions.

## Post a Comment

```bash
curl -sL -X POST \
  -H "Authorization: Key $MANIFOLD_KEY" \
  -H "Content-Type: application/json" \
  -d '{"contractId": "MARKET_ID", "markdown": "Your comment here"}' \
  "https://api.manifold.markets/v0/comment" | jq
```

**CRITICAL**: Never post comments without Soli's explicit permission.

## Soli's Manifold Profile

- **Account since**: Sept 2023
- **3,595 total bets** across 460 markets, **100 markets created**
- **4,535 mana balance**, 73,527 total deposited, premium subscriber
- **Peak activity**: Dec 2023 - Jan 2024 (750+ bets/month), tapered to occasional since mid-2025
- **Dominant interest**: AI/LLM (71% of created markets) — ChatBot Arena rankings, model releases, company moves
- **Notable markets created**: "Best LLM at end of 2025" (584K vol, 199 traders), "Trump die/ill before end of term" (503K vol, 874 traders)
- **Style**: Heavy YES bias (78%), bets mostly 10-500 mana range, trades actively in markets he cares about (359 bets in a single market)
- **Topics**: AI models, OpenAI vs Anthropic, tech stocks, Apple hardware, prediction markets meta, occasional politics/philosophy
- **Twitter**: @_xsoli

## Rules for Cloude

- READ-ONLY by default. Only browse, analyze, surface insights.
- Never bet, sell, create markets, or comment without Soli's explicit instruction.
- When suggesting opportunities, show the reasoning — Soli decides.
- This is Soli's account and identity. I don't pretend to be him.

## Rate Limits

- 500 requests per minute per IP
- No daily limit, but be reasonable
