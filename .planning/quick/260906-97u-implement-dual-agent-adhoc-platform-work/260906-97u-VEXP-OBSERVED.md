# Vexp Observed Reality — Quick Task 260906-97u

Recorded live on this machine (`dotatrash`) during Task 1 execution. Where a fact was inferred rather than directly measured, it is labelled `[inferred]` in place.

## Tier

`vexp license` output, verbatim:

```
vexp License Status

  Plan:      free
  Max nodes: 2,000
  Max repos: 1
  All tools: no (7/10)
```

## MCP tools exposed

Enumerated by a live JSON-RPC handshake (`initialize` -> `notifications/initialized` -> `tools/list`) against `vexp mcp` as registered (no proxy, no `--workspace` flag — the plain form, matching the registration in both profiles). A `tools/list` call is not a tool invocation and does not spend daily quota. Response `tools` array, by name:

- run_pipeline
- verify_done
- get_skeleton
- expand_vexp_ref

## Not exposed as MCP tools

Named in the source spec or in `vexp license`'s 7/10 fraction but absent from the live `tools/list` response above:

- get_context_capsule
- get_session_context
- search_memory
- save_observation
- get_impact_graph
- search_logic_flow
- index_status
- index_incremental
- pr_impact
- workspace_setup

## CLI fallbacks

The MCP surface is gated, but the CLI keeps the full verb set (`vexp --help`, verbatim command list): `index, daemon, skeleton, capsule, impact, flow, savings, search, verify, daemons, stop, shield, compress, setup-llm, hooks, init, mcp, daemon-cmd, doctor, setup, setup-agents, activate, deactivate, license, serve, autostart, use, version, help`.

Two CLI verbs specifically substitute for gated MCP tools and are the real blast-radius fallback for any agent holding `Bash`:

- `vexp impact <fqn>` — substitutes for the gated `get_impact_graph` MCP tool.
- `vexp flow <start> <end>` — substitutes for the gated `search_logic_flow` MCP tool.

`vexp hooks remove` is the supported removal path for the installed git hooks (see `## Git hooks installed` below).

No CLI substitute exists for `get_session_context` (persistent cross-session memory read) or `save_observation` (persistent cross-session memory write) — both are memory-store operations with no local/CLI equivalent found in the verb list above. `[inferred]` — absence confirmed by scanning the full verb list in `vexp --help`; not confirmed by vendor documentation, none of which is available locally.

## Tool count discrepancy

Three separate numbers are in play, none reconciled to a single "true" count — each measures something different:

- **14** — the tool catalogue named in the original task brief (`adhoc_platform_agent_workflow.txt` section 3): `get_session_context`, `get_impact_graph`, `search_logic_flow`, `run_pipeline`, `get_skeleton`, `save_observation`, `verify_done`, plus others implied by the capability descriptions (context capsules, search, index status). The brief's own count is descriptive prose, not an enumerated list, so this figure is a citation of the brief's framing rather than a directly-counted total.
- **7/10** — `vexp license`'s own tool-availability fraction for the free tier, printed verbatim above. This is the vendor's internal accounting of gated-vs-ungated tools across its whole catalogue (MCP and otherwise), not a live MCP enumeration.
- **4** — the number actually exposed over `tools/list` against the registered `vexp mcp` server, measured directly above. This is the only number that governs what the agents in this plan may call.

The agents in this plan are built against the measured **4**. The brief's 14 and the license's 7/10 are recorded as context for why the spec cannot be followed literally, not reconciled against the 4.

## Unexecutable spec steps

By source-spec reference (`adhoc_platform_agent_workflow.txt` section 4):

- **Stage 1, step 1** (`Query get_session_context to retrieve past architectural decisions and platform invariants`) — unexecutable. `get_session_context` is not exposed. No CLI substitute exists (see `## CLI fallbacks`). The Investigator has no persistent cross-session memory here and must start cold every time.
- **Stage 1, step 2** (`Call get_impact_graph or search_logic_flow to trace the blast radius`) — unexecutable via MCP. `get_impact_graph` and `search_logic_flow` are not exposed. Substitute: `vexp impact <fqn>` and `vexp flow <start> <end>` as CLI verbs, usable by any agent holding `Bash`.
- **Stage 2, step 5** (`Run save_observation to persist any new infrastructure rules to memory`) — unexecutable. `save_observation` is not exposed. No CLI substitute exists. The Executor instead writes any such rule into its own final report for a human to file.

