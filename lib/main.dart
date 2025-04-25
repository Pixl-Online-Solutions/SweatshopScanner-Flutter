import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:video_player/video_player.dart';
import 'package:lottie/lottie.dart';
import 'ticket_api_service.dart';
import 'event_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? lastResult;
  Event? selectedEvent;

  void updateLastResult(String result) {
    setState(() {
      lastResult = result;
    });
  }

  void setSelectedEvent(Event event) {
    setState(() {
      selectedEvent = event;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: selectedEvent == null
          ? EventSelectionScreen(
              onEventSelected: (event) {
                setSelectedEvent(event);
              },
            )
          : LandingScreen(
              lastResult: lastResult,
              onUpdateLastResult: updateLastResult,
              // event: selectedEvent, (add to LandingScreen constructor in future if needed)
            ),
    );
  }
}

class LandingScreen extends StatefulWidget {
  final String? lastResult;
  final void Function(String) onUpdateLastResult;
  const LandingScreen({super.key, this.lastResult, required this.onUpdateLastResult});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late VideoPlayerController _videoController;
  bool _showVideo = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/background_video.mp4')
      ..setLooping(true)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _videoController.play();
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_showVideo && _initialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController.value.size.width,
                height: _videoController.value.size.height,
                child: VideoPlayer(_videoController),
              ),
            )
          else
            Image.asset(
              'assets/images/static_bg.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/sweatshop_logo.png',
                    height: 100,
                  ),
                  const SizedBox(height: 32),
                  if (widget.lastResult != null) ...[
                    Text(
                      'Last Result:',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        widget.lastResult!,
                        style: const TextStyle(fontSize: 16, color: Colors.greenAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QRScannerScreen(),
                        ),
                      );
                      if (result is String) {
                        widget.onUpdateLastResult(result);
                      }
                    },
                    child: const Text('Scan Ticket'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManualEntryScreen(),
                        ),
                      );
                      if (result is String) {
                        widget.onUpdateLastResult(result);
                      }
                    },
                    child: const Text('Manual Entry'),
                  ),
                  const SizedBox(height: 32),
                  IconButton(
                    icon: Icon(_showVideo ? Icons.image : Icons.videocam, color: Colors.white),
                    tooltip: _showVideo ? 'Switch to image' : 'Switch to video',
                    onPressed: () {
                      setState(() {
                        _showVideo = !_showVideo;
                        if (_showVideo && _initialized) {
                          _videoController.play();
                        } else {
                          _videoController.pause();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  String? qrData;
  bool isLoading = false;
  String? apiResult;
  bool? lastValid;

  Future<void> _showLottieModal(bool valid) async {
    final compositionCompleter = Completer<LottieComposition>();
    AnimationController? animationController;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Center(
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Lottie.asset(
                      valid ? 'assets/lottie/success_animation.json' : 'assets/lottie/error_animation.json',
                      repeat: false,
                      controller: animationController,
                      onLoaded: (composition) {
                        compositionCompleter.complete(composition);
                        animationController = AnimationController(
                          vsync: NavigatorState(),
                          duration: Duration(milliseconds: (composition.duration.inMilliseconds * 0.75).round()),
                        );
                        animationController!.forward();
                        setState(() {}); // To trigger rebuild with controller
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Only close modal
                    },
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _verifyTicket(String code) async {
    setState(() {
      isLoading = true;
      apiResult = null;
    });
    final result = await TicketApiService.verifyTicket(code);
    setState(() {
      isLoading = false;
      if (!result.success) {
        apiResult = result.message ?? 'Verification failed.';
        _provideHapticFeedback(false);
        lastValid = false;
      } else if (result.valid) {
        apiResult = 'Valid ticket! Check-in successful at ${result.checkedInTime ?? "-"}';
        _provideHapticFeedback(true);
        lastValid = true;
      } else if (result.message == "Already used") {
        apiResult = 'Ticket already used at ${result.checkedInTime ?? "-"}';
        _provideHapticFeedback(false);
        lastValid = false;
      } else if (result.message == "Expired") {
        apiResult = 'Ticket has expired';
        _provideHapticFeedback(false);
        lastValid = false;
      } else {
        apiResult = 'Invalid ticket';
        _provideHapticFeedback(false);
        lastValid = false;
      }
    });
    if (lastValid != null) {
      await _showLottieModal(lastValid!);
    }
    // Return result to landing screen
    if (apiResult != null) {
      Navigator.of(context).pop(apiResult);
    }
  }

  void _provideHapticFeedback(bool success) {
    HapticFeedback.mediumImpact();
    if (!success) {
      HapticFeedback.vibrate();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && qrData != barcodes.first.rawValue) {
      final code = barcodes.first.rawValue ?? '';
      if (code.isNotEmpty) {
        setState(() {
          qrData = code;
        });
        _verifyTicket(code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('QR Scanner')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          // Square viewfinder overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
              ),
            ),
          ),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: apiResult != null
                  ? Text(apiResult!, style: const TextStyle(fontSize: 18, color: Colors.white))
                  : qrData != null
                      ? Text('Scanned: ${qrData!}', style: const TextStyle(color: Colors.white))
                      : const Text('Scan a code', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final TextEditingController _controller = TextEditingController();
  String? submittedNumber;
  String? errorText;
  bool isLoading = false;
  String? apiResult;
  bool? lastValid;

  static final RegExp ticketRegExp = RegExp(r'^[0-9]{3}-[0-9]{2}-[0-9]{6}$');

  Future<void> _showLottieModal(bool valid) async {
    final compositionCompleter = Completer<LottieComposition>();
    AnimationController? animationController;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Center(
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Lottie.asset(
                      valid ? 'assets/lottie/success_animation.json' : 'assets/lottie/error_animation.json',
                      repeat: false,
                      controller: animationController,
                      onLoaded: (composition) {
                        compositionCompleter.complete(composition);
                        animationController = AnimationController(
                          vsync: NavigatorState(),
                          duration: Duration(milliseconds: (composition.duration.inMilliseconds * 0.75).round()),
                        );
                        animationController!.forward();
                        setState(() {}); // To trigger rebuild with controller
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Only close modal
                    },
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _verifyTicket(String code) async {
    setState(() {
      isLoading = true;
      apiResult = null;
    });
    final result = await TicketApiService.verifyTicket(code);
    setState(() {
      isLoading = false;
      if (!result.success) {
        apiResult = result.message ?? 'Verification failed.';
        _provideHapticFeedback(false);
        lastValid = false;
      } else if (result.valid) {
        apiResult = 'Valid ticket! Check-in successful at ${result.checkedInTime ?? "-"}';
        _provideHapticFeedback(true);
        lastValid = true;
      } else if (result.message == "Already used") {
        apiResult = 'Ticket already used at ${result.checkedInTime ?? "-"}';
        _provideHapticFeedback(false);
        lastValid = false;
      } else if (result.message == "Expired") {
        apiResult = 'Ticket has expired';
        _provideHapticFeedback(false);
        lastValid = false;
      } else {
        apiResult = 'Invalid ticket';
        _provideHapticFeedback(false);
        lastValid = false;
      }
    });
    if (lastValid != null) {
      await _showLottieModal(lastValid!);
    }
    // Return result to landing screen
    if (apiResult != null) {
      Future.delayed(const Duration(milliseconds: 700), () {
        Navigator.of(context).pop(apiResult);
      });
    }
  }

  void _provideHapticFeedback(bool success) {
    HapticFeedback.mediumImpact();
    if (!success) {
      HapticFeedback.vibrate();
    }
  }

  void _validateAndSubmit() {
    final input = _controller.text.trim();
    final digitsOnly = input.replaceAll('-', '');
    if (digitsOnly.length != 11) {
      setState(() {
        errorText = 'Must be exactly 11 digits (XXX-XX-XXXXXX)';
        submittedNumber = null;
      });
      return;
    }
    if (!ticketRegExp.hasMatch(input)) {
      setState(() {
        errorText = 'Format must be XXX-XX-XXXXXX (numbers only)';
        submittedNumber = null;
      });
      return;
    }
    setState(() {
      errorText = null;
      submittedNumber = input;
    });
    _verifyTicket(input);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Manual Entry')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _controller,
              maxLength: 13,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
                TicketNumberDashFormatter(),
              ],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Enter Ticket Number',
                border: const OutlineInputBorder(),
                errorText: errorText,
                hintText: 'XXX-XX-XXXXXX',
                counterText: '',
              ),
              onChanged: (_) {
                setState(() {
                  errorText = null;
                  apiResult = null;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : _validateAndSubmit,
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit'),
            ),
            if (apiResult != null) ...[
              const SizedBox(height: 20),
              Text(apiResult!, style: const TextStyle(fontSize: 18, color: Colors.white)),
            ]
          ],
        ),
      ),
    );
  }
}

class TicketNumberDashFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll('-', '');
    if (digits.length > 11) digits = digits.substring(0, 11);
    var buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 2 || i == 4) {
        buffer.write('-');
      }
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
