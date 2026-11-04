extends RefCounted
class_name GameNetworkCadence

# Fixed-step sums can be just below an exact period (12 * 1/60 < .2).
# Consume all overdue slots while sending only once; retain the fractional
# remainder so a slow frame cannot permanently lower the nominal frequency.
const EPSILON := .000001

static func due(elapsed: float, period: float) -> bool:
	return period>0. and elapsed+EPSILON>=period

static func consume(elapsed: float, period: float) -> float:
	if period<=0.: return 0.
	return maxf(0.,elapsed-floor((elapsed+EPSILON)/period)*period)
