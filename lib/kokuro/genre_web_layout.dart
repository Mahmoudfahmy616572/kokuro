/// Fixed layout (x, y) positions for the genre constellation on the explore
/// screen. Positions are purely visual — real counts come from
/// [GenreNode.count] / the API — so these never change with live data.
class GenreWebNode {
  final String name;
  final double x;
  final double y;

  const GenreWebNode({required this.name, this.x = 0, this.y = 0});
}

/// One node per supported genre so the map always mirrors the genre chips.
final genreWebNodes = const [
  GenreWebNode(name: 'Action', x: 0.10, y: 0.34),
  GenreWebNode(name: 'Adventure', x: 0.26, y: 0.13),
  GenreWebNode(name: 'Fantasy', x: 0.46, y: 0.08),
  GenreWebNode(name: 'Comedy', x: 0.64, y: 0.20),
  GenreWebNode(name: 'Drama', x: 0.80, y: 0.38),
  GenreWebNode(name: 'Romance', x: 0.92, y: 0.58),
  GenreWebNode(name: 'Mystery', x: 0.70, y: 0.76),
  GenreWebNode(name: 'Sci-Fi', x: 0.50, y: 0.62),
  GenreWebNode(name: 'Horror', x: 0.32, y: 0.48),
  GenreWebNode(name: 'Slice of Life', x: 0.16, y: 0.70),
  GenreWebNode(name: 'Sports', x: 0.47, y: 0.86),
  GenreWebNode(name: 'Supernatural', x: 0.86, y: 0.10),
  GenreWebNode(name: 'Thriller', x: 0.04, y: 0.12),
];
