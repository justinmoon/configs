import type { Plugin } from "@opencode-ai/plugin"

const OPENCODE_NOTIFY_PATH = `${process.env.HOME}/.local/bin/opencode-notify`
const SESSION_STATUS = new Map<string, string>()

async function getTmuxTitle($: Plugin.Input["$"]): Promise<string> {
  try {
    const output = await $`tmux display-message -p '#{window_index} #{window_name}'`.quiet().text()
    const title = output.trim()
    return title.length > 0 ? title : "OpenCode"
  } catch {
    return "OpenCode"
  }
}

async function hasNotifier($: Plugin.Input["$"]): Promise<boolean> {
  try {
    await $`test -x ${OPENCODE_NOTIFY_PATH}`.quiet()
    return true
  } catch {
    return false
  }
}

async function notifyIdle($: Plugin.Input["$"]): Promise<void> {
  if (!(await hasNotifier($))) return
  const title = await getTmuxTitle($)
  await $`${OPENCODE_NOTIFY_PATH} --title ${title} --message ${" "}`.quiet()
}

function shouldNotify(sessionID: string): boolean {
  const previous = SESSION_STATUS.get(sessionID)
  if (previous === "idle") return false
  SESSION_STATUS.set(sessionID, "idle")
  return true
}

const plugin: Plugin = async (input) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.status") {
        const { sessionID, status } = event.properties as { sessionID: string; status: { type: string } }
        if (status.type === "idle") {
          if (shouldNotify(sessionID)) await notifyIdle(input.$)
          return
        }
        SESSION_STATUS.set(sessionID, status.type)
        return
      }

      if (event.type === "session.idle") {
        const { sessionID } = event.properties as { sessionID: string }
        if (shouldNotify(sessionID)) await notifyIdle(input.$)
      }
    },
  }
}

export default plugin
