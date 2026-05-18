/// Opção de avatar local (SVG em [assetPath]).
class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.label,
    required this.assetPath,
  });

  final String id;
  final String label;
  final String assetPath;

  static AvatarOption? byId(String? id) {
    if (id == null) return null;
    for (final o in all) {
      if (o.id == id) return o;
    }
    return null;
  }

  static const List<AvatarOption> all = [
    AvatarOption(
      id: 'bat',
      label: 'Morcego',
      assetPath: 'assets/avatars/bat.svg',
    ),
    AvatarOption(
      id: 'bear',
      label: 'Urso',
      assetPath: 'assets/avatars/bear.svg',
    ),
    AvatarOption(
      id: 'bee',
      label: 'Abelha',
      assetPath: 'assets/avatars/bee.svg',
    ),
    AvatarOption(
      id: 'bird',
      label: 'Pássaro',
      assetPath: 'assets/avatars/bird.svg',
    ),
    AvatarOption(
      id: 'bunny',
      label: 'Coelho',
      assetPath: 'assets/avatars/bunny.svg',
    ),
    AvatarOption(
      id: 'cat',
      label: 'Gato',
      assetPath: 'assets/avatars/cat.svg',
    ),
    AvatarOption(
      id: 'chicken',
      label: 'Galinha',
      assetPath: 'assets/avatars/chicken.svg',
    ),
    AvatarOption(
      id: 'cow',
      label: 'Vaca',
      assetPath: 'assets/avatars/cow.svg',
    ),
    AvatarOption(
      id: 'crocodile',
      label: 'Jacaré',
      assetPath: 'assets/avatars/crocodile.svg',
    ),
    AvatarOption(
      id: 'deer',
      label: 'Cervo',
      assetPath: 'assets/avatars/deer.svg',
    ),
  ];
}
