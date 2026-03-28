# Recording Overlay Fixed Height
<!-- build: 115 -->

Audio waveform container now has a fixed height (`DS.Size.row`) so the recording overlay doesn't jump around as bars animate.

## Test
- Start recording and watch the overlay
- Confirm it stays stable (no vertical shifting)
- Bars should still animate within the fixed container
