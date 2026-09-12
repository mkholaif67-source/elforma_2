import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elforma/api.dart';
import 'package:elforma/theme.dart';

class MealFavoritesScreen extends StatefulWidget {
 const MealFavoritesScreen({super.key});
 @override State<MealFavoritesScreen> createState()=>_MealFavoritesScreenState();
}
class _MealFavoritesScreenState extends State<MealFavoritesScreen>{
 final _search=TextEditingController(); Timer? _debounce;
 String _slot='breakfast'; int _generation=0;
 bool _busy=true,_saving=false,_changed=false,_prefsReady=false; String? _error;
 List<Map<String,dynamic>> _foods=[];
 final Map<String,List<Map<String,dynamic>>> _selected={
  'breakfast':[],'snack':[],'pre':[],'lunch':[],'dinner':[],
 };
 static const _labels={'breakfast':'إفطار','snack':'سناك','pre':'قبل التمرين','lunch':'غداء','dinner':'عشاء'};
 static const _icons={'breakfast':Icons.wb_sunny_outlined,'snack':Icons.apple_outlined,
  'pre':Icons.fitness_center,'lunch':Icons.restaurant_outlined,'dinner':Icons.nightlight_outlined};
 static const _tips={
  'breakfast':'اختار أصناف فطارك المفضلة',
  'snack':'اختيارات خفيفة من قائمة السناك المسموح بها',
  'pre':'تفضيلاتك لوجبة قبل التمرين في أيام التدريب',
  'lunch':'اختار أصناف وجبتك الرئيسية',
  'dinner':'اختيارات العشاء تلتزم بأصناف اليوم وقاعدة العشاء الخفيف',
 };
 @override void initState(){super.initState();_loadSelected();_load();}
 @override void dispose(){_debounce?.cancel();_search.dispose();super.dispose();}
 Future<void> _loadSelected()async{
  final r=await Api.I.foodPreferences();if(!mounted)return;
  if(r.ok&&r.data['mealFavorites'] is Map){setState((){
   _prefsReady=true;final groups=r.data['mealFavorites'] as Map;
   for(final key in _selected.keys){
    final raw=groups[key]??((key=='lunch'||key=='dinner')?groups['main']:null);
    _selected[key]=(raw is List?raw:const []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();
   }
  });}else{setState(()=>_error=r.friendlyError('تعذر تحميل المفضلة'));}
 }
 Future<void> _load()async{
  final generation=++_generation;
  setState((){_busy=true;_error=null;});
  final r=await Api.I.searchFoods(_search.text.trim(),diet:'',health:[],mealSlot:_slot);
  if(!mounted||generation!=_generation)return;
  setState((){_busy=false;if(r.ok){_foods=(r.data['foods'] is List?r.data['foods'] as List:const []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();}else{_error=r.friendlyError('تعذر تحميل الأطعمة');}});
 }
 void _chooseSlot(String slot){
  if(slot==_slot)return;_debounce?.cancel();
  setState(()=>_slot=slot);_load();
 }
 Future<void> _toggle(Map<String,dynamic> food)async{
  if(_saving||!_prefsReady)return;
  final slot=_slot,id='${food['id']}';final existed=_selected[slot]!.any((f)=>'${f['id']}'==id);
  setState(()=>_saving=true);
  final r=await Api.I.saveFoodPreference(id,mealSlot:slot,favorite:!existed);
  if(!mounted)return;setState(()=>_saving=false);
  if(r.ok&&r.data['queued']!=true){setState((){_changed=true;_selected[slot]!.removeWhere((f)=>'${f['id']}'==id);if(!existed)_selected[slot]!.add(food);_error=null;});}
  else{ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(r.data['queued']==true?'سيتم حفظ الاختيار عند عودة الاتصال':r.friendlyError('تعذر حفظ المفضلة'))));}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('أطعمتك المفضلة',style:TextStyle(fontWeight:FontWeight.w800)),
   leading:IconButton(icon:const Icon(Icons.arrow_back),onPressed:()=>Navigator.pop(context,_changed)),
   actions:[TextButton(onPressed:()=>Navigator.pop(context,_changed),child:const Text('تم',style:TextStyle(fontWeight:FontWeight.w800)))]),
  body:CustomScrollView(slivers:[
   SliverPadding(padding:const EdgeInsets.fromLTRB(16,8,16,0),sliver:SliverToBoxAdapter(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppColors.nu2.withValues(alpha:.09),borderRadius:BorderRadius.circular(20),border:Border.all(color:AppColors.nu2.withValues(alpha:.28))),
     child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('أكل بتحبه، وخطة تناسبك',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:AppColors.text)),
      SizedBox(height:8),Text('اختياراتك أولويات وليست وجبات مسجلة. النظام يوازنها مع هدفك وقواعد كل وجبة.',style:TextStyle(fontSize:14,color:AppColors.muted,height:1.6)),
     ])),
    const SizedBox(height:16),
    Wrap(spacing:8,runSpacing:8,children:[for(final slot in _labels.keys)ChoiceChip(
     avatar:Icon(_icons[slot],size:18,color:_slot==slot?AppColors.nu2:AppColors.muted),
     label:Text(_labels[slot]!),selected:_slot==slot,showCheckmark:false,
     labelStyle:TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:_slot==slot?AppColors.nu2:AppColors.text),
     selectedColor:AppColors.nu2.withValues(alpha:.17),backgroundColor:AppColors.card,
     side:BorderSide(color:_slot==slot?AppColors.nu2:AppColors.muted.withValues(alpha:.25)),
     padding:const EdgeInsets.symmetric(horizontal:10,vertical:12),onSelected:(_)=>_chooseSlot(slot))]),
    const SizedBox(height:16),
    TextField(controller:_search,decoration:InputDecoration(hintText:'ابحث عن أكلة بتحبها',prefixIcon:const Icon(Icons.search),filled:true,fillColor:AppColors.card,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16))),
     onChanged:(_){_debounce?.cancel();_debounce=Timer(const Duration(milliseconds:300),_load);}),
    const SizedBox(height:12),
    Text('${_tips[_slot]} · ${_selected[_slot]!.length} مفضلة',style:const TextStyle(color:AppColors.muted,fontSize:14,height:1.5)),
    if(_error!=null)TextButton(onPressed:(){_loadSelected();_load();},child:Text(_error!)),
    if(_saving)const Padding(padding:EdgeInsets.only(top:8),child:LinearProgressIndicator()),
    if(_selected[_slot]!.isNotEmpty)Padding(padding:const EdgeInsets.only(top:12),child:Wrap(spacing:6,runSpacing:6,children:[
     for(final f in _selected[_slot]!)InputChip(label:Text('${f['nameAr']}'),backgroundColor:AppColors.nu2.withValues(alpha:.10),onDeleted:_saving?null:()=>_toggle(f)),
    ])),
    const SizedBox(height:12),
   ]))),
   if(_busy)const SliverToBoxAdapter(child:Padding(padding:EdgeInsets.all(32),child:Center(child:CircularProgressIndicator())))
   else if(_foods.isEmpty)const SliverToBoxAdapter(child:Padding(padding:EdgeInsets.all(24),child:Text('مفيش نتائج مناسبة. جرب اسم تاني.',textAlign:TextAlign.center)))
   else SliverPadding(padding:const EdgeInsets.symmetric(horizontal:16),sliver:SliverList(delegate:SliverChildBuilderDelegate((context,i){
    final f=_foods[i],chosen=_selected[_slot]!.any((x)=>'${x['id']}'=='${f['id']}');
    return Padding(padding:const EdgeInsets.only(bottom:8),child:Material(color:chosen?AppColors.nu2.withValues(alpha:.10):AppColors.card,
     shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),side:BorderSide(color:chosen?AppColors.nu2.withValues(alpha:.55):AppColors.muted.withValues(alpha:.15))),
     clipBehavior:Clip.antiAlias,child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:10),
      title:Text('${f['nameAr']}',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)),
      subtitle:Padding(padding:const EdgeInsets.only(top:6),child:Text('${f['cal']??0} سعرة لكل 100 جم',style:const TextStyle(fontSize:14,color:AppColors.muted))),
      trailing:Icon(chosen?Icons.favorite:Icons.favorite_border,color:chosen?AppColors.nu2:AppColors.muted,size:26),
      onTap:(_saving||!_prefsReady)?null:()=>_toggle(f))));
   },childCount:_foods.length))),
   const SliverToBoxAdapter(child:SizedBox(height:24)),
  ]),
 );
}
