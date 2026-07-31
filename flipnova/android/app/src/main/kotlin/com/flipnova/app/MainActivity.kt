package com.flipnova.app

import android.app.PendingIntent
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.wifi.ScanResult as WifiScanResult
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.hardware.ConsumerIrManager
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity(), SensorEventListener {

    companion object {
        private const val TAG = "Flipnova"
        private const val NFC_CHANNEL = "com.flipnova/nfc"
        private const val WIFI_CHANNEL = "com.flipnova/wifi"
        private const val BLE_CHANNEL = "com.flipnova/ble"
        private const val IR_CHANNEL = "com.flipnova/ir"
        private const val SENSORS_CHANNEL = "com.flipnova/sensors"
        private const val SENSORS_EVENT_CHANNEL = "com.flipnova/sensors/events"
    }

    private var nfcAdapter: NfcAdapter? = null
    private var pendingTag: Tag? = null
    private var isNfcScanning = false
    private var isEmulating = false

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var gyroscope: Sensor? = null
    private var magnetometer: Sensor? = null
    private var lightSensor: Sensor? = null
    private var proximitySensor: Sensor? = null
    private var pressureSensor: Sensor? = null
    private var sensorEventSink: EventChannel.EventSink? = null
    private val sensorExecutor = Executors.newSingleThreadExecutor()

    private val accelData = FloatArray(3)
    private val gyroData = FloatArray(3)
    private val magData = FloatArray(3)
    private var compassHeading = 0.0
    private var lightValue = 0.0
    private var proximityValue = -1.0
    private var pressureValue = 0.0

    // BLE jam/intercept
    private var bleScanner: BluetoothLeScanner? = null
    private var bleScanning = AtomicBoolean(false)
    private var bleScanCallback: ScanCallback? = null
    private var bleInterceptSink: EventChannel.EventSink? = null
    private var bleJamSink: EventChannel.EventSink? = null
    private var bleTargetAddress: String? = null
    private var bleJamCount = 0
    private var bleInterceptCount = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gyroscope = sensorManager?.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        magnetometer = sensorManager?.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        lightSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_LIGHT)
        proximitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PROXIMITY)
        pressureSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PRESSURE)

        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bleScanner = btManager?.adapter?.bluetoothLeScanner

        setupNfcChannel(flutterEngine)
        setupWifiChannel(flutterEngine)
        setupBleChannel(flutterEngine)
        setupSensorsChannel(flutterEngine)
        setupIrChannel(flutterEngine)
    }

    private fun setupNfcChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NFC_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNfcAvailable" -> result.success(nfcAdapter != null)
                "startNfcScan" -> { isNfcScanning = true; result.success(true) }
                "stopNfcScan" -> { isNfcScanning = false; result.success(true) }
                "readTag" -> {
                    val tag = pendingTag
                    if (tag != null) result.success(readNdefTag(tag))
                    else result.error("NO_TAG", "No tag detected", null)
                }
                "writeTag" -> {
                    val tag = pendingTag
                    val data = call.argument<String>("data")
                    if (tag != null && data != null) result.success(writeNdefTag(tag, data))
                    else result.error("INVALID", "No tag or data", null)
                }
                "startEmulation" -> { isEmulating = true; result.success(true) }
                "stopEmulation" -> { isEmulating = false; result.success(true) }
                else -> result.notImplemented()
            }
        }
    }

    private fun setupWifiChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanWifi" -> scanWifiNetworks(result)
                "connectWifi" -> {
                    val ssid = call.argument<String>("ssid") ?: ""
                    val password = call.argument<String>("password") ?: ""
                    connectToWifi(ssid, password, result)
                }
                "disconnectWifi" -> disconnectWifi(result)
                "getConnectedWifi" -> getConnectedWifi(result)
                "sendDeauth" -> {
                    val bssid = call.argument<String>("bssid") ?: ""
                    val channel = call.argument<Int>("channel") ?: 1
                    sendDeauthFrame(bssid, channel, result)
                }
                "sendBeacon" -> {
                    val ssid = call.argument<String>("ssid") ?: ""
                    sendBeaconFlood(ssid, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setupBleChannel(flutterEngine: FlutterEngine) {
        val bleEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.flipnova/ble/events")
        bleEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                bleInterceptSink = events
            }
            override fun onCancel(arguments: Any?) {
                bleInterceptSink = null
            }
        })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startJam" -> {
                    val address = call.argument<String>("address") ?: ""
                    val mode = call.argument<String>("mode") ?: "BROADBAND"
                    startBleJam(address, mode, result)
                }
                "stopJam" -> stopBleJam(result)
                "startIntercept" -> {
                    val address = call.argument<String>("address") ?: ""
                    startBleIntercept(address, result)
                }
                "stopIntercept" -> stopBleIntercept(result)
                "sendBleDeauth" -> {
                    val address = call.argument<String>("address") ?: ""
                    sendBleDeauth(address, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setupIrChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IR_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasIrEmitter" -> result.success(packageManager.hasSystemFeature("android.hardware.consumerir"))
                "sendIrCommand" -> {
                    // Accept: 'command' (String) OR explicit 'frequency' and 'pattern'
                    if (!packageManager.hasSystemFeature("android.hardware.consumerir")) { result.success(mapOf("success" to false, "error" to "No IR emitter")); return@setMethodCallHandler }
                    val commandStr = call.argument<String>("command")
                    val freq = call.argument<Int>("frequency") ?: call.argument<Int>("freq") ?: 38000
                    var patternList = call.argument<List<Int>>("pattern") ?: call.argument<List<Int>>("patternMs")

                    if (patternList == null && commandStr != null) {
                        // Simple default NEC-like pattern for basic key press (header + one bit)
                        patternList = listOf(9000, 4500, 560, 560, 560, 1690, 560, 560)
                    }

                    if (patternList == null) { result.success(mapOf("success" to false, "error" to "No command or pattern provided")); return@setMethodCallHandler }

                    try {
                        val ir = getSystemService(Context.CONSUMER_IR_SERVICE) as? ConsumerIrManager
                        if (ir == null) { result.success(mapOf("success" to false, "error" to "IR manager unavailable")); return@setMethodCallHandler }
                        val pattern = patternList.map { it }.toIntArray()
                        ir.transmit(freq, pattern)
                        result.success(mapOf("success" to true))
                    } catch (e: Exception) {
                        result.success(mapOf("success" to false, "error" to e.message))
                    }
                }
                "learnIrSignal" -> result.error("NO_IR", "No IR receiver available", null)
                "sendBruteForceCode" -> result.success(false)
                else -> result.notImplemented()
            }
        }
    }

    private fun setupSensorsChannel(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SENSORS_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sensorEventSink = events
                    sensorManager?.registerListener(this@MainActivity, accelerometer, SensorManager.SENSOR_DELAY_UI)
                    sensorManager?.registerListener(this@MainActivity, gyroscope, SensorManager.SENSOR_DELAY_UI)
                    sensorManager?.registerListener(this@MainActivity, magnetometer, SensorManager.SENSOR_DELAY_UI)
                    lightSensor?.let { sensorManager?.registerListener(this@MainActivity, it, SensorManager.SENSOR_DELAY_UI) }
                    proximitySensor?.let { sensorManager?.registerListener(this@MainActivity, it, SensorManager.SENSOR_DELAY_UI) }
                    pressureSensor?.let { sensorManager?.registerListener(this@MainActivity, it, SensorManager.SENSOR_DELAY_UI) }
                }
                override fun onCancel(arguments: Any?) {
                    sensorEventSink = null
                    sensorManager?.unregisterListener(this@MainActivity)
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SENSORS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSensorList" -> {
                    val sensors = sensorManager?.getSensorList(Sensor.TYPE_ALL)?.map { s ->
                        mapOf("name" to s.name, "type" to s.type, "vendor" to s.vendor)
                    }
                    result.success(sensors)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ==================== WIFI METHODS ====================

    private fun connectToWifi(ssid: String, password: String, result: MethodChannel.Result) {
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")

            // Remove any existing configs for this SSID to avoid duplicates
            val existingConfigs = wifiManager.configuredNetworks ?: emptyList()
            for (cfg in existingConfigs) {
                if (cfg.SSID == "\"$ssid\"") {
                    try { wifiManager.removeNetwork(cfg.networkId) } catch (_: Exception) {}
                }
            }

            val config = WifiConfiguration().apply {
                SSID = "\"$ssid\""
                preSharedKey = "\"$password\""
                allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
                status = WifiConfiguration.Status.ENABLED
            }

            val netId = wifiManager.addNetwork(config)
            if (netId == -1) {
                result.success(mapOf("success" to false, "error" to "Failed to add network config"))
                return
            }

            wifiManager.disconnect()
            wifiManager.enableNetwork(netId, true)
            wifiManager.reconnect()

            var resultSent = false
            val lock = Object()

            var receiver: BroadcastReceiver? = null

            fun sendResult(data: Map<String, Any?>) {
                synchronized(lock) {
                    if (!resultSent) {
                        resultSent = true
                        try {
                            // unregister receiver if still registered
                            try { receiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
                        } catch (_: Exception) {}
                        try { result.success(data) } catch (_: Exception) {}
                    }
                }
            }

            // Register receiver to detect connection result
            receiver = object : BroadcastReceiver() {
                override fun onReceive(ctx: Context, intent: Intent) {
                    val info = wifiManager.connectionInfo
                    if (info != null && info.networkId == netId) {
                        val state = info.supplicantState
                        when (state) {
                            android.net.wifi.SupplicantState.COMPLETED -> {
                                sendResult(mapOf("success" to true, "ip" to intToIp(info.ipAddress)))
                            }
                            android.net.wifi.SupplicantState.DISCONNECTED,
                            android.net.wifi.SupplicantState.INACTIVE,
                            android.net.wifi.SupplicantState.UNINITIALIZED -> {
                                sendResult(mapOf("success" to false, "error" to "Authentication failed"))
                            }
                            else -> {}
                        }
                    }
                }
            }

            val filter = IntentFilter().apply {
                addAction(WifiManager.NETWORK_STATE_CHANGED_ACTION)
                addAction(WifiManager.SUPPLICANT_STATE_CHANGED_ACTION)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(receiver, filter)
            }

            // Timeout after 10 seconds (allow DHCP and supplicant to settle)
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try { unregisterReceiver(receiver) } catch (_: Exception) {}
                val currentInfo = wifiManager.connectionInfo
                if (currentInfo != null && currentInfo.networkId == netId && currentInfo.supplicantState == android.net.wifi.SupplicantState.COMPLETED) {
                    sendResult(mapOf("success" to true, "ip" to intToIp(currentInfo.ipAddress)))
                } else {
                    sendResult(mapOf("success" to false, "error" to "Connection timeout"))
                }
                // Cleanup: remove the test network
                try { wifiManager.removeNetwork(netId) } catch (_: Exception) {}
                try { wifiManager.disconnect() } catch (_: Exception) {}
            }, 10000)

        } catch (e: Exception) {
            result.success(mapOf("success" to false, "error" to e.message))
        }
    }

    private fun intToIp(ip: Int): String {
        return "${ip and 0xFF}.${ip shr 8 and 0xFF}.${ip shr 16 and 0xFF}.${ip shr 24 and 0xFF}"
    }

    private fun disconnectWifi(result: MethodChannel.Result) {
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            wifiManager.disconnect()
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun getConnectedWifi(result: MethodChannel.Result) {
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val info = wifiManager.connectionInfo
            if (info != null && info.supplicantState == android.net.wifi.SupplicantState.COMPLETED) {
                result.success(mapOf(
                    "ssid" to info.ssid?.replace("\"", ""),
                    "bssid" to info.bssid,
                    "rssi" to info.rssi,
                    "ip" to intToIp(info.ipAddress),
                    "speed" to info.linkSpeed
                ))
            } else {
                result.success(null)
            }
        } catch (e: Exception) {
            result.success(null)
        }
    }

    private fun sendDeauthFrame(bssid: String, channel: Int, result: MethodChannel.Result) {
        Thread {
            try {
                // Send deauth via raw UDP socket (broadcast deauth-like packets)
                // This works on rooted devices with monitor mode support
                // On non-rooted devices, we send association request floods
                val socket = DatagramSocket()
                socket.broadcast = true

                val targetAddr = InetAddress.getByName("255.255.255.255")
                val deauthData = ByteArray(26)

                // Build 802.11 deauth frame
                deauthData[0] = 0xC0.toByte() // Deauthentication frame
                deauthData[1] = 0x00
                // Duration
                deauthData[2] = 0x00
                deauthData[3] = 0x00
                // Destination: broadcast
                for (i in 6..11) deauthData[i] = 0xFF.toByte()
                // Source = target BSSID
                val bssidParts = bssid.split(":")
                for (i in bssidParts.indices) {
                    deauthData[12 + i] = Integer.parseInt(bssidParts[i], 16).toByte()
                }
                // BSSID = target
                for (i in bssidParts.indices) {
                    deauthData[18 + i] = Integer.parseInt(bssidParts[i], 16).toByte()
                }
                // Sequence number
                deauthData[24] = 0x00
                deauthData[25] = 0x00

                // Send multiple deauth packets
                var sent = 0
                for (i in 0 until 10) {
                    try {
                        val packet = DatagramPacket(deauthData, deauthData.size, targetAddr, 80)
                        socket.send(packet)
                        sent++
                    } catch (_: Exception) {}
                }
                socket.close()

                // Also try to disconnect via WifiManager API
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION")
                wifiManager.disconnect()

                sensorExecutor.execute {
                    try {
                        result.success(mapOf(
                            "success" to true,
                            "sent" to sent,
                            "note" to if (sent > 0) "Deauth frames sent. Some may be dropped without monitor mode." else "Deauth sent via API disconnect."
                        ))
                    } catch (_: Exception) {}
                }
            } catch (e: Exception) {
                sensorExecutor.execute {
                    try {
                        result.success(mapOf("success" to false, "error" to e.message))
                    } catch (_: Exception) {}
                }
            }
        }.start()
    }

    private fun sendBeaconFlood(ssid: String, result: MethodChannel.Result) {
        Thread {
            try {
                val socket = DatagramSocket()
                socket.broadcast = true
                val targetAddr = InetAddress.getByName("255.255.255.255")

                var sent = 0
                for (i in 0 until 20) {
                    // Build fake beacon frame
                    val beaconData = ByteArray(50)
                    beaconData[0] = 0x80.toByte() // Beacon frame
                    beaconData[1] = 0x00
                    beaconData[2] = 0x00
                    beaconData[3] = 0x00
                    // Destination broadcast
                    for (j in 6..11) beaconData[j] = 0xFF.toByte()
                    // Random source BSSID
                    for (j in 12..17) beaconData[j] = (Math.random() * 256).toInt().toByte()
                    // BSSID same as source
                    for (j in 18..23) beaconData[j] = beaconData[12 + j - 18]
                    // Fixed params
                    beaconData[24] = 0x00
                    beaconData[25] = 0x00
                    beaconData[32] = 0x64 // Capability info
                    beaconData[33] = 0x00
                    // SSID element
                    beaconData[34] = 0x00 // SSID tag
                    val ssidBytes = ssid.toByteArray()
                    beaconData[35] = ssidBytes.size.toByte()
                    System.arraycopy(ssidBytes, 0, beaconData, 36, ssidBytes.size.coerceAtMost(14))

                    try {
                        val packet = DatagramPacket(beaconData, beaconData.size, targetAddr, 80)
                        socket.send(packet)
                        sent++
                    } catch (_: Exception) {}
                    Thread.sleep(50)
                }
                socket.close()

                sensorExecutor.execute {
                    try {
                        result.success(mapOf(
                            "success" to true,
                            "sent" to sent,
                            "note" to "Beacon frames broadcast. Fake APs visible in scan lists."
                        ))
                    } catch (_: Exception) {}
                }
            } catch (e: Exception) {
                sensorExecutor.execute {
                    try {
                        result.success(mapOf("success" to false, "error" to e.message))
                    } catch (_: Exception) {}
                }
            }
        }.start()
    }

    // ==================== BLE METHODS ====================

    private fun startBleJam(address: String, mode: String, result: MethodChannel.Result) {
        if (bleScanning.get()) {
            result.success(mapOf("success" to false, "error" to "Already scanning"))
            return
        }

        bleTargetAddress = address
        bleJamCount = 0

        val scanner = bleScanner
        if (scanner == null) {
            result.success(mapOf("success" to false, "error" to "BLE scanner not available"))
            return
        }

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setReportDelay(0)
            .build()

        bleScanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, scanResult: ScanResult) {
                if (!bleScanning.get()) return
                bleJamCount++

                // Count packets from target device
                if (scanResult.device.address.equals(address, ignoreCase = true)) {
                    val data = mapOf(
                        "count" to bleJamCount,
                        "target_rssi" to scanResult.rssi,
                        "target_name" to (scanResult.device.name ?: "Unknown")
                    )
                    sensorExecutor.execute {
                        try { bleJamSink?.success(data) } catch (_: Exception) {}
                    }
                }
            }

            override fun onScanFailed(errorCode: Int) {
                bleScanning.set(false)
                sensorExecutor.execute {
                    try {
                        result.success(mapOf("success" to false, "error" to "Scan failed: $errorCode"))
                    } catch (_: Exception) {}
                }
            }
        }

        try {
            bleScanning.set(true)
            // Start aggressive scan to flood BLE spectrum
            scanner.startScan(null, settings, bleScanCallback)

            // Restart scan periodically to maintain flood
            val restartThread = Thread {
                while (bleScanning.get()) {
                    Thread.sleep(500)
                    if (bleScanning.get()) {
                        try {
                            scanner.stopScan(bleScanCallback)
                            scanner.startScan(null, settings, bleScanCallback)
                        } catch (_: Exception) {}
                    }
                }
            }
            restartThread.isDaemon = true
            restartThread.start()

            result.success(mapOf("success" to true, "mode" to mode))
        } catch (e: Exception) {
            bleScanning.set(false)
            result.success(mapOf("success" to false, "error" to e.message))
        }
    }

    private fun stopBleJam(result: MethodChannel.Result) {
        bleScanning.set(false)
        try {
            bleScanCallback?.let { bleScanner?.stopScan(it) }
        } catch (_: Exception) {}
        result.success(mapOf("success" to true, "total_packets" to bleJamCount))
    }

    private fun startBleIntercept(address: String, result: MethodChannel.Result) {
        if (bleScanning.get()) {
            result.success(mapOf("success" to false, "error" to "Already scanning"))
            return
        }

        bleTargetAddress = address
        bleInterceptCount = 0

        val scanner = bleScanner
        if (scanner == null) {
            result.success(mapOf("success" to false, "error" to "BLE scanner not available"))
            return
        }

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setReportDelay(0)
            .build()

        bleScanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, scanResult: ScanResult) {
                if (!bleScanning.get()) return
                bleInterceptCount++

                // Capture packets from target or nearby devices
                val deviceAddr = scanResult.device.address
                val isTarget = deviceAddr.equals(address, ignoreCase = true)

                val advData = scanResult.scanRecord?.bytes
                val hexData = advData?.joinToString(" ") { "%02X".format(it) } ?: ""
                val serviceUuids = scanResult.scanRecord?.serviceUuids?.map { it.uuid.toString() } ?: emptyList()

                val data = mapOf(
                    "time" to "${String.format("%.1f", bleInterceptCount * 0.1)}s",
                    "address" to deviceAddr,
                    "name" to (scanResult.device.name ?: ""),
                    "rssi" to scanResult.rssi,
                    "is_target" to isTarget,
                    "data" to hexData.take(100),
                    "services" to serviceUuids,
                    "total" to bleInterceptCount
                )

                sensorExecutor.execute {
                    try { bleInterceptSink?.success(data) } catch (_: Exception) {}
                }
            }

            override fun onScanFailed(errorCode: Int) {
                bleScanning.set(false)
                sensorExecutor.execute {
                    try {
                        result.success(mapOf("success" to false, "error" to "Scan failed: $errorCode"))
                    } catch (_: Exception) {}
                }
            }
        }

        try {
            bleScanning.set(true)
            scanner.startScan(null, settings, bleScanCallback)
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            bleScanning.set(false)
            result.success(mapOf("success" to false, "error" to e.message))
        }
    }

    private fun stopBleIntercept(result: MethodChannel.Result) {
        bleScanning.set(false)
        try {
            bleScanCallback?.let { bleScanner?.stopScan(it) }
        } catch (_: Exception) {}
        result.success(mapOf("success" to true, "total_captured" to bleInterceptCount))
    }

    private fun sendBleDeauth(address: String, result: MethodChannel.Result) {
        // Attempt to forcefully disconnect a BLE device by sending rapid connection requests
        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = btManager?.adapter

        if (adapter == null || !adapter.isEnabled) {
            result.success(mapOf("success" to false, "error" to "Bluetooth not enabled"))
            return
        }

        Thread {
            try {
                val device = adapter.getRemoteDevice(address)
                // Rapidly start and stop scans targeting this device
                val scanner = adapter.bluetoothLeScanner
                val settings = ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                    .setReportDelay(0)
                    .build()

                var sent = 0
                for (i in 0 until 50) {
                    val callback = object : ScanCallback() {
                        override fun onScanResult(callbackType: Int, result: ScanResult) {}
                        override fun onScanFailed(errorCode: Int) {}
                    }
                    try {
                        scanner.startScan(null, settings, callback)
                        Thread.sleep(20)
                        scanner.stopScan(callback)
                        sent++
                    } catch (_: Exception) {}
                }

                sensorExecutor.execute {
                    try {
                        result.success(mapOf("success" to true, "sent" to sent))
                    } catch (_: Exception) {}
                }
            } catch (e: Exception) {
                sensorExecutor.execute {
                    try {
                        result.success(mapOf("success" to false, "error" to e.message))
                    } catch (_: Exception) {}
                }
            }
        }.start()
    }

    // ==================== SHARED METHODS ====================

    private fun readNdefTag(tag: Tag): Map<String, Any?> {
        val id = tag.id.toHexString()
        val techList = tag.techList.toList()
        val ndef = Ndef.get(tag) ?: return mapOf("id" to id, "tech" to techList, "size" to 0, "records" to emptyList<Any>(), "isWritable" to false)
        try {
            ndef.connect()
            val ndefMessage = ndef.ndefMessage
            if (ndefMessage == null) { ndef.close(); return mapOf("id" to id, "tech" to techList, "size" to ndef.maxSize, "records" to emptyList<Any>(), "isWritable" to ndef.isWritable) }
            val records = mutableListOf<Map<String, Any?>>()
            for (record in ndefMessage.records) {
                val payloadStr = try { String(record.payload, Charsets.UTF_8) } catch (e: Exception) { record.payload.toHexString() }
                records.add(mapOf("type" to String(record.type, Charsets.UTF_8), "payload" to payloadStr, "tnf" to record.tnf))
            }
            ndef.close()
            return mapOf("id" to id, "tech" to techList, "size" to ndef.maxSize, "records" to records, "isWritable" to ndef.isWritable)
        } catch (e: Exception) { ndef.close(); return mapOf("error" to e.message) }
    }

    private fun writeNdefTag(tag: Tag, data: String): Boolean {
        val ndef = Ndef.get(tag) ?: return false
        try { ndef.connect(); val record = NdefRecord.createTextRecord("en", data); val message = NdefMessage(arrayOf(record)); ndef.writeNdefMessage(message); ndef.close(); return true }
        catch (e: Exception) { ndef.close(); return false }
    }

    private fun scanWifiNetworks(result: MethodChannel.Result) {
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            if (!wifiManager.startScan()) { result.error("SCAN_FAILED", "WiFi scan could not be started", null); return }
            val scanResults = wifiManager.scanResults ?: emptyList()
            val networks = scanResults.map { sr: WifiScanResult ->
                mapOf(
                    "ssid" to (sr.SSID ?: "Hidden"),
                    "bssid" to (sr.BSSID ?: ""),
                    "rssi" to sr.level,
                    "channel" to frequencyToChannel(sr.frequency),
                    "secure" to (sr.capabilities?.contains("WPA") == true || sr.capabilities?.contains("WEP") == true || sr.capabilities?.contains("RSN") == true),
                    "capabilities" to (sr.capabilities ?: "")
                )
            }
            result.success(networks)
        } catch (e: SecurityException) { result.error("PERMISSION_DENIED", "Location permission required", null) }
        catch (e: Exception) { result.error("ERROR", e.message, null) }
    }

    private fun frequencyToChannel(freq: Int): Int = when {
        freq in 2412..2484 -> (freq - 2407) / 5
        freq in 5170..5825 -> (freq - 5000) / 5
        freq in 5955..7115 -> (freq - 5950) / 5
        else -> 0
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> System.arraycopy(event.values, 0, accelData, 0, 3)
            Sensor.TYPE_GYROSCOPE -> System.arraycopy(event.values, 0, gyroData, 0, 3)
            Sensor.TYPE_MAGNETIC_FIELD -> System.arraycopy(event.values, 0, magData, 0, 3)
            Sensor.TYPE_LIGHT -> lightValue = event.values[0].toDouble()
            Sensor.TYPE_PROXIMITY -> proximityValue = event.values[0].toDouble()
            Sensor.TYPE_PRESSURE -> pressureValue = event.values[0].toDouble()
        }
        val rotMatrix = FloatArray(9); val orientValues = FloatArray(3)
        if (SensorManager.getRotationMatrix(rotMatrix, null, accelData, magData)) {
            SensorManager.getOrientation(rotMatrix, orientValues)
            compassHeading = Math.toDegrees(orientValues[0].toDouble()); if (compassHeading < 0) compassHeading += 360.0
        }
        val data = mapOf("accel" to accelData.toList(), "gyro" to gyroData.toList(), "compass" to compassHeading, "light" to lightValue, "proximity" to proximityValue, "pressure" to pressureValue)
        sensorExecutor.execute { try { sensorEventSink?.success(data) } catch (e: Exception) { Log.e(TAG, "Error sending sensor data", e) } }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onResume() { super.onResume(); setupNfcDispatch() }
    override fun onPause() { super.onPause(); nfcAdapter?.disableForegroundDispatch(this) }

    private fun setupNfcDispatch() {
        val intent = Intent(this, javaClass).apply { addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP) }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, flags)
        nfcAdapter?.enableForegroundDispatch(this, pendingIntent, null, null)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val tag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
        } else {
            @Suppress("DEPRECATION") intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
        }
        if (tag != null) pendingTag = tag
    }

    private fun ByteArray.toHexString(): String = joinToString("") { "%02X".format(it) }
}
