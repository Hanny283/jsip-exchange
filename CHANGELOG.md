## v1.0.1 — incident fix

The incident was triggered by a commit that swapped the comparison operators in the matching logic. While the auto-revert restored the correct operator positions, the original code still harbored a latent bug: it used strict inequality (>, <) instead of inclusive inequality (>=, <=), which silently rejected orders at exactly the resting price. This fix corrects the matching semantics to properly handle orders at the touch.

_Fix applied: applied the diagnosed one-edit fix to `lib/types/src/price.ml`._

