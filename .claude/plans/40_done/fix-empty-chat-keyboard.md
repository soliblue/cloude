# Fix: empty chat input above keyboard

Wrapped EmptyConversationView in a ScrollView so SwiftUI keyboard avoidance works correctly in new empty conversations. Without a ScrollView, the keyboard safe area adjustment pushed the input field above the keyboard with a gap.
