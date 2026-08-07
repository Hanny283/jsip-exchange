## v1.0.6 — incident fix

The auto-revert restored the correct operator order (buy >, sell <), but the matching semantics require >= and <= to allow orders at the exact resting price to match; this fix allows orders at the touch to execute instead of silently rejecting them.

_Fix applied: applied the diagnosed one-edit fix to `lib/types/src/price.ml`._

## v1.0.5 — incident fix

The incident was triggered by a commit that swapped the buy/sell comparison operators, which auto-reverted correctly. However, the reverted code contains a latent bug: it uses strict inequalities (> and <) instead of allowing equality, which silently drops orders sitting exactly at the resting price. This fix adds equality to both comparisons to match correct exchange matching semantics.

_Fix applied: applied the diagnosed one-edit fix to `lib/types/src/price.ml`._

## v1.0.4 — incident fix

The bad commit inverted the comparison operators, breaking matching entirely. The revert restored the original code, but the original already had a latent bug: it used strict comparisons (> and <) instead of inclusive (>= and <=), silently dropping orders that sit exactly at the resting price. This fix uses inclusive comparisons to match the correct semantics.

_Fix applied: applied the diagnosed one-edit fix to `lib/types/src/price.ml`._

## v1.0.3 — incident fix

The revert restored the original code, but the original was also buggy—it uses strict inequality operators, silently dropping orders at the exact resting price, which must match per spec. The fix adds equality checks: buy orders match when price >= resting ask, sell orders when price <= resting bid.

_Fix applied: applied the diagnosed one-edit fix to `lib/types/src/price.ml`._

## v1.0.2 — incident fix

The auto-revert restored the correct operator order but left the strict comparisons intact. Matching semantics require that a buy order is marketable when price >= resting ask and a sell order when price <= resting bid; using strict > and < silently drops orders sitting exactly at the touch price, breaking the fill guarantee.

_Fix applied: applied the diagnosed one-edit fix to `lib/types/src/price.ml`._

## v1.0.1 — incident fix

The auto-revert restored the operator directions but left them strict (> and <) when they must be inclusive (>= and <=). Orders exactly at the resting price MUST match—a buy at the ask touch and a sell at the bid touch are both marketable and this fix restores that.

_Fix applied: applied the diagnosed one-edit fix to `lib/types/src/price.ml`._

