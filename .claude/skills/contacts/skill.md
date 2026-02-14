---
name: contacts
description: Search and read Apple Contacts. Lookup phone numbers, emails, birthdays, addresses. Enables other skills to resolve names.
user-invocable: true
icon: person.crop.rectangle.stack
aliases: [contact, people, addressbook]
---

# Apple Contacts Skill

Search and read contacts from Contacts.app via AppleScript. Enables other skills (email, calendar, iMessage) to resolve "send to Adam" into actual contact info.

## First-Time Setup

Run any script once to trigger the macOS permission dialog:
```bash
bash .claude/skills/contacts/contact-search.sh "test"
```
Click "Allow" in System Settings → Privacy & Security → Automation → Terminal → Contacts.

## Scripts

### Search contacts
```bash
bash .claude/skills/contacts/contact-search.sh "Adam"           # By name
bash .claude/skills/contacts/contact-search.sh "Soliman"         # By last name
bash .claude/skills/contacts/contact-search.sh "knowunity"       # By company
```

### Get full contact details
```bash
bash .claude/skills/contacts/contact-detail.sh "Adam"            # First match
```

### List contacts in a group
```bash
bash .claude/skills/contacts/contact-groups.sh                   # List all groups
```

## Output Format

Search results:
```
Name|Phone|Email|Company
```

Detail view:
```
Name: Full Name
Phone: +49 176 ...
Email: name@example.com
Address: Street, City, ZIP
Birthday: YYYY-MM-DD
Company: Company Name
Notes: ...
```

## Use Cases
- "What's Mom's phone number?"
- "When is Hatem's birthday?"
- Other skills: resolve "email Adam" → lookup Adam's email → pass to email skill
