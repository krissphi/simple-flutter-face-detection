import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:new_project/face_detection_service.dart'; // Assuming your package name is new_project

// Generate mocks for BuildContext and Face
@GenerateMocks([BuildContext, Face])
import 'face_detection_service_test.mocks.dart';

// Custom class to track notifyListeners calls
class TestFaceDetectionService extends FaceDetectionService {
  int notifyListenersCallCount = 0;

  @override
  void notifyListeners() {
    notifyListenersCallCount++;
    super.notifyListeners();
  }

  // Helper to expose _checkFaceStability for testing
  void testCheckFaceStability(List<Face> newFaces, DateTime now, Size imageSize) {
    _checkFaceStability(newFaces, now, imageSize);
  }

  // Helper to expose _lastFacePositions for testing
  Map<int, Offset> get lastFacePositions => _lastFacePositions;

  // Helper to expose _countdownSeconds for testing
  int? get countdownSeconds => _countdownSeconds;

  // Helper to expose _isFaceInBoundary for testing
  bool? get isFaceInBoundary => _isFaceInBoundary;

  // Helper to set _lastFacePositions for testing setup
  void setLastFacePositions(Map<int, Offset> positions) {
    _lastFacePositions = positions;
  }
   // Helper to get _faceStableStartTime for testing
  DateTime? get faceStableStartTime => _faceStableStartTime;
}

