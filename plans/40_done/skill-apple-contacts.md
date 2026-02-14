# Apple Contacts Skill {person.crop.rectangle.stack}
<!-- priority: 5 -->
<!-- tags: skill, integration, apple -->

> Search, read, and create contacts via AppleScript. Lookup phone numbers, emails, birthdays. Enables other skills (email, calendar) to resolve names to contact info.

## Approach
AppleScript via `osascript`. Read-heavy — creating/editing contacts less common.

## Commands
- Search contacts by name
- Get contact details (phone, email, address, birthday)
- Create new contact
- List contacts in a group

## Use Cases
- "What's Mom's phone number?"
- "When is Hatem's birthday?"
- "Add this new contact: ..."
- Other skills: calendar can auto-lookup attendee emails, email can resolve "send to Adam"

**Files:** `.claude/skills/contacts/`, shell scripts with AppleScript
