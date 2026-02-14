---
name: goodreads
description: Access the user's Goodreads reading history for context about their intellectual journey, book search, and reading patterns.
user-invocable: true
icon: book.fill
aliases: [books, reading]
---

# Goodreads Skill

Access the user's reading history from Goodreads. Books are stored locally as CSV for fast search and analysis.

## Setup (First Time)

If `data/books.csv` doesn't exist yet, ask the user for their Goodreads RSS feed URL.

How to find it: Go to goodreads.com → My Books → any shelf → click the RSS icon at the bottom of the page. The URL looks like:
`https://www.goodreads.com/review/list_rss/12345678?key=abc123...`

Then fetch:
```bash
node .claude/skills/goodreads/fetch.js "FEED_URL_HERE"
```

This saves the URL to `data/feed_url.txt` and fetches all shelves into `data/books.csv`.

## Refresh Data

Re-run the fetch script (it reuses the saved URL):
```bash
node .claude/skills/goodreads/fetch.js
```

## Data Location

```
.claude/skills/goodreads/data/books.csv      # All books (gitignored)
.claude/skills/goodreads/data/feed_url.txt   # Saved RSS URL (gitignored)
```

## CSV Columns

`book_id, title, author, isbn, rating, avg_rating, date_read, date_added, shelves, pages, published, review`

- `rating`: User's rating (0 = unrated, 1-5)
- `shelves`: comma-separated shelf names (read, currently-reading, to-read, custom)
- `date_read`: when finished (empty if not yet read)
- `review`: User's review text (if any)

## Common Queries

All examples use the CSV directly. Write JS to a temp file and run with `node`.

### Search books by keyword (title/author)
```js
const fs = require("fs");
const csv = fs.readFileSync(".claude/skills/goodreads/data/books.csv", "utf8");
const lines = csv.split("\n");
const headers = lines[0].split(",");
const q = (process.argv[2] || "").toLowerCase();
const books = [];
for (let i = 1; i < lines.length; i++) {
  if (!lines[i].trim()) continue;
  const vals = lines[i].match(/(".*?"|[^,]*)/g) || [];
  const row = {};
  headers.forEach((h, j) => row[h] = (vals[j] || "").replace(/^"|"$/g, "").replace(/""/g, '"'));
  if (row.title.toLowerCase().includes(q) || row.author.toLowerCase().includes(q)) books.push(row);
}
books.forEach(b => console.log(`${b.rating > 0 ? "★".repeat(+b.rating) : "unrated"} | ${b.title} — ${b.author} [${b.shelves}]`));
console.log(`\n${books.length} matches`);
```

### List all read books sorted by rating
```js
const fs = require("fs");
const csv = fs.readFileSync(".claude/skills/goodreads/data/books.csv", "utf8");
const lines = csv.split("\n");
const headers = lines[0].split(",");
const books = [];
for (let i = 1; i < lines.length; i++) {
  if (!lines[i].trim()) continue;
  const vals = lines[i].match(/(".*?"|[^,]*)/g) || [];
  const row = {};
  headers.forEach((h, j) => row[h] = (vals[j] || "").replace(/^"|"$/g, "").replace(/""/g, '"'));
  if (row.shelves.includes("read")) books.push(row);
}
books.sort((a, b) => +b.rating - +a.rating);
books.forEach(b => console.log(`${b.rating > 0 ? "★".repeat(+b.rating) : "-"} | ${b.title} — ${b.author}`));
console.log(`\n${books.length} read books`);
```

### Stats overview
```js
const fs = require("fs");
const csv = fs.readFileSync(".claude/skills/goodreads/data/books.csv", "utf8");
const lines = csv.split("\n");
const headers = lines[0].split(",");
const books = [];
for (let i = 1; i < lines.length; i++) {
  if (!lines[i].trim()) continue;
  const vals = lines[i].match(/(".*?"|[^,]*)/g) || [];
  const row = {};
  headers.forEach((h, j) => row[h] = (vals[j] || "").replace(/^"|"$/g, "").replace(/""/g, '"'));
  books.push(row);
}
const read = books.filter(b => b.shelves.includes("read"));
const rated = read.filter(b => +b.rating > 0);
const avgRating = rated.length ? (rated.reduce((s, b) => s + +b.rating, 0) / rated.length).toFixed(2) : "N/A";
const totalPages = read.reduce((s, b) => s + (+b.pages || 0), 0);
const authors = {};
read.forEach(b => { authors[b.author] = (authors[b.author] || 0) + 1; });
const topAuthors = Object.entries(authors).sort((a, b) => b[1] - a[1]).slice(0, 10);
console.log(JSON.stringify({
  total: books.length,
  read: read.length,
  currentlyReading: books.filter(b => b.shelves.includes("currently-reading")).length,
  toRead: books.filter(b => b.shelves.includes("to-read")).length,
  rated: rated.length,
  avgRating,
  totalPages,
  topAuthors: topAuthors.map(([a, c]) => `${a} (${c})`),
}, null, 2));
```

### Books by shelf
```js
const fs = require("fs");
const csv = fs.readFileSync(".claude/skills/goodreads/data/books.csv", "utf8");
const lines = csv.split("\n");
const headers = lines[0].split(",");
const shelf = (process.argv[2] || "read").toLowerCase();
const books = [];
for (let i = 1; i < lines.length; i++) {
  if (!lines[i].trim()) continue;
  const vals = lines[i].match(/(".*?"|[^,]*)/g) || [];
  const row = {};
  headers.forEach((h, j) => row[h] = (vals[j] || "").replace(/^"|"$/g, "").replace(/""/g, '"'));
  if (row.shelves.toLowerCase().includes(shelf)) books.push(row);
}
books.forEach(b => console.log(`${b.title} — ${b.author}`));
console.log(`\n${books.length} books on "${shelf}"`);
```

### 5-star books
```js
const fs = require("fs");
const csv = fs.readFileSync(".claude/skills/goodreads/data/books.csv", "utf8");
const lines = csv.split("\n");
const headers = lines[0].split(",");
for (let i = 1; i < lines.length; i++) {
  if (!lines[i].trim()) continue;
  const vals = lines[i].match(/(".*?"|[^,]*)/g) || [];
  const row = {};
  headers.forEach((h, j) => row[h] = (vals[j] || "").replace(/^"|"$/g, "").replace(/""/g, '"'));
  if (+row.rating === 5) console.log(`★★★★★ ${row.title} — ${row.author}`);
}
```

## IMPORTANT: Shell Escaping

Same as the tweets skill — **never use inline `node -e` with queries**. Always write JS to a temp file and run with `node /path/to/script.js`.

## Use Cases

- **Intellectual context**: What books shaped the user's thinking on a topic? Search by keyword.
- **Reading journey**: Trace the arc from religious texts → philosophy → CS → markets.
- **Recommendations**: Based on 5-star books and patterns, suggest new reads.
- **Conversation context**: Reference relevant books when discussing topics the user cares about.
- **Pattern analysis**: Reading pace, genre distribution, author preferences.

## Limitations

- RSS feeds return max ~200 books per shelf. For very large libraries, some books may be missing.
- `date_read` may be empty even for read books if Goodreads didn't track it.
- Re-run the fetch script periodically to pick up new additions.
