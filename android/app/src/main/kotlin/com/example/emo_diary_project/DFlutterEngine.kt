package com.example.emo_diary_spinoff

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine

class DFlutterEngine(private val context: Context, private val flutterEngine: FlutterEngine) {
    fun initialize() {}

    fun startAnotherActivity() {
        val intent = Intent(context, UsageActivity::class.java)
        context.startActivity(intent)
    }

}