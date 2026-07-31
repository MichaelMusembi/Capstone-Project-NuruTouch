# NuruTouch - Braille Literacy System

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![Version](https://img.shields.io/badge/version-1.0.0-orange)
![Flutter](https://img.shields.io/badge/flutter-3.0+-blue)
![Dart](https://img.shields.io/badge/dart-3.0+-cyan)

**An offline-first Android application designed to teach Braille literacy to blind and low-vision children in Kenya using commodity smartphones.**

[Download NuruTouch APK (250 MB)](https://github.com/MichaelMusembi/Capstone-Project-NuruTouch/releases/latest/download/app-release.apk)

***

## Table of Contents
1. [Overview/Introduction](#1-overviewintroduction)
2. [Key Features](#2-key-features)
3. [System Architecture](#3-system-architecture)
4. [Machine Learning Models](#4-machine-learning-models)
5. [Installation & Setup](#5-installation--setup)
6. [Usage Guide](#6-usage-guide)
7. [Team & Acknowledgments](#7-team--acknowledgments)
8. [Additional Links](#8-additional-links)

***

## 1. Overview/Introduction

### The Problem: The Braille Literacy Gap
Blind and low-vision children in Sub-Saharan Africa face severe barriers to early literacy. Traditional Braille hardware, such as the Perkins Brailler or refreshable digital displays, costs hundreds or thousands of dollars. Furthermore, the region suffers from an acute shortage of specialized Teachers of the Visually Impaired (TVI). This leaves children in rural or low-income households educationally isolated.

### Our Solution: NuruTouch
NuruTouch is an accessible, offline Android application that transforms a standard touchscreen smartphone into an intelligent Braille tutor. By combining multi-touch chord input, localized speech synthesis, and an adaptive learning engine, NuruTouch removes the need for expensive dedicated hardware.

### Key Value Proposition
* **Zero Hardware Cost:** Runs on standard budget Android smartphones that families already own.
* **Offline-First:** No internet connection is required, removing data costs and connectivity barriers.
* **Bilingual Support:** Teaches in both English and Swahili to accommodate local households.
* **Self-Calibrating:** Adapts the digital Braille dots to the geometry of the child's own hand rather than forcing a fixed screen layout.

***

## 2. Key Features

* **Dynamic Calibration:** The system maps the six standard Braille dots to the learner's natural resting finger positions, automatically drifting and correcting as the hand moves during a session.
* **Adaptive Lesson Engine:** Automatically tracks mastery scores (0 to 100) and prioritizes review lessons based on spaced repetition, guiding learners from single letters to full sentences.
* **Global Gesture Layer:** Allows completely blind navigation using multi-finger swipes and holds, avoiding the need for visual buttons.
* **Dual-Language Audio:** Integrates a custom Swahili text-to-speech engine alongside the native English engine, with strict session tracking to prevent audio overlap.
* **Haptic Feedback:** Delivers precise success and error vibration cues optimized for the eccentric rotating mass (ERM) motors found in budget Android devices.
* **Supervisor Dashboard:** A secure, password-protected administrative view for sighted teachers or parents to review student progress and manage the curriculum.

***

## 3. System Architecture

NuruTouch follows a strict **Layered Singleton Architecture** within a single Flutter application. There is no cloud backend, ensuring absolute offline reliability in remote regions.

### Layer Breakdown
* **Service Layer:** Manages non-visual logic, including the TTS Router, Narration Service, Haptic Service, and Face Recognition pipeline.
* **Domain Layer:** Contains the Adaptive Learning Engine, Curriculum Database, and Mastery Calculator.
* **Data Layer:** A centralized local SQLite database handling all student and lesson progress tracking.

### Technology Stack
* **Frontend:** Flutter and Dart for high-performance, cross-platform UI.
* **Database:** SQLite (sqflite) for robust offline relational data storage.
* **Machine Learning:** Google ML Kit, TensorFlow Lite, and ONNX Runtime for on-device inference.

***

## 4. Machine Learning Models

NuruTouch relies on a suite of highly optimized edge-ML models that run entirely offline to protect student privacy and remove cloud dependencies.

### Swahili Text-to-Speech Engine
* **Architecture:** Character-level Piper VITS model.
* **Training & Fine-Tuning:** The acoustic model was custom fine-tuned for this project using the **Google WaxalNLP Single-Speaker Dataset**, leveraging a high-quality corpus of 1,387 single-speaker Swahili phrases.
* **Format:** ONNX.
* **Performance:** Operates at a 16,000 Hz sample rate. It tokenizes normalized Swahili text and synthesizes audio chunks asynchronously, writing to a temporary WAV file for immediate, zero-latency playback.

### Biometric Authentication Pipeline
* **Face Detection & Pose Estimation:** Utilizes **Google ML Kit** to rapidly detect the user's facial bounding box and calculate head yaw angles directly from the live camera feed (guiding the front, left, and right pose capture).
* **Feature Extraction (MobileFaceNet):** A quantized **TFLite** MobileFaceNet model takes the 112x112 pixel facial crop and extracts a unique 128-dimensional numerical embedding.
* **Authentication Logic:** The system uses **Cosine Similarity** to mathematically compare live embeddings against stored JSON profiles. To account for sub-optimal camera angles used by children, the system grants authentication at a relaxed similarity threshold of 0.20.

> **Built by**: Michael Musembi  
> **Status**: Final Capstone Submission  
> **Domain**: Accessible EdTech (Machine Learning & Edge AI)

## 📥 Download App
The fully compiled Android APK is available on GitHub Releases:
* **[Download NuruTouch v1.0 APK](https://github.com/MichaelMusembi/Capstone-Project-NuruTouch/releases/latest/download/app-release.apk)** *(Requires Android 9.0+)*

---

## 🏗️ Architecture & Diagnostic Calibration
### Adaptive Geometric Calibration (Online Learning)
* **Architecture:** Dynamic Heuristic Clustering.
* **KNN Centroid Matching:** During active lessons, the system acts as a localized K-Nearest Neighbors (KNN) classifier. It calculates the Euclidean distance of incoming touch coordinates to classify which of the six calibrated Braille dots the child intended to strike (using a 200-pixel radius).
* **Drift Adaptation:** The system utilizes an **Exponential Moving Average (EMA)** to perform "online learning." On every successful tap, the mathematical centroids drift by 10% towards the new touch point, allowing the interface to invisibly adapt to the child's hand drifting across the glass over a long session.

***

## 5. Installation & Setup

### Prerequisites
* Flutter SDK (Version 3.0+)
* Android Studio or VS Code with Flutter extensions
* An Android physical device (recommended for testing multi-touch and haptics)

### Build Instructions
```bash
# Navigate to the project directory
cd nurutouch

# Fetch dependencies
flutter pub get

# Run on a connected Android device
flutter run --release
```

***

## 6. Usage Guide

### Learner Workflow
1. **Login:** The student positions their face in front of the camera for biometric authentication.
2. **Language Selection:** Swipe left or right to select Swahili or English.
3. **Calibration:** Place all six fingers on the screen simultaneously. The system registers the coordinates and maps them to the Braille cell.
4. **Active Lesson:** Listen to the audio prompt, press the correct Braille chord, and lift all fingers to submit. Correct chords trigger a success haptic and advance the lesson.
5. **Navigation:** Swipe left to go back, swipe right for a hint, or hold six fingers to exit.

### Supervisor Workflow
1. **Access:** Perform a six-second hold anywhere on the screen to trigger the hidden gateway.
2. **Login:** Enter administrative email and password.
3. **Dashboard:** View the student list, review individual mastery scores across Letters, Words, and Sentences, and enroll new students via the camera interface.

***

## 7. Team & Acknowledgments

* **Lead Developer / Researcher:** Michael Musa Musembi
* **Supervisor:** Kevin Sebineza
* **Institution:** Faculty of Software Engineering, African Leadership University, Kigali, Rwanda

***

## 8. Additional Links

* [Technical Walkthrough Video](https://drive.google.com/drive/folders/1JQh8Nml7C00Woo0qx46Qj86XNQavvkUX?usp=sharing)
* [Download NuruTouch APK (283 MB)](INSERT_GITHUB_RELEASE_LINK_HERE)
