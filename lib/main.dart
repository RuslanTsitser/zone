import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';

Future<void> main() async {
  // try {
  //   fineMethod();
  // } catch (e) {
  //   debugPrint('RootZone Caught error standard way: $e');
  // }

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // try {
      //   // await badMethod();
      //   await fineMethod();
      // } catch (e) {
      //   debugPrint('Caught error standard way: $e');
      // }
      FlutterError.onError = (details) {
        debugPrint('Caught error in FlutterError.onError: ${details.exception}');
      };
      WidgetsBinding.instance.platformDispatcher.onError = (err, st) {
        debugPrint('Caught error in platformDispatcher.onError: $err');
        return true;
      };
      runApp(const MyApp());
    },
    (e, s) {
      debugPrint('Caught error in runZonedGuarded.onError: $e');
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late SendPort _sendPort;
  final Completer<void> _isolateReady = Completer.sync();
  static void _startRemoteIsolate(SendPort port) {
    final receivePort = ReceivePort();
    port.send(receivePort.sendPort);
    runZonedGuarded(
      () async {
        receivePort.listen((dynamic message) async {
          throw 'Isolate exception message: $message';
          // port.send(message);
        });
      },
      (e, s) {
        port.send(RemoteError(
          e.toString(),
          s.toString(),
        ));
      },
    );
  }

  Future<void> spawn() async {
    final receivePort = ReceivePort();
    receivePort.listen(_handleResponsesFromIsolate);
    await Isolate.spawn(_startRemoteIsolate, receivePort.sendPort);
  }

  void _handleResponsesFromIsolate(dynamic message) {
    if (message is SendPort) {
      _sendPort = message;
      _isolateReady.complete();
    } else if (message is RemoteError) {
      throw message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              child: const Text('spawn'),
              onPressed: () {
                // asyncError(); // could be caught by runZonedGuarded.onError
                // Future(() => throw "Future exception"); // could be caught by runZonedGuarded.onError
                // syncError(); // could be caught by FlutterError.onError
                // throw "Flutter exception"; // could be caught by FlutterError.onError
                // compute((_) => asyncError(), 'message');
                // compute((_) => syncError(), 'message');
                spawn();
              },
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              onPressed: () {
                // asyncError(); // could be caught by runZonedGuarded.onError
                // Future(() => throw "Future exception"); // could be caught by runZonedGuarded.onError
                // syncError(); // could be caught by FlutterError.onError
                // throw "Flutter exception"; // could be caught by FlutterError.onError
                // compute((_) => asyncError(), 'message');
                // compute((_) => syncError(), 'message');
                // spawn();
                _sendPort.send('message');
              },
            ),
          ],
        ),
      ),
    );
  }
}

void syncError() {
  throw "Sync error";
}

Future<void> asyncError() async {
  Future.delayed(const Duration(seconds: 1), () => throw "Future exception");
  await Future(() {});
}

Future<void> fineMethod() async {
  await asyncError();
}

Future<void> badMethod() async {
  asyncError();
}
