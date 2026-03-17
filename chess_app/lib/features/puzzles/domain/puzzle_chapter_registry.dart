/// Static definition of a single puzzle chapter (id, display data, theme tags).
class ChapterDefinition {
  final String id;
  final String name;
  final String icon;
  final List<String> themeTags; // Lichess tag strings that belong to this chapter
  final String statusVerb;     // Short verb shown in the puzzle play status bar, e.g. 'Find the fork'

  const ChapterDefinition({
    required this.id,
    required this.name,
    required this.icon,
    required this.themeTags,
    required this.statusVerb,
  });
}

/// The 9 themed chapters in display order.
const List<ChapterDefinition> kChapterDefinitions = [
  ChapterDefinition(
    id: 'checkmate_in_1',
    name: 'Checkmate in 1',
    icon: '♟',
    themeTags: ['mateIn1'],
    statusVerb: 'Deliver checkmate',
  ),
  ChapterDefinition(
    id: 'forks',
    name: 'Forks',
    icon: '⚔',
    themeTags: ['fork'],
    statusVerb: 'Find the fork',
  ),
  ChapterDefinition(
    id: 'pins_and_skewers',
    name: 'Pins & Skewers',
    icon: '📌',
    themeTags: ['pin', 'skewer'],
    statusVerb: 'Find the pin or skewer',
  ),
  ChapterDefinition(
    id: 'discovered_attacks',
    name: 'Discovered Attacks',
    icon: '💥',
    themeTags: ['discoveredAttack'],
    statusVerb: 'Find the discovered attack',
  ),
  ChapterDefinition(
    id: 'sacrifices',
    name: 'Sacrifices',
    icon: '🎯',
    themeTags: ['sacrifice'],
    statusVerb: 'Find the sacrifice',
  ),
  ChapterDefinition(
    id: 'back_rank_mates',
    name: 'Back Rank Mates',
    icon: '🏰',
    themeTags: ['backRankMate'],
    statusVerb: 'Find the back rank mate',
  ),
  ChapterDefinition(
    id: 'endgames',
    name: 'Endgames',
    icon: '♛',
    themeTags: ['endgame'],
    statusVerb: 'Find the best move',
  ),
  ChapterDefinition(
    id: 'checkmate_in_2_plus',
    name: 'Checkmate in 2+',
    icon: '♟♟',
    themeTags: ['mateIn2', 'mateIn3'],
    statusVerb: 'Find the mating sequence',
  ),
  ChapterDefinition(
    id: 'advanced_tactics',
    name: 'Advanced Tactics',
    icon: '⚡',
    themeTags: ['attraction', 'deflection', 'clearance', 'interference', 'zugzwang', 'quietMove'],
    statusVerb: 'Find the winning tactic',
  ),
];

/// Maps a Lichess theme tag to the chapter ID it belongs to.
/// A puzzle is assigned to the chapter whose tag appears first in this map.
const Map<String, String> kTagToChapterId = {
  'mateIn1': 'checkmate_in_1',
  'fork': 'forks',
  'pin': 'pins_and_skewers',
  'skewer': 'pins_and_skewers',
  'discoveredAttack': 'discovered_attacks',
  'sacrifice': 'sacrifices',
  'backRankMate': 'back_rank_mates',
  'endgame': 'endgames',
  'mateIn2': 'checkmate_in_2_plus',
  'mateIn3': 'checkmate_in_2_plus',
  'attraction': 'advanced_tactics',
  'deflection': 'advanced_tactics',
  'clearance': 'advanced_tactics',
  'interference': 'advanced_tactics',
  'zugzwang': 'advanced_tactics',
  'quietMove': 'advanced_tactics',
};