void main() {
  group('FaceDetectionService _checkFaceStability', () {
    late TestFaceDetectionService service;
    late MockBuildContext mockContext;
    final imageSize = Size(1000, 1000); // Standard image size for tests
    final now = DateTime.now();

    setUp(() {
      service = TestFaceDetectionService();
      mockContext = MockBuildContext();
      // Default auto-capture settings for most tests
      service.setAutoCapture(true, mockContext, (context) {}, true); 
      service.notifyListenersCallCount = 0; // Reset counter before each test
    });

    // Helper to create a mock Face
    MockFace createMockFace(int trackingId, Rect boundingBox, {Offset? centerOverride}) {
      final mockFace = MockFace();
      when(mockFace.trackingId).thenReturn(trackingId);
      when(mockFace.boundingBox).thenReturn(boundingBox);
      // If centerOverride is not provided, calculate from boundingBox
      final center = centerOverride ?? Offset(boundingBox.left + boundingBox.width / 2, boundingBox.top + boundingBox.height / 2);
      // Mocking headEulerAngleX, headEulerAngleY, headEulerAngleZ for completeness if needed by some internal logic not explicitly tested here
      when(mockFace.headEulerAngleX).thenReturn(0.0);
      when(mockFace.headEulerAngleY).thenReturn(0.0);
      when(mockFace.headEulerAngleZ).thenReturn(0.0);
      // Mocking smilingProbability, leftEyeOpenProbability, rightEyeOpenProbability
      when(mockFace.smilingProbability).thenReturn(0.5);
      when(mockFace.leftEyeOpenProbability).thenReturn(0.5);
      when(mockFace.rightEyeOpenProbability).thenReturn(0.5);
      // Mocking landmarks - assuming no specific landmark checks in _checkFaceStability
      when(mockFace.landmarks).thenReturn({});
      // Mocking contours - assuming no specific contour checks in _checkFaceStability
      when(mockFace.contours).thenReturn({});
      return mockFace;
    }

    test('No faces: should call reset if countdown was active and then return', () {
      // Setup: Simulate an active countdown
      service.testCheckFaceStability([
        createMockFace(1, Rect.fromLTWH(400, 400, 100, 100))
      ], now, imageSize);
      expect(service.countdownSeconds, 3); // Countdown started
      service.notifyListenersCallCount = 0; // Reset for this specific check

      service.testCheckFaceStability([], now.add(Duration(milliseconds: 100)), imageSize);

      expect(service.notifyListenersCallCount, 1, reason: "notifyListeners should be called by _resetAutoCapture when no faces are present and countdown was active");
      expect(service.countdownSeconds, null);
      expect(service.isFaceInBoundary, false);
      expect(service.faceStableStartTime, null);
    });

    test('Stable face in bounds: _lastFacePositions updated, countdown starts, no immediate reset', () {
      final face1 = createMockFace(1, Rect.fromLTWH(400, 400, 100, 100)); // Center (450,450)
      
      service.testCheckFaceStability([face1], now, imageSize);

      expect(service.lastFacePositions.containsKey(1), true);
      expect(service.lastFacePositions[1], Offset(450, 450));
      expect(service.countdownSeconds, 3);
      expect(service.isFaceInBoundary, true);
      expect(service.notifyListenersCallCount, 1); // For initial countdown set
    });

    test('Multiple stable faces in bounds: _lastFacePositions updated for all, countdown starts', () {
      final face1 = createMockFace(1, Rect.fromLTWH(200, 200, 100, 100)); // Center (250,250)
      final face2 = createMockFace(2, Rect.fromLTWH(600, 600, 100, 100)); // Center (650,650)
      
      // Simulate initial detection of two faces
      service.testCheckFaceStability([face1, face2], now, imageSize);
      
      expect(service.lastFacePositions.containsKey(1), true);
      expect(service.lastFacePositions[1], Offset(250,250));
      expect(service.lastFacePositions.containsKey(2), true);
      expect(service.lastFacePositions[2], Offset(650,650));
      expect(service.countdownSeconds, 3);
      expect(service.isFaceInBoundary, true);
      expect(service.notifyListenersCallCount, 1); 
    });

    test('One face becomes unstable (moves significantly): reset called, _lastFacePositions not updated with new unstable position during this check', () {
      final initialPosFace1 = Rect.fromLTWH(400, 400, 100, 100); // Center (450,450)
      final face1Stable = createMockFace(1, initialPosFace1);

      // Initial stable state
      service.testCheckFaceStability([face1Stable], now, imageSize);
      expect(service.countdownSeconds, 3);
      expect(service.lastFacePositions[1], Offset(450,450));
      service.notifyListenersCallCount = 0; // Reset for this part of the test

      // Face moves significantly (unstable)
      final face1Unstable = createMockFace(1, Rect.fromLTWH(450, 450, 100, 100)); // Center (500,500) - distance > threshold
      
      service.testCheckFaceStability([face1Unstable], now.add(Duration(milliseconds: 100)), imageSize);

      expect(service.notifyListenersCallCount, 1, reason: "Reset should be called due to instability");
      expect(service.countdownSeconds, null);
      expect(service.isFaceInBoundary, false);
      // _lastFacePositions should NOT be updated with the unstable position in the same call that detects instability.
      // It reflects the last known STABLE positions. The update happens when all faces are stable.
      expect(service.lastFacePositions[1], Offset(450,450), reason: "_lastFacePositions should hold the last stable position");
    });

    test('One face out of bounds (_isBoundaryEnabled = true): reset called, _lastFacePositions not updated', () {
      final face1InBounds = createMockFace(1, Rect.fromLTWH(400, 400, 100, 100)); // Center (450,450) - in bounds

      // Initial stable state
      service.testCheckFaceStability([face1InBounds], now, imageSize);
      expect(service.countdownSeconds, 3);
      expect(service.lastFacePositions[1], Offset(450,450));
      service.notifyListenersCallCount = 0;

      // Face moves out of bounds (e.g., to top-left corner, well outside the 80% width/45% height oval)
      // Default boundary: ovalWidth = 800, ovalHeight = 450. CenterX=500, CenterY=500.
      // Face center (50,50) is out. ( (50-500)/400 )^2 + ( (50-500)/225 )^2 > 1
      final face1OutOfBounds = createMockFace(1, Rect.fromLTWH(0, 0, 100, 100)); 
      
      service.testCheckFaceStability([face1OutOfBounds], now.add(Duration(milliseconds: 100)), imageSize);

      expect(service.notifyListenersCallCount, 1, reason: "Reset should be called due to face out of bounds");
      expect(service.countdownSeconds, null);
      expect(service.isFaceInBoundary, false);
      expect(service.lastFacePositions[1], Offset(450,450), reason: "_lastFacePositions should hold the last stable position");
    });
    
    test('Face out of bounds when _isBoundaryEnabled = false: no reset, countdown continues', () {
      service.setAutoCapture(true, mockContext, (context) {}, false); // Boundary check disabled
      service.notifyListenersCallCount = 0;

      final face1Stable = createMockFace(1, Rect.fromLTWH(400, 400, 100, 100));
      service.testCheckFaceStability([face1Stable], now, imageSize); // Initial stable state
      expect(service.countdownSeconds, 3);
      expect(service.isFaceInBoundary, null); // isFaceInBoundary is null when boundary check disabled
      service.notifyListenersCallCount = 0;

      final face1WayOut = createMockFace(1, Rect.fromLTWH(0, 0, 100, 100)); // Position that would be out of bounds
      service.testCheckFaceStability([face1WayOut], now.add(Duration(milliseconds: 100)), imageSize);
      
      expect(service.notifyListenersCallCount, 0, reason: "Reset should NOT be called as boundary check is off");
      expect(service.countdownSeconds, 3, reason: "Countdown should still be active or progressing if time passed");
      // _lastFacePositions IS updated because the face is considered "stable" (no boundary check failure)
      expect(service.lastFacePositions[1], Offset(50,50)); 
    });

    test('Multiple events (unstable + out of bounds): reset called only once', () {
      final face1StableIn = createMockFace(1, Rect.fromLTWH(400, 400, 100, 100)); // Center (450,450)
      service.testCheckFaceStability([face1StableIn], now, imageSize); // Initial stable state
      expect(service.countdownSeconds, 3);
      service.notifyListenersCallCount = 0;

      // Face 1 moves a bit (potentially unstable) AND Face 2 is added out of bounds
      // Face 1 new pos: (460,460), box (410,410,100,100). Distance from (450,450) is sqrt(10^2+10^2) = 14.14
      // Threshold for 100x100 box is sqrt(100^2+100^2)*0.1 = sqrt(20000)*0.1 = 141.42*0.1 = 14.142
      // So, a 10px move for a 100px box is NOT unstable by itself if threshold is 0.1 * diagonal.
      // Let's make face1 clearly unstable: new pos (500,500), box (450,450,100,100)
      final face1UnstableIn = createMockFace(1, Rect.fromLTWH(450, 450, 100, 100)); 
      final face2OutOfBounds = createMockFace(2, Rect.fromLTWH(0, 0, 100, 100));
      
      service.testCheckFaceStability([face1UnstableIn, face2OutOfBounds], now.add(Duration(milliseconds: 100)), imageSize);

      expect(service.notifyListenersCallCount, 1, reason: "Reset should be called only ONCE, even with multiple reasons (unstable + out of bounds)");
      expect(service.countdownSeconds, null);
      expect(service.isFaceInBoundary, false);
    });

    test('_lastFacePositions only updated when ALL faces are stable AND in bounds', () {
      final face1StableIn = createMockFace(1, Rect.fromLTWH(400, 400, 100, 100)); // Center (450,450)
      final face2StableInOldPos = createMockFace(2, Rect.fromLTWH(200, 200, 100, 100)); // Center (250,250)

      // Initial state with two stable faces
      service.testCheckFaceStability([face1StableIn, face2StableInOldPos], now, imageSize);
      expect(service.lastFacePositions[1], Offset(450,450));
      expect(service.lastFacePositions[2], Offset(250,250));
      expect(service.countdownSeconds, 3);
      service.notifyListenersCallCount = 0;

      // Face 2 moves (becomes unstable), Face 1 remains stable
      final face2Unstable = createMockFace(2, Rect.fromLTWH(250, 250, 100, 100)); // New center (300,300)
      
      service.testCheckFaceStability([face1StableIn, face2Unstable], now.add(Duration(milliseconds: 100)), imageSize);
      
      expect(service.notifyListenersCallCount, 1, reason: "Reset due to face2 instability");
      expect(service.countdownSeconds, null);
      // _lastFacePositions should NOT be updated because not all faces were stable
      expect(service.lastFacePositions[1], Offset(450,450), reason: "Face 1 position should remain from last stable state");
      expect(service.lastFacePositions[2], Offset(250,250), reason: "Face 2 position should remain from last stable state");

      // Now, Face 2 becomes stable again at its new position
      service.notifyListenersCallCount = 0; // Reset for next check
      final face2StableNewPos = createMockFace(2, Rect.fromLTWH(250, 250, 100, 100)); // Stable at (300,300)
      // We need to set the _lastFacePositions to what would have been the 'currentFacePositions' in the previous failed check for face2
      // or more simply, set it to the old stable position for face1, and the new (now considered current) position for face2 that we are testing stability against.
      // The key is that the _checkFaceStability will compare currentFacePositions with _lastFacePositions.
      // To make face2 appear stable, its current passed position must be close to what's in _lastFacePositions for it.
      // So, let's simulate that the system has processed the unstable frame, and now we are sending a new frame.
      // In the *previous* call, currentFacePositions for face2 would have been (300,300)
      // but _lastFacePositions was NOT updated. So _lastFacePositions[2] is still (250,250).
      // If we pass face2StableNewPos (center 300,300) again, it will be compared against _lastFacePositions[2] (250,250) and be unstable.
      // This test needs to be structured carefully.
      // Let's reset the service's _lastFacePositions to simulate a prior state for a cleaner test of this specific rule.

      service.setLastFacePositions({
         1: Offset(450,450), // face1 was stable here
         // face2 was previously at (250,250)
      });
      // Now, if we pass face1StableIn (450,450) and face2StableNewPos (300,300),
      // face1 will be stable. face2 will be unstable because its new position (300,300)
      // is different from its _lastFacePosition (which we haven't updated for it yet).
      // This test is tricky because _lastFacePositions is internal state.

      // Alternative approach for this test:
      // 1. Start with face1 stable, face2 stable at posA. _lastFacePositions updated.
      // 2. Send frame: face1 stable, face2 unstable (moved to posB). Reset occurs. _lastFacePositions NOT updated to include posB.
      // 3. Send frame: face1 stable, face2 stable at posB.
      //    - face1 is stable relative to its entry in _lastFacePositions.
      //    - face2 is stable relative to its entry in _lastFacePositions (which is still posA). This means it will be seen as UNSTABLE.
      // This shows that _lastFacePositions isn't updated with unstable parts.
      // To show it IS updated when all are stable:
      // 1. face1 stable (pos1), face2 stable (posA). Call check. _lastFacePositions has {1:pos1, 2:posA}. Countdown starts.
      service.setLastFacePositions({}); // Clear last positions
      service.testCheckFaceStability([face1StableIn, createMockFace(2, Rect.fromLTWH(200, 200, 100, 100)) /* stable at (250,250) */], now, imageSize);
      expect(service.lastFacePositions[1], Offset(450,450));
      expect(service.lastFacePositions[2], Offset(250,250));
      service.notifyListenersCallCount = 0;

      // 2. Send frame: face1 stable (pos1), face2 stable (moved to posB - Rect.fromLTWH(300,300,100,100) -> center(350,350) )
      //    This will make face2 unstable relative to _lastFacePositions[2]
      final face2MovedStable = createMockFace(2, Rect.fromLTWH(300, 300, 100, 100));
      service.testCheckFaceStability([face1StableIn, face2MovedStable], now.add(Duration(milliseconds:100)), imageSize);
      expect(service.notifyListenersCallCount, 1, reason: "Reset because face2 moved, becoming unstable relative to its last pos");
      // _lastFacePositions should NOT have been updated with face2's new position (350,350)
      expect(service.lastFacePositions[1], Offset(450,450));
      expect(service.lastFacePositions[2], Offset(250,250));
      service.notifyListenersCallCount = 0;

      // 3. Send frame: face1 stable (pos1), face2 also stable at its NEW position (posB - center 350,350)
      //    To make face2 appear stable now, its entry in _lastFacePositions for comparison should be (350,350).
      //    This means we need to manually set the _lastFacePositions to what currentFacePositions *would have been*
      //    in the previous call where face2 was unstable.
      //    This is what the actual code does: currentFacePositions is built, then compared. If all stable, _lastFacePositions = currentFacePositions.
      service.setLastFacePositions({
        1: Offset(450,450),       // face1's last stable position
        2: Offset(350,350)        // Simulate face2's new position is now the one to check for stability against
      });
      service.testCheckFaceStability([face1StableIn, face2MovedStable], now.add(Duration(milliseconds:200)), imageSize);
      expect(service.notifyListenersCallCount, 1, reason: "Countdown should start/continue, new positions are now stable");
      expect(service.countdownSeconds, 3);
      // NOW _lastFacePositions should be updated because both were stable relative to the (manually adjusted) _lastFacePositions
      expect(service.lastFacePositions[1], Offset(450,450));
      expect(service.lastFacePositions[2], Offset(350,350));
    });

    test('New face appears: considered unstable, reset called if countdown was active', (){
      final face1 = createMockFace(1, Rect.fromLTWH(400, 400, 100, 100));
      service.testCheckFaceStability([face1], now, imageSize); // face1 is now stable, countdown starts
      expect(service.countdownSeconds, 3);
      expect(service.lastFacePositions.containsKey(1), true);
      service.notifyListenersCallCount = 0;

      final face2 = createMockFace(2, Rect.fromLTWH(200, 200, 100, 100));
      service.testCheckFaceStability([face1, face2], now.add(Duration(milliseconds:100)), imageSize);
      
      expect(service.notifyListenersCallCount, 1, reason: "Reset because new face (face2) appeared, considered unstable");
      expect(service.countdownSeconds, null);
      // _lastFacePositions should not yet contain face2's new position because the frame was unstable
      expect(service.lastFacePositions.containsKey(1), true);
      expect(service.lastFacePositions.containsKey(2), false, reason: "Face 2 was new and caused instability, so its pos shouldn't be in _lastFacePositions yet.");
    });

  });
}

// Note: After creating this file, you'll need to run:
// flutter pub run build_runner build --delete-conflicting-outputs
// to generate the face_detection_service_test.mocks.dart file.
// Ensure your pubspec.yaml has build_runner and mockito in dev_dependencies.
// dev_dependencies:
//   flutter_test:
//     sdk: flutter
//   mockito: ^5.0.0 # use appropriate version
//   build_runner: ^2.0.0 # use appropriate version
