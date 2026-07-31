package com.flipnova.app

import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.os.Bundle
import android.nfc.cardemulation.HostApduService
import android.util.Log

class NfcHceService : HostApduService() {

    companion object {
        private const val TAG = "NfcHceService"
        private val SELECT_APDU = byteArrayOf(
            0x00.toByte(), 0xA4.toByte(), 0x04.toByte(), 0x00.toByte(),
            0x07.toByte(),
            0xD2.toByte(), 0x76.toByte(), 0x00.toByte(), 0x00.toByte(),
            0x85.toByte(), 0x01.toByte(), 0x01.toByte()
        )
        private val STATUS_OK = byteArrayOf(0x90.toByte(), 0x00.toByte())
        private val STATUS_WRONG_LENGTH = byteArrayOf(0x67.toByte(), 0x00.toByte())
    }

    @Suppress("unused")
    private var emulatorUid = "4F4C49564941"

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (commandApdu == null) {
            return STATUS_WRONG_LENGTH
        }

        Log.d(TAG, "Processing APDU command: ${commandApdu.toHexString()}")

        if (commandApdu.size >= 5 && commandApdu[0] == 0x00.toByte() && commandApdu[1] == 0xA4.toByte()) {
            return handleSelectCommand(commandApdu)
        }

        if (commandApdu.size >= 2 && commandApdu[0] == 0x90.toByte() && commandApdu[1] == 0x00.toByte()) {
            return buildNdefResponse()
        }

        return STATUS_OK
    }

    private fun handleSelectCommand(commandApdu: ByteArray): ByteArray {
        @Suppress("UNUSED_PARAMETER")
        return buildNdefResponse()
    }

    private fun buildNdefResponse(): ByteArray {
        val text = "FLIPNOVA_HCE"

        val ndefRecord = NdefRecord.createTextRecord("en", text)
        val ndefMessage = NdefMessage(arrayOf(ndefRecord))
        val ndefBytes = ndefMessage.toByteArray()

        val lengthField = byteArrayOf((ndefBytes.size and 0xFF).toByte())
        val result = ByteArray(lengthField.size + ndefBytes.size + STATUS_OK.size)
        System.arraycopy(lengthField, 0, result, 0, lengthField.size)
        System.arraycopy(ndefBytes, 0, result, lengthField.size, ndefBytes.size)
        System.arraycopy(STATUS_OK, 0, result, lengthField.size + ndefBytes.size, STATUS_OK.size)

        return result
    }

    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "Deactivated: $reason")
    }

    private fun ByteArray.toHexString(): String = joinToString("") { "%02X".format(it) }
}
