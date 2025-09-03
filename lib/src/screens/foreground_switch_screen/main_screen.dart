import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:md_ui_kit/widgets/wave_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave/src/core/keys.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String localId = '';

  @override
  void initState() {
    _getLocalOfferId();
    super.initState();
  }

  Future<void> _getLocalOfferId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // TODO: обработать случай когда нет кода в локальной памяти
      localId =
          prefs.getString(currentPeerLocalIdKey) ?? 'Invalid two-word code';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child:
                  WaveStatus(type: WaveStatusType.positive, label: 'Connected'),
            ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  WaveText(
                    localId,
                    type: WaveTextType.title,
                    color: MdColors.titleColor,
                    weight: WaveTextWeight.bold,
                  ),
                ],
              ),
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: WaveText(
                      'QASGHSVRGMOHGM4O87GH345G8H75W46V8MAYHW765T3HM7HPGBFGUIHHSVRG...MON',
                      maxLines: 3,
                      type: WaveTextType.caption,
                      color: MdColors.subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(),
            ),
            SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  WaveText(
                    'Waiting your friend’s device to answer..',
                    type: WaveTextType.caption,
                    color: MdColors.subtitleColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
