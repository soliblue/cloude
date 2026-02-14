---
name: reminders
description: Create, complete, list, and search Apple Reminders. Real-time via AppleScript, syncs across all Apple devices via iCloud.
user-invocable: true
icon: checklist
aliases: [remind, reminder, todo]
---

# Apple Reminders Skill

Real-time access to Reminders.app via AppleScript. Changes sync to all Apple devices via iCloud.

## First-Time Setup

Run any script once to trigger the macOS permission dialog:
```bash
bash .claude/skills/reminders/rem-lists.sh
```
Click "Allow" in System Settings → Privacy & Security → Automation → Terminal → Reminders.

## Scripts

### List reminder lists
```bash
bash .claude/skills/reminders/rem-lists.sh
```

### View reminders
```bash
bash .claude/skills/reminders/rem-view.sh                          # All incomplete, all lists
bash .claude/skills/reminders/rem-view.sh "Shopping"                # Specific list
bash .claude/skills/reminders/rem-view.sh "" completed              # All completed
```

### Create reminder
```bash
bash .claude/skills/reminders/rem-create.sh "Call dentist"                                    # Simple
bash .claude/skills/reminders/rem-create.sh "Buy milk" "Shopping"                              # With list
bash .claude/skills/reminders/rem-create.sh "Submit report" "Work" "2026-02-15 17:00"          # With due date
bash .claude/skills/reminders/rem-create.sh "Mom birthday gift" "Personal" "2026-03-01" "Get flowers"  # With notes
```
Args: name, [list], [due_date], [notes]

### Complete a reminder
```bash
bash .claude/skills/reminders/rem-complete.sh "Call dentist"                # By name
bash .claude/skills/reminders/rem-complete.sh "Call dentist" "Personal"     # By name + list
```

### Search reminders
```bash
bash .claude/skills/reminders/rem-search.sh "dentist"
```

## Output Format

```
List|Name|DueDate|Completed|Notes
```

## Security
- All operations are local via AppleScript
- No data leaves the Mac, syncs only via iCloud (Apple's own sync)
