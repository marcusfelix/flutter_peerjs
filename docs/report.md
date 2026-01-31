# Flutter PeerJS API Report

## Overview

This report analyzes the `flutter_peerjs` package, a Flutter library providing a PeerJS-like API for WebRTC communication. The analysis focuses on its architecture, public API, and alignment with the goal of being a stateless API layer.

## Architecture

The package is well-structured, with a clear separation of concerns. The core components are:

- **`Peer`**: The main class in `lib/src/peer.dart`. It manages the WebSocket connection to the PeerJS server for signaling and orchestrates the creation and management of WebRTC `PeerConnection`s.
- **`DataConnection`**: A wrapper around `RTCDataChannel` in `lib/src/data_connection.dart` that simplifies sending and receiving data between peers.
- **`PeerOptions` and `ConnectionOptions`**: Classes in `lib/src/options.dart` that provide a convenient way to configure the `Peer` and `DataConnection` objects.
- **`PeerError`**: A class in `lib/src/peer_error.dart` for handling and reporting errors.
- **Enums**: The `lib/src/enums.dart` file defines various enums for connection types, serialization, and error types, which helps in creating a more robust and predictable API.

## Public API

The public API is exposed through `lib/flutter_peerjs.dart`, which exports the main classes. The primary entry point for developers is the `Peer` class.

### `Peer` Class

The `Peer` class provides the following main features:

- **`Peer({String? id, PeerOptions? options})`**: The constructor initializes a new `Peer` object. It can be created with an optional `id` and `PeerOptions`. If no `id` is provided, one is fetched from the PeerJS server.
- **`onOpen`**: A `Stream` that emits the peer's `id` when the connection to the PeerJS server is established.
- **`onConnection`**: A `Stream` that emits a `DataConnection` object when a new connection is established with another peer.
- **`onClose`**: A `Stream` that emits when the `Peer` is destroyed.
- **`onDisconnected`**: A `Stream` that emits when the `Peer` is disconnected from the PeerJS server.
- **`onError`**: A `Stream` that emits `PeerError` objects when an error occurs.
- **`connect(String peerId, {ConnectionOptions? options})`**: This method creates a new `DataConnection` to the specified `peerId`.

### `DataConnection` Class

The `DataConnection` class provides a simple way to interact with a data channel:

- **`onOpen`**: A `Stream` that emits when the data connection is established.
- **`onClose`**: A `Stream` that emits when the data connection is closed.
- **`onData`**: A `Stream` that emits the data received from the remote peer.
- **`onError`**: A `Stream` that emits `PeerError` objects when an error occurs.
- **`send(dynamic data)`**: This method sends data to the remote peer.
- **`close()`**: This method closes the data connection.

## Stateless API Alignment

The current implementation of the `flutter_peerjs` package aligns well with the goal of being a stateless API for the underlying WebRTC protocol. The package does not manage any application-level state. Instead, it provides a set of tools and events that allow the parent application to manage the state of the connections.

The use of `Stream`s for events is a key feature that supports this stateless approach. The parent application can listen to these streams and react to events in a way that is appropriate for its own state management logic.

For example, the parent application can listen to the `onConnection` stream and decide whether to accept or reject the connection based on its own business logic. Similarly, it can listen to the `onData` stream and process the received data in a way that is appropriate for its own data model.

## Conclusion

The `flutter_peerjs` package is a well-designed and implemented library that provides a simple and effective way to use WebRTC in a Flutter application. Its stateless API makes it a flexible and powerful tool that can be used in a wide variety of applications. The parent application is responsible for managing the state of the connections, which gives it the flexibility to implement its own business logic and data models.
