import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'enums.dart';

class PeerOptions {
  final String? key;
  final String host;
  final int port;
  final String path;
  final bool secure;
  final RTCConfiguration rtcConfig;
  final int debug;

  PeerOptions({
    this.key = 'peerjs',
    this.host = '0.peerjs.com',
    this.port = 443,
    this.path = '/',
    this.secure = true,
    RTCConfiguration? rtcConfig,
    this.debug = 0,
  }) : this.rtcConfig = rtcConfig ??
            RTCConfiguration(iceServers: [
              RTCIceServer(urls: 'stun:stun.l.google.com:19302'),
            ]);
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
