import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:elforma/api.dart';

class AnnouncementStore extends ChangeNotifier {
  AnnouncementStore._() { Api.I.accountChanges.addListener(() {
    stop(); items=[]; loaded=false; _cursor=''; notifyListeners();
  }); }
  static final I=AnnouncementStore._();
  List<Map<String,dynamic>> items=[];
  bool loaded=false;
  int _generation=0;
  bool _running=false;
  String _cursor='';
  void start(){if(_running)return;_running=true;unawaited(_watch(++_generation));}
  void stop(){_running=false;_generation++;}
  Future<void> _watch(int generation) async {
    while(_running && generation==_generation && Api.I.accountId!=null){
      final r=await Api.I.watchAnnouncements(_cursor);
      if(!_running||generation!=_generation)return;
      if(r.ok && r.data['announcements'] is List){
        items=(r.data['announcements'] as List).whereType<Map>().map((m)=>Map<String,dynamic>.from(m)).toList();
        _cursor='${r.data['cursor']??''}'; loaded=true; notifyListeners();
      }else{
        // On disconnection don't claim a deleted server ad is still current.
        items=[]; loaded=true; notifyListeners();
        await Future<void>.delayed(const Duration(seconds:10));
      }
    }
    if(generation==_generation)_running=false;
  }
}
