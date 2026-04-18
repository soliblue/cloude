---
title: "Skill: Apple Music"
description: "Built Apple Music skill for playback control, library search, and playlist management via AppleScript."
created_at: 2026-02-14
tags: ["skills"]
icon: music.note
build: 71
---


# Skill: Apple Music {music.note}
## What
Control Apple Music — now playing, search library, playback control, playlists.

## Scripts
- `music-now.sh` — Current track info (name, artist, album, position)
- `music-search.sh` — Search library by name/artist/album
- `music-control.sh` — Play/pause/next/previous/volume
- `music-playlist.sh` — List playlists or tracks in a playlist

## Permissions Needed
- Automation permission for Music (auto-prompted)

## Testing
- [ ] `music-now.sh` shows now playing
- [ ] `music-search.sh "song name"` finds tracks
- [ ] `music-control.sh toggle` plays/pauses
- [ ] `music-playlist.sh` lists playlists
