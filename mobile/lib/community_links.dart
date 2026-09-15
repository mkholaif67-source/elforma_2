import 'package:flutter/material.dart';
import 'package:elforma/api.dart';
import 'package:elforma/widgets/forma_design.dart';
import 'package:elforma/screens/community_screen.dart';

/// Internal notification links are queued until the authenticated shell exists.
class CommunityLinks {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static String? _pending;
  static bool shellReady = false;
  static bool accept(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri?.scheme != 'elforma') return false;
    if (!['recipe', 'challenge'].contains(uri!.host) ||
        uri.pathSegments.length != 1)
      return true;
    _pending = raw;
    flush();
    return true;
  }

  static void flush() {
    if (!shellReady ||
        Api.I.accountId == null ||
        navigatorKey.currentState == null ||
        _pending == null)
      return;
    final uri = Uri.parse(_pending!);
    _pending = null;
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
