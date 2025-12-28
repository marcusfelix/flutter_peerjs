enum SerializationType { binary, binaryUTF8, json, none }

enum ConnectionType { data, media }

enum PeerErrorType {
  browserIncompatible,
  disconnected,
  invalidId,
  invalidKey,
  network,
  peerUnavailable,
  sslUnavailable,
  serverError,
  socketError,
  socketClosed,
  unavailableId,
  webrtc,
}
