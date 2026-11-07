package dev.kairostep.kairo_step

import android.content.Intent
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingContactResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CONTACTS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // 系统联系人选择器（ACTION_PICK）：不申请 READ_CONTACTS 权限，
                // 仅返回用户在系统界面主动选中的那一条（姓名 + 首个电话）。
                "pickContact" -> {
                    pendingContactResult = result
                    try {
                        val intent = Intent(
                            Intent.ACTION_PICK,
                            ContactsContract.Contacts.CONTENT_URI,
                        )
                        startActivityForResult(intent, PICK_CONTACT_REQUEST)
                    } catch (e: Exception) {
                        // 无通讯录应用（部分模拟器/平板）：回退空值，Dart 侧提示手动填写
                        pendingContactResult = null
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_CONTACT_REQUEST) return
        val result = pendingContactResult
        pendingContactResult = null
        if (result == null) return

        if (resultCode != RESULT_OK || data?.data == null) {
            result.success(null) // 用户取消选择
            return
        }

        try {
            val contactUri = data.data!!
            var name = ""
            var phone = ""
            contentResolver.query(contactUri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    name = cursor.getString(
                        cursor.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME),
                    ) ?: ""
                    val hasPhone = cursor.getInt(
                        cursor.getColumnIndexOrThrow(ContactsContract.Contacts.HAS_PHONE_NUMBER),
                    ) > 0
                    if (hasPhone) {
                        val contactId = cursor.getString(
                            cursor.getColumnIndexOrThrow(ContactsContract.Contacts._ID),
                        )
                        contentResolver.query(
                            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                            null,
                            "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
                            arrayOf(contactId),
                            null,
                        )?.use { phoneCursor ->
                            if (phoneCursor.moveToFirst()) {
                                phone = phoneCursor.getString(
                                    phoneCursor.getColumnIndexOrThrow(
                                        ContactsContract.CommonDataKinds.Phone.NUMBER,
                                    ),
                                ) ?: ""
                            }
                        }
                    }
                }
            }
            result.success(mapOf("name" to name, "phone" to phone))
        } catch (e: Exception) {
            result.success(null)
        }
    }

    companion object {
        private const val CONTACTS_CHANNEL = "kairostep/contacts"
        private const val PICK_CONTACT_REQUEST = 4021
    }
}
