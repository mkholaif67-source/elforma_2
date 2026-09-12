// ── ElForma · widgets/announcement_card.dart ──
// كارت الإعلان اللي الأدمن بيظبطه من لوحة الإدارة.
//
// كل حقل بيوصل من السيرفر له تأثير حقيقي هنا — مفيش حقل متجاهل:
//  · title / body / image / link / cta / phone
//  · style       → لون الحد والتدرج والأيقونة
//  · dismissible → زر الإغلاق (وبيتحفظ محليا فمايرجعش تاني)
//  · maxViews    → أقصى عدد مرات ظهور للمستخدم ده (0 = بلا حدود)
//
// الإغلاق وعداد المشاهدات متعامل معاهم جوا الكارت نفسه بـ SharedPreferences،
// عشان أي شاشة تستخدم الكارت تاخد السلوك ده من غير تكرار منطق.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/api.dart';
import 'package:elforma/models/announcement_store.dart';

class AnnouncementCard extends StatefulWidget {
  const AnnouncementCard({super.key, required this.data,this.onUnavailable});
  final Map<String, dynamic> data;
  final VoidCallback? onUnavailable;

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard> {
  // الحالات التلاتة: بنتأكد الأول ، بنعرض ، مخفي خلاص.
  bool _checked = false;
  bool _hidden = false;

  String get _id {
    final raw = (widget.data['id'] ?? '').toString().trim();
    if (raw.isNotEmpty) return raw;
    // لو مفيش id لسبب ما، بنعتمد على العنوان كمفتاح مستقر.
    return 't:${(widget.data['title'] ?? '').toString().trim()}';
  }

  String _s(String key) => (widget.data[key] ?? '').toString().trim();

  int get _maxViews {
    final v = widget.data['maxViews'];
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  bool get _dismissible => widget.data['dismissible'] != false;

  @override
  void initState() {
    super.initState();
    AnnouncementStore.I.addListener(_liveChanged);
    _gate();
  }

  bool _unavailableSent=false;
  void _liveChanged(){
    if(!mounted)return;
    final live=AnnouncementStore.I;
    if(live.loaded&&!live.items.any((a)=>a['id']==widget.data['id'])&&!_unavailableSent){
      _unavailableSent=true;
      WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)widget.onUnavailable?.call();});
    }
    setState((){});
  }
  @override
  void dispose(){AnnouncementStore.I.removeListener(_liveChanged);super.dispose();}
  @override
  void didUpdateWidget(covariant AnnouncementCard oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.data['id']!=widget.data['id']){_hidden=false;_checked=false;_gate();}
  }

  /// بيقرر هل الكارت يظهر ولا لأ، وبيزود عداد المشاهدات مرة واحدة لكل عرض.
  Future<void> _gate() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final dismissed = sp.getStringList('ann_dismissed:${Api.I.accountId}') ?? const <String>[];
      if (dismissed.contains(_id)) {
        if (mounted) setState(() { _hidden = true; _checked = true; });
        return;
      }
      final cap = _maxViews;
      if (cap > 0) {
        final key = 'ann_views:${Api.I.accountId}:$_id';
        final seen = sp.getInt(key) ?? 0;
        if (seen >= cap) {
          if (mounted) setState(() { _hidden = true; _checked = true; });
          return;
        }
        await sp.setInt(key, seen + 1);
      }
    } catch (_) {
      // فشل التخزين المحلي ماينفعش يخفي إعلان الأدمن — بنعرضه عادي.
    }
    if (mounted) setState(() => _checked = true);
  }

  Future<void> _dismiss() async {
    final owner=Api.I.accountId,id=_id;
    setState(() => _hidden = true);
    try {
      final sp = await SharedPreferences.getInstance();
      final list = sp.getStringList('ann_dismissed:$owner') ?? const <String>[];
      if (!list.contains(id)) {
        // بنحد القائمة عشان ماتكبرش للأبد.
        final next = [...list, id];
        await sp.setStringList(
            'ann_dismissed:$owner', next.length > 200 ? next.sublist(next.length - 200) : next);
      }
    } catch (_) {}
  }

  Future<void> _open(String raw) async {
    if (raw.isEmpty) return;
    var url = raw.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://') &&
        !url.startsWith('tel:') && !url.startsWith('mailto:') &&
        !url.startsWith('wa.me') && !url.startsWith('whatsapp:') &&
        !url.startsWith('instagram:') && !url.startsWith('fb:')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}
    if (!launched) {
      try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
    }
  }

  Future<void> _call(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('tel:$digits');
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
  }

  /// شكل الكارت حسب style اللي اختاره الأدمن.
  ({Color tint, IconData icon}) get _look {
    switch (_s('style')) {
      case 'success':
        return (tint: AppColors.nu, icon: Icons.check_circle_rounded);
      case 'warn':
        return (tint: const Color(0xFFFBBF24), icon: Icons.warning_amber_rounded);
      case 'promo':
        return (tint: const Color(0xFFA78BFA), icon: Icons.local_offer_rounded);
      default:
        return (tint: const Color(0xFF38BDF8), icon: Icons.campaign_rounded);
    }
  }

  Widget _image(String raw, {bool full = false, bool portrait = false}) {
    final url = Uri.parse(Api.baseUrl).resolve(raw).toString();
    final picture = Image.network(url, width: double.infinity,
      fit: full ? BoxFit.fitWidth : BoxFit.cover,
      errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(24), child: Icon(Icons.image_not_supported_outlined, color: AppColors.muted)),
    );
    return Semantics(button: true, label: _s('imageAction') == 'phone' ? 'اتصل بنا' : 'افتح الإعلان',
      child: GestureDetector(onTap: () => _s('imageAction') == 'phone' ? _call(_s('phone')) : _open(_s('link')),
        child: full ? picture : AspectRatio(aspectRatio: portrait ? 3 / 4 : 16 / 7, child: picture)));
  }

  Widget _close() => IconButton(tooltip: 'إخفاء الإعلان', onPressed: _dismiss,
      style: IconButton.styleFrom(backgroundColor: AppColors.bg.withValues(alpha: .8)),
      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white));

  @override
  Widget build(BuildContext context) {
    if (AnnouncementStore.I.loaded && !AnnouncementStore.I.items.any((a)=>'${a['id']}'==_id)) return const SizedBox.shrink();
    if (!_checked || _hidden) return const SizedBox.shrink();
    final look = _look;
    final title = _s('title');
    final body = _s('body');
    final link = _s('link');
    final phone = _s('phone');
    final image = _s('image');
    final imageOnly = _s('layout') == 'imageOnly' && image.isNotEmpty;
    final cta = _s('cta').isEmpty ? 'اكتشف التفاصيل' : _s('cta');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22),
        color: AppColors.card,
        border: Border.all(color: look.tint.withValues(alpha: .25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (image.isNotEmpty) Stack(children: [
          _image(image, full: imageOnly, portrait: _s('layout') == 'portrait'),
          if (_dismissible) Positioned(top: 8, left: 8, child: _close()),
        ]),
        if (!imageOnly) Padding(padding: const EdgeInsets.all(18), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(look.icon, color: look.tint, size: 16),
              const SizedBox(width: 6),
              Text('إعلان', style: TextStyle(color: look.tint, fontSize: 11, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (image.isEmpty && _dismissible) _close(),
            ]),
            if (title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, height: 1.4, fontWeight: FontWeight.w900)),
            ],
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(body, style: const TextStyle(color: Color(0xFFCAD5E2), fontSize: 14, height: 1.75)),
            ],
            if (link.isNotEmpty || phone.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (link.isNotEmpty) FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: look.tint, foregroundColor: AppColors.bg,
                    minimumSize: const Size(140, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => _open(link), icon: const Icon(Icons.arrow_outward_rounded, size: 18),
                  label: Text(cta, style: const TextStyle(fontWeight: FontWeight.w900))),
                if (phone.isNotEmpty) OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF71DFC1),
                    side: const BorderSide(color: Color(0xFF277D70)),
                    minimumSize: const Size(140, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => _call(phone), icon: const Icon(Icons.call_outlined, size: 18),
                  label: Text(phone, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
              ]),
            ],
          ])),
      ]),
    );
  }
}
