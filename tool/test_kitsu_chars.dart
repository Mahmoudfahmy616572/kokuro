import 'dart:convert';
import 'package:http/http.dart' as http;

const _baseUrl = 'https://kitsu.io/api/edge';
const _headers = {
  'Accept': 'application/vnd.api+json',
  'Content-Type': 'application/vnd.api+json',
  'User-Agent': 'Animiat/1.0 (a legal anime metadata app)',
};

Future<void> main(List<String> args) async {
  final kitsuId = args.isNotEmpty ? int.tryParse(args.first) ?? 12 : 12;
  final client = http.Client();
  try {
    final url =
        '$_baseUrl/anime/$kitsuId/characters'
        '?include=character&page[limit]=3';
    print('URL: $url');
    final response = await client
        .get(Uri.parse(url), headers: _headers)
        .timeout(const Duration(seconds: 12));
    print('Status: ${response.statusCode}');
    if (response.statusCode != 200) {
      print(
        'Body: ${response.body.substring(0, response.body.length.clamp(0, 300))}',
      );
      return;
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    final included = body['included'] as List<dynamic>? ?? [];
    print('data entries: ${data.length}, included: ${included.length}');
    for (final item in data) {
      final map = item as Map<String, dynamic>;
      print(
        '  type=${map['type']} role=${map['attributes']?['role']} '
        'charRel=${map['relationships']?['character']?['data']}',
      );
    }
    final byId = <String, Map<String, dynamic>>{};
    for (final item in included) {
      final map = item as Map<String, dynamic>;
      if (map['type'] == 'characters') {
        byId[map['id'].toString()] =
            map['attributes'] as Map<String, dynamic>? ?? {};
      }
    }
    for (final item in data) {
      final map = item as Map<String, dynamic>;
      final charRel = map['relationships']?['character']?['data'] as Map?;
      final charId = charRel?['id']?.toString();
      final charAttrs = charId != null ? byId[charId] : null;
      print('  resolved: ${charAttrs?['canonicalName']} (id=$charId)');
    }
  } catch (e) {
    print('Exception: $e');
  } finally {
    client.close();
  }
}
