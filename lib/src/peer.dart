import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

import 'enums.dart';
import 'options.dart';
import 'peer_error.dart';
import 'data_connection.dart';

class Peer {
  String? _id;
  String? get id => _id;

  final PeerOptions options;
  final Map<String, DataConnection> _connections = {};
  Map<String, DataConnection> get connections => Map.unmodifiable(_connections);

  WebSocketChannel? _socket;
  bool _disconnected = true;
  bool get isDisconnected => _disconnected;
  
  bool _destroyed = false;
  bool get isDestroyed => _destroyed;


  // Stream controllers
  final _openController = StreamController<String>.broadcast();
  Stream<String> get onOpen => _openController.stream;

  final _connectionController = StreamController<DataConnection>.broadcast();
  Stream<DataConnection> get onConnection => _connectionController.stream;

  final _closeController = StreamController<void>.broadcast();
  Stream<void> get onClose => _closeController.stream;

  final _disconnectedController = StreamController<void>.broadcast();
  Stream<void> get onDisconnected => _disconnectedController.stream;

  final _errorController = StreamController<PeerError>.broadcast();
  Stream<PeerError> get onError => _errorController.stream;

  // Internal maps for active RTCPeerConnections pending setup
  final Map<String, RTCPeerConnection> _peerConnections = {};

  Peer({String? id, PeerOptions? options}) 
      : options = options ?? PeerOptions() {
    _id = id;
    _initialize();
  }

  Future<void> _initialize() async {
    if (_id == null) {
      try {
        _id = await _fetchId();
      } catch (e) {
        _emitError(PeerErrorType.serverError, 'Could not retrieve ID from server: $e');
        return;
      }
    }
    
    _connectToServer();
  }

