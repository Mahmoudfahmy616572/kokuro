/// Exceptions thrown inside the data layer while talking to
/// remote/local data sources. The repository layer catches these and
/// converts them into [Failure]s of the domain layer.
class ServerException implements Exception {
  final String message;
  final int? statusCode;
  const ServerException(this.message, {this.statusCode});
}

class CacheException implements Exception {
  final String message;
  const CacheException(this.message);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);
}
