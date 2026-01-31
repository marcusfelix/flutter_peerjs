# Flutter PeerJS

A stateless, pure-Dart implementation of the PeerJS API for Flutter, leveraging the power of `flutter_webrtc`. This package enables developers to easily integrate P2P data connections into their Flutter applications using the familiar PeerJS event-driven logic.

**Note:** This package is focused on `DataConnection` and does not support media streams (video/audio) at this time.

## Features

- **Stateless API**: Designed as a stateless wrapper around WebRTC, giving you full control over your application's state management.
- **PeerJS Compatible**: Works with any standard PeerJS signaling server.
- **Event-Driven**: A fully `Stream`-based API for handling events like `open`, `connection`, `data`, and `close`.
- **Data Channels**: Easily send `String` or binary data between peers.

## Installation

Add `flutter_peerjs` to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  flutter_peerjs: ^latest_version # Replace with the actual version
```

Then, run `flutter pub get`.

## Usage

### 1. Initialize the Peer

First, create a `Peer` instance. You can provide a custom ID or let the PeerJS server assign one for you.

```dart
import 'package:flutter_peerjs/flutter_peerjs.dart';

// Create a Peer instance
final peer = Peer(
  options: PeerOptions(
    debug: 2, // Log level: 0:None, 1:Error, 2:Warnings, 3:All
    // For a local server:
    // host: 'localhost',
    // port: 9000,
    // path: '/myapp',
    // secure: false,
  ),
);

// Listen for the 'open' event to get your Peer ID
peer.onOpen.listen((id) {
  print('My Peer ID is: $id');
  // You can now connect to other peers
});

// Listen for errors
peer.onError.listen((error) {
  print('An error occurred: ${error.message}');
});

// Listen for disconnection from the signaling server
peer.onDisconnected.listen((_) {
  print('Disconnected from the signaling server.');
  // You might want to attempt a reconnect here
  // peer.reconnect();
});

// Listen for the 'close' event when the peer is destroyed
peer.onClose.listen((_) {
  print('The peer has been destroyed.');
});
```

### 2. Connect to a Peer

To initiate a connection with another peer, use the `connect` method.

```dart
// Connect to a peer with the ID 'another-peer-id'
final connection = peer.connect('another-peer-id');

// Listen for the 'open' event on the connection
connection.onOpen.listen((_) {
  print('Connection established!');
  connection.send('Hello from the other side!');
});

// Listen for data from the remote peer
connection.onData.listen((data) {
  print('Received data: $data');
});

// Listen for the 'close' event on the connection
connection.onClose.listen((_) {
  print('Connection closed.');
});
```

### 3. Receiving Connections

To handle incoming connections from other peers, listen to the `onConnection` stream on your `Peer` instance.

```dart
peer.onConnection.listen((connection) {
  print('Incoming connection from ${connection.peerId}');

  // Listen for data from the new connection
  connection.onData.listen((data) {
    print('Received: $data');
    // Send a message back
    connection.send('Hello back!');
  });
  
  // You can also listen for open/close events on the incoming connection
  connection.onOpen.listen((_) {
    print('New connection is open and ready.');
  });
});
```

## API Overview

### `Peer` Class

The main class for managing connections.

- **`Peer({String? id, PeerOptions? options})`**: Constructor.
- **Streams**:
    - `onOpen`: Emits the peer's ID upon successful connection to the signaling server.
    - `onConnection`: Emits a `DataConnection` object for each new incoming connection.
    - `onDisconnected`: Emits when disconnected from the signaling server.
    - `onClose`: Emits when the peer is destroyed via `peer.destroy()`.
    - `onError`: Emits a `PeerError` on failure.
- **Methods**:
    - `connect(String peerId, {ConnectionOptions? options})`: Creates a new `DataConnection` to a remote peer.
    - `disconnect()`: Disconnects from the signaling server.
    - `reconnect()`: Attempts to reconnect to the signaling server.
    - `destroy()`: Closes all connections and destroys the peer.

### `DataConnection` Class

A wrapper for a WebRTC data channel.

- **Streams**:
    - `onOpen`: Emits when the data connection is ready to use.
    - `onData`: Emits any data received from the remote peer.
    - `onClose`: Emits when the connection is closed.
    - `onError`: Emits a `PeerError` on failure.
- **Methods**:
    - `send(dynamic data)`: Sends `String` or binary data to the remote peer.
    - `close()`: Closes the data connection.


## Requirements

This package requires `flutter_webrtc`. Please follow its setup instructions to ensure you have the necessary permissions (e.g., Internet/Network access) configured for each platform.

For a complete runnable example, please check the `example/` folder.
