---
name: tweets
description: Search, analyze, and use Soli's Twitter archive (462 tweets, 39 note-tweets). Use for context, voice matching, pattern analysis.
user-invocable: true
icon: bubble.left.and.text.bubble.right
aliases: [twitter, tweet, x]
---

# Tweets Skill

Access Soli's Twitter archive (@_xsoli) for search, analysis, and context.

## Privacy

**CRITICAL**: Tweet data is symlinked into `.claude/skills/tweets/data/` and gitignored. Never commit tweet data. Never share raw tweet content outside this project.

## Data Location

```
.claude/skills/tweets/data/tweets.js       # 462 tweets (main archive)
.claude/skills/tweets/data/note-tweet.js    # 39 long-form note-tweets (full text of truncated tweets)
```

## Parsing the Data

Both files have a JS prefix that must be stripped before JSON parsing.

```bash
# Parse tweets.js
node -e "
const fs = require('fs');
const raw = fs.readFileSync('.claude/skills/tweets/data/tweets.js', 'utf8');
const json = JSON.parse(raw.replace('window.YTD.tweets.part0 = ', ''));
console.log(JSON.stringify(json, null, 2));
" > /tmp/tweets.json

# Parse note-tweet.js
node -e "
const fs = require('fs');
const raw = fs.readFileSync('.claude/skills/tweets/data/note-tweet.js', 'utf8');
const json = JSON.parse(raw.replace('window.YTD.note_tweet.part0 = ', ''));
console.log(JSON.stringify(json, null, 2));
" > /tmp/note-tweets.json
```

## Tweet Structure

Each entry in `tweets.js`:
```
{ tweet: {
    id / id_str         — tweet ID
    full_text           — tweet text (may be truncated with "…" for long tweets)
    created_at          — "Mon Jan 05 08:36:41 +0000 2026"
    favorite_count      — likes (string)
    retweet_count       — retweets (string)
    lang                — language code
    in_reply_to_status_id_str  — (if reply) parent tweet ID
    in_reply_to_screen_name    — (if reply) parent user
    in_reply_to_user_id        — (if reply) parent user ID
    entities.user_mentions     — mentioned users
    entities.urls              — embedded URLs with expanded_url
    entities.media             — attached media
    source                     — client (iPhone, web, etc.)
}}
```

## Note-Tweet Structure (Long-Form)

Each entry in `note-tweet.js`:
```
{ noteTweet: {
    noteTweetId    — unique ID for the note-tweet
    createdAt      — ISO timestamp
    core.text      — FULL text (no truncation)
    core.mentions  — mentioned users
    core.urls      — embedded URLs
    core.styletags — formatting (bold, italic)
}}
```

## Matching Truncated Tweets to Note-Tweets

Tweets ending with `…` are truncated. Their full text lives in `note-tweet.js`. Match by **creation timestamp** (within 5 seconds). Note: reply tweets have `@username` prefixes in `full_text` that are stripped in the note-tweet's `core.text`, so text prefix matching alone fails for replies. Always use timestamp as the primary match.

## IMPORTANT: Shell Escaping

**NEVER use inline `node -e` with tweet queries.** Bash escapes `!` inside strings, breaking any code with `.startsWith('RT @')`, negation operators, etc. Instead, always:
1. Write the JS to a temp file using the Write tool (scratchpad directory)
2. Run with `node /path/to/script.js`

## Common Queries

All examples below show the JS content to write to a temp file, then run with `node`.

### Search tweets by keyword
```js
// Write to temp file, run with: node /path/to/search.js "KEYWORD"
const fs = require("fs");
const raw = fs.readFileSync(".claude/skills/tweets/data/tweets.js", "utf8");
const tweets = JSON.parse(raw.replace("window.YTD.tweets.part0 = ", ""));
const q = (process.argv[2] || "").toLowerCase();
const matches = tweets
  .filter(t => t.tweet.full_text.toLowerCase().includes(q))
  .map(t => ({
    date: t.tweet.created_at,
    text: t.tweet.full_text,
    likes: +t.tweet.favorite_count,
    rts: +t.tweet.retweet_count,
    id: t.tweet.id_str
  }));
console.log(JSON.stringify(matches, null, 2));
```

### Get top tweets by likes
```js
const fs = require("fs");
const raw = fs.readFileSync(".claude/skills/tweets/data/tweets.js", "utf8");
const tweets = JSON.parse(raw.replace("window.YTD.tweets.part0 = ", ""));
const sorted = tweets
  .map(t => ({
    date: t.tweet.created_at,
    text: t.tweet.full_text,
    likes: +t.tweet.favorite_count,
    rts: +t.tweet.retweet_count,
    id: t.tweet.id_str
  }))
  .sort((a, b) => b.likes - a.likes)
  .slice(0, 20);
console.log(JSON.stringify(sorted, null, 2));
```

### Filter by date range
```js
// Run with: node script.js "2024-01-01" "2024-12-31"
const fs = require("fs");
const raw = fs.readFileSync(".claude/skills/tweets/data/tweets.js", "utf8");
const tweets = JSON.parse(raw.replace("window.YTD.tweets.part0 = ", ""));
const start = new Date(process.argv[2]);
const end = new Date(process.argv[3]);
const matches = tweets
  .filter(t => { const d = new Date(t.tweet.created_at); return d >= start && d <= end; })
  .map(t => ({ date: t.tweet.created_at, text: t.tweet.full_text, likes: +t.tweet.favorite_count, id: t.tweet.id_str }));
console.log(JSON.stringify(matches, null, 2));
```

