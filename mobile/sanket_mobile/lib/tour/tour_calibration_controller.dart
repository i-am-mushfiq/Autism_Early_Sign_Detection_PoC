import '../core/calibration.dart';
import '../runtime/calibration_controller.dart';

/// No samples were measured: keep gaze excluded in the example summary.
class TourCalibrationController extends CalibrationController {
  TourCalibrationController(super.sensors);
  @override
  bool get canRetry => false;
  @override
  void start() {
    if (phase != CalibrationPhase.intro) return;
    result = CalibrationResult.notRun;
    phase = CalibrationPhase.done;
    notifyListeners();
  }
}
