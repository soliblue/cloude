const https = require("https");
const fs = require("fs");
const path = require("path");

const DATA_DIR = path.join(__dirname, "data");
const CSV_PATH = path.join(DATA_DIR, "books.csv");
const URL_PATH = path.join(DATA_DIR, "feed_url.txt");

function fetch(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return fetch(res.headers.location).then(resolve).catch(reject);
      }
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => resolve(data));
      res.on("error", reject);
    }).on("error", reject);
  });
}

function extractTag(xml, tag) {
  const re = new RegExp(`<${tag}><!\\[CDATA\\[([\\s\\S]*?)\\]\\]></${tag}>|<${tag}>([\\s\\S]*?)</${tag}>`);
  const m = xml.match(re);
  if (!m) return "";
  return (m[1] || m[2] || "").trim();
}

function escapeCSV(val) {
  const s = String(val).replace(/\r?\n/g, " ").trim();
  if (s.includes(",") || s.includes('"') || s.includes("\n")) {
    return '"' + s.replace(/"/g, '""') + '"';
  }
  return s;
}

async function main() {
  let feedUrl = process.argv[2];

  if (!feedUrl) {
    if (fs.existsSync(URL_PATH)) {
      feedUrl = fs.readFileSync(URL_PATH, "utf8").trim();
    } else {
      console.error("Usage: node fetch.js <goodreads_rss_url>");
      console.error("Or save the URL to " + URL_PATH);
      process.exit(1);
    }
  }

  if (!fs.existsSync(URL_PATH) || fs.readFileSync(URL_PATH, "utf8").trim() !== feedUrl) {
    fs.writeFileSync(URL_PATH, feedUrl);
  }

  const shelves = ["read", "currently-reading", "to-read", "%23ALL%23"];
  const allBooks = new Map();

  for (const shelf of shelves) {
    let url = feedUrl;
    if (!url.includes("shelf=")) {
      url += (url.includes("?") ? "&" : "?") + "shelf=" + shelf;
    } else {
      url = url.replace(/shelf=[^&]*/, "shelf=" + shelf);
    }
    url += "&per_page=200";

    try {
      const xml = await fetch(url);
      const items = xml.split("<item>").slice(1);

      for (const item of items) {
        const bookId = extractTag(item, "book_id");
        if (allBooks.has(bookId)) {
          const existing = allBooks.get(bookId);
          if (shelf !== "%23ALL%23" && !existing.shelves.includes(shelf)) {
            existing.shelves += ", " + shelf;
          }
          continue;
        }

        allBooks.set(bookId, {
          bookId,
          title: extractTag(item, "title"),
          author: extractTag(item, "author_name"),
          isbn: extractTag(item, "isbn"),
          rating: extractTag(item, "user_rating"),
          avgRating: extractTag(item, "average_rating"),
          dateRead: extractTag(item, "user_read_at"),
          dateAdded: extractTag(item, "user_date_added"),
          shelves: shelf === "%23ALL%23" ? extractTag(item, "user_shelves") : shelf,
          pages: extractTag(item, "book").replace(/.*num_pages.*?>(\d+)<.*/, "$1").replace(/<.*/, ""),
          published: extractTag(item, "book_published"),
          review: extractTag(item, "user_review"),
        });
      }
      console.log(`Fetched shelf "${shelf}": ${items.length} items`);
    } catch (e) {
      console.error(`Failed to fetch shelf "${shelf}": ${e.message}`);
    }
  }

  const headers = ["book_id", "title", "author", "isbn", "rating", "avg_rating", "date_read", "date_added", "shelves", "pages", "published", "review"];
  const rows = [headers.join(",")];

  for (const book of allBooks.values()) {
    rows.push([
      book.bookId, escapeCSV(book.title), escapeCSV(book.author), book.isbn,
      book.rating, book.avgRating, escapeCSV(book.dateRead), escapeCSV(book.dateAdded),
      escapeCSV(book.shelves), book.pages, book.published, escapeCSV(book.review),
    ].join(","));
  }

  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(CSV_PATH, rows.join("\n"));
  console.log(`\nSaved ${allBooks.size} books to ${CSV_PATH}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
