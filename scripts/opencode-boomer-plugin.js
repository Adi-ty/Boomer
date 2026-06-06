// Boomer — opencode integration.
//
// Makes your desktop pet hop onto the terminal and celebrate whenever an
// opencode session finishes responding (the `session.idle` event).
//
// Install globally:
//   mkdir -p ~/.config/opencode/plugins
//   cp scripts/opencode-boomer-plugin.js ~/.config/opencode/plugins/boomer.js
//
// Or per-project: .opencode/plugins/boomer.js
//
// Test the bridge without opencode:
//   open "boomer://event/agent-done?agent=opencode"

export const BoomerPlugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        await $`open ${"boomer://event/agent-done?agent=opencode"}`
      }
    },
  }
}
