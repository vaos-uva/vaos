# K* — a POSIX `sh` symbolic self-rewrite kernel

This is a small, executable conceptual system for the requested hierarchy:

\[
\boxed{\mathrm{Lang}[\mathrm{lvl}:N]\text{ is the alphabet for }\mathrm{Lang}[\mathrm{lvl}:N+1]}
\]

It is intentionally written for POSIX `sh` and POSIX `awk`, not Bash. The
main program's shebang is `#!/bin/sh`; it uses no arrays, `[[ ... ]]`, `local`,
`source`, process substitution, `pipefail`, or `eval`.

## Model

Let `L_N = Lang[lvl:N]`. Each complete member of `L_N` is treated as a single,
atomic symbol one level up:

\[
\Sigma_{N+1} = L_N, \qquad L_{N+1} \subseteq \Sigma_{N+1}^{+}.
\]

At level `N`, an ordered rule set `R_N` rewrites words whose atoms are in
`L_N`. The kernel `K` is deterministic:

\[
K_{R_N}(w) =
\begin{cases}
\text{replace the leftmost match of the first applicable rule}, & \text{if a rule applies};\\
\bot, & \text{otherwise.}
\end{cases}
\]

`K*` is the finite orbit from a seed,

\[
K^*_{R_N}(w) = \{w, K(w), K^2(w), \ldots\},
\]

terminated only at normal form. The implementation detects cycles and refuses
to claim a completed next language when its fuel bound is exhausted. A lift is
therefore:

\[
\mathrm{Lang}[\mathrm{lvl}:N+1] =
\bigcup_{s\in S_N} K^*_{R_N}(s).
\]

Because the collected packed words become the lines of `Lang[lvl:N+1]`, those
lines are immediately the alphabet used to form `Lang[lvl:N+2]`.

## Safe symbolic representation

A word is a concatenation of frames:

```text
<byte-length>:<atom><byte-length>:<atom>...
```

For example, over a base language with atoms `K`, `:`, and `SELF`, the word
`K : SELF` is encoded as `1:K1::4:SELF`. The length framing matters: a complete
lower-level word can be embedded as one higher-level atom without needing an
escape character or a separator that will eventually collide at deeper levels.

A `.lang` file has one non-empty atom per line. A `.k` rule is
`packed-left<TAB>=><TAB>packed-right`. Tabs are reserved for that rule-file
meta-syntax and are not valid language symbols.

The system is **symbolically self-rewriting**, not a shell self-modifier:
rewritten terms are never executed as shell. There is no `eval`, `source`, or
code generation. That boundary keeps self-description and symbolic mutation
inspectable and prevents a term from silently acquiring host-shell authority.

## Run the built-in two-level example

```sh
cd /home/ubuntu/kstar-self-rewrite
sh ./kstar.sh demo ./example
cat ./example/README.md
```

The example starts with a level-1 symbolic self-description:

```text
K : SELF : RULES : v0 K : STATE : DRAFT
```

At level 0, its `K*` orbit changes the self-rule version to `v1` and drives the
state through `DRAFT → CHECK → EMIT → HALT`. The resulting closure becomes
`Lang[lvl:1]`. A level-2 word then treats the entire level-1 draft description
as **one atomic symbol** and rewrites it to the entire stable level-1
description, demonstrating the requested alphabet lift literally.

## Commands

```sh
# Build a word over Lang[lvl:N] from a list of its atom lines.
sh ./kstar.sh pack Lang-lvl-N.lang atom-lines.txt > seed.word

# Verify word framing and that its atoms belong to that language.
sh ./kstar.sh check Lang-lvl-N.lang seed.word

# One K application; output indicates rewrite vs. normal form.
sh ./kstar.sh step Lang-lvl-N.lang Rules-lvl-N.k seed.word

# Trace K* with cycle detection and a maximum rewrite count.
sh ./kstar.sh close Lang-lvl-N.lang Rules-lvl-N.k seeds.words 32

# Create Lang[lvl:N+1] from the full K* closure of the seeds.
sh ./kstar.sh evolve Lang-lvl-N.lang Rules-lvl-N.k seeds.words Lang-lvl-N-plus-1.lang 32

# Reveal one nesting layer of any packed word.
sh ./kstar.sh unpack seed.word
```

Rules are ordered, so this prototype has an explicit operational semantics;
rule order and leftmost position resolve otherwise ambiguous overlap. For a
nondeterministic version, replace `step` with a frontier-expanding `K` and
retain every successor in the closure. For a true fixed-point system, treat a
cycle as an object-level result rather than rejecting it during language
materialization.
