---
name: music-player
description: Control Apple Music — now playing, search library, play/pause, queue, playlists. Real-time via AppleScript.
user-invocable: true
icon: music.note
aliases: [apple-music, music, now-playing]
---

# Apple Music Skill

Control Music.app (Apple Music) via AppleScript. Play, pause, search, browse playlists, check what's playing.

## First-Time Setup

Run any script once to trigger the macOS permission dialog:
```bash
bash .claude/skills/music-player/music-now.sh
```
Click "Allow" in System Settings > Privacy & Security > Automation > Terminal > Music.

## Scripts

### Now playing
```bash
bash .claude/skills/music-player/music-now.sh
```
Shows current track name, artist, album, duration, position, and player state.

### Search library
```bash
bash .claude/skills/music-player/music-search.sh "bohemian"          # Search tracks (default 20 results)
bash .claude/skills/music-player/music-search.sh "kendrick" 50       # Search with custom limit
```
Searches track name, artist, and album. Output: `Name|Artist|Album|Duration`

### Playback control
```bash
bash .claude/skills/music-player/music-control.sh play
bash .claude/skills/music-player/music-control.sh pause
bash .claude/skills/music-player/music-control.sh toggle             # Play/pause toggle
bash .claude/skills/music-player/music-control.sh next
bash .claude/skills/music-player/music-control.sh previous
bash .claude/skills/music-player/music-control.sh volume 75          # Set volume 0-100
bash .claude/skills/music-player/music-control.sh volume up          # +10
bash .claude/skills/music-player/music-control.sh volume down        # -10
```

### Playlists
```bash
bash .claude/skills/music-player/music-playlist.sh                   # List all playlists
bash .claude/skills/music-player/music-playlist.sh "Favorites"       # Tracks in a playlist
```
List output: `PlaylistName|TrackCount`
Tracks output: `Name|Artist|Album|Duration`

## Security
- All operations are local via AppleScript
- No data leaves the Mac
