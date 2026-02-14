# Spotify Skill {music.note}
<!-- priority: 4 -->
<!-- tags: skill, integration, media -->

> Control Spotify playback on Mac. Play/pause, skip, queue, search, play artist/album/playlist. Inspired by OpenClaw's spotify-mac skill.

## Approach
AppleScript for basic playback control (play, pause, skip, volume). Spotify Web API for search, queue management, playlist operations (needs OAuth token).

## Commands
- Play / pause / skip / previous
- Volume up / down / set
- Now playing (current track info)
- Search tracks, artists, albums
- Play specific artist/album/playlist by name
- Queue a track
- List playlists

## Use Cases
- "Play some lo-fi"
- "What's playing?"
- "Skip this track"
- "Queue Nile's Black Seeds of Vengeance"

**Files:** `.claude/skills/spotify/`, AppleScript + optional Spotify API wrapper
