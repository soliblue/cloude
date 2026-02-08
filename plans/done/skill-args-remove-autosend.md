# Remove Skill Arg Forms
<!-- priority: 10 -->
<!-- tags: skills -->
<!-- build: 56 -->

Currently skills with args show a custom form UI with input fields. Remove that — selecting a skill should just populate the input bar with the skill name. User types freeform context if needed, then sends. The AI figures out what to do from the skill prompt + user message.

- Skills with no args (like /clear, /compact) can auto-send immediately
- Everything else: no form, no structured inputs, just freeform text
