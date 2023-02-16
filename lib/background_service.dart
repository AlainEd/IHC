// import 'dart:ui';
// import 'dart:async';
// import 'dart:math';
// import 'dart:convert';
// import 'package:flutter/services.dart';
// import 'package:flutter/material.dart';

// // Request http
// import 'package:http/http.dart' as http;
// import 'package:proyecto_ihc/main.dart';
// import 'package:soundpool/soundpool.dart';

// // Sensores
// import 'package:sensors_plus/sensors_plus.dart';

// // Speech to text
// import 'package:speech_to_text/speech_recognition_error.dart';
// import 'package:speech_to_text/speech_recognition_result.dart';
// import 'package:speech_to_text/speech_to_text.dart';

// //Dialog flow
// import 'package:dialogflow_flutter/dialogflowFlutter.dart';
// import 'package:dialogflow_flutter/googleAuth.dart';

// // Ubicacion
// import 'package:geocoding/geocoding.dart';
// import 'package:location_platform_interface/location_platform_interface.dart';
// import 'package:location/location.dart' as loc;

// import 'package:flutter_background_service_android/flutter_background_service_android.dart';

// import 'package:flutter_background_service/flutter_background_service.dart'
//     show
//         AndroidConfiguration,
//         FlutterBackgroundService,
//         IosConfiguration,
//         ServiceInstance;
// import 'package:flutter_tts/flutter_tts.dart';

// final service = FlutterBackgroundService();
// final flutterTts = FlutterTts();

// // var Shake
// int _shakeCount = 0;
// Timer _timer = Timer(Duration.zero, () {});
// double _previousX = 4;
// List<double>? _accelerometerValues;
// List<double>? _userAccelerometerValues;
// List<double>? _gyroscopeValues;
// final _streamSubscriptions = <StreamSubscription<dynamic>>[];

// bool _hasSpeech = false;
// bool _logEvents = true;
// bool _onDevice = false;
// bool _readySpeech = false;
// final int _pauseForController = 3; //seconds
// final int _listenForController = 30; //seconds
// double level = 0.0;
// double minSoundLevel = -2.0;
// double maxSoundLevel = 10.0;
// String lastWords = '';
// String lastError = '';
// String lastStatus = '';
// String _currentLocaleId = 'es_BO';
// List<LocaleName> _localeNames = [];
// final SpeechToText speech = SpeechToText();

// loc.Location location = loc.Location();

// Future initializeService() async {
//   startListeningLocation();
//   initSpeechState();
//   _initShakeListen();
//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       // this will executed when app is in foreground or background in separated isolate
//       onStart: onStart,
//       // auto start service
//       autoStart: true,
//       isForegroundMode: true,
//     ),
//     iosConfiguration: IosConfiguration(
//       // auto start service
//       autoStart: true,

//       // this will executed when app is in foreground in separated isolate
//       onForeground: onStart,

//       // you have to enable background fetch capability on xcode project
//       onBackground: onIosBackground,
//     ),
//   );
//   await service.startService();
// }

// bool onIosBackground(ServiceInstance service) {
//   WidgetsFlutterBinding.ensureInitialized();
//   print('FLUTTER BACKGROUND FETCH');

//   return true;
// }

// void onStart(ServiceInstance service) async {
//   DartPluginRegistrant.ensureInitialized();
//   startListeningLocation();
//   initSpeechState();
//   _initShakeListen();
//   if (service is AndroidServiceInstance) {
//     service.on('setAsForeground').listen((event) {
//       //set as foreground
//       service.setAsForegroundService();
//     });

//     service.on('setAsBackground').listen((event) async {
//       //set as background
//       service.setAsBackgroundService();
//     });
//   }

//   service.on('stopService').listen((event) {
//     service.stopSelf();
//   });
//   // bring to foreground
//   Timer.periodic(const Duration(seconds: 1), (timer) async {
//     if (service is AndroidServiceInstance) {
//       service.setForegroundNotificationInfo(
//         title: "My App Service",
//         content: "Updated at ${DateTime.now()}",
//       );
//     }

//     //_startListening();

//     /// you can see this log in logcat
//     //print('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');

//     // test using external plugin
//     service.invoke(
//       'update',
//       {
//         "current_date": DateTime.now().toIso8601String(),
//         "counter": _shakeCount,
//       },
//     );
//   });
// }

// void _initShakeListen() async {
//   _streamSubscriptions.add(accelerometerEvents.listen((event) {
//     _accelerometerValues = <double>[event.x, event.y, event.z];

