import 'package:elforma/widgets/brand_experience_visual.dart';
import 'package:elforma/widgets/brand_intro_scene.dart';
import 'package:elforma/widgets/brand_onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sizes=[Size(320,568),Size(360,640),Size(375,667),Size(360,800),Size(393,852),Size(412,915),Size(600,960),Size(800,1280)];
  for(final size in sizes) {
    testWidgets('all pages preserve text and controls at $size',(tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(()=>tester.binding.setSurfaceSize(null));
      for(var i=0;i<4;i++) {
        var taps=0;
        await tester.pumpWidget(MaterialApp(home:Directionality(textDirection:TextDirection.rtl,
          child:BrandOnboardingSurface(key:ValueKey(i),index:i,onNext:(){taps++;},pages:BrandOnboardingPage(index:i)))));
        await tester.pump(const Duration(milliseconds:350));
        final title=find.byKey(ValueKey('onboarding-title-$i'));
        final subtitle=find.byKey(ValueKey('onboarding-subtitle-$i'));
        final button=find.byType(FilledButton);
        expect(tester.takeException(),isNull);
        expect(tester.getRect(title).bottom,lessThanOrEqualTo(tester.getRect(subtitle).top));
        expect(tester.getRect(subtitle).bottom,lessThanOrEqualTo(tester.getRect(button).top));
        expect(tester.getRect(button).left,greaterThanOrEqualTo(0));
        expect(tester.getRect(button).bottom,lessThanOrEqualTo(size.height));
        await tester.tap(button); expect(taps,1);
      }
    });
  }
  testWidgets('intro objects settle before the final hold',(tester) async {
    List<BrandObject> objects=[];
    for(final progress in [.8,1.0]) {
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:BrandIntroScene(progress:progress))));
      final current=tester.widgetList<BrandObject>(find.byType(BrandObject)).toList();
      if(objects.isNotEmpty) {
        for(var i=0;i<current.length;i++) {
          expect(current[i].rect,objects[i].rect);
          expect(current[i].offset,objects[i].offset);
          expect(current[i].opacity,1);
          expect(current[i].angle,objects[i].angle);
        }
      }
      objects=current;
      expect(tester.takeException(),isNull);
    }
    expect(brandIntroDuration,const Duration(milliseconds:5500));
  });
}
