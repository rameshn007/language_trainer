import 'package:flutter/services.dart';
import 'package:flutter_carplay/flutter_carplay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui/listen_repeat/listen_repeat_view_model.dart';
import '../utils/logger.dart';

/// Orchestrates the CarPlay experience.
///
/// Design goals:
///  * Tapping the app icon in CarPlay drops the driver straight into a
///    running Listen & Repeat session - no intermediate "Start Session" menu.
///  * Word-level playback controls live on a CarPlay list template:
///    Pause/Resume, Replay word, Previous/Next word, Shuffle, Speed, Stop.
///  * The session reuses the same [ListenRepeatViewModel] (and its
///    just_audio playlist) as the phone UI, so audio keeps flowing to the
///    car regardless of which template is on screen.
///
/// Trigger sources (how we learn the driver wants the experience):
///  * The plugin's `connected` event cannot distinguish a plain cable
///    connect (dashboard still on screen) from an app-icon tap - it fires
///    for both. So on `connected` we instead query the native
///    `language_trainer/carplay_scene` channel (see AppDelegate.swift /
///    CarPlaySceneObserver) and only act when the CarPlay scene is actually
///    in the foreground.
///  * `sceneWillEnterForeground` pushes from that channel are the precise
///    "driver tapped the app icon / our UI became visible" signal and
///    start the session directly.
///  * `background` fires when another CarPlay app takes the screen. Playback
///    intentionally keeps running (media-app behavior); only `disconnected`
///    stops the session.
class CarPlayService {
  static final CarPlayService _instance = CarPlayService._internal();
  factory CarPlayService() => _instance;
  CarPlayService._internal();

  final FlutterCarplay _flutterCarplay = FlutterCarplay();

  ProviderContainer? _container;
  bool _stateListenerAdded = false;

  /// Dedicated app channel: pushes `sceneWillEnterForeground` events and
  /// answers `sceneStatus` pulls. Implemented natively (AppDelegate.swift);
  /// absent on Android/tests, where calls fail harmlessly.
  static const MethodChannel _sceneChannel =
      MethodChannel('language_trainer/carplay_scene');

  /// Throttles repeat activations so the paired trigger for a single
  /// "driver wants the experience" moment (foreground push + connected
  /// event, or the two plugin connection events) only starts one session.
  DateTime? _lastActivation;

  /// Player template for the visible session. Null while CarPlay shows the
  /// main menu or is not connected.
  CPListTemplate? _playerTemplate;
  CPListItem? _wordItem;
  CPListItem? _pauseItem;
  CPListItem? _speedItem;

  String? _shownWordId;
  bool? _shownPlayingState;
  String? _shownFailure;

  void init({required ProviderContainer container}) {
    AppLogger.log("init() called", name: 'CarPlay');
    _container = container;

    // Precise CarPlay-scene foreground signal (iOS only).
    _sceneChannel.setMethodCallHandler(_onSceneChannelCall);

    _flutterCarplay.addListenerOnConnectionChange((status) {
      switch (status) {
        case ConnectionStatusTypes.connected:
          // Ambiguous event (cable connect looks identical to an icon tap),
          // so only act once the native side confirms the CarPlay scene is
          // really foreground - i.e. the driver is looking at our UI.
          _querySceneState('connected');
          break;
        case ConnectionStatusTypes.background:
          // Another CarPlay app took over the screen. Keep the audio
          // playing; only reconnecting to our app or disconnecting changes
          // the session.
          break;
        case ConnectionStatusTypes.disconnected:
          AppLogger.log("Disconnected - stopping session", name: 'CarPlay');
          _lastActivation = null;
          _resetPlayer();
          _stopSession();
          break;
        case ConnectionStatusTypes.unknown:
          break;
      }
    });

    // Cold start directly into the CarPlay scene: scene activation can
    // race ahead of this handler being installed, so pull the current
    // scene state a moment after startup as well.
    Future<void>.delayed(
        const Duration(milliseconds: 300),
        () => _querySceneState('launch'));
    Future<void>.delayed(
        const Duration(milliseconds: 1500),
        () => _querySceneState('launch-late'));
  }

  // ------------------------------------------------------------------
  // Scene activation
  // ------------------------------------------------------------------

  Future<Object?> _onSceneChannelCall(MethodCall call) async {
    if (call.method == 'sceneWillEnterForeground') {
      AppLogger.log("CarPlay scene entering foreground", name: 'CarPlay');
      _onSceneActivated();
    }
    return null;
  }