//     double currentX = event.x;
//     //print("prev: " + _previousX.toString() + '   ' + currentX.toString());
//     if (_previousX > 1 && currentX < -1) {
//       //agitado de derecha a izquierda
//       _shakeCount++;
//       if (_shakeCount >= 2) {
//         startWizard();
//         //synthesizeText("Esta es una prueba de que si funciona");
//         print("prueba");
//       } else {
//         if (_timer != null) _timer.cancel();

//         _timer = Timer(Duration(seconds: 2), () {
//           _shakeCount = 0;
//         });
//       }
//     }

//     _previousX = currentX;
//   }));
// }

// Future<void> synthesizeText(String text) async {
//   String apiKey = 'AIzaSyCWfrH1QTMtwdDpJ4KrmwEDT92ulz-9phg';
//   var url =
//       'https://texttospeech.googleapis.com/v1beta1/text:synthesize?key=$apiKey';
//   var uri = Uri.parse(url);
//   var response = await http.post(uri,
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({
//         "input": {"text": text},
//         "voice": {"languageCode": "es-US", "name": "es-US-Neural2-A"},
//         "audioConfig": {"audioEncoding": "MP3"}
//       }));

//   print("status: " + response.statusCode.toString());

//   if (response.statusCode == 200) {
//     var data = jsonDecode(response.body);
//     print(data.toString());
//     var audioContent = base64.decode(data['audioContent']);
//     Uint8List audioBytes = audioContent;
//     playAudio(audioBytes);
//   } else {
//     // handle error response
//   }
// }

// void playAudio(Uint8List audioBytes) async {
//   var pool = Soundpool();
//   ByteData byteData = ByteData.view(audioBytes.buffer);
//   var soundId = await pool.load(byteData);
//   await pool.play(soundId);
//   print('terminando');
// }

// Future<void> startWizard() async {
//   playSound("assets/audio/ding.mp3");
//   //speak("Hola, ¿Qué necesitas?");
//   synthesizeText("Hola, ¿En que puedo ayudarte?");
//   HapticFeedback.vibrate();

//   Completer<void> completer = Completer<void>();
//   Timer(Duration(seconds: 4), () => completer.complete());
//   await completer.future.then((_) {
//     if (_hasSpeech) {
//       startListening();
//     }
//   });

//   // if (_readySpeech) {
//   //   if (_hasSpeech) startListening();
//   // }
//   //sendMessage("Cual es la parada de micro mas cercana");
// }

// Future<void> playSound(String path) async {
//   Soundpool pool = Soundpool(streamType: StreamType.notification);
//   String audioasset = path;
//   int soundId = await rootBundle.load(audioasset).then((ByteData soundData) {
//     return pool.load(soundData);
//   });

//   int streamId = await pool.play(soundId);
// }

// void startListening() {
//   _logEvent('start listening');
//   lastWords = '';
//   lastError = '';

//   speech.listen(
//     onResult: resultListener,
//     listenFor: Duration(seconds: _listenForController),
//     pauseFor: Duration(seconds: _pauseForController),
//     partialResults: true,
//     localeId: _currentLocaleId,
//     onSoundLevelChange: soundLevelListener,
//     cancelOnError: true,
//     listenMode: ListenMode.confirmation,
//     onDevice: _onDevice,
//   );

//   print('axy: $lastWords');
// }

// void resultListener(SpeechRecognitionResult result) {
//   _logEvent(
//       'Result listener final: ${result.finalResult}, words: ${result.recognizedWords}');

//   if (result.finalResult) {
//     print("palabra final: ${result.recognizedWords}");
//     sendMessage('${result.recognizedWords}');
//   } else
//     lastWords = '${result.recognizedWords} - ${result.finalResult}';
// }

// void _logEvent(String eventDescription) {
//   if (_logEvents) {
//     var eventTime = DateTime.now().toIso8601String();
//     print('evento: $eventTime $eventDescription');
//   }
// }

// void errorListener(SpeechRecognitionError error) {
//   _logEvent(
//       'Received error status: $error, listenening: ${speech.isListening}');

//   lastError = '${error.errorMsg} - ${error.permanent}';
// }

// void statusListener(String status) {
//   _logEvent(
//       'Received listener status: $status, listening, ${speech.isListening}');

//   lastStatus = '$status';
// }

// void soundLevelListener(double level) {
//   minSoundLevel = min(minSoundLevel, level);
//   maxSoundLevel = max(maxSoundLevel, level);
// }

// Future<void> initSpeechState() async {
//   _logEvent('Initialize');

//   try {
//     var hasSpeech = await speech.initialize(
//       onError: errorListener,
//       onStatus: statusListener,
//       debugLogging: _logEvents,
//     );

//     if (hasSpeech) {
//       _localeNames = await speech.locales();

//       var systemLocale = await speech.systemLocale();
//       _currentLocaleId = systemLocale?.localeId ?? '';

//       print('hasSpeech is true');
//     }

//     //if (!mounted) return;

//     _hasSpeech = hasSpeech;
//   } catch (e) {
//     lastError = 'Speech recognition failed: ${e.toString()}';
//     _hasSpeech = false;
//   }
// }

// Future<void> sendMessage(String message) async {
//   AuthGoogle authGoogle =
//       await AuthGoogle(fileJson: "assets/json/ihc-eyqw-40780e429e02.json")
//           .build();
//   DialogFlow dialogFlow = DialogFlow(authGoogle: authGoogle);
//   AIResponse response = await dialogFlow.detectIntent(message);
//   String text = response.getMessage() ?? "No response";
//   print("dialog: $text");

//   if (text.toLowerCase() == 'ubicacion') {
//     getCurrentAddress();
//   } else {
//     synthesizeText(text);
//   }

//   // synthesizeText("viendo luegaressssss");
//   // getCurrentPlaces();

//   //synthesizeText("Porfavor agita nuevamente el celular, no te escuché bien...");
// }

// Future<void> getCurrentAddress() async {
//   // loc.Location location = loc.Location();
//   // bool _serviceEnabled;
//   // PermissionStatus _permissionGranted;
//   // loc.LocationData _locationData;

//   // _serviceEnabled = await location.serviceEnabled();
//   // if (!_serviceEnabled) {
//   //   synthesizeText('Debes activar la ubicación para poder ayudarte');
//   //   _serviceEnabled = await location.requestService();
//   //   if (!_serviceEnabled) {
//   //     synthesizeText('¡Lo siento!, pero sin la ubicación no podré ayudarte');
//   //     return;
//   //   }
//   // }

//   // _permissionGranted = await location.hasPermission();
//   // if (_permissionGranted == loc.PermissionStatus.denied) {
//   //   _permissionGranted = await location.requestPermission();
//   //   if (_permissionGranted != loc.PermissionStatus.granted) {
//   //     print('Prueba2');
//   //     return;
//   //   }
//   // }

//   StreamSubscription<LocationData> streamSubscription = location.onLocationChanged.listen((LocationData locationData) {
//     print('ubi: ' + locationData.latitude.toString());
//     print('ubi: ' + locationData.longitude.toString());
//   });

//   // try {
//   //   // _locationData = await location.getLocation();
//   //   if (_locationData != null) {
//   //     List<Placemark> placemark = await placemarkFromCoordinates(
//   //         _locationData.latitude!, _locationData.longitude!);
//   //     if (placemark != null && placemark.isNotEmpty) {
//   //       String street = '', state = '', city = '', country = '';
//   //       //print("lugar: " + placemark[1].toJson().toString());
//   //       for (var address in placemark) {
//   //         print(address.toJson());
//   //         //Placemark address = placemark[1];
//   //         street = (address.thoroughfare != null) ? address.thoroughfare! : '';
//   //         state = (address.name != null) ? address.name! : '';
//   //         city = (address.administrativeArea != null)
//   //             ? address.administrativeArea!
//   //             : '';
//   //         country = (address.country != null) ? address.country! : '';
//   //       }

//   //       print("Te encuentras en $street, $city, $state, $country");
//   //       synthesizeText("Te encuentras en $street, $city, $state, $country");
//   //     }
//   //   }
//   // } on PlatformException catch (e) {
//   //   // location.changeSettings(interval: 5000);
//   //   // StreamSubscription<LocationData> locationSubscription = location.onLocationChanged.listen((LocationData currentLocation) {
//   //   //   print(currentLocation);
//   //   // });
//   //   synthesizeText(
//   //       "Lo siento, no he podido captar tu ubicación, vuelve a intentarlo...");
//   //   print('Error al obtener la ubicación: ${e.message}');
//   // }
// }

// void startListeningLocation() async {

//   LocationData _locationData;
//   bool _serviceEnabled;
//   PermissionStatus _permissionGranted;
  

//   //try {
//     _serviceEnabled = await location.serviceEnabled();
//     if (!_serviceEnabled) {
//       _serviceEnabled = await location.requestService();
//       if (!_serviceEnabled) {
//         return;
//       }
//     }

//     _permissionGranted = await location.hasPermission();
//     if (_permissionGranted == PermissionStatus.denied) {
//       _permissionGranted = await location.requestPermission();
//       if (_permissionGranted != PermissionStatus.granted) {
//         return;
//       }
//     }

//     _locationData = await location.getLocation();
//     location.enableBackgroundMode(enable: true);

//     print('ubi: $_locationData');
//     print('ubi: ' + _locationData.latitude.toString());
//     print('ubi: ' + _locationData.longitude.toString());
//   // } on PlatformException catch (e) {
//   //   print('error ubi: $e.message');
//   // }
// }
