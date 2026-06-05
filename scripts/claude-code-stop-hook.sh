#!/usr/bin/env bash
#
# Claude Code Stop hook → tell Boomer that a coding agent just finished, so it
# hops onto the Terminal and celebrates.
#
# Install by adding this to ~/.claude/settings.json:
#
#   {
#     "hooks": {
#       "Stop": [
#         { "hooks": [{ "type": "command", "command": "open 'boomer://event/agent-done?agent=claude-code'" }] }
#       ]
#     }
#   }
#
# Or run this script directly to test the bridge.

set -euo pipefail
open "boomer://event/agent-done?agent=claude-code"
