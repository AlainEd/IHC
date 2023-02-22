import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:location_platform_interface/location_platform_interface.dart';
import 'package:location/location.dart' as loc;
import 'package:app_settings/app_settings.dart';

import 'package:flutter_background_service/flutter_background_service.dart'
    show
        AndroidConfiguration,
        FlutterBackgroundService,
        IosConfiguration,
        ServiceInstance;
import 'package:flutter/material.dart';
import 'background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeService();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({
    Key? key,
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String text = "Stop Service";

  @override
  void initState() {
    super.initState();
    requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Voice Bot"),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              //for listen Continuous change in foreground we will be using Stream builder
              StreamBuilder<Map<String, dynamic>?>(
                  stream: FlutterBackgroundService().on('update'),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    final data = snapshot.data!;
                    int? counter = data["counter"];
                    DateTime? date = DateTime.tryParse(data["current_date"]);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Counter => $counter'),
                        Text(date.toString()),
                      ],
                    );
                  }),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 20),
                      decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(16)),
                      child: const Text(
                        "Foreground Mode",
                        style: TextStyle(color: Colors.white),
                      )),
                  onTap: () {
                    FlutterBackgroundService().invoke("setAsForeground");
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 20),
                      decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(16)),
                      child: const Text(
                        "Background Mode",
                        style: TextStyle(color: Colors.white),
                      )),
                  onTap: () {
                    print('start');
                    FlutterBackgroundService().invoke("setAsBackground");
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(16)),
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  onTap: () async {
                    final service = FlutterBackgroundService();
                    //final service = widget.appStateService.service;
                    var isRunning = await service.isRunning();
                    if (isRunning) {
                      service.invoke("stopService");
                    } else {
                      service.startService();
                    }

                    if (!isRunning) {
                      text = 'Stop Service';
                    } else {
                      text = 'Start Service';
                    }
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void requestPermission() async {
    loc.Location location = loc.Location();
    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;
    loc.LocationData _locationData;
    

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      synthesizeText('Debes activar la ubicación para poder ayudarte');
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        synthesizeText('¡Lo siento!, pero no podré ayudarte a saber tu ubicación...');
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == loc.PermissionStatus.denied) {
      synthesizeText('Debes activar el permiso para poder acceder siempre a la ubicación...');
      AppSettings.openAppSettings();
      if (_permissionGranted != loc.PermissionStatus.granted) {
        print('Prueba2');
        return;
      }
    }
  }
}
