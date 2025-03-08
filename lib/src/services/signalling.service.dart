import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SignallingService {
  // instance of Socket
  Socket? socket;
  WebSocketChannel? wsChannel;
  SignallingService._();
  static final instance = SignallingService._();

  init({required String websocketUrl, required String selfCallerID}) {
    // init Socket
    debugPrint(websocketUrl);
    try {
      socket = io(websocketUrl, {
        "transports": ['websocket'],
        "query": {"callerId": selfCallerID},
      });

      // listen onConnect event
      socket!.onConnect((data) {
        log("Socket connected !!");
      });

      // listen onConnectError event
      socket!.onConnectError((data) {
        log("Connect Error $data");
      });

      // connect socket
      socket!.connect();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void init2({required String websocketUrl, required String selfCallerID}) {
    wsChannel = WebSocketChannel.connect(Uri.parse(websocketUrl));

    wsChannel!.stream.listen((message) {
      debugPrint('Signaling data received: $message');
      // Handle SDP or ICE candidates
    });
  }
}