  /// Asks the native side whether a CarPlay template scene is currently
  /// foregrounded, and only treats that as a session trigger when true.
  Future<void> _querySceneState(String source) async {
    try {
      final result = await _sceneChannel.invokeMethod<Object>('sceneStatus');
      if (result is Map && result['foreground'] == true) {
        AppLogger.log("Scene foreground confirmed ($source)", name: 'CarPlay');
        _onSceneActivated();
      }
    } catch (e) {
      // Android and tests have no native channel; CarPlay support is iOS
      // only, so nothing to do.
      AppLogger.log("sceneStatus unavailable: $e", name: 'CarPlay');
    }
  }

  /// Called when the CarPlay scene is (about to be) visible to the driver.
  void _onSceneActivated() {
    final container = _container;
    if (container == null) return;

    final now = DateTime.now();
    if (_lastActivation != null &&
        now.difference(_lastActivation!) < const Duration(seconds: 2)) {
      // Duplicate trigger for the same activation (e.g. the foreground
      // push plus the paired connected event) - the first one acted.
      return;
    }
    _lastActivation = now;

    _ensureStateListener(container);

    final state = container.read(listenRepeatViewModelProvider);
    final sessionActive = state.isPlaying || state.currentItem != null;

    if (sessionActive) {
      // A session is already running (or paused) - keep it. Re-show the
      // player if it is not the current template (e.g. the session was
      // started from the phone screen before plugging in).
      if (_playerTemplate == null) {
        AppLogger.log(
            "Session already running - showing player without restarting",
            name: 'CarPlay');
        _showPlayer(state);
      }
      return;
    }

    AppLogger.log(
        "CarPlay scene activated - starting Listen & Repeat",
        name: 'CarPlay');
    _startExperience();
  }

  void _startExperience() {
    final container = _container;
    if (container == null) return;

    // Show the player immediately (in a loading state) so the driver sees
    // controls right away, then let the view model build the audio playlist.
    _showPlayer(container.read(listenRepeatViewModelProvider));

    container
        .read(listenRepeatViewModelProvider.notifier)
        .startSession()
        .then((_) {
      // startSession() resolves without error on an empty library; say so
      // explicitly instead of leaving the player on "Loading words...".
      final state = container.read(listenRepeatViewModelProvider);
      if (state.currentItem == null && state.failure == null) {
        final wordItem = _wordItem;
        if (wordItem != null) {
          wordItem.setText('No words to play');
          wordItem.setDetailText('Add vocabulary to start a session');
        }
      }
    }).catchError((error) {
      AppLogger.error('CarPlay session failed to start',
          name: 'CarPlay', error: error);
    });
  }

  // ------------------------------------------------------------------
  // Templates
  // ------------------------------------------------------------------

  void _showPlayer(ListenRepeatState state) {
    _shownWordId = state.currentItem?.id;
    _shownPlayingState = state.isPlaying;
    _shownFailure = null;

    final notifier = _container!.read(listenRepeatViewModelProvider.notifier);

    final wordItem = CPListItem(
      text: state.currentItem?.portuguese ?? 'Loading words...',
      detailText: state.currentItem?.english ??
          'Listen to the word, then repeat it aloud',
      isPlaying: state.isPlaying,
      playingIndicatorLocation: CPListItemPlayingIndicatorLocation.trailing,
      onPress: (complete, self) {
        complete();
        notifier.replayCurrentWord();
      },
    );

    final pauseItem = CPListItem(
      text: state.isPlaying ? 'Pause' : 'Resume',
      detailText: 'Pause or resume playback',
      onPress: (complete, self) {
        complete();
        notifier.togglePlayPause();
      },
    );

    final replayItem = CPListItem(
      text: 'Replay word',
      detailText: 'Hear the current word again',
      onPress: (complete, self) {
        complete();
        notifier.replayCurrentWord();
      },
    );

    final previousItem = CPListItem(
      text: 'Previous word',
      onPress: (complete, self) {
        complete();
        notifier.previousWord();
      },
    );

    final nextItem = CPListItem(
      text: 'Next word',
      onPress: (complete, self) {
        complete();
        notifier.nextWord();
      },
    );

    final shuffleItem = CPListItem(
      text: 'Shuffle words',
      detailText: 'Restart with a reshuffled deck',
      onPress: (complete, self) {
        complete();
        notifier.shufflePool();
      },
    );

    final speedItem = CPListItem(
      text: 'Speed: ${state.playbackSpeed}x',
      detailText: 'Tap to change speech speed',
      onPress: (complete, self) {
        final newSpeed = notifier.cycleSpeed();
        _speedItem?.setText('Speed: ${newSpeed}x');
        complete();
      },
    );

    final stopItem = CPListItem(
      text: 'Stop session',
      detailText: 'Stop playback and open the menu',
      onPress: (complete, self) {
        complete();
        _stopSession();
        _showMainMenu();
      },
    );

    final template = CPListTemplate(
      title: 'Listen & Repeat',
      systemIcon: 'headphones',
      sections: [
        CPListSection(header: 'Current word', items: [wordItem]),
        CPListSection(
          header: 'Playback',
          items: [pauseItem, replayItem, previousItem, nextItem],
        ),
        CPListSection(
          header: 'Session',
          items: [shuffleItem, speedItem, stopItem],
        ),
      ],
    );

    _playerTemplate = template;
    _wordItem = wordItem;
    _pauseItem = pauseItem;
    _speedItem = speedItem;

    FlutterCarplay.setRootTemplate(rootTemplate: template, animated: true);
  }

