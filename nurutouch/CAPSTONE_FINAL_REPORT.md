# NuruTouch: Comprehensive System Audit & Architectural Breakdown

This document serves as a detailed structural and architectural audit of the active NuruTouch Flutter codebase. It is intended to serve as the foundational reference for the Software Engineering Capstone Final Report.

---

## 1. Active File Structure & Application Architecture

### Clean File Tree
```text
lib/
├── data/
│   └── local/
│       ├── app_database.dart       # SQLite Database configuration & queries
│       └── app_state.dart          # Global Singleton for State Management
├── features/
│   ├── learner/
│   │   ├── calibration_screen.dart # 6-finger spatial calibration
│   │   ├── grid_training_screen.dart
│   │   ├── home_menu_screen.dart
│   │   ├── orientation_screen.dart # Initial spatial orientation
│   │   └── raw_touch_screen.dart   # Core learning engine & touch listener
│   ├── splash/
│   │   └── gateway_screen.dart     # Language selection entry point
│   └── supervisor/
│       ├── dashboard_screen.dart   # Teacher/Parent statistics view
│       └── global_pin_gate.dart    # Global gesture interceptor
├── models/
│   └── braille_record.dart         # SM-2 state tracking model
├── services/
│   ├── audio_service.dart          # AudioPlayer wrapper for chimes/thuds
│   ├── curriculum_engine.dart      # Dart-native Spaced Repetition logic
│   ├── haptic_service.dart         # Vibration pattern mappings
│   ├── swahili_tts_engine.dart     # Piper ONNX offline TTS for Swahili
│   └── tts_service.dart            # Wrapper switching between en/sw TTS engines
└── main.dart                       # App entry point
```

### Application Architecture
The application follows a **Service-Oriented Feature Architecture**:
* **UI Layer:** UI components are grouped by their domain (`learner`, `splash`, `supervisor`). The `RawTouchScreen` acts as the primary interactive surface, bypassing standard Flutter gesture detectors to capture raw `PointerDown`/`PointerUp` events.
* **State Management:** *Note: While Riverpod may have been considered in planning, the active implementation relies on a lightweight Singleton `AppState` using `ValueNotifier`.* This allows widgets to reactively rebuild when the global language (`languageNotifier`) or `calibratedDots` map changes, without the overhead of external state management libraries.
* **Data Layer:** The `AppDatabase` handles SQLite interactions asynchronously. It operates independently of the UI, communicating entirely via the `CurriculumEngine`.
* **Service Layer:** Tools like audio, haptics, and TTS are abstracted into Singleton services (`HapticService`, `TtsService`) to ensure hardware resources are shared cleanly and initialized only once.

---

## 2. Technology Stack & Key Details

* **Framework:** Flutter / Dart (`^3.12.2`)
* **Local Database:** `sqflite` (`^2.4.3`) combined with `path` for local directory mapping.
* **Offline Machine Learning (TTS):** `flutter_onnxruntime` (`^1.8.2`). Used specifically to run a custom, fine-tuned Swahili TTS model (`sw_fine-tuned-medium.onnx`) locally via the Piper TTS architecture.
* **Audio & Hardware:** `audioplayers` (`^6.8.1`) for rapid playing of success/error `.ogg` chimes. `vibration` (`^3.2.0`) for haptic feedback. `flutter_tts` for native English voice synthesis.

**Offline-First & Low-Memory Integration:**
The system achieves its low-memory requirements by avoiding heavy frameworks (like TensorFlow Lite) for the curriculum. Instead of neural networks, the app calculates lesson progression instantly using a Dart-native algorithmic approach (SM-2). The only ML model packaged is the ONNX TTS model, which runs highly optimized C++ bindings underneath to generate Swahili speech offline.

---

## 3. System Navigation & User Flow

