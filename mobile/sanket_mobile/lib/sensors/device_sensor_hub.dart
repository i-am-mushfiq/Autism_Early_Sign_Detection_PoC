import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' hide PoseLandmark;
import 'package:permission_handler/permission_handler.dart' as ph;

import '../core/activity_capture.dart';
import '../core/samples.dart';
import 'sensor_hub.dart';

class DevicePermissionGateway implements PermissionGateway {
  PermissionState _map(ph.PermissionStatus s) => s.isGranted
      ? PermissionState.granted
      : s.isPermanentlyDenied || s.isRestricted
          ? PermissionState.permanentlyDenied
          : PermissionState.denied;

  @override
  Future<PermissionResult> current() async => PermissionResult(
      _map(await ph.Permission.camera.status), _map(await ph.Permission.microphone.status));

  @override
  Future<PermissionResult> request() async {
    final r = await [ph.Permission.camera, ph.Permission.microphone].request();
    return PermissionResult(_map(r[ph.Permission.camera]!), _map(r[ph.Permission.microphone]!));
  }

  @override
  Future<void> openSettings() => ph.openAppSettings();
}

/// Front camera + on-device ML Kit face/pose detection + native microphone
/// loudness stream. Frames are processed one at a time (dropping frames while
/// busy) so low-end devices stay responsive; the resulting frame rate is
/// measured and quality-gated downstream.
class DeviceSensorHub implements SensorHub {
  DeviceSensorHub();

  @override
  final SessionClock clock = StopwatchClock();

  static const _audioChannel = EventChannel('sanket/audio_level');
  static const _minFrameGapMs = 70;

  CameraController? _controller;
  CameraDescription? _camera;
  final _frames = StreamController<VisionFrame>.broadcast();
  late final StreamController<AudioLevel> _audio = StreamController<AudioLevel>.broadcast(
      onListen: _startAudio, onCancel: _stopAudio);
  StreamSubscription<dynamic>? _audioSub;

