import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/texttospeech/v1.dart';
import 'package:http/http.dart' as http;
import 'package:dialogflow_flutter/dialogflowFlutter.dart';
import 'package:dialogflow_flutter/googleAuth.dart';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:geocoding/geocoding.dart';
import 'package:location_platform_interface/location_platform_interface.dart';
import 'package:location/location.dart' as loc;

import 'package:flutter_tts/flutter_tts.dart';
import 'package:soundpool/soundpool.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
  var colors = [Colors.blue, Colors.red, Colors.yellow];
  int _value = 0;
  String apiKey = 'AIzaSyCWfrH1QTMtwdDpJ4KrmwEDT92ulz-9phg';

  // Speech to tex
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

  Timer _timer = Timer(Duration.zero, () {});
  int _shakeCount = 0;
  double _previousX = 4;
  final FlutterTts flutterTts = FlutterTts();

  List<double>? _accelerometerValues;
  List<double>? _userAccelerometerValues;
  List<double>? _gyroscopeValues;
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];

  @override
  Widget build(BuildContext context) {
    final accelerometer =
        _accelerometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final gyroscope =
        _gyroscopeValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final userAccelerometer = _userAccelerometerValues
        ?.map((double v) => v.toStringAsFixed(1))
        .toList();

    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('Sensor Example'),
        ),
        body: Container(
          decoration: BoxDecoration(
              image: DecorationImage(
            image: AssetImage('assets/img/micro.gif'),
            fit: BoxFit.contain,
          )),
        ));
  }

  @override
  void dispose() {
    super.dispose();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    initSpeechState();
    _streamSubscriptions.add(accelerometerEvents.listen((event) {
      setState(() {
        _accelerometerValues = <double>[event.x, event.y, event.z];

        double currentX = event.x;
        //print("prev: " + _previousX.toString() + '   ' + currentX.toString());
        if (_previousX > 1 && currentX < -1) {
          //agitado de derecha a izquierda
          _shakeCount++;
          if (_shakeCount >= 2) {
            startWizard();
          } else {
            if (_timer != null) _timer.cancel();
            
            _timer = Timer(Duration(seconds: 2), () {
              setState(() {
                _shakeCount = 0;
              });
            });
          }
        }

        _previousX = currentX;
      });
    }));
  }

  Future<void> playSound(String path) async {
    Soundpool pool = Soundpool(streamType: StreamType.notification);
    String audioasset = path;
    int soundId = await rootBundle.load(audioasset).then((ByteData soundData) {
      return pool.load(soundData);
    });

    int streamId = await pool.play(soundId);
  }

  speak(String text) async {
    await flutterTts.setLanguage("es-ES");
    await flutterTts.setPitch(1);
    await flutterTts.speak(text);
  }

  Future<void> synthesizeText(String text) async {
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

  Future<void> sendMessage(String message) async {
    AuthGoogle authGoogle =
        await AuthGoogle(fileJson: "assets/json/ihc-eyqw-40780e429e02.json")
            .build();
    DialogFlow dialogFlow = DialogFlow(authGoogle: authGoogle);
    AIResponse response = await dialogFlow.detectIntent(message);
    String text = response.getMessage() ?? "No response";
    print("dialog: $text");

    if (text.toLowerCase() == 'ubicacion') {
      getCurrentAddress();
    } else {
      synthesizeText(text);
    }

    // synthesizeText("viendo luegaressssss");
    // getCurrentPlaces();

    //synthesizeText("Porfavor agita nuevamente el celular, no te escuché bien...");
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

      if (!mounted) return;

      setState(() {
        _hasSpeech = hasSpeech;
      });
    } catch (e) {
      setState(() {
        lastError = 'Speech recognition failed: ${e.toString()}';
        _hasSpeech = false;
      });
    }
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

    setState(() {});
  }

  void resultListener(SpeechRecognitionResult result) {
    _logEvent(
        'Result listener final: ${result.finalResult}, words: ${result.recognizedWords}');
    setState(() {
      if (result.finalResult) {
        print("palabra final: ${result.recognizedWords}");
        sendMessage('${result.recognizedWords}');
      } else
        lastWords = '${result.recognizedWords} - ${result.finalResult}';
    });
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
    setState(() {
      lastError = '${error.errorMsg} - ${error.permanent}';
    });
  }

  void statusListener(String status) {
    _logEvent(
        'Received listener status: $status, listening, ${speech.isListening}');
    setState(() {
      lastStatus = '$status';
    });
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
    setState(() {
      this.level = level;
    });
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

    // if (_readySpeech) {
    //   if (_hasSpeech) startListening();
    // }
    //sendMessage("Cual es la parada de micro mas cercana");
  }

  // Método para indicar al usuario su ubicación actual
  void getCurrentAddress() async {
    loc.Location location = loc.Location();
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    loc.LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      synthesizeText('Debes activar la ubicación para poder ayudarte');
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        synthesizeText('¡Lo siento!, pero sin la ubicación no podré ayudarte');
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == loc.PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != loc.PermissionStatus.granted) {
        print('Prueba2');
        return;
      }
    }

    _locationData = await location.getLocation();
    if (_locationData != null) {
      List<Placemark> placemark = await placemarkFromCoordinates(
          _locationData.latitude!, _locationData.longitude!);
      if (placemark != null && placemark.isNotEmpty) {
        String street = '', state = '', city = '', country = '';
        //print("lugar: " + placemark[1].toJson().toString());
        for (var address in placemark) {
          print(address.toJson());
          //Placemark address = placemark[1];
          street = (address.thoroughfare != null) ? address.thoroughfare! : '';
          state = (address.name != null) ? address.name! : '';
          city = (address.administrativeArea != null)
              ? address.administrativeArea!
              : '';
          country = (address.country != null) ? address.country! : '';
        }

        print("Te encuentras en $street, $city, $state, $country");
        synthesizeText("Te encuentras en $street, $city, $state, $country");
      }
    }
  }

  Future<void> getCurrentPlaces() async {
    final location = loc.Location();
    bool isLocationEnabled = await location.serviceEnabled();

    if (!isLocationEnabled) {
      synthesizeText('Debes activar la ubicación para poder ayudarte');
      isLocationEnabled = await location.requestService();
      if (!isLocationEnabled) {
        synthesizeText('¡Lo siento!, pero sin la ubicación no podré ayudarte');
        return;
      }
    }

    final position = await location.getLocation();
    final latitude = position.latitude;
    final longitude = position.longitude;

    String baseUrl = 'https://api.foursquare.com/v3/places/search';
    final clientId = 'YH25OFTVW31WFWFNR04TANHJZOPQ4SQWMGU0RVZ0BAN1PBSW';
    final clientSecret = 'B5KGNFNTGNU2GFRIQRWSBXM0G1AIFVBTB5Z54MX5NFUXRHEE';
    final version = '20230215';
    final url = '$baseUrl?client_id=$clientId&client_secret=$clientSecret&v=$version&ll=$latitude,$longitude';

    final response = await http.get(Uri.parse(url));
    print("venues rb: " + response.body.toString());
    if (response.statusCode == 200) {
      Map<String, dynamic> jsonResponse = json.decode(response.body);
      List<dynamic> venues = jsonResponse['response']['venues'];
      print('venues: $venues');
    }else{
      print('venues: error al cargar lugares');
    }
  }
}
