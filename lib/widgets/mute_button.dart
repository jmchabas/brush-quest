import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class MuteButton extends StatefulWidget {
  const MuteButton({super.key});

  @override
  State<MuteButton> createState() => _MuteButtonState();
}

class _MuteButtonState extends State<MuteButton> {
  bool _muted = AudioService().isMuted;

  void _toggle() {
    AudioService().toggleMute();
    setState(() => _muted = AudioService().isMuted);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _toggle,
      icon: Icon(
        _muted ? Icons.volume_off : Icons.volume_up,
        color: Colors.white70,
        size: 28,
      ),
    );
  }
}
