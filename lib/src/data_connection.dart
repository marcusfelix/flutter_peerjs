import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'enums.dart';
import 'peer_error.dart';

class DataConnection {
  final String peerId;
  final String label;
  final dynamic metadata;
  final SerializationType serialization;
  final bool reliable;
  RTCDataChannel? _dataChannel;

  /// The type of connection.
  final ConnectionType type = ConnectionType.data;

  bool _isOpen = false;
  bool get isOpen => _isOpen;

  final _openController = StreamController<void>.broadcast();
  Stream<void> get onOpen => _openController.stream;

  final _closeController = StreamController<void>.broadcast();
  Stream<void> get onClose => _closeController.stream;

  final _dataController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get onData => _dataController.stream;

  final _errorController = StreamController<PeerError>.broadcast();
  Stream<PeerError> get onError => _errorController.stream;

  DataConnection(
    this.peerId,
    this._dataChannel, {
    this.label = '',
    this.metadata,
    this.serialization = SerializationType.json,
    this.reliable = true,
  }) {
    _configureDataChannel();
  }

  void configure(RTCDataChannel channel) {
    _dataChannel = channel;
    _configureDataChannel();
  }

  void _configureDataChannel() {
    if (_dataChannel == null) return;

    _dataChannel!.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _isOpen = true;
        _openController.add(null);
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _isOpen = false;
        _closeController.add(null);
      }
    };

    _dataChannel!.onMessage = (RTCDataChannelMessage message) {
      _handleMessage(message);
    };
  }

  void _handleMessage(RTCDataChannelMessage message) {
    if (message.isBinary) {
      // Handle binary data
       _dataController.add(message.binary);
    } else {
      // Handle text data - assuming JSON for now as per default, but could be plain text
       _dataController.add(message.text);
    }
  }

  /// Sends data to the remote peer.
  /// 
  /// [data] can be a String or user defined type if using JSON serialization,
  /// or a ByteBuffer/Uint8List if using Binary serialization.
  Future<void> send(dynamic data) async {
    if (!_isOpen) {
      _errorController.add(PeerError(PeerErrorType.socketClosed, 'Connection is not open.'));
      return;
    }

    if (_dataChannel == null) return; // Should not happen if open

    try {
      if (data is String) {
        await _dataChannel!.send(RTCDataChannelMessage(data));
      } else if (data is List<int>) { // Uint8List
         // flutter_webrtc expects Uint8List for binary
         // ignore: avoid_as, assuming data is Uint8List or compatible List<int>
         // We might need to cast to Uint8List explicitly if it isn't one.
         // checking if it is Uint8List
         /*
         if (data is! Uint8List) {
           data = Uint8List.fromList(data);
         }
         */
         // RTCDataChannelMessage.fromBinary expects Uint8List
         // Actually, let's just assume users pass what is needed or we convert string
         // Only basic support for now as per spec "Data must be of a serializable type"
         
        // If it's pure binary List<int>
         await _dataChannel!.send(RTCDataChannelMessage.fromBinary(data as dynamic)); 
      } else {
        // Try toString() for other objects? Or Throw?
        await _dataChannel!.send(RTCDataChannelMessage(data.toString()));
      }
    } catch (e) {
      _errorController.add(PeerError(PeerErrorType.webrtc, 'Failed to send data: $e'));
    }
  }

  void close() {
    if (!_isOpen) return;
    _dataChannel?.close();
    _isOpen = false;
    _closeController.add(null);
  }
}
