// import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:E3InspectionsMultiTenant/src/bloc/users_bloc.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SyncService {
  late WebSocketChannel channel;

  final Map<String, String> pendingMessages = {};

  bool pushToWebSocket(Map<String, Object> socketData, String messageId) {
    try {
      if (isWebSocketConnected) {
        //add client Id
        if (usersBloc.userDetails.username != null) {
          socketData['clientId'] = usersBloc.userDetails.username!;
        }
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
  Future<void> initSocketAsync() async {
    final wsUrl = Uri.parse(
      'ws://deckmultitenantwebservices-dev.azurewebsites.net',
    );
    //final wsUrl = Uri.parse('ws://192.168.1.3:3000/');
    channel = WebSocketChannel.connect(wsUrl);

    try {
      await channel.ready;
      isWebSocketConnected = true;
      var clientData = jsonEncode({
        "clientId": usersBloc.userDetails.username,
        "companyIdentifier": usersBloc.userDetails.companyidentifer,
        "deviceId": usersBloc.userDetails.deviceId,
      });
      channel.sink.add(clientData);
      debugPrint("Connected to WebSocket Server and registered client.");
    } on SocketException catch (e) {
      // Handle the exception.
      debugPrint("Connect Error: $e");
      isWebSocketConnected = false;
    } on WebSocketChannelException catch (e) {
      // Handle the exception.
      debugPrint("Connect Error: $e");
      isWebSocketConnected = false;
    }
  }

  void closeWebSocketChannel() {
    channel.sink.close();
    debugPrint("WebSocket channel closed");
    isWebSocketConnected = false;
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
