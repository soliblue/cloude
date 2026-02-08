# Plan File Upload {square.and.arrow.up}
<!-- build: 67 -->

> Create plans from the iOS app — title, stage, description, tags
> Sends markdown file to Mac agent which writes it to plans/ directory

<!-- tags: plans, ui -->

## Changes

- **ClientMessage**: Added `uploadPlan(stage, filename, content, workingDirectory)`
- **ServerMessage**: Added `planUploaded(stage, plan)` confirmation with parsed PlanItem
- **PlansService**: Added `writePlan()` to create plan files on disk
- **AppDelegate+MessageHandling**: Routes uploadPlan to PlansService.writePlan
- **ConnectionManager+API**: Added `uploadPlan()` convenience + `onPlanUploaded` callback
- **PlansSheet**: Added `+` toolbar button → CreatePlanSheet with title/stage/description/tags
- **CloudeApp**: Wired up upload callback + planUploaded handler to update local state
