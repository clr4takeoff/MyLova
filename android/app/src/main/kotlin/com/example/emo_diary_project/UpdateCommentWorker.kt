package com.example.emo_diary_project

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.firebase.FirebaseApp
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.ktx.Firebase
import com.google.firebase.database.ktx.database
import android.content.SharedPreferences
import android.preference.PreferenceManager

class UpdateCommentWorker(appContext: Context, workerParams: WorkerParameters) : Worker(appContext, workerParams) {

    override fun doWork(): Result {
        // Firebase 초기화 확인
        if (FirebaseApp.getApps(applicationContext).isEmpty()) {
            FirebaseApp.initializeApp(applicationContext)
        }

        // SharedPreferences에서 userId 가져오기 (username으로 이름 변경하여 일관성 유지)
        val sharedPreferences: SharedPreferences = PreferenceManager.getDefaultSharedPreferences(applicationContext)
        val userName = sharedPreferences.getString("name", null) // 기본값 없이 null로 설정

        // userName이 null인 경우 작업 실패 처리
        if (userName == null) {
            return Result.failure()
        }

        // inputData에서 diaryId 가져오기
        val diaryId = inputData.getString("diaryId") ?: return Result.failure()

        // Firebase Database 경로에 userName 포함
        val ref = Firebase.database.getReference("test/$userName/$diaryId")

        return try {
            ref.updateChildren(mapOf("isCommented" to true)) // isCommented 업데이트
            Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            Result.retry()
        }
    }
}
