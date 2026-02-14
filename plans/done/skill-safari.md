# Skill: Safari Browser

## What
Access Safari tabs, history, bookmarks, and reading list via AppleScript + SQLite.

## Scripts
- `safari-tabs.sh` — List all open tabs across windows (active tab marked)
- `safari-history.sh` — Search browsing history via History.db
- `safari-bookmarks.sh` — List/search bookmarks from Bookmarks.plist
- `safari-readinglist.sh` — Show Reading List items with read/unread status

## Permissions Needed
- Full Disk Access (for History.db and Bookmarks.plist)
- Automation permission for Safari (auto-prompted)

## Testing
- [ ] `safari-tabs.sh` lists open tabs
- [ ] `safari-history.sh` searches history
- [ ] `safari-history.sh google 5` limits results
- [ ] `safari-bookmarks.sh` lists all bookmarks
- [ ] `safari-readinglist.sh` shows reading list
