import 'package:flutter/material.dart';

class VoiceHomeScreen extends StatefulWidget {
  const VoiceHomeScreen({Key? key}) : super(key: key);

  @override
  State<VoiceHomeScreen> createState() => _VoiceHomeScreenState();
}

class _VoiceHomeScreenState extends State<VoiceHomeScreen> with SingleTickerProviderStateMixin {
  bool _isListening = false;
  String _statusText = "Kaam bolne ke liye mic dabayein";
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.85,
      upperBound: 1.15,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _pulseController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _pulseController.forward();
        }
      });
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _statusText = "Suno rahe hain... Bolein!";
        _pulseController.forward();
        // TODO: Trigger record_audio package & audio stream
      } else {
        _statusText = "Aapki aawaz record ho gayi hai";
        _pulseController.stop();
        _pulseController.reset();
        // TODO: Stop recording & dispatch to /api/voice/process Express endpoint
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // High contrast dark theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text(
          "BoloKaam",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up, color: Colors.amber, size: 28),
            onPressed: () {
              // Play instruction audio in Hindi/Regional dialect
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 20),
            
            // Audio Prompt Display / Transcript
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.record_voice_over, color: Colors.amber, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _statusText,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pulsing Mic Button (Central Touch Target)
            ScaleTransition(
              scale: _pulseController,
              child: GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.redAccent : Colors.amber,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.redAccent : Colors.amber).withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 80,
                    color: Colors.black,
                  ),
                ),
              ),
            ),

            // Quick Voice Keyword Buttons (Zero-Typing Shortcuts)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickAudioChip("🏗️ Mistri"),
                  _buildQuickAudioChip("🚚 Driver"),
                  _buildQuickAudioChip("📦 Loader"),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAudioChip(String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF333333),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      onPressed: () {
        // Quick select category via voice trigger
      },
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}
