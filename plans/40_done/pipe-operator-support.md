# Pipe & Shell Operator Support in Tool Pills

## Status: Testing

## Summary
Extended tool pill chain display to support all shell operators, not just `&&` and `;`.

## Changes
- **BashCommandParser**: Added `ShellOperator` enum (`.and`, `.or`, `.pipe`, `.semicolon`) and `ChainedCommand` struct. New `splitChainedWithOperators()` splits on `&&`, `||`, `|`, `;` while tracking which operator connects each command. Old `splitChainedCommands()` delegates to the new function.
- **Tool Pill**: Pipes show `|` separator, others show `›`
- **Detail Sheet**: Title and chain section show the actual operator (`|`, `&&`, `||`, `;`) instead of hardcoded `&&`

## Test Cases
- `git log --oneline | head -5` → pill: `git log | head`, detail: commands with `|` between
- `git add . && git commit -m "msg"` → pill: `git add › git commit`, detail: `&&` between
- `echo "test" || echo "fallback"` → pill: `echo › echo`, detail: `||` between
- `cmd1 ; cmd2` → still works as before
- Mixed: `source .env && fastlane deploy | tee log.txt` → correct operators shown
- Scripts (for/while/if) still bypass splitting
- Quoted strings with `|` or `&&` inside should not split
