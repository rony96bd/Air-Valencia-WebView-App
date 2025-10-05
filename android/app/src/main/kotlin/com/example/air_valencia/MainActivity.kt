package com.example.air_valencia

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Hide launch screen immediately
        setTheme(R.style.NormalTheme)
        super.onCreate(savedInstanceState)
    }
}
