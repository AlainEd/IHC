import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

// Request http
import 'package:http/http.dart' as http;
import 'package:proyecto_ihc/main.dart';
import 'package:soundpool/soundpool.dart';

// Sensores
import 'package:sensors_plus/sensors_plus.dart';

// Speech to text
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

//Dialog flow
import 'package:dialogflow_flutter/dialogflowFlutter.dart';
import 'package:dialogflow_flutter/googleAuth.dart';

// Ubicacion
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:osm_nominatim/osm_nominatim.dart';

import 'package:flutter_background_service_android/flutter_background_service_android.dart';

import 'package:flutter_background_service/flutter_background_service.dart'
    show
        AndroidConfiguration,
        FlutterBackgroundService,
        IosConfiguration,
        ServiceInstance;
import 'package:flutter_tts/flutter_tts.dart';

final service = FlutterBackgroundService();
final flutterTts = FlutterTts();

// var Shake
int _shakeCount = 0;
Timer _timer = Timer(Duration.zero, () {});
double _previousX = 4;
List<double>? _accelerometerValues;
List<double>? _userAccelerometerValues;
List<double>? _gyroscopeValues;
final _streamSubscriptions = <StreamSubscription<dynamic>>[];

bool _hasSpeech = false;
bool _logEvents = true;
bool _onDevice = false;
bool _readySpeech = false;
final int _pauseForController = 3; //seconds
final int _listenForController = 30; //seconds
double level = 0.0;
double minSoundLevel = -2.0;
double maxSoundLevel = 10.0;
String lastWords = '';
String lastError = '';
String lastStatus = '';
String _currentLocaleId = 'es_BO';
List<LocaleName> _localeNames = [];
final SpeechToText speech = SpeechToText();

String latitude = 'waiting...';
String longitude = 'waiting...';
String _locationValues = 'waiting...';
StreamSubscription<Position>? _positionStreamSubscription;

Future initializeService() async {
  initSpeechState();
  _initShakeListen();
  _initBackgroundLocation();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will executed when app is in foreground or background in separated isolate
      onStart: onStart,
      // auto start service
      autoStart: true,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,

      // this will executed when app is in foreground in separated isolate
      onForeground: onStart,

      // you have to enable background fetch capability on xcode project
      onBackground: onIosBackground,
    ),
  );
  await service.startService();
}

bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  print('FLUTTER BACKGROUND FETCH');

  return true;
}

void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  _initBackgroundLocation();
  initSpeechState();
  _initShakeListen();
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      //set as foreground
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) async {
      //set as background
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
  // bring to foreground
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    final accelerometer =
        _accelerometerValues?.map((double v) => v.toStringAsFixed(1)).toList();

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "My App Service",
        content: "Updated at $_locationValues",
      );
    }

    _initBackgroundLocation();
    // you can see this log in logcat
    print('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');

    // test using external plugin
    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
        "counter": _shakeCount,
      },
    );
  });
}

void _initShakeListen() async {
  _streamSubscriptions.add(accelerometerEvents.listen((event) {
    _accelerometerValues = <double>[event.x, event.y, event.z];

    double currentX = event.x;
    //print("prev: " + _previousX.toString() + '   ' + currentX.toString());
    if (_previousX > 1 && currentX < -1) {
      //agitado de derecha a izquierda
      _shakeCount++;
      if (_shakeCount >= 2) {
        startWizard();
        //synthesizeText("Esta es una prueba de que si funciona");
        print("prueba");
      } else {
        if (_timer != null) _timer.cancel();

        _timer = Timer(Duration(seconds: 2), () {
          _shakeCount = 0;
        });
      }
    }

    _previousX = currentX;
  }));
}

Future<void> synthesizeText(String text) async {
  String apiKey = 'AIzaSyCWfrH1QTMtwdDpJ4KrmwEDT92ulz-9phg';
  var url =
      'https://texttospeech.googleapis.com/v1beta1/text:synthesize?key=$apiKey';
  var uri = Uri.parse(url);
  var response = await http.post(uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "input": {"text": text},
        "voice": {"languageCode": "es-US", "name": "es-US-Neural2-A"},
        "audioConfig": {"audioEncoding": "MP3"}
      }));

  print("status: " + response.statusCode.toString());

  if (response.statusCode == 200) {
    var data = jsonDecode(response.body);
    print(data.toString());
    var audioContent = base64.decode(data['audioContent']);
    Uint8List audioBytes = audioContent;
    playAudio(audioBytes);
  } else {
    // handle error response
  }
}

void playAudio(Uint8List audioBytes) async {
  var pool = Soundpool();
  ByteData byteData = ByteData.view(audioBytes.buffer);
  var soundId = await pool.load(byteData);
  await pool.play(soundId);
  print('terminando');
}

Future<void> startWizard() async {
  playSound("assets/audio/ding.mp3");
  //speak("Hola, ¿Qué necesitas?");
  synthesizeText("Hola, ¿En que puedo ayudarte?");
  HapticFeedback.vibrate();

  Completer<void> completer = Completer<void>();
  Timer(Duration(seconds: 4), () => completer.complete());
  await completer.future.then((_) {
    if (_hasSpeech) {
      startListening();
    }
  });
}

Future<void> playSound(String path) async {
  Soundpool pool = Soundpool(streamType: StreamType.notification);
  String audioasset = path;
  int soundId = await rootBundle.load(audioasset).then((ByteData soundData) {
    return pool.load(soundData);
  });

  int streamId = await pool.play(soundId);
}

