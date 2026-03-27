import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Entry Point ───────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initBackgroundService();
  runApp(const MediaHubApp());
}

// ─── Background Service Setup ─────────────────────────────────────────────────
Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'mediahub_channel',
      initialNotificationTitle: 'MediaHub',
      initialNotificationContent: 'মিডিয়া চলছে...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  // Audio session configure korte hobe background play er jonno
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
    avAudioSessionMode: AVAudioSessionMode.defaultMode,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.music,
      flags: AndroidAudioFlags.audibilityEnforced,
      usage: AndroidAudioUsage.media,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    androidWillPauseWhenDucked: false,
  ));
  await session.setActive(true);
}

// ─── App Themes ────────────────────────────────────────────────────────────────
class MediaHubApp extends StatelessWidget {
  const MediaHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediaHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ─── App Model ────────────────────────────────────────────────────────────────
class AppItem {
  final String id;
  final String name;
  final String icon;
  final String url;
  final String category;

  const AppItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.url,
    required this.category,
  });

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'icon': icon, 'url': url, 'category': category};

  factory AppItem.fromMap(Map<String, dynamic> m) => AppItem(
        id: m['id'],
        name: m['name'],
        icon: m['icon'],
        url: m['url'],
        category: m['category'],
      );
}

// ─── Ad Block Rules ────────────────────────────────────────────────────────────
const List<String> adBlockDomains = [
  'doubleclick.net',
  'googlesyndication.com',
  'googleadservices.com',
  'ads.youtube.com',
  'static.ads-twitter.com',
  'advertising.com',
  'adservice.google.com',
  'pagead2.googlesyndication.com',
  'tiktokv.com/ads',
  'ads.tiktok.com',
  'imasdk.googleapis.com',
  'securepubads.g.doubleclick.net',
  'ade.googlesyndication.com',
];

bool isAdUrl(String url) {
  return adBlockDomains.any((domain) => url.contains(domain));
}

// ─── Default Apps ─────────────────────────────────────────────────────────────
const List<AppItem> defaultApps = [
  AppItem(
    id: 'youtube',
    name: 'YouTube',
    icon: '▶',
    url: 'https://m.youtube.com',
    category: 'video',
  ),
  AppItem(
    id: 'tiktok',
    name: 'TikTok',
    icon: '♪',
    url: 'https://www.tiktok.com',
    category: 'social',
  ),
  AppItem(
    id: 'spotify',
    name: 'Spotify',
    icon: '♫',
    url: 'https://open.spotify.com',
    category: 'music',
  ),
  AppItem(
    id: 'facebook',
    name: 'Facebook',
    icon: 'f',
    url: 'https://m.facebook.com',
    category: 'social',
  ),
];

