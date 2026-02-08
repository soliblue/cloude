# Center Toolbar Logo {person.crop.circle}
<!-- priority: 2 -->
<!-- tags: ui, header -->
<!-- build: 65 -->

> Logo in the navigation toolbar was visually off-center due to extra padding on the leading toolbar items.

## Change
- Removed `.padding(.horizontal, 14)` from the leading toolbar HStack in `CloudeApp.swift`
- The `.principal` placement now centers the `ConnectionStatusLogo` naturally between leading and trailing items

## Files
- `Cloude/Cloude/App/CloudeApp.swift`
