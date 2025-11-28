package com.example.android_host_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.Button
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView

class MainActivity : AppCompatActivity() {

    private lateinit var openSdkButton: Button
    private lateinit var logsRecyclerView: RecyclerView
    private lateinit var logsAdapter: KycLogAdapter

    // Permission launcher
    private val permissionLauncher =
        registerForActivityResult(
            ActivityResultContracts.RequestMultiplePermissions()
        ) { result ->
            val cameraGranted = result[Manifest.permission.CAMERA] ?: false
            val fineLocationGranted =
                result[Manifest.permission.ACCESS_FINE_LOCATION] ?: false
            val coarseLocationGranted =
                result[Manifest.permission.ACCESS_COARSE_LOCATION] ?: false

            val locationGranted = fineLocationGranted || coarseLocationGranted

            if (cameraGranted && locationGranted) {
                openUniversalSdk()
            } else {
                Toast.makeText(
                    this,
                    "Camera or location permission not granted. Opening SDK anyway for demo.",
                    Toast.LENGTH_SHORT
                ).show()
                openUniversalSdk()
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        openSdkButton = findViewById(R.id.openSdkButton)
        logsRecyclerView = findViewById(R.id.logsRecyclerView)

        logsAdapter = KycLogAdapter(KycLogStore.events)
        logsRecyclerView.layoutManager = LinearLayoutManager(this)
        logsRecyclerView.adapter = logsAdapter

        openSdkButton.setOnClickListener {
            checkAndRequestPermissions()
        }
    }

    override fun onResume() {
        super.onResume()
        // Refresh logs when coming back from SDK
        logsAdapter.update(KycLogStore.events)
    }

    private fun checkAndRequestPermissions() {
        val cameraStatus = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        )
        val fineLocationStatus = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        )
        val coarseLocationStatus = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )

        val cameraGranted = cameraStatus == PackageManager.PERMISSION_GRANTED
        val locationGranted =
            fineLocationStatus == PackageManager.PERMISSION_GRANTED ||
                    coarseLocationStatus == PackageManager.PERMISSION_GRANTED

        if (cameraGranted && locationGranted) {
            openUniversalSdk()
        } else {
            permissionLauncher.launch(
                arrayOf(
                    Manifest.permission.CAMERA,
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    android.Manifest.permission.ACCESS_COARSE_LOCATION
                )
            )
        }
    }

    private fun openUniversalSdk() {
        startActivity(Intent(this, UniversalSdkActivity::class.java))
    }
}