  void _showMainMenu() {
    _resetPlayer();
    AppLogger.log("Showing main menu", name: 'CarPlay');

    try {
      FlutterCarplay.setRootTemplate(
        rootTemplate: CPListTemplate(
          sections: [
            CPListSection(
              header: 'Listen & Repeat',
              items: [
                CPListItem(
                  text: 'Start Listen & Repeat',
                  detailText: 'Listen to a word, then repeat it aloud',
                  onPress: (complete, self) {
                    complete();
                    _startExperience();
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
      AppLogger.error('Error setting CarPlay main menu',
          name: 'CarPlay', error: e);
    }
  }

  // ------------------------------------------------------------------
  // Live updates
  // ------------------------------------------------------------------

  /// Mirrors [ListenRepeatViewModel] state changes onto the visible player.
  /// Runs even while the scene is in the background so the rows are current
  /// again once CarPlay re-shows them.
  void _onListenRepeatStateChanged(ListenRepeatState state) {
    if (_playerTemplate == null || _wordItem == null) return;

    final item = state.currentItem;
    if (item != null && item.id != _shownWordId) {
      _shownWordId = item.id;
      final wordItem = _wordItem!;
      wordItem.setText(item.portuguese);
      wordItem.setDetailText(item.english);
    }

    if (state.failure != null && state.failure != _shownFailure) {
      _shownFailure = state.failure;
      final wordItem = _wordItem;
      if (wordItem != null) {
        wordItem.setText('Session failed');
        wordItem.setDetailText(state.failure!);
      }
      _pauseItem?.setText('Resume');
    }

    if (state.isPlaying != _shownPlayingState) {
      _shownPlayingState = state.isPlaying;
      _wordItem?.setIsPlaying(state.isPlaying);
      _pauseItem?.setText(state.isPlaying ? 'Pause' : 'Resume');
    }
  }

  void _ensureStateListener(ProviderContainer container) {
    if (_stateListenerAdded) return;
    _stateListenerAdded = true;
    container.listen<ListenRepeatState>(
      listenRepeatViewModelProvider,
      (previous, next) => _onListenRepeatStateChanged(next),
    );
  }

  // ------------------------------------------------------------------
  // Teardown
  // ------------------------------------------------------------------

  void _resetPlayer() {
    _playerTemplate = null;
    _wordItem = null;
    _pauseItem = null;
    _speedItem = null;
    _shownWordId = null;
    _shownPlayingState = null;
    _shownFailure = null;
  }

  void _stopSession() {
    final container = _container;
    if (container == null) return;
    // stopSession() is async; handle its errors via the future so nothing
    // escapes unhandled (a try/catch here would only cover the sync part).
    container
        .read(listenRepeatViewModelProvider.notifier)
        .stopSession()
        .then((xp) {
      AppLogger.log("CarPlay session stopped, XP earned: $xp", name: 'CarPlay');
    }, onError: (Object e, StackTrace st) {
      AppLogger.error('Error stopping session',
          name: 'CarPlay', error: e, stackTrace: st);
    });
  }
}