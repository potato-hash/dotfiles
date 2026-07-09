# __PROJECT_NAME__

<!-- One-line description of what this project is. Fill this in. -->

## Delegation Policy

For delegation routing and sub-agent dispatch policy, load the `engineering-handbook` skill (`skill_view(name='engineering-handbook')`). The skill covers OMP routing, decompose/parallelize/brief/supervise/own/teach discipline, and when to delegate vs. do directly.

Project-specific delegation rules below override the skill defaults where they conflict.

## Memory — Hindsight

A `hindsight` MCP server is configured for cross-agent long-term memory. At the start of a session or project switch, call Hindsight `recall` with the project/task query. When you learn a durable decision, project convention, bug root cause, or user correction, call Hindsight `retain`. Use metadata `{"source":"<tool>", "project":"<name>"}` so memories are traceable. Use `reflect` for synthesis. Do not call destructive Hindsight tools unless Alan explicitly asks.