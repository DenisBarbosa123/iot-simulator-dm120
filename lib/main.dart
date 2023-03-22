import 'dart:io';
import 'package:dm120_mqtt_client/local_notification.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'thermometer_widget.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  final client = MqttServerClient('test.mosquitto.org', '');
  var pongCount = 0;
  double _temp = 20;
  double _hum = 50;

  @override
  void initState() {
    super.initState();
    ///Initialize notification component
    LocalNotification.initialize(flutterLocalNotificationsPlugin);

    ///Connect mqtt client
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _connect());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: SizedBox(
          child: ThermometerWidget(
          borderColor: Colors.red,
          innerColor: Colors.green,
          indicatorColor: Colors.red,
          temperature: _temp
    ),
    ),
    ),

    );
  }

  _connect() async {
    ///Configuring mqtt client
    client.logging(on: true);
    client.setProtocolV311();
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 2000; // milliseconds
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;
    client.pongCallback = pong;

    final connMess = MqttConnectMessage()
        .withClientIdentifier('Mqtt_MyClientUniqueId')
        .withWillTopic(
        'willtopic') // If you set this you must set a will message
        .withWillMessage('My Will message')
        .startClean() // Non persistent session for testing
        .withWillQos(MqttQos.atLeastOnce);

    print('EXAMPLE::Mosquitto client connecting....');

    client.connectionMessage = connMess;

    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      /// Raised by the client when connection fails.
      print('EXAMPLE::client exception - $e');
      client.disconnect();
    } on SocketException catch (e) {
      /// Raised by the socket layer
      print('EXAMPLE::socket exception - $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('EXAMPLE::Mosquitto client connected');
    } else {
      print(
          'EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, status is ${client
              .connectionStatus}');
      client.disconnect();
      exit(-1);
    }

    print('EXAMPLE::Subscribing to the wokwi-iot-simulator-dm120/test');
    const topic = 'wokwi-iot-simulator-dm120/test';
    client.subscribe(topic, MqttQos.atMostOnce);

    ///Listener used to capture messages
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt =
      MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      print(
          'EXAMPLE::Change notification:: topic is <${c[0]
              .topic}>, payload is <-- $pt -->');
      print('');

      Map responsePayload = json.decode(pt);
      print(responsePayload);

      ///Update values received from mqtt server
      setState(() {
        _temp = double.parse(responsePayload['temperature'].toString());
        _hum = double.parse(responsePayload['humidity'].toString());
      });

      ///Show notification after receiving message
      LocalNotification.showBigTextNotification(
          title: "Humidity Alert",
          body: "Your soil has humidity of $_hum",
          fln: flutterLocalNotificationsPlugin);
    });

    return 0;
  }

  /// The subscribed callback
  void onSubscribed(String topic) {
    print('EXAMPLE::Subscription confirmed for topic $topic');
  }

  /// The unsolicited disconnect callback
  void onDisconnected() {
    print('EXAMPLE::OnDisconnected client callback - Client disconnection');
    if (client.connectionStatus!.disconnectionOrigin ==
        MqttDisconnectionOrigin.solicited) {
      print('EXAMPLE::OnDisconnected callback is solicited, this is correct');
    } else {
      print(
          'EXAMPLE::OnDisconnected callback is unsolicited or none, this is incorrect - exiting');
      exit(-1);
    }
    if (pongCount == 3) {
      print('EXAMPLE:: Pong count is correct');
    } else {
      print('EXAMPLE:: Pong count is incorrect, expected 3. actual $pongCount');
    }
  }

  /// The successful connect callback
  void onConnected() {
    print(
        'EXAMPLE::OnConnected client callback - Client connection was successful');
  }

  /// Pong callback
  void pong() {
    print('EXAMPLE::Ping response client callback invoked');
    pongCount++;
  }
}