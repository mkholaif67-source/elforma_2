package com.elforma.elforma

import android.app.Activity
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView

class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = TextView(this).apply {
            text = "خصوصية خطواتك في الفورمة\n\nنطلب قراءة عدد خطواتك من Health Connect لعرض خطوات اليوم وآخر 7 أيام ومقارنتها بهدف تختاره.\n\nلا نطلب موقعك أو بياناتك الطبية الأخرى، ولا نكتب بيانات في Health Connect. تُقرأ الخطوات على جهازك ولا تُرسل لخادم الفورمة أو للإعلانات أو لترتيب التحديات.\n\nيمكنك إلغاء إذن القراءة في أي وقت من إعدادات Health Connect. هدف الخطوات محفوظ على هذا الجهاز لكل حساب. قد تحتاج لربط تطبيق يسجل الخطوات مثل Samsung Health لتظهر البيانات."
            textSize = 18f
            setTextColor(android.graphics.Color.rgb(23, 61, 46))
            setPadding(28, 48, 28, 48)
            layoutDirection = android.view.View.LAYOUT_DIRECTION_RTL
        }
        setContentView(ScrollView(this).apply { setBackgroundColor(android.graphics.Color.rgb(247,249,241)); addView(text) })
    }
}
