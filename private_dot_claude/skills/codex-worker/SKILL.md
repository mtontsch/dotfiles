---
name: codex-worker
description: Delegate scoped repository implementation, refactors, bug fixes, tests, CI/tooling, dependency work, and read-heavy exploration from Claude Code to Codex CLI. Picks a delegation mode (D0–D3 dial) and reasoning effort automatically from spec state and failure cost; Claude retains design decisions, session-tool work, destructive or external mutations, and final review. Includes hardened work-order rules for scientific/numerical code.
---

# Codex Worker

Use this skill only from Claude Code. In Codex or another harness, skip it and never self-delegate.

## Why this split (evidence snapshot, Aug 2026 — re-verify when models change)

- GPT-5.6 Sol (max) sits within ~1 point of Fable 5 on the Artificial Analysis Intelligence Index at roughly one third of the cost per task, and this account's Codex limits make it effectively free — so anything Sol can do reliably should not burn Fable tokens.
- The models diverge most on **planning and hard-repo reliability**, not execution: given a frozen, detailed spec, Sol executes at parity (and leads terminal/tool-use benchmarks such as Terminal-Bench ~89–92%), while Fable leads where failure is expensive (SWE-bench Pro 80% vs 64.6%; FrontierCode Diamond; completes hard agentic suites Sol drops tasks on).
- Graduate-level science Q&A (GPQA-class) is saturated across the frontier — both models "know the science." For scientific code the differentiator is **verification and problem framing**, which stay in Claude.

Consequence: Claude designs, decomposes, and reviews; Codex implements against frozen specs. The community pattern this follows reports ~60% orchestrator-token savings with no quality loss — provided the anti-patterns below are respected.

## Choose the delegation mode (the dial)

Classify every candidate task by two questions:

1. **Spec state** — can the work order be written without making design decisions? If writing the prompt forces architecture, naming, API, or metric choices, the spec is open: that is design, keep it in Claude until frozen.
2. **Failure cost** — if Codex gets it subtly wrong, does verification catch it cheaply (tests, diff read, invariant check), or is wrongness silent and expensive (numerical semantics, statistics, irreversible effects)?

| Mode | Use for | Codex effort | Claude verification |
|------|---------|-------------|---------------------|
| **D0 — keep in Claude** | open specs; tiny edits where delegation overhead exceeds the work (rename, null check, one-liner); session-only tools, secrets, releases, pushes, external mutations; destructive/irreversible operations; anything already through two failed correction rounds | — | — |
| **D1 — Codex drafts, Claude reviews closely** | frozen spec but silent-failure risk: numerical kernels, metric/loss semantics, CRS/geometry/units logic, resampling, statistics | `high` (worst case `xhigh`) | line-by-line diff read plus oracle/invariant tests (see scientific section) |
| **D2 — standard delegation (default)** | frozen spec with a testable outcome: features, refactors, bug fixes, tests, CI, dependencies, tooling | `medium`–`high` | run focused tests independently, read the complete diff |
| **D3 — bulk delegation** | mechanical sweeps with a clear pattern, migrations, read-only exploration, data analysis where reading dominates judgment | `medium` | spot-check a sample; sanity-check totals/coverage |

Dial override: the user can pin the dial for a session — `dial 0` (delegate nothing) to `dial 3` (delegate aggressively, batch even small edits into work orders). Default posture is D2. On borderline calls, prefer delegating: Codex tokens are cheap, and a weak result costs one review round, not the budget. The one exception is D1-shaped risk — when wrongness would be silent, never resolve a borderline call downward to D2/D3 verification.

For mixed tasks, decide and freeze the design in Claude before delegating implementation.

## Pick the reasoning effort

Pin effort explicitly per run (`-c model_reasoning_effort=...`); never rely on the config default, and never downgrade the model itself.

- `medium` — mechanical, clear-spec implementation, migrations, read-only exploration and data analysis. The default for D3 and simple D2.
- `high` — ordinary implementation with design judgment, nontrivial tests, tracing complex behavior, weighing competing solutions. The default for hard D2 and for D1.
- `xhigh` — only hard debugging, subtle correctness work, or design-sensitive/system-wide changes where every constraint must stay in one reasoning chain.

Calibration, from field reports: select the lowest tier that completes the work reliably, then escalate one tier on a weak result. Overshooting is not merely slow — it produces excessive planning, repository-wide scans, and unsolicited architectural changes, and `xhigh` can regress against `high` on ordinary tasks. Undershooting shows up as symptom-level fixes and missed constraints; treat that as the signal to escalate, not to take over. When in doubt between two tiers, take the lower one first.

