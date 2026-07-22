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
        _showMainMenu();
      } else {
        _stopListenRepeat();
      }
    });
  }

  void _showMainMenu() {
    if (_container == null) return;
    AppLogger.log("Setting up CarPlay main menu", name: 'CarPlay');

    try {
      FlutterCarplay.setRootTemplate(
        rootTemplate: CPListTemplate(
          sections: [
            CPListSection(
              header: 'Language Trainer',
              items: [
                CPListItem(
                  text: 'Start Session',
                  detailText: 'Listen and repeat vocabulary words',
                  onPress: (complete, self) async {
                    complete();
                    _startSession();
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
      AppLogger.error('Error setting CarPlay main menu', name: 'CarPlay', error: e);
    }
  }

  void _startSession() {
    if (_container == null) return;
    AppLogger.log("Starting CarPlay session", name: 'CarPlay');

    _container!
        .read(listenRepeatViewModelProvider.notifier)
        .startSession()
        .then((_) {
      // Audio started successfully — show the system Now Playing screen
      FlutterCarplay.showSharedNowPlaying(animated: true);
    }).catchError((error) {
      AppLogger.error('CarPlay session failed to start', name: 'CarPlay', error: error);
    });
  }

  void _stopListenRepeat() {
    AppLogger.log("Stopping CarPlay session", name: 'CarPlay');

    if (_container == null) return;
    _container!.read(listenRepeatViewModelProvider.notifier).stopSession();
  }
}
