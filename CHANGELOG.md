## v1.0.1 — incident fix

The auto-revert restored the operator directions but left them strict (> and <) when they must be inclusive (>= and <=). Orders exactly at the resting price MUST match—a buy at the ask touch and a sell at the bid touch are both marketable and this fix restores that.

_Fix applied: applied the diagnosed one-edit fix to `lib/types/src/price.ml`._