## Scientific and numerical work orders

Scientific code fails silently: a wrong sign, unit, CRS, or axis order passes every smoke test and poisons results downstream. Both models are past saturation on science knowledge, so do not delegate the *framing* — delegate the *implementation* and make the work order carry the verification:

- State expected numerical behavior explicitly: tolerances, invariants (CRS/units/axis order, conservation, monotonicity, symmetry, shape/dtype), and boundary cases.
- Require a deterministic repro: fixed seeds, pinned inputs, and the exact command whose output constitutes evidence.
- Provide an oracle where one exists: a closed-form case, a reference implementation, or a round-trip property (e.g. vectorize→rasterize, reproject→inverse). "Tests pass" is insufficient evidence for D1 work — the oracle result is the evidence.
- Never delegate: metric/estimator definitions, experimental design, train/eval split policy, statistical interpretation, benchmark methodology. Plausible-but-wrong survives ordinary review too easily there.
- Repository invariants (class-id derivation rules, module boundaries such as vector-GT-blindness) go into the work order verbatim, with the test that enforces them named as a required verification command.

## Establish the workspace

Resolve the exact repository or worktree path before invoking Codex. Read its `CLAUDE.md` and task plan, then capture `git status -sb`, the branch, and `git rev-parse HEAD`.

For parallel work:

- assign one branch, one worktree, and one result file per worker
- record the designated base SHA and any stacked-branch dependency; never infer the base from the current checkout
- compare planned touched files with active branches and serialize or assign ownership for overlaps
- tell Codex to work only in the assigned worktree and never modify the main checkout or sibling worktrees
- let the parent orchestrator create branches and worktrees; Codex must not create, switch, rebase, or delete them

## Write the work order

Codex starts without Claude's session context. Include:

1. Goal and exact repository/worktree path.
2. Relevant files, repository rules, and the applicable plan.
3. Decisions already made and behavior that must remain unchanged.
4. Scope, constraints, and explicit non-goals.
5. Exact verification commands and expected evidence (for D1: the oracle/invariant checks above).
6. Output request: changed files, tests and results, caveats, and remaining work.
7. Git rule: leave changes unstaged; never commit, push, rebase, switch branches, or perform GitHub mutations.
8. Safety rule: for any write-enabled (`--profile worker-write`) order, forbid destructive and out-of-scope commands per **Guard the sandbox** below, and require Codex to stop and report a blocker rather than run one.

For investigation, review, or data analysis, also state that no files may be modified.

## Guard the sandbox

`--profile worker-write` (defined in `~/.codex/config.toml`: `sandbox_mode = "danger-full-access"`, `approval_policy = "never"`) and its `--dangerously-bypass-approvals-and-sandbox` resume run every command with no sandbox and no approval prompt, so the work order is the only guardrail. Every write-enabled order must forbid destructive and out-of-scope commands and require Codex to stop and report a blocker instead of running one it believes is needed. Prohibited:

- Recursive or forced deletion — `rm -rf`, `rm -r`, `find … -delete`, `xargs rm`. Delete only an exact file the run created; never a directory or a glob.
- Discarding uncommitted work — `git reset --hard`, `git checkout -- .` / `git restore .`, `git clean -f*`, `git stash drop`/`clear` (history mutation is already barred by the Git rule).
- Killing or resetting processes the run did not start — `kill`, `pkill`, `killall`, `nvidia-smi --gpu-reset`; concurrent training runs and sibling workers share this host.
- Disk, mount, or device operations and privilege escalation — `dd`, `mkfs`, `mount`, writes under `/dev`, `sudo`, `chmod -R`/`chown -R` on broad paths.
- System- or environment-wide changes — `apt`, host-level `pip install`, deleting or recreating a shared virtualenv.
- Any write, delete, or overwrite outside the assigned worktree — especially append-only run-artifact stores (e.g. `/mnt/data/hegemon`) and sibling `.worktrees/` checkouts.
- Fetching and executing remote content (`curl … | sh`) or other network side effects beyond installing declared dependencies.

Read-only runs (`--profile worker-ro`) already block filesystem writes, so this list is the guardrail specifically for write-enabled runs.

## Invoke Codex

Write prompts to a temporary file rather than inline shell quoting. Give every concurrent worker a distinct result file; keep result files in a dated directory so runs stay attributable after the session ends.

