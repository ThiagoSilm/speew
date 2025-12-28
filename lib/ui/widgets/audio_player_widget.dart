import 'package:flutter/material.dart';
import '../../core/audio/audio_service.dart';

/// Widget de player de áudio para mensagens de voz
class AudioPlayerWidget extends StatefulWidget {
  final String audioFilePath; // Caminho simulado do arquivo de áudio
  final bool isMe;

  const AudioPlayerWidget({
    Key? key,
    required this.audioFilePath,
    required this.isMe,
  }) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioService _audioService = AudioService();
  
  // Estados reais do player
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    _audioService.getAudioDuration(widget.audioFilePath).then((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });
    
    // Escutar mudanças de estado e posição
    _audioService.playingStateStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });
    
    _audioService.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      _audioService.pauseAudioMessage();
    } else {
      _audioService.playAudioMessage(widget.audioFilePath);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final playColor = widget.isMe ? Colors.blue[700] : Colors.grey[700];
    final sliderColor = widget.isMe ? Colors.blue : Colors.grey;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botão Play/Pause
        InkWell(
          onTap: _togglePlayPause,
          child: Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            size: 32,
            color: playColor,
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Barra de Progresso
        Expanded(
          child: Slider(
            min: 0.0,
            max: _totalDuration,
            value: _currentPosition.inSeconds.toDouble(),
            onChanged: (newValue) {
              // Não permite arrastar durante a reprodução simulada
            },
            onChangeEnd: (newValue) {
              _audioService.seekAudioMessage(Duration(seconds: newValue.round()));
            },
            activeColor: sliderColor,
            inactiveColor: sliderColor?.withOpacity(0.3),
          ),
        ),
        
        // Duração
        Text(
          _formatDuration(_totalDuration - _currentPosition),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
