# Flutter PeerJS API Design

This document outlines the design for a pure Dart implementation of the PeerJS API, using `flutter_webrtc` for WebRTC data channels. The goal is to create a 1-to-1 API clone of the official PeerJS library, enabling Flutter developers to build peer-to-peer data applications with a familiar API.

This package is **not** a Flutter Plugin and contains no native platform code. All functionality is built upon the `flutter_webrtc` package.

## 1. Core Concepts

### Peer ID and Signaling Server

Each peer is identified by a unique ID. When a `Peer` object is created, it connects to a signaling server to obtain an ID if one is not provided. This ID is used by other peers to establish connections. All signaling communication (connection negotiation, ICE candidates) is brokered through this server. Once a peer-to-peer connection is established, data is transferred directly between peers.

### Connection Lifecycle

1.  **Initialization**: A `Peer` object is instantiated. It connects to the signaling server in the background. The `onOpen` stream emits the peer's ID when the connection is successful.
2.  **Connection**: Peer A calls `peer.connect(peerB_id)`. This returns a `DataConnection` object immediately. Peer B receives the connection request via the `onConnection` stream, which provides its own `DataConnection` object.
3.  **Handshake**: The two peers automatically exchange SDP and ICE candidates via the signaling server to establish a direct `RTCDataChannel`.
4.  **Open**: Once the direct channel is established, both `DataConnection` objects fire their `onOpen` stream event. At this point, data can be exchanged using `connection.send()`.
5.  **Data Exchange**: Data is sent with `send()` and received via the `onData` stream.
6.  **Close**: A connection can be closed by either peer calling `connection.close()`. This fires the `onClose` event on both ends. Destroying the parent `Peer` object with `peer.destroy()` will close all associated connections.

---

## 2. API Specification

The API mirrors the PeerJS event-driven nature by using Dart `Stream`s.

### `Peer` Class

The main class for managing a peer's identity and connections.

```dart
class Peer {
  /// The unique ID of this peer.
  final String? id;

  /// A map of all active connections, keyed by the remote peer's ID.
  final Map<String, DataConnection> connections;

  /// True if the peer is disconnected from the signaling server.
  final bool isDisconnected;

  /// True if the peer has been destroyed and can no longer be used.
  final bool isDestroyed;

  // Streams for Events
  Stream<String> get onOpen;
  Stream<DataConnection> get onConnection;
  Stream<void> get onClose;
  Stream<void> get onDisconnected;
  Stream<PeerError> get onError;

  /// Constructor. If `id` is null, one will be assigned by the server.
  Peer({String? id, PeerOptions? options});

  /// Creates a new data connection to the peer with the given `peerId`.
  ///
  /// - [peerId]: The ID of the peer to connect to.
  /// - [options]: Metadata and serialization options for the connection.
  DataConnection connect(String peerId, {ConnectionOptions? options});

  /// Disconnects from the signaling server.
  /// Existing connections will remain active.
  Future<void> disconnect();

  /// Attempts to reconnect to the signaling server if disconnected.
  Future<void> reconnect();

  /// Closes all connections and terminates the peer's connection to the server.
  /// The Peer object is no longer usable after this.
  Future<void> destroy();
}
```

### `DataConnection` Class

Represents a data channel connection to a remote peer.

```dart
class DataConnection {
  /// The label for the data channel.
  final String label;

  /// Any metadata associated with the connection.
  final dynamic metadata;

  /// True if the connection is open and ready to send/receive data.
  final bool isOpen;

  /// The ID of the remote peer.
  final String peerId;

  /// Whether the connection is reliable (using SCTP).
  final bool isReliable;

  /// The serialization format used for data.
  final SerializationType serialization;

  /// The type of connection.
  final ConnectionType type = ConnectionType.data;

  // Streams for Events
  Stream<dynamic> get onData;
  Stream<void> get onOpen;
  Stream<void> get onClose;
  Stream<PeerError> get onError;

  /// Sends data to the remote peer. Data must be of a serializable type.
  void send(dynamic data);

  /// Closes the data connection.
  void close();
}
```

### Supporting Enums and Classes

```dart
// Options for configuring the Peer object
class PeerOptions {
  final String? key; // API key for the PeerJS server
  final String host;
  final int port;
  final String path;
  final bool secure;
  final RTCConfiguration rtcConfig; // From flutter_webrtc
  final int debug;

  PeerOptions({
    this.key = 'peerjs',
    this.host = '0.peerjs.com',
    this.port = 443,
    this.path = '/',
    this.secure = true,
    RTCConfiguration? rtcConfig,
    this.debug = 0,
  }) : this.rtcConfig = rtcConfig ?? RTCConfiguration(iceServers: [
          RTCIceServer(urls: 'stun:stun.l.google.com:19302'),
        ]);
}

// Options for a new DataConnection
class ConnectionOptions {
  final String? label;
  final dynamic metadata;
  final SerializationType? serialization;
  final bool? reliable;

  ConnectionOptions({this.label, this.metadata, this.serialization, this.reliable});
}

// Represents an error from the Peer or Connection
class PeerError {
  final PeerErrorType type;
  final String message;
  PeerError(this.type, this.message);
}

enum SerializationType { binary, binaryUTF8, json, none }
enum ConnectionType { data, media } // Media is out of scope for now
enum PeerErrorType {
  browser-incompatible,
  disconnected,
  invalid-id,
  invalid-key,
  network,
  peer-unavailable,
  ssl-unavailable,
  server-error,
  socket-error,
  socket-closed,
  unavailable-id,
  webrtc
}
```

