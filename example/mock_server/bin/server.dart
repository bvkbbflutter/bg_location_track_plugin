import 'dart:convert';
import 'dart:io';

// In-memory store
final List<Map<String, dynamic>> _locations = [];
bool _failNextUpload = false;
int _failCode = 500;

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print(
      'Mock Backend listening on http://${server.address.host}:${server.port}');

  await for (HttpRequest request in server) {
    try {
      await _handleRequest(request);
    } catch (e) {
      print('Error handling request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }
}

Future<void> _handleRequest(HttpRequest request) async {
  final path = request.uri.path;
  print('--> ${request.method} $path');

  // Add CORS
  request.response.headers.add('Access-Control-Allow-Origin', '*');
  request.response.headers
      .add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  request.response.headers.add(
      'Access-Control-Allow-Headers', 'Origin, Content-Type, Authorization');

  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.ok;
    await request.response.close();
    return;
  }

  if (path == '/health' && request.method == 'GET') {
    request.response.statusCode = HttpStatus.ok;
    request.response.write('{"status":"ok"}');
    await request.response.close();
    return;
  }

  if (path == '/login' && request.method == 'POST') {
    // accept any credentials
    final body = await utf8.decoder.bind(request).join();
    print('Login payload: $body');
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
        '{"token":"mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}"}');
    await request.response.close();
    return;
  }

  if (path == '/debug/fail' && request.method == 'POST') {
    final mode = request.uri.queryParameters['mode'];
    _failNextUpload = true;
    _failCode = (mode == '401') ? 401 : 500;
    request.response.statusCode = HttpStatus.ok;
    request.response
        .write('{"status":"next upload will fail with $_failCode"}');
    await request.response.close();
    return;
  }

  // Auth check for locations
  final authHeader = request.headers.value('Authorization');
  if (authHeader == null || !authHeader.startsWith('Bearer mock_jwt_token_')) {
    request.response.statusCode = HttpStatus.unauthorized;
    request.response.write('{"error":"unauthorized"}');
    await request.response.close();
    print('<-- 401 Unauthorized');
    return;
  }

  if (path == '/locations/batch' && request.method == 'POST') {
    if (_failNextUpload) {
      _failNextUpload = false;
      request.response.statusCode = _failCode;
      request.response.write('{"error":"Simulated failure"}');
      await request.response.close();
      print('<-- $_failCode Simulated Failure');
      return;
    }

    // Handle possible GZIP
    Stream<List<int>> stream = request.cast<List<int>>();
    if (request.headers.value('Content-Encoding') == 'gzip') {
      stream = stream.transform(gzip.decoder);
    }

    final bodyStr = await utf8.decoder.bind(stream).join();
    final data = jsonDecode(bodyStr);

    List<dynamic> points;
    if (data is Map && data.containsKey('locations')) {
      points = data['locations'] as List<dynamic>;
    } else if (data is List) {
      points = data;
    } else {
      points = [];
    }

    int received = 0;
    int duplicates = 0;

    for (var point in points) {
      if (point is Map<String, dynamic>) {
        final uuid = point['uuid'];
        if (_locations.any((l) => l['uuid'] == uuid)) {
          duplicates++;
        } else {
          _locations.add(point);
          received++;
        }
      }
    }

    print('<-- 201 Created (Received: $received, Duplicates: $duplicates)');
    request.response.statusCode = HttpStatus.created;
    request.response.headers.contentType = ContentType.json;
    request.response
        .write(jsonEncode({'received': received, 'duplicates': duplicates}));
    await request.response.close();
    return;
  }

  if (path == '/locations' && request.method == 'GET') {
    final sessionId = request.uri.queryParameters['sessionId'];
    List<Map<String, dynamic>> results = _locations;

    if (sessionId != null) {
      results = results.where((l) => l['sessionId'] == sessionId).toList();
    }

    // Sort by timestamp
    results.sort(
        (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'locations': results}));
    await request.response.close();
    return;
  }

  request.response.statusCode = HttpStatus.notFound;
  await request.response.close();
}
