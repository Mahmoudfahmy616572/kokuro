import 'dart:convert';
import 'package:http/http.dart' as http;

void main(List<String> args) async {
  final malId = args.isNotEmpty ? int.tryParse(args.first) ?? 5114 : 5114;
  final client = http.Client();
  const endpoint = 'https://graphql.anilist.co';
  const query = '''
    query (\$idMal: Int) {
      Media(idMal: \$idMal, type: ANIME) {
        title { romaji }
        characters(perPage: 5, sort: FAVOURITES_DESC) {
          edges {
            node {
              id
              name { full }
              image { large }
            }
            role
            voiceActors(language: JAPANESE) {
              name { full }
              image { large }
            }
          }
        }
      }
    }
  ''';

  try {
    final response = await client
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'query': query,
            'variables': {'idMal': malId},
          }),
        )
        .timeout(const Duration(seconds: 15));

    print('Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final media = body['data']?['Media'] as Map<String, dynamic>?;
      final title = media?['title']?['romaji'];
      print('Anime: $title');

      final edges = media?['characters']?['edges'] as List<dynamic>? ?? [];
      print('Characters found: ${edges.length}');

      for (final edge in edges) {
        final node = edge['node'] as Map<String, dynamic>;
        final name = node['name']?['full'];
        final role = edge['role'];
        final vaList = edge['voiceActors'] as List<dynamic>? ?? [];
        final va = vaList.isNotEmpty ? vaList.first : null;
        final vaName = va?['name']?['full'];
        print('  $name ($role) - VA: $vaName');
      }
    } else {
      print('Error: ${response.body}');
    }
  } catch (e) {
    print('Exception: $e');
  } finally {
    client.close();
  }
}
