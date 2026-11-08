---
name: graphify
description: Build, refresh, query, and explain this project’s Graphify knowledge graph using the installed local CLI.
---
# Graphify in OpenCode

Use the real shell tool to call the installed graphify command. Do not imitate a tool call by printing code or tags.

- Refresh a code graph with graphify update "<path>". Add --force only for an intentional full rebuild or when the indexed root changes.
- Query with graphify query "<question>"; trace a route with graphify path "<A>" "<B>"; explain a node with graphify explain "<node>".
- A code-only update is local and needs no model API key. Its output is under graphify-out/.
- Keep project source files unchanged. Do not delete existing Graphify output without a backup.
- Report the command and its actual shell result; never claim success without tool output.
