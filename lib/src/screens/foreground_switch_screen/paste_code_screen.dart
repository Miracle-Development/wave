import 'package:flutter/material.dart';
import 'package:md_ui_kit/md_ui_kit.dart';

class PasteCodeScreen extends StatefulWidget {
  const PasteCodeScreen({super.key});

  @override
  State<PasteCodeScreen> createState() => _PasteCodeScreenState();
}

class _PasteCodeScreenState extends State<PasteCodeScreen> {
  final _codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 57.0),
          child: WaveText(
            'Copy your friend’s code and paste it to the text input below:',
            type: WaveTextType.caption,
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 27),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: TextField(
            controller: _codeController,
          ),
        ),
        SizedBox(height: 135),
        WaveSimpleButton(
          label: 'Connect',
          onPressed: () {},
        ),
      ],
    );
  }
}
