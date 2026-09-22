import '../sensors/sensor_hub.dart';

/// Camera/microphone access is never really requested during the demo tour
/// (there is no real sensor behind [TourSensorHub]), so permissions always
/// read as already granted.
class TourPermissionGateway implements PermissionGateway {
  @override
  Future<PermissionResult> current() async =>
      const PermissionResult(PermissionState.granted, PermissionState.granted);

  @override
  Future<PermissionResult> request() => current();

  @override
  Future<void> openSettings() async {}
}