## Quota

Free tier: 20 calls/day, shared across the pipeline/capsule/skeleton family, resetting at midnight UTC. When spent, the daemon stops answering entirely for that family. With the Investigator as the only heavy caller (`run_pipeline`, `get_skeleton`), this is roughly a handful of investigations per day. `expand_vexp_ref` and `verify_done` were not stated to share this specific cap in the tier probe output above; their own consumption, if any, is `[inferred]` as separate/lighter based on their different function (reference expansion, mechanical verification) rather than measured directly.

## Git hooks installed

`vexp hooks check` output, verbatim:

```
  ✓ pre-commit
  ✓ post-merge
  ✓ post-checkout
```

Three hooks, not the one the original task brief described. Each is marked `# --- vexp start ---` / `vexp-hook-version: 3` inside `.git/hooks/<name>`. Each reindexes the repository and each is wrapped so it cannot fail the git operation it hooks (`|| true`); none of them runs `git add` or stages any file. Kept by explicit user decision. Removal path: `vexp hooks remove`.

## Install facts

- `vexp-cli@3.1.1` installed globally; binary resolves at `/home/enzief/.nvm/versions/node/v24.18.1/bin/vexp`; `vexp --version` prints `3.1.1`; on PATH.
- `.vexp/` index built in this repository (`index.db` ~5.8 MB), daemon healthy at the time of this record.
- `claude-me` profile (`/home/enzief/.claude.json`, 10 project entries) already carried `mcpServers.vexp = {"type":"stdio","command":"vexp","args":["mcp"],"env":{}}` before this task ran; backed up to `/home/enzief/.claude.json.bak-97u-20260906064828` (72614 bytes) prior to that registration, in an earlier interrupted run of this same task.
- `byse` profile (`/home/enzief/.claude-byse/.claude.json`, 4 project entries) had no `mcpServers` key before this task. Backed up to `/home/enzief/.claude-byse/.claude.json.bak-97u-20260906133015` (64147 bytes) before mutation. Registered via `CLAUDE_CONFIG_DIR=/home/enzief/.claude-byse /home/enzief/.local/bin/claude mcp add -s user vexp -- vexp mcp`, which added exactly one top-level key (`mcpServers`) and removed none; the 4 project entries and every other top-level key are unchanged, confirmed by a top-level-key diff against the backup.
- Both profiles now hold `mcpServers.vexp` with `command: "vexp"`, `args: ["mcp"]`, matching shape in both.

## Restore procedure

To undo everything this task and its predecessor did, in order:

1. Remove the MCP registration from each profile (does not require the backup): `CLAUDE_CONFIG_DIR=/home/enzief/.claude.json claude mcp remove -s user vexp` and `CLAUDE_CONFIG_DIR=/home/enzief/.claude-byse claude mcp remove -s user vexp` — or restore each config from its backup (next step), which is equivalent and also undoes any other change made in that run.
2. Restore each profile config from its timestamped backup:
   - `cp /home/enzief/.claude.json.bak-97u-20260906064828 /home/enzief/.claude.json`
   - `cp /home/enzief/.claude-byse/.claude.json.bak-97u-20260906133015 /home/enzief/.claude-byse/.claude.json`
3. Remove the vexp git hooks from this repository: `vexp hooks remove` (run from the repo root).
4. Delete the local index directory: `rm -rf /home/enzief/work/iswi/script/.vexp`.
5. Uninstall the global npm package: `npm uninstall -g vexp-cli` (adjust to whatever package manager/scope the original global install used).

## Spec fingerprint

sha256 of `/home/enzief/work/iswi/script/adhoc_platform_agent_workflow.txt`:

```
ca71c41cd017b8266c03c5eb2f8b21ccdf344dad354a7fbcd5d96b368edd1efe
```