  final _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          enableClassification: true,
          minFaceSize: 0.1));
  PoseDetector? _poseDetector;

  VisionMode _mode = VisionMode.off;
  bool _busy = false;
  int _lastFrameMs = -1000;
  bool _microphoneAllowed = false;
  SensorAvailability _availability = SensorAvailability.none;

  @override
  SensorAvailability get availability => _availability;

  @override
  VisionMode get mode => _mode;
  @override
  set mode(VisionMode value) {
    _mode = value;
    if (value == VisionMode.pose) {
      _poseDetector ??= PoseDetector(
          options: PoseDetectorOptions(mode: PoseDetectionMode.stream, model: PoseDetectionModel.base));
    }
  }

  @override
  Stream<VisionFrame> get frames => _frames.stream;
  @override
  Stream<AudioLevel> get audio => _audio.stream;

  @override
  Future<SensorAvailability> start({required bool camera, required bool microphone}) async {
    _microphoneAllowed = microphone;
    var cameraOk = _controller?.value.isInitialized ?? false;
    if (camera && !cameraOk) {
      try {
        final cameras = await availableCameras();
        final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front);
        _camera = front.isNotEmpty ? front.first : cameras.first;
        final controller = CameraController(_camera!, ResolutionPreset.medium,
            enableAudio: false,
            imageFormatGroup:
                defaultTargetPlatform == TargetPlatform.android ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888);
        await controller.initialize();
        _controller = controller;
        await controller.startImageStream(_onImage);
        cameraOk = true;
      } catch (e) {
        debugPrint('Sanket camera unavailable: $e');
        cameraOk = false;
      }
    }
    _availability = SensorAvailability(camera: cameraOk, microphone: microphone);
    return _availability;
  }

  @override
  Widget? preview() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return null;
    return CameraPreview(c);
  }

  void _startAudio() {
    if (!_microphoneAllowed) return;
    _audioSub = _audioChannel.receiveBroadcastStream().listen((event) {
      final m = event as Map;
      _audio.add(AudioLevel(
          tMs: clock.nowMs(),
          rmsDb: (m['rmsDb'] as num).toDouble(),
          peakDb: (m['peakDb'] as num).toDouble()));
    }, onError: (Object e) {
      debugPrint('Sanket microphone stream error: $e');
      _availability = SensorAvailability(camera: _availability.camera, microphone: false);
    });
  }

  void _stopAudio() {
    _audioSub?.cancel();
    _audioSub = null;
  }

  Future<void> _onImage(CameraImage image) async {
    final now = clock.nowMs();
    if (_busy || _mode == VisionMode.off || now - _lastFrameMs < _minFrameGapMs) return;
    _busy = true;
    _lastFrameMs = now;
    try {
      final lighting = _meanLuma(image);
      final input = _inputImage(image);
      if (input == null) return;
      final rotated = input.metadata!.rotation == InputImageRotation.rotation90deg ||
          input.metadata!.rotation == InputImageRotation.rotation270deg;
      final width = (rotated ? image.height : image.width).toDouble();
      final height = (rotated ? image.width : image.height).toDouble();
      FaceObservation? face;
      PoseObservation? pose;
      final mode = _mode;
      if (mode == VisionMode.face) {
        final faces = await _faceDetector.processImage(input);
        if (faces.isNotEmpty) {
          final f = faces.reduce((a, b) =>
              a.boundingBox.width * a.boundingBox.height >= b.boundingBox.width * b.boundingBox.height ? a : b);
          face = FaceObservation(
            yawDeg: f.headEulerAngleY ?? 0,
            pitchDeg: f.headEulerAngleX ?? 0,
            widthFraction: f.boundingBox.width / width,
            centerX: f.boundingBox.center.dx / width,
            centerY: f.boundingBox.center.dy / height,
            leftEyeOpen: f.leftEyeOpenProbability,
            rightEyeOpen: f.rightEyeOpenProbability,
          );
        }
      } else if (mode == VisionMode.pose && _poseDetector != null) {
        final poses = await _poseDetector!.processImage(input);
        if (poses.isNotEmpty) {
          const map = {
            PoseLandmarkType.nose: PosePoint.nose,
            PoseLandmarkType.leftEye: PosePoint.leftEye,
            PoseLandmarkType.rightEye: PosePoint.rightEye,
            PoseLandmarkType.leftEar: PosePoint.leftEar,
            PoseLandmarkType.rightEar: PosePoint.rightEar,
            PoseLandmarkType.leftShoulder: PosePoint.leftShoulder,
            PoseLandmarkType.rightShoulder: PosePoint.rightShoulder,
            PoseLandmarkType.leftWrist: PosePoint.leftWrist,
            PoseLandmarkType.rightWrist: PosePoint.rightWrist,
          };
          final landmarks = poses.first.landmarks;
          pose = PoseObservation({
            for (final e in map.entries)
              if (landmarks[e.key] != null)
                e.value: PoseLandmark(landmarks[e.key]!.x / width, landmarks[e.key]!.y / width,
                    landmarks[e.key]!.likelihood)
          });
        }
      }
      if (!_frames.isClosed) {
        _frames.add(VisionFrame(tMs: now, mode: mode, lighting: lighting, face: face, pose: pose));
      }
    } catch (e) {
      debugPrint('Sanket frame processing failed: $e');
    } finally {
      _busy = false;
    }
  }

  double _meanLuma(CameraImage image) {
    final y = image.planes.first.bytes;
    final count = image.width * image.height;
    if (y.isEmpty || count == 0) return 0;
    final limit = y.length < count ? y.length : count;
    var sum = 0, n = 0;
    for (var i = 0; i < limit; i += 97) {
      sum += y[i];
      n++;
    }
    return n == 0 ? 0 : sum / (n * 255);
  }

  static const _orientationDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImage(CameraImage image) {
    final controller = _controller, camera = _camera;
    if (controller == null || camera == null) return null;
    final device = _orientationDegrees[controller.value.deviceOrientation] ?? 0;
    final degrees = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + device) % 360
        : (camera.sensorOrientation - device + 360) % 360;
    final rotation = InputImageRotationValue.fromRawValue(degrees);
    if (rotation == null) return null;

    final Uint8List bytes;
    final InputImageFormat format;
    if (defaultTargetPlatform == TargetPlatform.android) {
      bytes = image.planes.length == 1 ? image.planes.first.bytes : _yuv420ToNv21(image);
      format = InputImageFormat.nv21;
    } else {
      bytes = image.planes.first.bytes;
      format = InputImageFormat.bgra8888;
    }
    return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: image.planes.first.bytesPerRow));
  }

  /// Fallback for devices that deliver three YUV planes despite the NV21 request.
  Uint8List _yuv420ToNv21(CameraImage image) {
    final w = image.width, h = image.height;
    final out = Uint8List(w * h + 2 * ((w + 1) ~/ 2) * ((h + 1) ~/ 2));
    final yPlane = image.planes[0];
    for (var row = 0; row < h; row++) {
      final src = row * yPlane.bytesPerRow;
      if (src + w <= yPlane.bytes.length) {
        out.setRange(row * w, row * w + w, yPlane.bytes, src);
      }
    }
    final u = image.planes[1], v = image.planes[2];
    final uvRowStride = u.bytesPerRow, uvPixelStride = u.bytesPerPixel ?? 1;
    var o = w * h;
    for (var row = 0; row < h ~/ 2; row++) {
      for (var col = 0; col < w ~/ 2; col++) {
        final i = row * uvRowStride + col * uvPixelStride;
        if (i < v.bytes.length && i < u.bytes.length && o + 1 < out.length) {
          out[o++] = v.bytes[i];
          out[o++] = u.bytes[i];
        }
      }
    }
    return out;
  }

  @override
  Future<void> dispose() async {
    _mode = VisionMode.off;
    _stopAudio();
    final c = _controller;
    _controller = null;
    try {
      if (c != null && c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
    await c?.dispose();
    await _faceDetector.close();
    await _poseDetector?.close();
    await _frames.close();
    await _audio.close();
  }
}
