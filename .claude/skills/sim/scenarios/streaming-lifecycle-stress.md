# Streaming Lifecycle Stress

Use this scenario when the goal is to stress the full streaming lifecycle instead of only one response.

This is one multi-turn flow. Run every step in order. Do not substitute prompts unless the round explicitly needs a variant.

## Coverage Goal

This flow is meant to cover:

- initial connection and auth
- first streamed response with markdown before and after tool groups
- follow-up messaging in the same conversation
- multiple tool calls in one group
- agent tool calls and subagent completion behavior
- reconnect pressure during streaming
- app termination and relaunch during an active streamed response
- recovery of conversation state after relaunch
- final render stability and completion correctness

## Setup

1. Launch the local stack.
2. Start log streaming.
3. Wait for `finish name=environment.auth ... success=true` in `app-debug.log`.
4. Open a fresh repo-rooted conversation.
5. Switch the active conversation model to `haiku` unless the round explicitly targets another model.
6. Clear `app-debug.log` and `debug-metrics.log` if the round needs clean before and after counts.

## Message 1

Send this exact prompt:

```text
This is a streaming regression test. Follow these instructions exactly in one response.

Write a short markdown paragraph labeled `Message 1 Intro`.

Then make exactly 3 tool calls in one continuous group.
- Use only `Bash`, `Read`, or `Grep`.
- Use at least 2 different tool types in the group.
- Do not write text between the first and third tool call.

After the tool group, write a markdown heading, two bullet points, and one short concluding paragraph labeled `Message 1 End`.
```

Wait for the response to finish normally.

## Message 2

Send this exact prompt:

```text
This is the second step of a streaming regression test. Follow these instructions exactly in one response.

Write one short markdown paragraph labeled `Message 2 Before`.

Then make exactly 3 tool calls in one continuous group.
- Use only `Bash`, `Read`, or `Grep`.
- Do not write text between the first and third tool call.

After the tool group, write one markdown heading, one numbered list with three items, one fenced code block, and one short paragraph labeled `Message 2 After`.
```

During the streamed response for Message 2:

1. After the first assistant text appears and at least one tool call is visible, disconnect the selected environment.
2. Wait briefly.
3. Reconnect the same environment.
4. Keep the app open and let the response continue if it recovers.

Record whether the response resumes, duplicates, stalls, or finalizes incorrectly.

## Message 3

Send this exact prompt:

```text
This is the third step of a streaming regression test. Follow these instructions exactly in one response.

Write one short markdown paragraph labeled `Message 3 Before`.

Then make exactly 2 `Agent` tool calls in one continuous group with no text between them.
- Each `Agent` call must ask the agent to run only `Bash` commands.
- The first agent should run `sleep 1` and then `ls`.
- The second agent should run `sleep 2` and then `pwd` and `ls`.

After both agent calls finish, write one markdown heading, two bullet points, and one short paragraph labeled `Message 3 After`.
```

During the streamed response for Message 3:

1. Wait until the response is visibly streaming and at least one agent tool call is active.
2. Terminate the app.
3. Relaunch the app.
4. Reopen the same conversation if needed.
5. Observe whether the in-flight response recovers, duplicates, disappears, or corrupts the live-to-static handoff.

## Pass Signals

Look for:

- no duplicated markdown sections
- no duplicated tool groups
- no missing trailing text after tools
- no stuck live bubble after completion
- no corruption when reconnecting during Message 2
- no broken recovery semantics during Message 3 relaunch
- correct final ordering of text, tool groups, and completion state
- stable render counts after handoff

## Failure Signals

Common failures this scenario should expose:

- text repeated before or after tool groups
- tool pills duplicated or reordered
- final text missing after reconnect or relaunch
- agent group completion not reflected correctly
- live bubble never finalizes
- app resumes in a stale running state
- reconnect causes partial replay or double append
- relaunch loses the in-flight message entirely or shows both live and static copies

## Artifact Guidance

For serious rounds, store these paths in the round doc when available:

- `app-debug.log`
- `debug-metrics.log`
- screenshot path
- screen recording path