---

## 3. Configuration

### Default Signaling Server

The package will be hardcoded to use the public PeerJS server by default.

-   **Host**: `0.peerjs.com`
-   **Port**: `443`
-   **Path**: `/`
-   **Secure**: `true`

These values can be overridden in the `PeerOptions` constructor.

### Default STUN/TURN Servers

The default `RTCConfiguration` will use Google's public STUN server. Users can provide a custom `RTCConfiguration` object via `PeerOptions` to specify their own STUN/TURN servers.

-   **STUN**: `stun:stun.l.google.com:19302`

---

## 4. Signaling Mechanism Explained

The signaling process is managed entirely by this package and the PeerJS server.

1.  **Client A -> Server**: `Peer` A is created and sends a "REGISTER" message to the signaling server. The server stores A's ID. The `onOpen` stream is fired with A's ID.
2.  **Client B -> Server**: `Peer` B does the same.
3.  **Client A -> Server -> Client B**: Client A calls `peerA.connect(peerB_id)`. This sends an "OFFER" message to the server, containing SDP (Session Description Protocol) data. The server forwards this offer to Client B.
4.  **Client B -> Server -> Client A**: On receiving the "OFFER", Client B's `onConnection` stream is fired. Internally, Client B generates an SDP "ANSWER" and sends it back to Client A via the server.
5.  **ICE Candidate Exchange**: Both clients, now aware of each other, start generating ICE (Interactive Connectivity Establishment) candidates and exchange them via the signaling server. These candidates describe possible network paths.
6.  **Direct Connection**: Once both peers find a compatible network path, a direct `RTCDataChannel` is established. The `onOpen` stream of the `DataConnection` fires on both peers.
7.  **Data Flow**: All subsequent data sent via `connection.send()` travels directly between A and B, not through the signaling server.

---

## 5. Identity and Reconnection

-   **Identity**: A peer's ID is its sole identifier on the signaling network. A specific ID can only be used by one connected peer at a time. If an ID is unavailable, the `onError` stream will fire.
-   **Reconnection**: If a peer loses its connection to the signaling server, the `onDisconnected` stream is fired. The peer will automatically attempt to reconnect. If successful, it re-registers with the server under its original ID and the peer object can continue to be used. If reconnection fails, manual intervention via `peer.reconnect()` may be needed. During disconnection, existing P2P connections remain active.

---

## 6. Limitations and Differences from PeerJS (JS)

-   **`MediaConnection`**: This design explicitly **excludes** `MediaConnection` and audio/video streaming (`peer.call()`). The focus is solely on the `DataConnection` API.
-   **Browser Compatibility**: As a Flutter package, this is not subject to browser WebRTC differences. However, it is entirely dependent on the implementation and stability of `flutter_webrtc`.
-   **Serialization**: The `binary` serialization in PeerJS (JS) uses `Blob`s. In Dart, this will be mapped to `Uint8List`.
-   **Event System**: This API uses Dart `Stream`s (`onOpen`, `onData`, etc.) instead of a string-based `on('event', ...)` pattern. This is more idiomatic for Dart and provides better type safety.
-   **No DOM Dependencies**: Any PeerJS features related to browser-specific elements (like rendering a `<video>` tag) are irrelevant and not included.

---

## 7. Example Usage

This minimal snippet demonstrates how a developer would use the API in a Flutter application.

```dart
import 'package:flutter_peerjs/flutter_peerjs.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'; // For RTCConfiguration if needed

class P2PService {
  late Peer peer;
  DataConnection? connection;
  String? peerId;

  // Initialize the peer
  void create() {
    peer = Peer(id: 'my-unique-id'); // Or let the server assign one

    // Listen for when the peer connection to server is established
    peer.onOpen.listen((id) {
      print('Peer connection opened with id: $id');
      this.peerId = id;
    });

    // Listen for incoming data connections
    peer.onConnection.listen((conn) {
      print('Received connection from ${conn.peerId}');
      connection = conn;
      _listenForConnectionEvents();
    });

    peer.onError.listen((error) {
      print('Peer error: ${error.type} - ${error.message}');
    });
  }

  // Connect to a remote peer
  void connectToPeer(String remotePeerId) {
    if (peer == null) return;

    print('Connecting to peer: $remotePeerId');
    connection = peer.connect(remotePeerId,
      options: ConnectionOptions(
        metadata: {'message': 'Hi from the connecting peer!'},
      ),
    );
    _listenForConnectionEvents();
  }

  void _listenForConnectionEvents() {
    if (connection == null) return;

    // When the connection is ready to be used
    connection!.onOpen.listen((_) {
      print('Data connection opened!');
      connection!.send('Hello from ${peer.id}!');
    });

    // When data is received
    connection!.onData.listen((data) {
      print('Received data: $data');
    });

    // When the connection is closed
    connection!.onClose.listen((_) {
      print('Connection closed.');
      connection = null;
    });

    connection!.onError.listen((error) {
      print('Connection error: ${error.type} - ${error.message}');
    });
  }

  // Clean up
  void dispose() {
    peer.destroy();
  }
}
```
