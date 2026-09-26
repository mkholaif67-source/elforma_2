import 'package:flutter_test/flutter_test.dart';
import 'package:elforma/models/plan_export.dart';
void main(){test('meal footer sums all three macros',(){
final html=PlanExport.nutritionHtml(dayLabel:'اليوم',meals:[{'name':'فطار','foods':[{'name':'بيض','grams':100,'cals':150,'pro':13,'carb':1,'fat':10},{'name':'عيش','grams':50,'cals':130,'pro':4,'carb':27,'fat':1}]}]);
expect(html,contains('بروتين: 17 جم'));expect(html,contains('كربوهيدرات: 28 جم'));expect(html,contains('دهون: 11 جم'));
});}
