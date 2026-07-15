// Personal-fork configuration. Upstream never edits this file, so it is the
// single source of divergence for the fork. Chokepoint files import from here
// instead of hard-coding fork-specific choices, which keeps rebase conflicts
// confined to a handful of one-line reads.
import type { TuiAgent } from './types'

// The only agents surfaced in this fork. Everything else is hidden from every
// picker and the settings pane. Must be valid `TuiAgent` members.
export const KEPT_AGENTS = [
  'claude',
  'claude-agent-teams',
  'copilot'
] as const satisfies readonly TuiAgent[]

// Source-control review + task providers kept. GitHub is already the hard-coded
// default/fallback everywhere, so the others hide without breaking anything.
export const KEPT_FORGES = ['github'] as const
export const KEPT_TASK_PROVIDERS = ['github'] as const

// Hygiene: keep the fork from phoning home to / colliding with upstream.
export const DISABLE_UPDATER = true
export const DISABLE_STAR_NAG = true
export const DISABLE_TELEMETRY = true // belt-and-suspenders; unofficial builds are already off

// Heavy subsystems hidden from the UI (code kept, just not surfaced).
export const HIDE_EMULATOR = true
export const HIDE_MOBILE_COMPANION = true
export const HIDE_AUTOMATIONS_BUTTON = true
export const HIDE_COMPUTER_USE = true
// Kept and unchanged: speech (sherpa-onnx), browser (agent-browser), native-chat.

const KEPT_AGENT_SET: ReadonlySet<TuiAgent> = new Set(KEPT_AGENTS)
const KEPT_FORGE_SET: ReadonlySet<string> = new Set(KEPT_FORGES)
const KEPT_TASK_PROVIDER_SET: ReadonlySet<string> = new Set(KEPT_TASK_PROVIDERS)

// Why: these are the single predicates every chokepoint reads, so the "what
// survives" decision lives only in the KEPT_* lists above. They accept `string`
// so callers avoid the `readonly [...] .includes()` argument-narrowing trap.
export function isForkKeptAgent(agent: TuiAgent): boolean {
  return KEPT_AGENT_SET.has(agent)
}

export function isForkKeptForge(id: string): boolean {
  return KEPT_FORGE_SET.has(id)
}

export function isForkKeptTaskProvider(id: string): boolean {
  return KEPT_TASK_PROVIDER_SET.has(id)
}
