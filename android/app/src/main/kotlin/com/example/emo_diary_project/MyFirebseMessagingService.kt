package com.example.emo_diary_spinoff

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // 메시지가 도착했을 때 Flutter로 넘겨 처리할 로직
        if (remoteMessage.data.isNotEmpty()) {
            val title = remoteMessage.data["title"] ?: "알림"
            val body = remoteMessage.data["body"] ?: "새로운 알림이 도착했습니다."
            Log.d("MyFirebaseService", "Message received: title=$title, body=$body")
            // Flutter가 알림을 처리하므로, 여기서는 알림 생성 로직을 제거
        }
    }
}