Implementation in an externally sandboxed workspace:

```bash
RESULT_DIR="/tmp/codex-worker/$(date +%F)"; mkdir -p "$RESULT_DIR"
PROMPT=$(mktemp)
RESULT=$(mktemp "$RESULT_DIR/XXXXXX.md")
cat >"$PROMPT" <<'EOF'
<self-contained work order>
EOF
command codex exec --profile worker-write -C <exact-worktree> \
  -c model_reasoning_effort="<effort per mode/tier rules above>" \
  -o "$RESULT" - <"$PROMPT" 2>/dev/null
```

Investigation, review, or data analysis:

```bash
RESULT_DIR="/tmp/codex-worker/$(date +%F)"; mkdir -p "$RESULT_DIR"
PROMPT=$(mktemp)
RESULT=$(mktemp "$RESULT_DIR/XXXXXX.md")
cat >"$PROMPT" <<'EOF'
<self-contained read-only work order>
EOF
command codex exec --profile worker-ro -C <exact-worktree> \
  -c model_reasoning_effort="<effort per mode/tier rules above>" \
  -o "$RESULT" - <"$PROMPT" 2>/dev/null
```

- The model comes from `~/.codex/config.toml` (currently `gpt-5.6-sol`); never pass a `-m` downgrade.
- The sandbox comes from the `worker-write` / `worker-ro` profiles in `~/.codex/config.toml`; profile values override the config's fail-safe root defaults (`workspace-write`). Always pass one of the two profiles explicitly — never rely on the root default, and never substitute raw `--yolo` / `-s` flags, which bypass the profile convention.
- Use `command codex` to bypass an interactive shell wrapper. If it is absent from `PATH`, use `fnm exec --using default -- codex`.
- Use `--profile worker-write` only where repository policy confirms the surrounding container is the sandbox; otherwise use the repository's authorized workspace-write mode (the config root default, no profile flag). Because `worker-write` suppresses approval prompts, the work order must carry the **Guard the sandbox** prohibitions.
- Add `--skip-git-repo-check` only outside a Git repository.
- Read the result file after exit; do not parse the JSONL event stream.
- For long runs, use Claude's background execution, retain the exact worktree/result mapping, and do not kill a quiet run before 30 minutes without evidence that it is stuck.
- Expose stderr only while diagnosing a failed invocation.

## Iterate

Prefer resuming the same Codex session for corrections. `codex exec resume` has no `--profile` flag, so reproduce the original run's profile via explicit overrides — resume with the **same sandbox mode as the original run** and never escalate on resume:

- run started under `--profile worker-write` → resume with `--dangerously-bypass-approvals-and-sandbox` (equivalent to that profile)
- run started under `--profile worker-ro` → resume with `-c sandbox_mode="read-only"`

Run from the same worktree so `--last` remains cwd-filtered. Keep to one Codex session per worktree; if a worktree has ever hosted more than one session, do not use `--last` — capture the session id from the original run's output and resume it explicitly with `codex exec resume <session-id>`.

```bash
# implementation run (started under --profile worker-write)
(cd <exact-worktree> && command codex exec resume --last \
  --dangerously-bypass-approvals-and-sandbox \
  -o "$RESULT" - <"$FOLLOWUP_PROMPT" 2>/dev/null)

# investigation run (started under --profile worker-ro)
(cd <exact-worktree> && command codex exec resume --last \
  -c sandbox_mode="read-only" \
  -o "$RESULT" - <"$FOLLOWUP_PROMPT" 2>/dev/null)
```

A weak-but-honest result gets one effort escalation (see tier rule) before a correction round counts as failed. After two unsuccessful correction rounds, stop delegating and take over in Claude — the task has revealed itself as D0.

## Verify and hand off

Claude always owns acceptance; verification depth follows the mode (D1: close diff read + oracle evidence; D2: tests + full diff; D3: sampled spot-checks):

1. Run `git status -sb` in the assigned worktree and read the complete diff (D1/D2) or a representative sample (D3).
2. Check scope, repository invariants, and overlap with other active branches.
3. Run focused tests independently; treat Codex's claims as advisory. For D1, rerun the oracle/invariant commands yourself — the work order's evidence, not the summary, is what counts.
4. Confirm changes remain unstaged and no unauthorized Git or external mutation occurred.
5. Report the base SHA, HEAD, status, changed files, tests, dependencies, known overlaps, and caveats.
6. Complete the repository's normal review and closeout process.
