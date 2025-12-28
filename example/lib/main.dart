import 'package:flutter/material.dart';
import 'package:flutter_peerjs/flutter_peerjs.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeerJS Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PeerPage(),
    );
  }
}

class PeerPage extends StatefulWidget {
  const PeerPage({super.key});

  @override
  State<PeerPage> createState() => _PeerPageState();
}

class _PeerPageState extends State<PeerPage> {
  Peer? _peer;
  DataConnection? _connection;
  String _myId = 'Loading...';
  final _connectToController = TextEditingController();
  final _messageController = TextEditingController();
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _createPeer();
  }

  void _log(String message) {
    setState(() {
      _logs.add(message);
    });
  }

  void _createPeer() {
    _log('Creating Peer...');
    _peer = Peer(options: PeerOptions(debug: 3));

    _peer!.onOpen.listen((id) {
      setState(() {
        _myId = id;
      });
      _log('Peer opened with ID: $id');
    });

    _peer!.onConnection.listen((connection) {
      _log('Incoming connection from: ${connection.peerId}');
      _setupConnection(connection);
    });

    _peer!.onClose.listen((_) {
      _log('Peer closed');
    });

    _peer!.onDisconnected.listen((_) {
      _log('Peer disconnected');
    });

    _peer!.onError.listen((error) {
      _log('Peer Error: $error');
    });
  }

  void _setupConnection(DataConnection connection) {
    setState(() {
      _connection = connection;
    });

    connection.onOpen.listen((_) {
      _log('Connection opened with ${connection.peerId}');
      setState(() {}); // refresh UI
    });

    connection.onData.listen((data) {
      _log('Received from ${connection.peerId}: $data');
    });

    connection.onClose.listen((_) {
      _log('Connection closed with ${connection.peerId}');
      setState(() {
        _connection = null;
      });
    });

    connection.onError.listen((error) {
      _log('Connection Error: $error');
    });
  }

  void _connect() {
    final targetId = _connectToController.text.trim();
    if (targetId.isEmpty || _peer == null) return;

    _log('Connecting to $targetId...');
    final conn = _peer!.connect(targetId);
    _setupConnection(conn);
  }

  void _sendHello() {
    if (_connection == null) return;
    _connection!.send('Hello from $_myId');
  }

  void _sendMessage() {
     if (_connection == null) return;
     final msg = _messageController.text;
     if (msg.isNotEmpty) {
       _connection!.send(msg);
       _log('Sent: $msg');
       _messageController.clear();
     }
  }

  void _disconnectPeer() {
    _peer?.disconnect();
  }

  void _reconnectPeer() {
    _peer?.reconnect();
  }

  void _destroyPeer() {
    _peer?.destroy();
  }

  @override
  void dispose() {
    _peer?.dispose();
    _connectToController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PeerJS Example'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('My Peer ID: $_myId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(onPressed: _disconnectPeer, child: const Text('Disconnect')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _reconnectPeer, child: const Text('Reconnect')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _destroyPeer, 
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
                      child: const Text('Destroy')
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_connection == null) ...[
                  TextField(
                    controller: _connectToController,
                    decoration: const InputDecoration(
                      labelText: 'Remote Peer ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _connect, child: const Text('Connect')),
                ] else ...[
                   Text('Connected to: ${_connection!.peerId}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   ElevatedButton(onPressed: _sendHello, child: const Text('Send "Hello"')),
                   const SizedBox(height: 8),
                   Row(
                     children: [
                       Expanded(child: TextField(controller: _messageController, decoration: const InputDecoration(hintText: 'Type message'))),
                       IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
                     ],
                   ),
                   TextButton(
                     onPressed: () {
                       _connection?.close();
                     }, 
                     child: const Text('Close Connection')
                   ),
                ]
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Logs:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Text(_logs[index], style: const TextStyle(fontSize: 12)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
