// Added regression tests. Must run under Flutter CI; not executable in the audit sandbox.
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elforma/api.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 test('late A response is rejected after binding B',() async {
  final pending=Completer<http.Response>();var count=0;
  final api=Api.forTesting(MockClient((r){count++;if(count==1)return pending.future;return Future.value(http.Response(jsonEncode({'ok':true,'profile':{'name':'B'}}),200));}));
  await api.bindAccount('A');
  final old=api.mobileBootstrap(force:true);await Future<void>.delayed(Duration.zero);
  await api.bindAccount('B');
  pending.complete(http.Response(jsonEncode({'ok':true,'profile':{'name':'A'}}),200));
  expect((await old).status,409);
  expect((await api.mobileBootstrap(force:true)).data['profile']['name'],'B');
 });
 test('account listeners cannot read prior bootstrap memo',() async {
  var name='A';
  final api=Api.forTesting(MockClient((r)async=>http.Response(jsonEncode({'ok':true,'profile':{'name':name}}),200)));
  await api.bindAccount('A');await api.mobileBootstrap();
  Future<ApiResult>? observed;
  api.accountChanges.addListener((){observed=api.mobileBootstrap();});
  name='B';await api.bindAccount('B');
  expect(observed,isNotNull);expect((await observed!).data['profile']['name'],'B');
 });
}
