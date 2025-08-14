package com.example.qrio;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/**
 * MainActivity extended to expose a MethodChannel for starting/stopping BLE peripheral mode.
 */
public class MainActivity extends FlutterActivity {
	private static final String CHANNEL = "qrio/ble_peripheral";
	private BlePeripheralService peripheralService;

	@Override
	public void configureFlutterEngine(FlutterEngine flutterEngine) {
		super.configureFlutterEngine(flutterEngine);
		peripheralService = new BlePeripheralService(this);
		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
				.setMethodCallHandler((call, result) -> {
					switch (call.method) {
						case "startPeripheral":
							String sessionId = call.argument("sessionId");
							boolean ok = peripheralService.start(sessionId == null ? "session" : sessionId);
							result.success(ok);
							break;
						case "stopPeripheral":
							peripheralService.stop();
							result.success(true);
							break;
						default:
							result.notImplemented();
					}
				});
	}

	@Override
	protected void onDestroy() {
		try { peripheralService.stop(); } catch (Exception ignored) {}
		super.onDestroy();
	}
}
