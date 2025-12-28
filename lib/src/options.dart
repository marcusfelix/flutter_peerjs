import 'enums.dart';

class PeerOptions {
  final String? key;
  final String host;
  final int port;
  final String path;
  final bool secure;
  final Map<String, dynamic> rtcConfig;
  final int debug;

  PeerOptions({
    this.key = 'peerjs',
    this.host = '0.peerjs.com',
    this.port = 443,
    this.path = '/',
    this.secure = true,
    Map<String, dynamic>? rtcConfig,
    this.debug = 0,
  }) : rtcConfig = rtcConfig ??
            {
              'iceServers': [
                {'urls': 'stun:stun.l.google.com:19302'},
              ]
            };
}

class ConnectionOptions {
  final String? label;
  final dynamic metadata;
  final SerializationType? serialization;
  final bool? reliable;

  ConnectionOptions({
    this.label,
    this.metadata,
    this.serialization,
    this.reliable,
  });
}
