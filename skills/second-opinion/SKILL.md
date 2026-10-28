---
name: second-opinion
description: Get a review from a model by another developer (OpenAI's Codex CLI, signed in with the user's ChatGPT account), then check each of its findings and report them with a verdict. Two modes, matching research.md's Review stages - fresh (a reader without context checks clarity and states the idea) and adversarial (holes, steps, quantifiers, hypotheses of cited results). Use when the user asks for a second opinion, a ChatGPT or Codex review, or an outside referee.
argument-hint: "fresh|adversarial <file> [focus or intended reader]"
---

# Second opinion

Written by Claude (AI), for @magerton.

Arguments: $ARGUMENTS

1. **Check before sending.** Codex sends what it reads to OpenAI. If the file is in a shared repo (its `AGENTS.md` lists a team) or a coauthor wrote it, ask the user first. If the mode or file is missing, ask.

2. **Run Codex** read-only, at high effort, from the repo root, with the prompt on stdin. Use `codex` if it is on PATH, else the copy in the ChatGPT app. Run it in the background (a review takes several minutes) and wait for the notification:
   ```
   C="$(command -v codex || echo /Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex)"
   out="$(mktemp -d)/codex-review.md"; echo "$out"
   "$C" exec -s read-only --ephemeral -c model_reasoning_effort='"high"' \
     -C "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" --skip-git-repo-check \
     -o "$out" - <<'EOF'
   <prompt>
   EOF
   ```
   Write the prompt from the mode below. Name the file, the intended reader (a coauthor, a referee, the user), and any focus the user gave. Give no conclusions of this session and no guess about what is wrong. Codex also reads the repo's `AGENTS.md`, so it is not a blank reader.
   - **fresh**: "Read only `<file>` and the files it links. You know nothing else about this project. (1) State the document's idea in at most five sentences. (2) List each term or symbol used before it is defined, or unsuited to the reader. (3) List each place where the argument skips a step or the reader loses the thread. (4) Say what the reader would do or decide after reading it, and whether the document supports that. Quote the passage for each finding. Do not edit files."
   - **adversarial**: "Referee `<file>` as a hostile, competent reader. Look for holes. Check each step and its quantifiers, each number against its source in the repo, and that the hypotheses of each cited result hold. For each finding give the location, a quote, what is wrong, and whether it sinks a result, narrows it, or is minor. Say what you did not check. Do not edit files."

3. **Check each finding** against the source before reporting it (read the line, re-derive the step, open the cited result). Outside reviewers sometimes invent problems. Give each one a verdict: right, wrong (and why), or unchecked.

4. **Report**:
   - Codex's statement of the idea (fresh mode), and whether it matches the intended one.
   - The findings, most serious first, one line each with location, Codex's claim and your verdict. A finding that sinks a result goes first. A finding that narrows a result comes with a proposed fix.
   - Findings you would have missed, marked as such. These measure whether the second opinion earns its cost.
   - The path of Codex's raw output.

   Do not edit the file unless the user asks. In a repo with a `STATUS.md`, save the raw output beside the reviewed file if a finding changes the work, and log a FINDING that links it.
