package com.example.qrio

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import java.util.*

/**
 * Minimal BLE GATT peripheral exposing a writable/notifiable characteristic for chat. Production:
 * add security, persistence, error handling.
 */
class BlePeripheralService(private val context: Context) {
    companion object {
        val SERVICE_UUID: UUID = UUID.fromString("12345678-1234-5678-1234-56789ABCDEF0")
        val CHARACTERISTIC_UUID: UUID = UUID.fromString("12345678-1234-5678-1234-56789ABCDEF1")
        private const val TAG = "BlePeripheral"
    }

    private var bluetoothManager: BluetoothManager? = null
    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var currentDevice: BluetoothDevice? = null

    private val characteristic =
            BluetoothGattCharacteristic(
                    CHARACTERISTIC_UUID,
                    BluetoothGattCharacteristic.PROPERTY_WRITE or
                            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                    BluetoothGattCharacteristic.PERMISSION_WRITE
            )

    private val cccd =
            BluetoothGattDescriptor(
                    UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"),
                    BluetoothGattDescriptor.PERMISSION_WRITE or
                            BluetoothGattDescriptor.PERMISSION_READ
            )

    private val gattCallback =
            object : BluetoothGattServerCallback() {
                override fun onConnectionStateChange(
                        device: BluetoothDevice?,
                        status: Int,
                        newState: Int
                ) {
                    super.onConnectionStateChange(device, status, newState)
                    Log.d(TAG, "Conn state change: $device status=$status newState=$newState")
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        currentDevice = device
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        currentDevice = null
                    }
                }

                override fun onDescriptorWriteRequest(
                        device: BluetoothDevice?,
                        requestId: Int,
                        descriptor: BluetoothGattDescriptor?,
                        preparedWrite: Boolean,
                        responseNeeded: Boolean,
                        offset: Int,
                        value: ByteArray?
                ) {
                    if (descriptor?.uuid == cccd.uuid) {
                        descriptor.value = value
                        gattServer?.sendResponse(
                                device,
                                requestId,
                                BluetoothGatt.GATT_SUCCESS,
                                0,
                                null
                        )
                    } else {
                        gattServer?.sendResponse(
                                device,
                                requestId,
                                BluetoothGatt.GATT_FAILURE,
                                0,
                                null
                        )
                    }
                }

                override fun onCharacteristicWriteRequest(
                        device: BluetoothDevice?,
                        requestId: Int,
                        characteristic: BluetoothGattCharacteristic?,
                        preparedWrite: Boolean,
                        responseNeeded: Boolean,
                        offset: Int,
                        value: ByteArray?
                ) {
                    if (characteristic?.uuid == CHARACTERISTIC_UUID && value != null) {
                        characteristic.value = value
                        if (responseNeeded) {
                            gattServer?.sendResponse(
                                    device,
                                    requestId,
                                    BluetoothGatt.GATT_SUCCESS,
                                    0,
                                    null
                            )
                        }
                        notifyMessage(value) // echo back
                    } else {
                        if (responseNeeded) {
                            gattServer?.sendResponse(
                                    device,
                                    requestId,
                                    BluetoothGatt.GATT_FAILURE,
                                    0,
                                    null
                            )
                        }
                    }
                }
            }

    @SuppressLint("MissingPermission")
    fun start(sessionId: String): Boolean {
        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = bluetoothManager?.adapter ?: return false
        if (!adapter.isEnabled) return false

        gattServer = bluetoothManager?.openGattServer(context, gattCallback)
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        cccd.value = byteArrayOf(0x01, 0x00)
        characteristic.addDescriptor(cccd)
        service.addCharacteristic(characteristic)
        gattServer?.addService(service)

        advertiser = adapter.bluetoothLeAdvertiser
        val settings =
                AdvertiseSettings.Builder()
                        .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                        .setConnectable(true)
                        .setTimeout(0)
                        .build()
        val data =
                AdvertiseData.Builder()
                        .setIncludeDeviceName(true)
                        .addServiceUuid(ParcelUuid(SERVICE_UUID))
                        .build()
        try {
            adapter.name = "QRio_$sessionId"
        } catch (_: Exception) {}
        advertiser?.startAdvertising(
                settings,
                data,
                object : AdvertiseCallback() {
                    override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                        Log.d(TAG, "Advertising started")
                    }
                    override fun onStartFailure(errorCode: Int) {
                        Log.e(TAG, "Advertising failed: $errorCode")
                    }
                }
        )
        return true
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        try {
            advertiser?.stopAdvertising(object : AdvertiseCallback() {})
        } catch (_: Exception) {}
        try {
            gattServer?.close()
        } catch (_: Exception) {}
        advertiser = null
        gattServer = null
    }

    @SuppressLint("MissingPermission")
    fun notifyMessage(bytes: ByteArray) {
        currentDevice?.let { dev ->
            try {
                gattServer?.notifyCharacteristicChanged(dev, characteristic, false, bytes)
            } catch (_: Exception) {}
        }
    }
}
