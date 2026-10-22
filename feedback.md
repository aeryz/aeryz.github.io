# Review — "Switching between tasks"

Editorial read of `_posts/2026-09-27-trap-frames-and-ctx-switches.md`.
Structure, flow and pedagogy only — grammar, TODOs and markdown mechanics
deliberately ignored.

## What's working

The question-chain is the best thing in here. "How's the OS running when a user
task runs?" → "It's not." → "Then what stops the user task from doing anything it
wants?" That's three lines that do more teaching than three paragraphs would, and
the move repeats well: "Hold on hold on!!! We saved the registers and now we are
loading them back in, so how do we actually switch to some other user task?" lands
exactly where a reader's confusion peaks. Keep doing that.

The opening hook is concrete — download, music, video — and earns the abstraction
that follows. Real code from a real kernel at pinned commits gives it weight that a
synthesized example never has. The voice ("Heyyo, I'm blocked", "hurrayy") is
consistent with the older posts and it works.

## The big one: the central question is posed and never answered

Line 312:

> We already saved the trap frame previously and now saving the same stuff again
> but as `Context` this time????

That is *the* question of the post. What follows is a scenario showing **when** a
context switch happens — Task A blocks on `read` — but never states **why the two
structures are different things**. The reader finishes still not knowing.

The answer is already sitting in the pasted code, unremarked:

- `TrapFrame` — 34 fields. Every GP register plus `sepc` / `scause` / `sstatus`.
- `Context` — 14 registers. `ra`, `sp`, `s0`–`s11`. That's it.

Why the asymmetry? A trap is **asynchronous** — it can land between any two
instructions, so every register is potentially live and all of it must be
preserved. A context switch is a **function call** — `swtch` is entered through the
normal ABI, so the caller-saved registers (`t*`, `a*`) are already dead by contract
and the compiler has spilled anything it cared about. Only callee-saved state is
needed.

Trap frame = the *user task's* state. Context = the *kernel thread's* state. Each
task has both, and they're saved by completely different mechanisms at completely
different moments. Say that out loud — one short paragraph, pointing at the 34-vs-14
that the reader can count for themselves. Right now the strongest teaching moment in
the post is invisible.

## Ordering in the context switch section

The section opens with "it might be the easiest part", then drops 37 lines of
register spills, *then* asks the interesting question. Flip it: ask the question
first, so the code reads as the answer instead of as a wall to get through.

That block is also the only place without elision. It's handled well everywhere
else — `sd gp, {TF_GP}(sp)` / `# .. saving all the registers` / `sd t6, {TF_T6}(sp)`.
Do the same here; `s0` through `s11` twice is 24 lines of visual noise carrying one
bit of information.

## What the final diagram has to do

Two diagrams so far and both stop early. Diagram 1 ends at "save Task A registers
into its trap frame". Diagram 2 ends at "call read syscall handler" — right before
the part the section is actually about. Neither shows a return path, and nothing
anywhere shows a *complete* cycle.

So the third one carries the whole post. It needs to close the loop end to end:

Task A in U-mode → timer → trap entry → trap frame saved → handler → scheduler
picks B → `swtch` (A's Context out, B's Context in) → and then the bit that makes
people's heads hurt: execution **resumes inside B's old `swtch` call**, unwinds back
through B's trap handler, `trap_resume` reloads B's trap frame, `sret`, B is in
U-mode.

Show both halves — the trap frame path and the context path — as visibly different
mechanisms and it'll do the work the prose currently doesn't.

Related: the genuinely strange property is never named — you call a function and it
returns *in a different task*, and much later it "returns" back into you. That's the
mind-bender of context switching and it deserves the "Hold on hold on!!!" treatment
everything else gets.

## Smaller reader-experience notes

- **Audience drifts.** Opens at "your phone is doing many things at once"; by the
  middle it's `csrrw tp, sscratch, tp` with no word on what `csrrw` does or what
  `tp` / `ra` / `sp` mean in the RISC-V ABI. Collapsible notes are now available —
  this is the ideal use: a "RISC-V register naming, if you need it" `<details>` that
  experienced readers skip.
- **The `sscratch` trick is undersold.** The setup is perfect ("where do we save the
  trap frame if all the registers belong to the interrupted task?") and then the
  answer arrives flat. The elegance is that `csrrw` *swaps atomically* — it solves
  the chicken-and-egg of needing a free register in order to free up registers,
  without clobbering a single user register. Worth a sentence.
- **"I finally can mention the `time-sharing`"** reads as a first mention, but it
  was introduced back at the timer paragraph. Make it an explicit callback or drop
  the "finally".
- **No conclusion.** It ends on a link to OSTEP. There are forward-references to
  paging and COW scattered around; gather them into a short closing that recaps the
  three mechanisms (privilege levels, traps/trap frames, context switches) and says
  what's next. Ending on an external link makes a finished post feel abandoned.
- **Title.** "Switching between tasks" undersells it — the post is the whole
  trap → schedule → switch pipeline. The filename is closer to the truth.
- Readers *will* pause at the privilege table showing 0, 1, 3. One parenthetical
  about level 2 kills the distraction.

## One judgment call

The LLM note is the second thing on the page, styled as a warning, before any
content. It's a statement about the author, not about tasks and traps, and it
interrupts a hook that was just built well. Move it to the end or to the about page.
The point stands on its own — it just doesn't need to be the first thing between the
reader and the subject they came for.
