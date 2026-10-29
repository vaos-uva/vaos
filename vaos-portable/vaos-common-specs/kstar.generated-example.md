# K* generated example

`Lang[lvl:0]` is the raw symbol inventory. `Rules-lvl-0.k` transforms a
level-1 word that says `K : SELF : RULES : v0 K : STATE : DRAFT` into a stable
self-description at `v1` with state `HALT`.

`Lang[lvl:1]` is the entire K* orbit, one packed word per line. Therefore each
of its complete lines is an atomic alphabet symbol for level 2. The level-2
rule changes the first level-1 description atom into the final stable
level-1 description atom. This is the hierarchy in executable form:

    Lang[lvl:N]  = alphabet for Lang[lvl:N+1]

The `.word` and `.k` files are framed machine notation. Use `unpack` to view
one structural layer; repeated `unpack` peels nested levels.

## Level-1 trace

```text
seed=1	step=0	status=seed	word=1:K1::4:SELF1::5:RULES1::2:v01:K1::5:STATE1::5:DRAFT
seed=1	step=1	status=rewrite	word=1:K1::4:SELF1::5:RULES1::2:v11:K1::5:STATE1::5:DRAFT
seed=1	step=2	status=rewrite	word=1:K1::4:SELF1::5:RULES1::2:v11:K1::5:STATE1::5:CHECK
seed=1	step=3	status=rewrite	word=1:K1::4:SELF1::5:RULES1::2:v11:K1::5:STATE1::4:EMIT
seed=1	step=4	status=rewrite	word=1:K1::4:SELF1::5:RULES1::2:v11:K1::5:STATE1::4:HALT
seed=1	step=4	status=normal	word=1:K1::4:SELF1::5:RULES1::2:v11:K1::5:STATE1::4:HALT
```

## Seed, unpacked at level 1

```text
word 1:
  1. K
  2. :
  3. SELF
  4. :
  5. RULES
  6. :
  7. v0
  8. K
  9. :
  10. STATE
  11. :
  12. DRAFT
```

## Seed, unpacked at level 2

```text
word 1:
  1. 1:K1::4:SELF1::5:RULES1::2:v01:K1::5:STATE1::5:DRAFT
```