void startListening() {
  _logEvent('start listening');
  lastWords = '';
  lastError = '';

  speech.listen(
    onResult: resultListener,
    listenFor: Duration(seconds: _listenForController),
    pauseFor: Duration(seconds: _pauseForController),
    partialResults: true,
    localeId: _currentLocaleId,
    onSoundLevelChange: soundLevelListener,
    cancelOnError: true,
    listenMode: ListenMode.confirmation,
    onDevice: _onDevice,
  );

  print('axy: $lastWords');
}

void resultListener(SpeechRecognitionResult result) {
  _logEvent(
      'Result listener final: ${result.finalResult}, words: ${result.recognizedWords}');

  if (result.finalResult) {
    print("palabra final: ${result.recognizedWords}");
    sendMessage('${result.recognizedWords}');
  } else
    lastWords = '${result.recognizedWords} - ${result.finalResult}';
}

void _logEvent(String eventDescription) {
  if (_logEvents) {
    var eventTime = DateTime.now().toIso8601String();
    print('evento: $eventTime $eventDescription');
  }
}

void errorListener(SpeechRecognitionError error) {
  _logEvent(
      'Received error status: $error, listenening: ${speech.isListening}');

  lastError = '${error.errorMsg} - ${error.permanent}';
}

void statusListener(String status) {
  _logEvent(
      'Received listener status: $status, listening, ${speech.isListening}');

  lastStatus = '$status';
}

void soundLevelListener(double level) {
  minSoundLevel = min(minSoundLevel, level);
  maxSoundLevel = max(maxSoundLevel, level);
}

Future<void> initSpeechState() async {
  _logEvent('Initialize');

  try {
    var hasSpeech = await speech.initialize(
      onError: errorListener,
      onStatus: statusListener,
      debugLogging: _logEvents,
    );

    if (hasSpeech) {
      _localeNames = await speech.locales();

      var systemLocale = await speech.systemLocale();
      _currentLocaleId = systemLocale?.localeId ?? '';

      print('hasSpeech is true');
    }

    //if (!mounted) return;

    _hasSpeech = hasSpeech;
  } catch (e) {
    lastError = 'Speech recognition failed: ${e.toString()}';
    synthesizeText('Estoy teniendo problemas con el micrófono...');
    _hasSpeech = false;
  }
}

Future<void> sendMessage(String message) async {
  AuthGoogle authGoogle =
      await AuthGoogle(fileJson: "assets/json/ihc-eyqw-40780e429e02.json")
          .build();
  DialogFlow dialogFlow = DialogFlow(authGoogle: authGoogle);
  AIResponse response = await dialogFlow.detectIntent(message);
  String text = response.getMessage() ?? "No response";
  print("dialog: $text");

  switch (text.toLowerCase()) {
    case 'ubicacion':
      getCurrentLocation();
      break;
    case 'lugares':
      getCurrentPlaces('');
      break;
    case 'tiendas':
      getCurrentPlaces('grocery');
      break;
    case 'restaurant':
      getCurrentPlaces('restaurant');
      break;
    case 'No response':
      synthesizeText("Porfavor agita nuevamente el celular, no te escuché bien...");
      break;
    default:
      synthesizeText(text);
  }
  // synthesizeText("viendo luegaressssss");
  // getCurrentPlaces();

  
}

void getCurrentLocation() async {
  final reverseResult = await Nominatim.reverseSearch(
    lat: double.parse(latitude),
    lon: double.parse(longitude),
    addressDetails: true,
    extraTags: true,
    nameDetails: true,
  );

  List<Placemark> placemark = await placemarkFromCoordinates(
      double.parse(latitude), double.parse(longitude));
  String street = '', thoroughfare = '';
  if (placemark != null && placemark.isNotEmpty) {
    for (var address in placemark) {
      //print('places: ${address.toJson()}');
      if (street.isEmpty)
        street = isAddress(address.street!) ? address.street! : '';

      if (thoroughfare.isEmpty)
        thoroughfare =
            isAddress(address.thoroughfare!) ? address.thoroughfare! : '';

      // print("Te encuentras en $street, $city, $state, $country");
      // synthesizeText("Te encuentras en $street, $state, $city, $country");
    }

    print('ubicacion: $street, $thoroughfare, $thoroughfare');
  }

  synthesizeText(
      'Te encuentras en $street, $thoroughfare ,${reverseResult.displayName}');
}

bool isAddress(String address) {
  if (address.length < 3) return false;

  String addressStreet = address.substring(0, 2).toLowerCase();
  if (addressStreet == 'ca' || addressStreet == 'av' || addressStreet == 'ba')
    return true;
  return false;
}

Future<void> getCurrentPlaces(String keyword) async {
  List<dynamic> places = [];
  String apiKey = 'AIzaSyCWfrH1QTMtwdDpJ4KrmwEDT92ulz-9phg';
  String url =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=100&keyword=$keyword&key=$apiKey';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    Map<String, dynamic> data = json.decode(response.body);
    places = data['results'];
    String lugares = '';
    for (var i = 0; i < places.length; i++) {
      print('data: ' + places[i].toString());
      String place = places[i]['name'];
      lugares += '${place.toLowerCase()}, ';
    }
    print('lugares: $lugares');
    if (lugares.length > 1) {
      synthesizeText('Encontré los siguientes lugares: $lugares');
    }else{
      synthesizeText('No encontré lugares cercanos...');
    }
  } else {
    synthesizeText('Error al obtener la ubicación...');
  }
}


Future<void> _initBackgroundLocation() async {
  print('empezando con la ubicacion');
  final LocationSettings locationSettings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
    forceLocationManager: true,
  );
  _positionStreamSubscription = Geolocator.getPositionStream(
    locationSettings: locationSettings,
  ).listen((Position position) {
    print(position);
    _locationValues =
        position.latitude.toString() + ', ' + position.longitude.toString();
    longitude = position.longitude.toString();
    latitude = position.latitude.toString();
  });
}