### Programmatic User Journey
1. **Gateway (`gateway_screen.dart`):** The entry point where a left/right swipe sets the global `ValueNotifier<String>` to "en" or "sw".
2. **Calibration & Orientation:** The user receives localized instructions and must place 6 fingers on the screen simultaneously. The `RawTouchScreen` calculates the spatial coordinates of each finger, saving the mapping to `AppState().calibratedDots`.
3. **Core Loop (`raw_touch_screen.dart`):** The user stays on this screen indefinitely. Progression is not handled by routing (`Navigator.push`), but by the `CurriculumEngine` fetching the next lesson dynamically and re-rendering the prompt.

### Global Gestures & Interception
* **2-Finger Swipe Down (Go Back):** Handled in the `_analyzeGestureAndExecute` method of `RawTouchScreen`. If `dx/dy` indicates a downward swipe and exactly 2 pointers were active, it triggers `Navigator.pop()`.
* **Teacher Portal (6-Second Hold):** Handled by the `GlobalPinGate` wrapper widget. This widget sits near the top of the widget tree (in `main.dart`) and wraps the entire `MaterialApp`. It tracks `onPointerDown` events; if a specific multi-finger tap is held for 6 seconds, it intercepts the app flow and pushes the `SupervisorDashboard` over the current route.

---

## 4. Core Functional Implementations

### Haptics
Implemented via `HapticService`. The app uses temporal encoding mapped to ERM (Eccentric Rotating Mass) capabilities:
* **Tick (Single Dot):** 50ms duration at 128 amplitude.
* **Success Pulse:** 300ms duration at 255 amplitude (max strength).
* **Error Buzz:** A rhythmic pattern: `[0, 150, 100, 150]` (Wait 0ms, vibrate 150ms, wait 100ms, vibrate 150ms) to clearly demarcate failure.

### Audio & TTS
The app utilizes a dual-engine wrapper (`tts_service.dart`):
* **English:** Passed to the native `flutter_tts` plugin which hooks into Android/iOS system voices.
* **Swahili:** Passed to `SwahiliTTSEngine`. The engine uses a custom phoneme dictionary (`assets/mms_model/sw_fine-tuned-medium.onnx.json`) to tokenize Swahili text into ID arrays, feeds it into the Piper ONNX graph, and outputs a raw Float32 audio waveform.

*Note: The prompt references constrained FST graphs and Sherpa-ONNX ASR. In the current active implementation, the app relies purely on the 6-finger spatial calibration grid (touch input) for assessment. Voice Input (ASR) is not currently an active file in the `lib` directory.*

---

## 5. Database & Adaptive Curriculum Engine

### SQLite Schema (`student_progress`)
The `AppDatabase` maintains a targeted schema optimized for the Spaced Repetition algorithm:
* `letter_id` (TEXT PRIMARY KEY)
* `easiness_factor` (REAL): The dynamic multiplier (defaults to 2.5) that grows if the child gets the letter right, and shrinks if they struggle.
* `interval_minutes` (INTEGER): How many minutes must pass before the letter is queried again.
* `repetitions` (INTEGER): Current streak of successful completions.
* `next_review_date` (INTEGER): Epoch timestamp denoting when the letter is due.

### Algorithmic Engine (SM-2)
The `CurriculumEngine` replaces linear JSON progression.
1. It separates static instruction screens (`nav_intro`, `grid_intro`) and forces them first.
2. It queries `student_progress` for any `practice` letters where `next_review_date` is in the past.
3. If multiple letters are due, it sorts them by `easiness_factor` to prioritize the ones the child struggles with most.
4. When a child completes a chord, `updateProgress` assesses a "Grade" (0-5) based on their `mistakeCount` and latency (`timeToAnswerMs`), immediately recalculating the interval for that specific letter.

---

## 6. Testing Implementations

Currently, the testing infrastructure is minimal:
* **Widget Testing:** A default `widget_test.dart` exists in the `test/` directory, testing basic frame pumping and text assertions. 
* To ensure production-readiness for the Capstone, the addition of dedicated Unit Tests targeting the `CurriculumEngine`'s math, and Integration Tests simulating 6-finger PointerEvents on `RawTouchScreen`, are highly recommended.
