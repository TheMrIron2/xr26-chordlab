class_name ChordValidator
extends RefCounted

enum Quality { MAJOR, MINOR }

const INTERVALS := {
	Quality.MAJOR: [0, 4, 7],
	Quality.MINOR: [0, 3, 7],
}


## Match an exact triad in any order or inversion. Octave doublings count as extra notes.
static func matches(notes: Array[int], root_midi: int, quality: Quality) -> bool:
	if notes.size() != 3 or root_midi < 0 or root_midi > 127 or not INTERVALS.has(quality):
		return false
	var intervals: Array[int] = []
	for note in notes:
		if note < 0 or note > 127:
			return false
		intervals.append(posmod(note - root_midi, 12))
	intervals.sort()
	return intervals == INTERVALS[quality]
