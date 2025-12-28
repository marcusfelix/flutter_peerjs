# Flutter PeerJS

A pure Dart implementation of the PeerJS API for Flutter, built on top of
`flutter_webrtc`. This package allows you to create P2P data connections in your
Flutter applications using the familiar PeerJS logic.

**Note:** This package currently supports **DataConnection** only (no media
calls).

## Installation

Add `flutter_peerjs` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_peerjs:
    path: ./ # Or git/pub version
```

## Usage

### Initialization

```dart
import 'package:flutter_peerjs/flutter_peerjs.dart';

// Create a Peer
final peer = Peer(
  options: PeerOptions(
    debug: 2, // 0: None, 1: Error, 2: Warnings, 3: All
  ),
);

// Listen for the OPEN event
peer.onOpen.listen((id) {
  print('My Peer ID is: $id');
});
```

### Connect to a Peer

```dart
final connection = peer.connect('another-peer-id');

connection.onOpen.listen((_) {
  connection.send('Hello!');
});
```

### Receive Connections

```dart
peer.onConnection.listen((connection) {
  print('Incoming connection from ${connection.peerId}');
  
  connection.onData.listen((data) {
    print('Received: $data');
  });
  
  connection.onOpen.listen((_) {
    connection.send('Hello back!');
  });
});
```

## Features

- **PeerJS Compatible**: Uses standard PeerJS signaling server by default.
- **Data Channels**: Send text or binary data.
- **Event Driven**: fully Stream-based API.

## Requirements

- Flutter SDK
- `flutter_webrtc` setup (permissions for Internet/Network)

For a complete runnable example, check the `example/` folder.
