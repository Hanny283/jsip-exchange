## v1.0.2 — incident fix

The auto-revert restored the correct operator order but left the strict comparisons intact. Matching semantics require that a buy order is marketable when price >= resting ask and a sell order when price <= resting bid; using strict > and < silently drops orders sitting exactly at the touch price, breaking the fill guarantee.

_Fix applied: applied the diagnosed one-edit fix to `lib/types/src/price.ml`._

## v1.0.1 — incident fix

The auto-revert restored the operator directions but left them strict (> and <) when they must be inclusive (>= and <=). Orders exactly at the resting price MUST match—a buy at the ask touch and a sell at the bid touch are both marketable and this fix restores that.

_Fix applied: applied the diagnosed one-edit fix to `lib/types/src/price.ml`._