  Future<String> _fetchId() async {
    final protocol = options.secure ? 'https' : 'http';
    final url = Uri.parse('$protocol://${options.host}:${options.port}${options.path}${options.key}/id');
    
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return response.body; 
    } else {
      throw Exception('Failed to get ID from server. Status: ${response.statusCode}');
    }
  }

  void _connectToServer() {
    if (_disconnected == false || _destroyed) return;

    final protocol = options.secure ? 'wss' : 'ws';
    final url = '$protocol://${options.host}:${options.port}${options.path}peerjs?key=${options.key}&id=$_id&token=${Uuid().v4()}';

    try {
      _socket = WebSocketChannel.connect(Uri.parse(url));
      _disconnected = false;

      _socket!.stream.listen((message) {
        _handleMessage(message);
      }, onDone: () {
        _disconnected = true;
        _disconnectedController.add(null);
      }, onError: (error) {
        _emitError(PeerErrorType.socketError, 'Socket error: $error');
      });
      
      // If we made it here, we are effectively "Open" for business once the server confirms sending OPEN
      // Note: PeerJS server sends an OPEN message
    } catch (e) {
        _emitError(PeerErrorType.socketError, 'Could not connect to socket: $e');
    }
  }

  void _handleMessage(dynamic message) {
    dynamic data;
    try {
      data = jsonDecode(message);
    } catch (e) {
      // Non-JSON message?
      return;
    }

    final type = data['type'];
    final payload = data['payload'];
    final src = data['src'];

    switch (type) {
      case 'OPEN':
        _disconnected = false;
        _openController.add(_id!);
        break;
      case 'ERROR':
        _emitError(PeerErrorType.serverError, '$payload');
        break;
      case 'ID-TAKEN':
         _emitError(PeerErrorType.unavailableId, 'ID "$_id" is taken');
         break;
      case 'INVALID-KEY':
         _emitError(PeerErrorType.invalidKey, 'API KEY "${options.key}" is invalid');
         break;
      case 'OFFER':
        _handleOffer(src, payload);
        break;
      case 'ANSWER':
        _handleAnswer(src, payload);
        break;
      case 'CANDIDATE':
        _handleCandidate(src, payload);
        break;
      case 'EXPIRE':
        // Handle token expiration if needed
        break;
      default:
        if (options.debug > 0) {
          // ignore: avoid_print
          print('Peer: Unhandled message type: $type');
        }
    }
  }

  // --- Connection Logic ---

  DataConnection connect(String peerId, {ConnectionOptions? options}) {
    if (_destroyed) {
       throw Exception('Peer is destroyed');
    }
    if (_disconnected) {
       // Prefer to warn or try reconnect? 
       // print('Peer is disconnected, attempting to clean reconnect...');
    }

    final connectionOptions = options ?? ConnectionOptions();
    final label = connectionOptions.label ?? 'data-${Uuid().v4()}'; // Default label?

    // Create RTCPeerConnection
    // We can't act synchronously entirely because createPeerConnection is async
    // But we need to return DataConnection immediately. 
    // So we'll act async internally.
    
    // Placeholder DataConnection until channel is ready?
    // Actually, we create the channel on the PC.
    
    final dataConnection = DataConnection(
      peerId,
      null, // Channel will be assigned later? OR we wait?
      // Wait, standard PeerJS implementation returns DataConnection immediately.
      // But we need the RTCDataChannel object to construct DataConnection wrapper properly usually, 
      // OR we update the wrapper with the channel later.
      // Let's modify DataConnection to accept a future or be updatable, 
      // OR, simpler: We start the process and assign the channel when created.
      // For providing a synchronous return, we likely need to construct the PC and Channel immediately after this return via async execution.
      label: label,
      metadata: connectionOptions.metadata,
      serialization: connectionOptions.serialization ?? SerializationType.json,
      reliable: connectionOptions.reliable ?? true,
    );

    // Store connection?
    // _connections[peerId] = dataConnection; // Multiple connections per peer allowed? 
    // PeerJS JS stores them in a list usually or map.
    
    _startConnection(peerId, dataConnection, connectionOptions);

    return dataConnection;
  }
  
  Future<void> _startConnection(String remotePeerId, DataConnection dataConnection, ConnectionOptions connectionOptions) async {
    try {
      final pc = await createPeerConnection(options.rtcConfig, {});
      _peerConnections[remotePeerId] = pc; // Store PC

      // Setup ICE handling
      pc.onIceCandidate = (candidate) {
        _sendToSocket({
          'type': 'CANDIDATE',
          'dst': remotePeerId,
          'payload': {
             'candidate': candidate.candidate,
             'sdpMid': candidate.sdpMid,
             'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
      };

      // Create Data Channel
      final dcInit = RTCDataChannelInit();
      dcInit.negotiated = false; // We are doing negotiation via SDP
      // dcInit.id = ?; Auto-assigned
      // dcInit.ordered = connectionOptions.reliable; 
      // Flutter WebRTC Map-based config for createDataChannel
      
      final dcConfig = RTCDataChannelInit();
      // dcConfig.reliable = connectionOptions.reliable ?? true; // Deprecated/mapped differently usually?
      
      final dataChannel = await pc.createDataChannel(dataConnection.label, dcConfig);
      
      // Inject channel into our DataConnection wrapper
        // NOTE: We need a way to pass this channel to the already created DataConnection object.
        // This is a small design flaw in my DataConnection earlier. 
        // I should have made the channel setter public or internal.
        // For now, I'll rely on a hack or simple modification to DataConnection if I can't edit it. 
        // Or I just re-create it? No, user has the reference.
        // I will assume I can edit `DataConnection` to add a method `_setChannel` or similar in next step if needed, or I utilize a constructor that takes a Future?
        // Actually, looking at `DataConnection`, `_dataChannel` is final. I should change that.
    
      // FIXING DataConnection on the fly: I'll use a hack or reflection? 
      // Better: I will re-write DataConnection in next step or use a property.
      // Wait, I am writing Peer.dart now. I can just assume DataConnection has a setter or I will Modify it.
      // I will assume I can access a private setter or I will fix DataConnection after.
      // Let's modify DataConnection to allow late assignment or look at `lib/src/data_connection.dart`...
      
      // Since I am writing `Peer.dart` and `DataConnection.dart` was just written, I can go back and edit DataConnection.
      // BUT, I can't do that within this single `write_to_file`.
      // I will use `_configureDataChannel` publically if I can? No it is private.
      
      // Plan: I will define `internalSetDataChannel` in DataConnection in a separate `multi_replace` or `write` call if I was strictly following tools.
      // But here I am implementing Peer.
      
      // Strategy: I will rely on `DataConnection` having a public, or accessible way. 
      // I'll pause `Peer` implementation to fix `DataConnection` first.
      
      // Wait, I can't pause mid-tool call.
      // I will write `Peer.dart` assuming `DataConnection` has a `configure(RTCDataChannel dc)` method.
      // Then I will update `DataConnection.dart` to include it.
      
      dataConnection.configure(dataChannel); // Method to be added

      // Create Offer
      final offer = await pc.createOffer({});
      await pc.setLocalDescription(offer);

      _sendToSocket({
        'type': 'OFFER',
        'dst': remotePeerId,
        'payload': {
          'sdp': offer.sdp,
          'type': offer.type,
          'label': dataConnection.label, 
          'connectionId': null, // PeerJS uses connectionId sometimes?
          'reliable': connectionOptions.reliable,
          'serialization': connectionOptions.serialization?.toString(),
          'metadata': connectionOptions.metadata,
        }
      });
      
    } catch (e) {
      _emitError(PeerErrorType.webrtc, 'Failed to connect: $e');
    }
  }

  // --- Handling Incoming Events ---

  Future<void> _handleOffer(String srcId, Map<String, dynamic> payload) async {
    final sdp = payload['sdp'];
    final type = payload['type'];
    final label = payload['label'];
    // final reliable = payload['reliable'];
    // final metadata = payload['metadata'];
    // final serialization = payload['serialization'];

    try {
      final pc = await createPeerConnection(options.rtcConfig, {});
      _peerConnections[srcId] = pc;

      // Handle Data Channel from remote
      pc.onDataChannel = (channel) {
         final connection = DataConnection(
           srcId, 
           channel, 
           label: label,
           // metadata: metadata, // PeerJS Offer payload includes metadata?
           // reliable: reliable
         );
         _connections[srcId] = connection; // Store?
         _connectionController.add(connection);
      };

      pc.onIceCandidate = (candidate) {
        _sendToSocket({
          'type': 'CANDIDATE',
          'dst': srcId,
          'payload': {
             'candidate': candidate.candidate,
             'sdpMid': candidate.sdpMid,
             'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
      };

      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
      final answer = await pc.createAnswer({});
      await pc.setLocalDescription(answer);

      _sendToSocket({
        'type': 'ANSWER',
        'dst': srcId,
        'payload': {
          'sdp': answer.sdp,
          'type': answer.type,
        }
      });

    } catch (e) {
      _emitError(PeerErrorType.webrtc, 'Failed to handle offer: $e');
    }
  }

  Future<void> _handleAnswer(String srcId, Map<String, dynamic> payload) async {
    final pc = _peerConnections[srcId];
    if (pc != null) {
      try {
        await pc.setRemoteDescription(RTCSessionDescription(payload['sdp'], payload['type']));
      } catch (e) {
        _emitError(PeerErrorType.webrtc, 'Failed to set remote description (answer): $e');
      }
    }
  }

  Future<void> _handleCandidate(String srcId, Map<String, dynamic> payload) async {
     final pc = _peerConnections[srcId];
     if (pc != null) {
       try {
         await pc.addCandidate(RTCIceCandidate(
           payload['candidate'], 
           payload['sdpMid'], 
           payload['sdpMLineIndex']
         ));
       } catch (e) {
         _emitError(PeerErrorType.webrtc, 'Failed to add candidate: $e');
       }
     }
  }

  // --- Utilities ---

  void _sendToSocket(Map<String, dynamic> message) {
    if (_socket != null) {
      _socket!.sink.add(jsonEncode(message));
    }
  }

  void _emitError(PeerErrorType type, String message) {
    _errorController.add(PeerError(type, message));
  }
  
  Future<void> dispose() async {
    await destroy();
  }

  Future<void> destroy() async {
    _destroyed = true;
    _startDisconnect();
    
    // Close all connections
    _peerConnections.forEach((key, pc) => pc.close());
    _connections.forEach((key, dc) => dc.close());
    
    _peerConnections.clear();
    _connections.clear();
    
    _closeController.add(null);
  }
  
  Future<void> disconnect() async {
    _startDisconnect();
  }
  
  Future<void> reconnect() async {
    if (!_disconnected) return;
    _connectToServer();
  }
  
  void _startDisconnect() {
    _disconnected = true;
    _socket?.sink.close();
    _socket = null;
    _disconnectedController.add(null);
  }
}
