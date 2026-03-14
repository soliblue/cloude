# Fix Line Wrap Toggle in File Preview

The wrap toggle in file preview wasn't working - nested ScrollViews prevented text from wrapping.

## Done
- [x] Replaced nested ScrollViews with single ScrollView with conditional axes
- [x] Hide line numbers when wrapping (they misalign with wrapped lines)
- [x] Deployed to iPhone
