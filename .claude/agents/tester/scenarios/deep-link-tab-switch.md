# deep-link-tab-switch

Non-chat smoke: deep links correctly drive window and tab navigation.

## Run

```
./scripts/open-simulator-url.sh new-window
./scripts/open-simulator-url.sh files-tab
./scripts/open-simulator-url.sh chat-tab
./scripts/open-simulator-url.sh settings
```

## Assertions

- `app-debug.log` contains four `deeplink url=cloude://...` lines under Bootstrap in order
- Visual: settings sheet is presented (capture screenshot as artifact)
