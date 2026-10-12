import 'package:equatable/equatable.dart';

/// Base class for all failures returned as [Left] of a `Either`.
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType: $message';
}

/// Failure thrown when all data sources are unreachable.
class FetchFailure extends Failure {
  const FetchFailure([super.message = 'فشل جلب البيانات من كل المصادر']);
}

/// Failure thrown when a specific data source fails but a fallback
/// succeeded; surfaced so the UI can inform the user.
class PartialFetchFailure extends Failure {
  final String source;
  const PartialFetchFailure(this.source, [String? message])
    : super(message ?? 'المصدر الرئيسي مش متاح، بنعرض من $source');
}

/// Failure for offline/local storage problems.
class LocalStorageFailure extends Failure {
  const LocalStorageFailure([super.message = 'خطأ في التخزين المحلي']);
}
