package com.example.cashawy_pro
// ⚠️ سيب أول سطر بتاع (package ...) اللي عندك فوق زي ما هو متمسحوش!

import android.Manifest
import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMS_EVENT_CHANNEL = "cashawy/sms_stream"
    private val PERMISSION_METHOD_CHANNEL = "cashawy/permissions"
    private val USSD_METHOD_CHANNEL = "cashawy/ussd_channel"

    companion object {
        var eventSink: EventChannel.EventSink? = null
        // متغيرات مؤقتة لحفظ الرقم السري أثناء تنفيذ عملية التحويل فقط
        var pendingPinCode: String? = null
        var isAwaitingUssdPin: Boolean = false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. قناة بث الرسائل اللحظية
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        // 2. قناة الصلاحيات
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSmsPermissions" -> {
                    val hasPermission = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECEIVE_SMS
                    ) == PackageManager.PERMISSION_GRANTED

                    if (!hasPermission) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(
                                Manifest.permission.RECEIVE_SMS,
                                Manifest.permission.READ_SMS,
                                Manifest.permission.CALL_PHONE,
                                Manifest.permission.READ_PHONE_STATE
                            ),
                            101
                        )
                        result.success(false)
                    } else {
                        result.success(true)
                    }
                }
                "checkSmsPermissions" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECEIVE_SMS
                    ) == PackageManager.PERMISSION_GRANTED &&
                    ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.CALL_PHONE
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                else -> result.notImplemented()
            }
        }

        // 3. قناة تنفيذ أكواد الـ USSD والتحويل بضغطة واحدة
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USSD_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "executeUssdTransfer" -> {
                    val ussdCode = call.argument<String>("ussdCode") ?: ""
                    val pinCode = call.argument<String>("pinCode") ?: ""
                    val simSlot = call.argument<Int>("simSlot") ?: 0 // 0 للشريحة الأولى، 1 للشريحة الثانية

                    if (ussdCode.isEmpty()) {
                        result.error("INVALID_CODE", "كود التحويل فارغ", null)
                        return@setMethodCallHandler
                    }

                    // تجهيز الرقم السري ليكتبه النظام تلقائياً فور ظهور نافذة الشبكة
                    if (pinCode.isNotEmpty()) {
                        pendingPinCode = pinCode
                        isAwaitingUssdPin = true
                    } else {
                        isAwaitingUssdPin = false
                    }

                    val dialSuccess = dialUssdCode(ussdCode, simSlot)
                    result.success(dialSuccess)
                }
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * دالة الاتصال بكود الـ USSD مع دعم اختيار الشريحة (SIM 1 أو SIM 2)
     */
    private fun dialUssdCode(ussdCode: String, simSlot: Int): Boolean {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CALL_PHONE, Manifest.permission.READ_PHONE_STATE),
                102
            )
            return false
        }

        // تحويل رمز الشباك # إلى %23 ليفهمه نظام الاتصال في أندرويد
        val encodedHash = Uri.encode("#")
        val cleanCode = ussdCode.replace("#", encodedHash)
        val uri = Uri.parse("tel:$cleanCode")

        val intent = Intent(Intent.ACTION_CALL, uri)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

        // تحديد الشريحة المطلوبة (SIM 1 = 0, SIM 2 = 1)
        try {
            intent.putExtra("com.android.phone.force.slot", true)
            intent.putExtra("Cdma_Supp", true)
            intent.putExtra("simSlot", simSlot)
            intent.putExtra("slot", simSlot)
            intent.putExtra("simnum", simSlot + 1)
            intent.putExtra("phone", simSlot)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
            ) {
                val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                val phoneAccountHandleList = telecomManager.callCapablePhoneAccounts
                if (phoneAccountHandleList != null && phoneAccountHandleList.size > simSlot) {
                    intent.putExtra(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, phoneAccountHandleList[simSlot])
                }
            }
        } catch (_: Exception) {}

        startActivity(intent)
        return true
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val prefString = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        return prefString != null && prefString.contains("${packageName}/${UssdAccessibilityService::class.java.name}")
    }
}

/**
 * 1. الرادار الخلفي لالتقاط رسائل الـ SMS
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNotEmpty()) {
                val sender = messages[0].originatingAddress ?: "Unknown"
                val fullBody = StringBuilder()
                for (sms in messages) {
                    fullBody.append(sms.messageBody ?: "")
                }
                val smsData = mapOf(
                    "sender" to sender,
                    "body" to fullBody.toString(),
                    "timestamp" to System.currentTimeMillis()
                )
                MainActivity.eventSink?.success(smsData)
            }
        }
    }
}

/**
 * 2. المساعد الذكي: يراقب نافذة الـ USSD، يكتب الرقم السري للمحفظة، ويضغط إرسال تلقائياً
 */
class UssdAccessibilityService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!MainActivity.isAwaitingUssdPin || MainActivity.pendingPinCode.isNullOrEmpty()) return

        val rootNode = rootInActiveWindow ?: return

        // البحث عن خانة كتابة الرقم السري داخل نافذة الـ USSD
        val editTextNode = findEditTextNode(rootNode)
        if (editTextNode != null) {
            val arguments = Bundle()
            arguments.putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                MainActivity.pendingPinCode
            )
            editTextNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)

            // تصفير الرقم السري فوراً بعد كتابته للأمان ولعدم تكرار الإرسال
            MainActivity.isAwaitingUssdPin = false
            MainActivity.pendingPinCode = null

            // البحث عن زر الإرسال (Send / إرسال / موافق / OK) والضغط عليه تلقائياً
            val sendButtonTexts = listOf("إرسال", "ارسال", "Send", "SEND", "موافق", "OK", "تأكيد")
            for (btnText in sendButtonTexts) {
                val buttons = rootNode.findAccessibilityNodeInfosByText(btnText)
                if (!buttons.isNullOrEmpty()) {
                    for (btn in buttons) {
                        if (btn.isClickable) {
                            btn.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                            return
                        } else if (btn.parent != null && btn.parent.isClickable) {
                            btn.parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                            return
                        }
                    }
                }
            }
        }
    }

    private fun findEditTextNode(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null
        if (node.className != null && node.className.toString().contains("EditText")) {
            return node
        }
        for (i in 0 until node.childCount) {
            val found = findEditTextNode(node.getChild(i))
            if (found != null) return found
        }
        return null
    }

    override fun onInterrupt() {}
}