import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:elforma/api.dart';
import 'package:elforma/widgets/forma_design.dart';
import 'package:elforma/screens/community_screen.dart';
import 'package:elforma/screens/friend_challenges_screen.dart';

/// Internal notification links are queued until the authenticated shell exists.
class CommunityLinks {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static const _native = MethodChannel('elforma/links');
  static String? _pending;
  static bool shellReady = false;

  static bool accept(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return false;
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host == 'elforma.onrender.com' &&
        uri.pathSegments.length == 3 &&
        uri.pathSegments[0] == 'challenge' &&
        uri.pathSegments[1] == 'join') {
      _pending = 'friend:${uri.pathSegments[2]}';
      flush();
      return true;
    }
    if (uri.scheme != 'elforma') return false;
    if (uri.host == 'friend-challenge' && uri.pathSegments.length == 1) {
      _pending = 'friend:${uri.pathSegments.single}';
      flush();
      return true;
    }
    if (!['recipe', 'challenge'].contains(uri.host) ||
        uri.pathSegments.length != 1) return true;
    _pending = raw;
    flush();
    return true;
  }

  static Future<void> readNativeLink() async {
    try {
      final raw = await _native.invokeMethod<String>('getLatestLink');
      if (raw != null && raw.isNotEmpty) accept(raw);
    } catch (_) {}
  }

  static void flush() {
    if (!shellReady ||
        Api.I.accountId == null ||
        navigatorKey.currentState == null ||
        _pending == null) return;
    final pending = _pending!;
    _pending = null;
    if (pending.startsWith('friend:')) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => FriendChallengePreviewScreen(
            code: pending.substring('friend:'.length),
          ),
        ),
      );
      return;
    }
    final uri = Uri.parse(pending);
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => uri.host == 'challenge'
            ? ChallengeScreen(id: uri.pathSegments.single)
            : _RecipeLink(id: uri.pathSegments.single),
      ),
    );
  }
}

class _RecipeLink extends StatefulWidget {
  const _RecipeLink({required this.id});
  final String id;
  @override
  State<_RecipeLink> createState() => _RecipeLinkState();
}

class _RecipeLinkState extends State<_RecipeLink> {
  Map<String, dynamic>? recipe;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await Api.I.community();
    if (!mounted) return;
    final matches = communityRows(
      r.data['recipes'],
    ).where((e) => e['id'] == widget.id);
    setState(() {
      recipe = matches.isEmpty ? null : matches.first;
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) => recipe != null
      ? RecipeScreen(item: recipe!)
      : Scaffold(
          appBar: AppBar(title: const Text('الوصفة')),
          body: Center(
            child: busy
                ? const FormaLoader()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('الوصفة غير متاحة أو الاتصال انقطع'),
                      TextButton(
                        onPressed: load,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
          ),
        );
}
