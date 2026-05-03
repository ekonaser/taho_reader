package com.example.taho_reader

import android.app.PendingIntent
import android.content.*
import android.hardware.usb.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.Executors
import androidx.annotation.NonNull

class MainActivity : FlutterActivity() {

  private val channelName = "com.example.taho_reader/taho_reader"

  private lateinit var usbManager: UsbManager
  private var usbConnection: UsbDeviceConnection? = null
  private var usbInterface: UsbInterface? = null
  private var inEndpoint: UsbEndpoint? = null
  private var outEndpoint: UsbEndpoint? = null

  private var sequenceNumber = 0
  private val usbPermissionAction = "com.example.taho_reader.USB_PERMISSION"

  private var lastAtr: ByteArray? = null

  private val executor = Executors.newSingleThreadExecutor()

  private val usbReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      intent ?: return
      when (intent.action) {
        usbPermissionAction -> {
          val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
          val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
          if (device != null && granted) openUsbDevice(device)
        }

        UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
          val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
          if (device != null) findAndOpenUsbDevice(device)
        }
      }
    }
  }

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    usbManager = getSystemService(Context.USB_SERVICE) as UsbManager

    val filter = IntentFilter(usbPermissionAction).apply {
      addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
    }

    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
      registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
    } else {
      registerReceiver(usbReceiver, filter)
    }

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->

        when (call.method) {

          "initReader" -> result.success(initReader())
          "isConnected" -> result.success(usbConnection != null)
          "isCardPresent" -> result.success(isCardPresent())
          "getReaderInfo" -> result.success(getReaderInfo())
          "getATR" -> result.success(getATR())

          "close" -> {
            closeUsbConnection()
            result.success(null)
          }

          "transmit" -> {
            val cmd = call.arguments as? ByteArray
            if (cmd == null) {
              result.error("INVALID_ARGUMENT", "Expected byte array", null)
            } else {
              executor.execute {
                try {
                  val res = transmitApdu(cmd)
                  runOnUiThread { result.success(res) }
                } catch (e: Exception) {
                  runOnUiThread { result.error("TX_ERROR", e.message, null) }
                }
              }
            }
          }

          "readData" -> {
            val length = call.argument<Int>("length") ?: 0
            executor.execute {
              try {
                val data = readData(length)
                runOnUiThread { result.success(data) }
              } catch (e: Exception) {
                runOnUiThread { result.error("READ_ERROR", e.message, null) }
              }
            }
          }

          else -> result.notImplemented()
        }
      }
  }

  override fun onDestroy() {
    super.onDestroy()
    unregisterReceiver(usbReceiver)
    closeUsbConnection()
    executor.shutdown()
  }

  // ---------------- CORE ----------------

  private fun initReader(): Boolean {
    val device = findUsbDevice() ?: return false
    return if (usbManager.hasPermission(device)) openUsbDevice(device)
    else {
      requestUsbPermission(device)
      false
    }
  }

  private fun findUsbDevice(): UsbDevice? {
    return usbManager.deviceList.values.firstOrNull { device ->
      (0 until device.interfaceCount).any {
        device.getInterface(it).interfaceClass == 0x0B
      }
    }
  }

  private fun findAndOpenUsbDevice(device: UsbDevice) {
    if (usbManager.hasPermission(device)) openUsbDevice(device)
    else requestUsbPermission(device)
  }

  private fun requestUsbPermission(device: UsbDevice) {
    val intent = Intent(usbPermissionAction)
    val flags = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
      PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    } else PendingIntent.FLAG_UPDATE_CURRENT

    val pi = PendingIntent.getBroadcast(this, 0, intent, flags)
    usbManager.requestPermission(device, pi)
  }

  private fun openUsbDevice(device: UsbDevice): Boolean {
    closeUsbConnection()

    val conn = usbManager.openDevice(device) ?: return false

    val iface = (0 until device.interfaceCount)
      .map { device.getInterface(it) }
      .firstOrNull { it.interfaceClass == 0x0B }
      ?: return false

    if (!conn.claimInterface(iface, true)) {
      conn.close()
      return false
    }

    usbInterface = iface
    usbConnection = conn

    inEndpoint = null
    outEndpoint = null

    for (i in 0 until iface.endpointCount) {
      val ep = iface.getEndpoint(i)
      if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
        if (ep.direction == UsbConstants.USB_DIR_IN) inEndpoint = ep
        else outEndpoint = ep
      }
    }

    return inEndpoint != null && outEndpoint != null
  }

  private fun closeUsbConnection() {
    try {
      usbConnection?.releaseInterface(usbInterface)
      usbConnection?.close()
    } catch (_: Exception) {}
    usbConnection = null
    usbInterface = null
    inEndpoint = null
    outEndpoint = null
  }

  // ---------------- READ DATA (UPORABA ITERATOR2023) ----------------

  @Throws(Exception::class)
  private fun readData(length: Int): ByteArray {
    println("readData: Received length = $length")
    val result = java.io.ByteArrayOutputStream()
    val iterator = Iterator2023(length)

    while (true) {
      val chunk = iterator.next()
      if (chunk == 0.toShort()) break

      val pos = result.size()
      println("DEBUG: Reading chunk at offset $pos, length $chunk")

      val cmd = byteArrayOf(
        0x00, 0xB0.toByte(),
        ((pos shr 8) and 0xFF).toByte(),
        (pos and 0xFF).toByte(),
        (chunk.toInt() and 0xFF).toByte()
      )

      val resp = transmitApdu(cmd)
      if (resp.size < 2) break

      val sw1 = resp[resp.size - 2].toInt() and 0xFF
      val sw2 = resp[resp.size - 1].toInt() and 0xFF

      if (sw1 != 0x90 || sw2 != 0x00) break

      // Strip status bytes (SW1, SW2)
      result.write(resp, 0, resp.size - 2)
    }

    return result.toByteArray()
  }

  class Iterator2023(len: Int) {
    private var no = len / 255
    private var rem = (len % 255).toShort()

    fun next(): Short {
      return if (no > 0) {
        no--
        255.toShort()
      } else if (rem.toInt() != 0) {
        val t = rem
        rem = 0
        t
      } else {
        0
      }
    }
  }

  // ---------------- APDU & CCID CORE ----------------

  @Throws(Exception::class, IOException::class)
  private fun transmitApdu(command: ByteArray): ByteArray {
    var response = sendApduCommand(command)

    var limit = 0
    while (response.size == 2 && (response[0].toInt() and 0xFF) == 0x61 && limit < 15) {
      val lenToGet = response[1].toInt() and 0xFF
      val getResponseCmd = byteArrayOf(0x00, 0xC0.toByte(), 0x00, 0x00, if (lenToGet == 0) 0x00.toByte() else lenToGet.toByte())
      response = sendApduCommand(getResponseCmd)
      limit++
    }

    return response
  }

  @Throws(IllegalStateException::class, IOException::class)
  private fun sendApduCommand(command: ByteArray): ByteArray {
    val connection = usbConnection ?: throw IllegalStateException("No USB reader connected")
    val out = outEndpoint ?: throw IllegalStateException("USB output endpoint not found")
    val input = inEndpoint ?: throw IllegalStateException("USB input endpoint not found")

    // 1. Pošiljanje ukaza
    val wrappedCommand = buildCcIdXfrBlock(command)
    val sent = connection.bulkTransfer(out, wrappedCommand, wrappedCommand.size, 5000)
    if (sent < 0) throw IOException("CCID Send failed")

    println("CCID SENT: " + command.joinToString("") { String.format("%02X", it.toInt() and 0xFF) })

    var responseBuffer = ByteArray(10) // Najprej preberemo samo glavo
    var totalReceived = 0

    // 2. Branje odgovora (z zanko za Time Extension in sestavljanje paketov)
    while (true) {
      val tempBuffer = ByteArray(4096)
      val received = connection.bulkTransfer(input, tempBuffer, tempBuffer.size, 5000)

      if (received < 10) throw IOException("CCID Receive failed (too short: $received)")

      val ccidStatus = tempBuffer[7].toInt() and 0xFF

      // Če je kartica še zaposlena (Time Extension 0x40), čakamo naprej
      if ((ccidStatus and 0x40) != 0) {
        println("DEBUG: Card busy (0x40), waiting...")
        continue
      }

      // Izračunamo pričakovano dolžino iz CCID glave (bazičnih 10 bajtov + podatki)
      val expectedDataLength = (tempBuffer[1].toInt() and 0xFF) or
              ((tempBuffer[2].toInt() and 0xFF) shl 8) or
              ((tempBuffer[3].toInt() and 0xFF) shl 16) or
              ((tempBuffer[4].toInt() and 0xFF) shl 24)

      val totalExpected = 10 + expectedDataLength
      var fullResponse = tempBuffer.copyOfRange(0, received)

      // 3. KLJUČNI POPRAVEK: Branje preostalih kosov, če paket ni cel
      var currentReceived = received
      while (currentReceived < totalExpected) {
        val chunk = ByteArray(4096)
        val chunkReceived = connection.bulkTransfer(input, chunk, chunk.size, 2000)
        if (chunkReceived <= 0) break

        val newResponse = ByteArray(fullResponse.size + chunkReceived)
        System.arraycopy(fullResponse, 0, newResponse, 0, fullResponse.size)
        System.arraycopy(chunk, 0, newResponse, fullResponse.size, chunkReceived)
        fullResponse = newResponse
        currentReceived += chunkReceived
      }

      // Vrnemo samo APDU del (brez 10 bajtov CCID glave)
      val response = if (expectedDataLength > 0) {
        fullResponse.copyOfRange(10, 10 + expectedDataLength)
      } else {
        ByteArray(0)
      }

      println("CCID RCVD: " + response.joinToString("") { String.format("%02X", it.toInt() and 0xFF) })
      return response
    }
  }

  private fun getCcidStatus(): Int {
    return try {
      val connection = usbConnection ?: return 2
      val out = outEndpoint ?: return 2
      val input = inEndpoint ?: return 2
      val cmd = byteArrayOf(0x65, 0, 0, 0, 0, 0, (sequenceNumber++ and 0xFF).toByte(), 0, 0, 0)
      connection.bulkTransfer(out, cmd, cmd.size, 1000)
      val buffer = ByteArray(64)
      val received = connection.bulkTransfer(input, buffer, buffer.size, 1000)
      if (received >= 10) buffer[7].toInt() and 0x03 else 2
    } catch (e: Exception) { 2 }
  }

  private fun powerOnCard(): Boolean {
    return try {
      val connection = usbConnection ?: return false
      val out = outEndpoint ?: return false
      val input = inEndpoint ?: return false

      // PC_to_RDR_IccPowerOn (0x62) s 5V (0x01)
      val cmd = byteArrayOf(0x62, 0, 0, 0, 0, 0, (sequenceNumber++ and 0xFF).toByte(), 0x01, 0, 0)
      connection.bulkTransfer(out, cmd, cmd.size, 5000)

      val buffer = ByteArray(512)
      val received = connection.bulkTransfer(input, buffer, buffer.size, 5000)
      if (received >= 10 && (buffer[0].toInt() and 0xFF) == 0x80) {
        val len = (buffer[1].toInt() and 0xFF) or ((buffer[2].toInt() and 0xFF) shl 8)
        lastAtr = buffer.copyOfRange(10, 10 + len)
        println("ATR: " + lastAtr?.joinToString("") { String.format("%02X", it.toInt() and 0xFF) })

        // Nastavimo T=0 parametre takoj po vklopu
        setT0Parameters()
        return true
      }
      false
    } catch (e: Exception) { false }
  }

  private fun setT0Parameters() {
    try {
      val connection = usbConnection ?: return
      val out = outEndpoint ?: return

      // Ukaz 0x61 (PC_to_RDR_SetParameters) za protokol T=0
      val cmd = ByteArray(10 + 5)
      cmd[0] = 0x61.toByte()
      cmd[1] = 0x05.toByte() // Dolžina za T=0
      cmd[5] = 0x00          // Slot
      cmd[6] = (sequenceNumber++ and 0xFF).toByte()
      cmd[7] = 0x00          // T=0 protokol

      cmd[10] = 0x11.toByte() // bmFindexDindex
      cmd[11] = 0x00.toByte() // bmTCCKST0
      cmd[12] = 0x00.toByte() // bGuardTimeT0
      cmd[13] = 0x00.toByte() // bWaitingIntegerT0
      cmd[14] = 0x00.toByte() // bClockStop

      connection.bulkTransfer(out, cmd, cmd.size, 1000)
    } catch (_: Exception) {}
  }

  private fun buildCcIdXfrBlock(command: ByteArray): ByteArray {
    val length = command.size
    val out = ByteArray(10 + length)
    out[0] = 0x6F.toByte() // PC_to_RDR_XfrBlock
    out[1] = (length and 0xFF).toByte()
    out[2] = ((length shr 8) and 0xFF).toByte()
    out[3] = ((length shr 16) and 0xFF).toByte()
    out[4] = ((length shr 24) and 0xFF).toByte()
    out[5] = 0x00 // Slot
    out[6] = (sequenceNumber++ and 0xFF).toByte()
    out[7] = 0x00 // BWI
    out[8] = 0x00 // LevelParameter
    out[9] = 0x00
    System.arraycopy(command, 0, out, 10, length)
    return out
  }

  private fun isCardPresent() = getCcidStatus() < 2
  private fun getATR(): ByteArray? {
    if (lastAtr == null) {
      powerOnCard() // Poskusi vklopiti kartico, če še nimaš ATR-ja
    }
    return lastAtr
  }
  private fun getReaderInfo() = mapOf("connected" to (usbConnection != null))
}
