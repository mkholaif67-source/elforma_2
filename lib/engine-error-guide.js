'use strict';
const GUIDE = Object.freeze({
  engine_missing_age:'محتاجين عمرك عشان نحسب احتياجك بدقة — اكمل بياناتك الأساسية.',
  engine_missing_height:'محتاجين طولك بالسنتيمتر عشان نحسب معدل الأيض الأساسي.',
  engine_missing_weight:'محتاجين وزنك الحالي بالكيلو عشان نبني خطة صحيحة.',
  engine_implausible_age:'العمر المكتوب غير منطقي — راجعه من فضلك.',
  engine_implausible_height:'الطول المكتوب غير منطقي — اكتبه بالسنتيمتر (مثال: 178).',
  engine_implausible_weight:'الوزن المكتوب غير منطقي — اكتبه بالكيلوجرام.',
  engine_implausible_target:'وزن الهدف غير منطقي — راجعه من فضلك.',
  engine_zero_protein:'بياناتك ناقصة فما قدرناش نحدد البروتين المناسب — اكمل ملفك وحاول تاني.',
  engine_implausible_bmr:'الأرقام المدخلة مش متسقة — راجع الطول والوزن والعمر.',
  engine_implausible_tdee:'الأرقام المدخلة مش متسقة — راجع نشاطك اليومي.',
  engine_target_exceeds_tdee:'فيه تناقض بين بياناتك — راجع الوزن والنشاط والهدف.'
});
function codeFrom(error) { return String((error && error.message) || error || '').split(':')[0]; }
function messageFor(error) { return GUIDE[codeFrom(error)] || null; }
module.exports = { GUIDE, codeFrom, messageFor };
