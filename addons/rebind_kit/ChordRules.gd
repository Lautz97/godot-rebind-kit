## ChordRules: when two inputs can't live together among the commands active at the same time. A key that opens a
## combination is only a prefix: it can't be a command of its own, nor can a shorter combination stop where a longer one
## goes on (with Q+E+R there can't be Q+E). The order of the keys counts: E+Q doesn't open Q+E+R.
class_name ChordRules
extends RefCounted

## true if `a` and `b` can't sit on two commands active together: the same input, or one is where the other starts.
static func clashes(a: InputKey, b: InputKey) -> bool:
	if a == null or b == null:
		return false
	var short := a.sequence()
	var long := b.sequence()
	if short.size() > long.size():
		var swap := short
		short = long
		long = swap
	return starts_with(long, short)

## true if `whole` begins with every key of `start`, in order.
static func starts_with(whole: Array[InputKey], start: Array[InputKey]) -> bool:
	if start.size() > whole.size():
		return false
	for i in start.size():
		if not start[i].equals(whole[i]):
			return false
	return true
