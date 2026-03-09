# Defer Environment Assignment to First Message

Don't bake in environmentId when creating a new chat. Instead, capture it when:
- User sends their first message
- User picks a working directory on an empty chat

This way switching envs before chatting works correctly.