// ─── Home Screen ──────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AppItem> apps = List.from(defaultApps);
  AppItem? activeApp;
  bool adBlockEnabled = true;
  String selectedCategory = 'all';
  final service = FlutterBackgroundService();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _setupAudioSession();
  }

  Future<void> _setupAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      adBlockEnabled = prefs.getBool('adblock') ?? true;
    });
  }

  Future<void> _saveAdBlock(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adblock', val);
  }

  void _startBackgroundService() async {
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  List<AppItem> get filteredApps {
    if (selectedCategory == 'all') return apps;
    return apps.where((a) => a.category == selectedCategory).toList();
  }

  void _openApp(AppItem app) {
    _startBackgroundService();
    setState(() => activeApp = app);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebViewScreen(
          app: app,
          adBlockEnabled: adBlockEnabled,
        ),
      ),
    );
  }

  void _showAddAppDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddAppSheet(
        onAdd: (app) {
          setState(() => apps.add(app));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Media',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: colors.onSurface,
              ),
            ),
            Text(
              'Hub',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: colors.primary,
              ),
            ),
          ],
        ),
        actions: [
          // Ad Block Toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(
                  'Ad Block',
                  style: TextStyle(
                    fontSize: 13,
                    color: adBlockEnabled ? Colors.green[700] : colors.onSurfaceVariant,
                  ),
                ),
                Switch(
                  value: adBlockEnabled,
                  activeColor: Colors.green[700],
                  onChanged: (v) {
                    setState(() => adBlockEnabled = v);
                    _saveAdBlock(v);
                  },
                ),
              ],
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // Category Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final cat in [
                  ('all', 'সব অ্যাপ'),
                  ('video', 'ভিডিও'),
                  ('social', 'সোশ্যাল'),
                  ('music', 'মিউজিক'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat.$2),
                      selected: selectedCategory == cat.$1,
                      onSelected: (_) =>
                          setState(() => selectedCategory = cat.$1),
                      selectedColor: colors.primaryContainer,
                    ),
                  ),
              ],
            ),
          ),

          // Apps Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: filteredApps.length + 1,
              itemBuilder: (context, index) {
                if (index == filteredApps.length) {
                  return _AddAppCard(onTap: _showAddAppDialog);
                }
                final app = filteredApps[index];
                return _AppCard(
                  app: app,
                  isActive: activeApp?.id == app.id,
                  onTap: () => _openApp(app),
                  onRemove: () => setState(() {
                    apps.removeWhere((a) => a.id == app.id);
                    if (activeApp?.id == app.id) activeApp = null;
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── App Card ─────────────────────────────────────────────────────────────────
class _AppCard extends StatelessWidget {
  final AppItem app;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _AppCard({
    required this.app,
    required this.isActive,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('${app.name} সরাবো?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('না'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onRemove();
                },
                child: const Text('হ্যাঁ'),
              ),
            ],
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isActive
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: colors.primary, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  app.icon,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              app.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            Text(
              app.category,
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAppCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddAppCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: colors.outline,
            width: 1.5,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 36, color: colors.primary),
            const SizedBox(height: 8),
            Text(
              'যোগ করুন',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add App Bottom Sheet ─────────────────────────────────────────────────────
class AddAppSheet extends StatefulWidget {
  final Function(AppItem) onAdd;
  const AddAppSheet({super.key, required this.onAdd});

  @override
  State<AddAppSheet> createState() => _AddAppSheetState();
}

class _AddAppSheetState extends State<AddAppSheet> {
  final urlCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  final presets = const [
    AppItem(id: 'yt', name: 'YouTube', icon: '▶', url: 'https://m.youtube.com', category: 'video'),
    AppItem(id: 'tt', name: 'TikTok', icon: '♪', url: 'https://www.tiktok.com', category: 'social'),
    AppItem(id: 'sp', name: 'Spotify', icon: '♫', url: 'https://open.spotify.com', category: 'music'),
    AppItem(id: 'fb', name: 'Facebook', icon: 'f', url: 'https://m.facebook.com', category: 'social'),
    AppItem(id: 'tw', name: 'Twitter/X', icon: 'X', url: 'https://mobile.twitter.com', category: 'social'),
    AppItem(id: 'ig', name: 'Instagram', icon: '◉', url: 'https://www.instagram.com', category: 'social'),
    AppItem(id: 'sc', name: 'SoundCloud', icon: '☁', url: 'https://soundcloud.com', category: 'music'),
    AppItem(id: 'yt2', name: 'YouTube Music', icon: '♬', url: 'https://music.youtube.com', category: 'music'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('অ্যাপ বেছে নিন', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((p) => ActionChip(
              label: Text('${p.icon} ${p.name}'),
              onPressed: () {
                widget.onAdd(AppItem(
                  id: '${p.id}_${DateTime.now().millisecondsSinceEpoch}',
                  name: p.name, icon: p.icon, url: p.url, category: p.category,
                ));
                Navigator.pop(context);
              },
            )).toList(),
          ),
          const Divider(height: 24),
          const Text('অথবা কাস্টম URL দিন', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: urlCtrl,
            decoration: const InputDecoration(
              hintText: 'https://example.com',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              hintText: 'অ্যাপের নাম',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('বাতিল'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final url = urlCtrl.text.trim();
                  if (url.isEmpty) return;
                  widget.onAdd(AppItem(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim().isEmpty ? 'Custom' : nameCtrl.text.trim(),
                    icon: '🌐',
                    url: url,
                    category: 'video',
                  ));
                  Navigator.pop(context);
                },
                child: const Text('যোগ করুন'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── WebView Screen ────────────────────────────────────────────────────────────
class WebViewScreen extends StatefulWidget {
  final AppItem app;
  final bool adBlockEnabled;

  const WebViewScreen({
    super.key,
    required this.app,
    required this.adBlockEnabled,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> with WidgetsBindingObserver {
  InAppWebViewController? webCtrl;
  double loadProgress = 0;
  bool isLoading = true;

  // Background audio keepalive JavaScript
  final String bgAudioJS = '''
    (function() {
      // Screen lock holeo audio continue korbe
      document.addEventListener('visibilitychange', function() {
        if (document.hidden) {
          // Background e gele pause korbe na
          const videos = document.querySelectorAll('video, audio');
          videos.forEach(v => {
            v.setAttribute('playsinline', '');
            if (v.paused === false) {
              // Playing thakle keep playing
            }
          });
        }
      });

      // Page e naya video element ashle setup kore
      const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
          mutation.addedNodes.forEach(function(node) {
            if (node.tagName === 'VIDEO' || node.tagName === 'AUDIO') {
              node.setAttribute('playsinline', '');
            }
            if (node.querySelectorAll) {
              node.querySelectorAll('video, audio').forEach(function(el) {
                el.setAttribute('playsinline', '');
              });
            }
          });
        });
      });
      observer.observe(document.body, { childList: true, subtree: true });

      // Media Session API - lock screen e control dekhabe
      if ('mediaSession' in navigator) {
        navigator.mediaSession.setActionHandler('play', function() {
          document.querySelectorAll('video, audio').forEach(v => v.play());
        });
        navigator.mediaSession.setActionHandler('pause', function() {
          document.querySelectorAll('video, audio').forEach(v => v.pause());
        });
      }

      console.log('MediaHub: Background audio enabled');
    })();
  ''';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Screen off holeo app background e thakbe
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App background e gele audio session active rakhbo
    if (state == AppLifecycleState.paused) {
      webCtrl?.evaluateJavascript(source: bgAudioJS);
    }
  }

  InAppWebViewSettings get _settings => InAppWebViewSettings(
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    useWideViewPort: true,
    loadWithOverviewMode: true,
    supportZoom: true,
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.app.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(widget.app.name, style: const TextStyle(fontSize: 16)),
            if (widget.adBlockEnabled) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  'Ad Blocked',
                  style: TextStyle(fontSize: 11, color: Colors.green[800]),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => webCtrl?.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () async {
              if (await webCtrl?.canGoBack() ?? false) {
                webCtrl?.goBack();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (isLoading)
            LinearProgressIndicator(
              value: loadProgress,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colors.primary),
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(widget.app.url),
              ),
              initialSettings: _settings,
              onWebViewCreated: (ctrl) => webCtrl = ctrl,
              onLoadStart: (ctrl, url) {
                setState(() => isLoading = true);
              },
              onLoadStop: (ctrl, url) async {
                setState(() => isLoading = false);
                // Background audio JS inject
                await ctrl.evaluateJavascript(source: bgAudioJS);
              },
              onProgressChanged: (ctrl, progress) {
                setState(() => loadProgress = progress / 100);
              },
              // Ad Blocking
              shouldOverrideUrlLoading: (ctrl, navigationAction) async {
                if (widget.adBlockEnabled) {
                  final url = navigationAction.request.url?.toString() ?? '';
                  if (isAdUrl(url)) {
                    return NavigationActionPolicy.CANCEL;
                  }
                }
                return NavigationActionPolicy.ALLOW;
              },
              shouldInterceptRequest: (ctrl, request) async {
                if (widget.adBlockEnabled) {
                  final url = request.url.toString();
                  if (isAdUrl(url)) {
                    return WebResourceResponse(
                      data: null,
                      statusCode: 204,
                      contentType: 'text/plain',
                    );
                  }
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}
