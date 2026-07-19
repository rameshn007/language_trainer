import 'package:flutter_carplay/flutter_carplay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui/listen_repeat/listen_repeat_view_model.dart';
import '../utils/logger.dart';

class CarPlayService {
  static final CarPlayService _instance = CarPlayService._internal();
  factory CarPlayService() => _instance;
  CarPlayService._internal();

  final FlutterCarplay _flutterCarplay = FlutterCarplay();
  ProviderContainer? _container;

  void init({
    required ProviderContainer container,
  }) {
    AppLogger.log("init() called", name: 'CarPlay');
    _container = container;

    _flutterCarplay.addListenerOnConnectionChange((status) {
      if (status.toString().toLowerCase().contains('connected')) {
        _startListenRepeat();
      } else {
        _stopListenRepeat();
      }
    });
  }

  void _startListenRepeat() {
    if (_container == null) return;
    AppLogger.log("Setting up CarPlay for Listen & Repeat", name: 'CarPlay');

    try {
      FlutterCarplay.setRootTemplate(
        rootTemplate: CPListTemplate(
          sections: [
            CPListSection(
              header: 'Language Trainer',
              items: [
                CPListItem(
                  text: 'Start Session',
                  detailText: 'Shuffle words and start Listen & Repeat',
                  onPress: (complete, self) async {
                    try {
                      await _container!.read(listenRepeatViewModelProvider.notifier).startSession();
                      FlutterCarplay.showSharedNowPlaying(animated: true);
                    } catch (e) {
                      AppLogger.error('Failed to start session', name: 'CarPlay', error: e);
                    } finally {
                      complete();
                    }
                  },
                ),
              ],
            ),
          ],
          title: 'Language Trainer',
          systemIcon: 'headphones',
        ),
        animated: true,
      );
    } catch (e) {
      AppLogger.error('Error in CarPlay template setup', name: 'CarPlay', error: e);
    }
  }

  void _stopListenRepeat() {
    if (_container == null) return;
    AppLogger.log("Stopping Listen & Repeat for CarPlay", name: 'CarPlay');
    _container!.read(listenRepeatViewModelProvider.notifier).stopSession();
  }
}
