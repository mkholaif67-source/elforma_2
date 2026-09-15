import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elforma/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  http.Response ok(Map<String,dynamic> data) => http.Response(jsonEncode(data),200);

  test('concurrent bootstrap readers share one request and receive isolated maps', () async {
    final pending=Completer<http.Response>();var calls=0;
    final api=Api.forTesting(MockClient((r){calls++;return pending.future;}));
    final a=api.mobileBootstrap(),b=api.mobileBootstrap();
    await Future<void>.delayed(Duration.zero);
    pending.complete(ok({'ok':true,'profile':{'weight':108}}));
    final values=await Future.wait([a,b]);
    expect(calls,1);
    values[0].data['profile']['weight']=1;
    expect(values[1].data['profile']['weight'],108);
    expect((await api.mobileBootstrap()).data['profile']['weight'],108);
  });

  test('profile mutation removes persistent and memory stale reads', () async {
    var weight=108;
    final api=Api.forTesting(MockClient((r)async{
      if(r.method=='PUT'){weight=105;return ok({'profile':{'weight':weight}});}
      return ok({'ok':true,'profile':{'weight':weight}});
    }));
    await api.mobileBootstrap();
    await api.saveMobileProfile({'weight':105},patch:true);
    expect((await api.mobileBootstrap()).data['profile']['weight'],105);
  });

  test('nutrition requests deduplicate even on force reload', ()async{
    final pending=Completer<http.Response>();var calls=0;
    final api=Api.forTesting(MockClient((r){calls++;return pending.future;}));
    final a=api.nutritionPlan(force:true),b=api.nutritionPlan(force:true);
    await Future<void>.delayed(Duration.zero);
    pending.complete(ok({'plan':{'meals':[]},'targets':{'targetCals':2000}}));
    await Future.wait([a,b]);expect(calls,1);
  });

  test('HTML with HTTP 200 is not accepted as an empty successful plan', ()async{
    final api=Api.forTesting(MockClient((r)async=>http.Response('<html>Gateway</html>',200)));
    final result=await api.mobileBootstrap();expect(result.ok,false);expect(result.status,502);
  });

  test('timeout has a distinct nontechnical message, not a false offline assertion', ()async{
    final api=Api.forTesting(MockClient((r)async=>throw TimeoutException('internal timeout')));
    final result=await api.me();expect(result.status,408);
    expect(result.friendlyError('fallback'),isNot(contains('TimeoutException')));
    expect(result.friendlyError('fallback'),contains('وقتا أطول'));
  });

  test('server codes never appear verbatim in user-facing messages', (){
    for(final message in ['SQLITE_BUSY','SocketException','engine_missing_age']){
      expect(ApiResult(400,{'error':message}).friendlyError('حاول مرة أخرى'),'حاول مرة أخرى');
    }
  });

  test('read finishing after a mutation cannot restore the old profile', ()async{
    var gets=0;final pending=Completer<http.Response>();
    final api=Api.forTesting(MockClient((r)async{
      if(r.method=='PUT')return ok({'profile':{'weight':105}});
      gets++;
      if(gets==1)return pending.future;
      return ok({'profile':{'weight':105}});
    }));
    final stale=api.mobileBootstrap();
    await Future<void>.delayed(Duration.zero);
    await api.saveMobileProfile({'weight':105},patch:true);
    pending.complete(ok({'profile':{'weight':108}}));
    expect((await stale).data['profile']['weight'],105);
    expect((await api.mobileBootstrap()).data['profile']['weight'],105);
  });
}
