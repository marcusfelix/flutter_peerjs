import 'enums.dart';

class PeerError {
  final PeerErrorType type;
  final String message;

  PeerError(this.type, this.message);
  
  @override
  String toString() => 'PeerError(type: $type, message: $message)';
}
