// import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
//import 'package:http/http.dart' as http;
//import 'package:realm/realm.dart';
// import 'package:socket_io_client/socket_io_client.dart';

// import '../models/realm/realm_schemas.dart';
// import 'realm_local_services.dart';

// import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

class SyncService {
  late WebSocketChannel channel;

  final Map<String, String> pendingMessages = {};

  bool pushToWebSocket(Map<String, Object> socketData, String messageId) {
    try {
      // Map<String, Object> socketData = {};
      // final messageId = ObjectId().hexString;
      // if (isDelete) {
      //   socketData = {
      //     "messageId": messageId,
      //     "collectionName": collectionName,
      //     "action": "delete",
      //     "data": jsonEncode({"id": data['id']}),
      //   };
      // } else {
      //   socketData = {
      //     "messageId": messageId,
      //     "collectionName": collectionName,
      //     "action": eventName,
      //     "data": jsonEncode(data),
      //   };
      // }
      //if (socket.connected) {
      if (isWebSocketConnected) {
        debugPrint("Pushing to WebSocket: $socketData");
        pendingMessages[messageId] = jsonEncode(socketData);
        //final response = await socket.emitWithAckAsync("message", socketData);
        channel.sink.add(jsonEncode(socketData));
        return true;
      } else {
        // Handle the case when the socket is not connected
        debugPrint("WebSocket is not connected");
        return false;
      }
    } catch (e) {
      debugPrint("Error pushing to WebSocket: $e");
      return false;
    }
  }

  bool isWebSocketConnected = false;
  void initSocketAsync() async {
    final wsUrl = Uri.parse('ws://192.168.1.7:3000');
    channel = WebSocketChannel.connect(wsUrl);

    try {
      await channel.ready;
      isWebSocketConnected = true;
      debugPrint("Connected to WebSocket Server");
    } on SocketException catch (e) {
      // Handle the exception.
      debugPrint("Connect Error: $e");
    } on WebSocketChannelException catch (e) {
      // Handle the exception.
      debugPrint("Connect Error: $e");
    }
  }

  void closeWebSocketChannel() {
    channel.sink.close();
    debugPrint("WebSocket channel closed");
  }

  void disconnectWebSocketAndClean() {
    try {
      channel.sink.close();
      debugPrint("WebSocket channel closed");
    } catch (e) {
      debugPrint("Error closing WebSocket channel: $e");
    }
    pendingMessages.clear();
    isWebSocketConnected = false;
    debugPrint("Pending messages cleared and connection flags reset");
  }
}
