class_name LessonData
extends RefCounted

const MAJOR := ChordValidator.Quality.MAJOR
const MINOR := ChordValidator.Quality.MINOR

const STAGES := [
	{
		"title": "Build a triad",
		"intro": "The root gives a chord its name.\nThe third gives it a major or minor sound.\nThe fifth is the top note in this shape.",
		"practice": "Build C major using the three gold keys.\nEach step to the next key is one semitone,\nincluding the black keys.",
		"guide": [60, 64, 67],
		"demo": [
			{"notes": [60], "caption": "C is the root", "seconds": 0.85},
			{"notes": [64], "caption": "E is the third", "seconds": 0.85},
			{"notes": [67], "caption": "G is the fifth", "seconds": 0.85},
			{"notes": [60, 64, 67], "caption": "Together they make C major", "seconds": 1.55},
		],
		"exercises": [{"name": "C major", "root": 60, "quality": MAJOR}],
	},
	{
		"title": "Major and minor",
		"intro": "Start with C, E and G.\nMove E one key left to E♭.\nListen for what changes.",
		"practice": "Build C minor. Keep the root and fifth.\nFrom the root, a major third is 4 steps up.\nA minor third is 3. The fifth is always 7.",
		"demo": [
			{"notes": [60, 64, 67], "caption": "C major  ·  C  E  G", "seconds": 1.55},
			{"notes": [64], "caption": "E is 4 semitones above C", "seconds": 0.85},
			{"notes": [63], "caption": "E♭ is 3 semitones above C", "seconds": 0.85},
			{"notes": [60, 63, 67], "caption": "C minor  ·  C  E♭  G", "seconds": 1.55},
		],
		"exercises": [{"name": "C minor", "root": 60, "quality": MINOR}],
	},
	{
		"title": "On your own",
		"practice": "Start on %s. Count up from the root.\nBuild %s, then check your answer.",
		"exercises": [
			{"name": "F major", "root": 65, "quality": MAJOR},
			{"name": "G major", "root": 67, "quality": MAJOR},
			{"name": "D minor", "root": 62, "quality": MINOR},
		],
		"record_results": true,
	},
]