### Get original tweets only (no replies, no RTs)
```js
const fs = require("fs");
const raw = fs.readFileSync(".claude/skills/tweets/data/tweets.js", "utf8");
const tweets = JSON.parse(raw.replace("window.YTD.tweets.part0 = ", ""));
const originals = tweets.filter(t =>
  t.tweet.full_text.indexOf("RT @") !== 0 &&
  !t.tweet.in_reply_to_status_id_str
);
console.log("Original tweets:", originals.length);
originals.forEach(t => {
  console.log(`[${t.tweet.created_at}] (+${t.tweet.favorite_count} likes) ${t.tweet.full_text.slice(0, 120)}`);
});
```

### Get full text of a truncated tweet
```js
const fs = require("fs");
const tweetsRaw = fs.readFileSync(".claude/skills/tweets/data/tweets.js", "utf8");
const notesRaw = fs.readFileSync(".claude/skills/tweets/data/note-tweet.js", "utf8");
const tweets = JSON.parse(tweetsRaw.replace("window.YTD.tweets.part0 = ", ""));
const notes = JSON.parse(notesRaw.replace("window.YTD.note_tweet.part0 = ", ""));
const truncated = tweets.filter(t => t.tweet.full_text.endsWith("\u2026") && t.tweet.full_text.indexOf("RT @") !== 0);
truncated.forEach(t => {
  const tDate = new Date(t.tweet.created_at).getTime();
  const match = notes.find(n => Math.abs(new Date(n.noteTweet.createdAt).getTime() - tDate) < 5000);
  if (match) {
    console.log("---");
    console.log("Tweet ID:", t.tweet.id_str);
    console.log("Date:", t.tweet.created_at);
    console.log("Full text:", match.noteTweet.core.text);
    console.log("Likes:", t.tweet.favorite_count);
  }
});
```

### Stats overview
```js
const fs = require("fs");
const raw = fs.readFileSync(".claude/skills/tweets/data/tweets.js", "utf8");
const tweets = JSON.parse(raw.replace("window.YTD.tweets.part0 = ", ""));
const originals = tweets.filter(t => t.tweet.full_text.indexOf("RT @") !== 0 && !t.tweet.in_reply_to_status_id_str);
const replies = tweets.filter(t => t.tweet.in_reply_to_status_id_str);
const rts = tweets.filter(t => t.tweet.full_text.indexOf("RT @") === 0);
const totalLikes = tweets.reduce((s, t) => s + (+t.tweet.favorite_count), 0);
const totalRTs = tweets.reduce((s, t) => s + (+t.tweet.retweet_count), 0);
const dates = tweets.map(t => new Date(t.tweet.created_at));
const months = {};
dates.forEach(d => { const k = d.toISOString().slice(0,7); months[k] = (months[k]||0) + 1; });
console.log(JSON.stringify({
  total: tweets.length, originals: originals.length, replies: replies.length, retweets: rts.length,
  totalLikes, totalRetweets: totalRTs,
  dateRange: dates.sort((a,b)=>a-b)[0].toISOString().slice(0,10) + " to " + dates.sort((a,b)=>b-a)[0].toISOString().slice(0,10),
  tweetsByMonth: months
}, null, 2));
```

### Topic frequency analysis
```js
const fs = require("fs");
const raw = fs.readFileSync(".claude/skills/tweets/data/tweets.js", "utf8");
const tweets = JSON.parse(raw.replace("window.YTD.tweets.part0 = ", ""));
const topics = {
  AI: /\b(ai|gpt|claude|llm|openai|anthropic|chatgpt|gemini|copilot|cursor|model|neural|transformer)\b/i,
  Crypto: /\b(crypto|bitcoin|btc|eth|web3|blockchain|nft)\b/i,
  Apple: /\b(apple|iphone|ipad|mac|vision pro|swiftui|xcode|ios)\b/i,
  Startups: /\b(startup|founder|vc|fundrais|yc|investor|pitch)\b/i,
  Prediction: /\b(manifold|polymarket|prediction market|metaculus|bet|forecast)\b/i,
  Music: /\b(rocycle|music|spotify|song|album|concert|cycling)\b/i,
  Germany: /\b(berlin|germany|deutsch|german)\b/i,
};
const counts = {};
for (const [topic, regex] of Object.entries(topics)) {
  counts[topic] = tweets.filter(t => regex.test(t.tweet.full_text)).length;
}
console.log("Topic frequency:", JSON.stringify(counts, null, 2));
```

## Use Cases

- **Voice matching**: Search tweets to understand how Soli writes — his tone, vocabulary, sentence structure. Use when writing as or for him.
- **Context for interviews**: Pull relevant tweets when using the Get To Know skill or when discussing Soli's views on a topic.
- **Pattern analysis**: Track how interests shifted over time (obsession cycles), what topics dominate which periods.
- **Content creation**: Find themes and ideas worth expanding into longer content.
- **Self-reflection**: Surface contradictions, evolution of views, patterns Soli might not see himself.

## Account Info

- **Handle**: @_xsoli
- **User ID**: 297600500
- **Archive date**: January 6, 2026
- **Tweet URL format**: `https://x.com/_xSoli/status/{tweet_id}`
