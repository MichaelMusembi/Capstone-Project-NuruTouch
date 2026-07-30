# NuruTouch Technical Diagrams & Charts

This directory contains the core technical diagrams, evaluation sequences, and analytics charts generated during the development and testing of NuruTouch. 

These images serve as technical proof of the application's offline machine learning accuracy and adaptive learning progression.

## 🏗️ Architecture
Contains structural diagrams defining the software design of the application.
- **[System Architecture Diagram](architecture/system-architecture-diagram.png)**: Showcases the strict Layered Singleton Architecture (Presentation, Service, Domain, Data) and how the isolated UI overlays communicate with the SQLite database.

## 🔄 Sequence Diagrams
Contains logical flow diagrams for the core interactions in the app.
- **[Braille Evaluation Sequence](sequences/braille-evaluation-sequence-diagram.png)**: Maps the lifecycle of a multi-touch Braille chord input—from pointer detection, heuristic centroid matching, and haptic feedback, to scoring and database writing.
- **[Facial Enrolment Sequence](sequences/facial-enrolment-sequence-diagram.png)**: Details the background biometric pipeline, showing how Google ML Kit extracts a bounding box and TFLite runs MobileFaceNet asynchronously in an isolate to compute a 128D embedding.

## 📊 Analytics & Accuracy Charts
Contains raw data visualizations proving the efficacy of the ML models and learning engine.
- **[Facial Recognition Accuracy](analytics/facial-recognition-accuracy-chart.png)**: A scatter plot demonstrating the Cosine Similarity scores between enrolled targets and imposters over 25 login attempts.
- **[First-Attempt Success Rate](analytics/first-attempt-success-rate-chart.png)**: A bar chart detailing the accuracy with which children successfully inputted specific Braille letters (e.g., Letter A vs. Letter G) on their first try.
- **[Learner Mastery Progression](analytics/learner-mastery-progression-chart.png)**: Tracks the session-by-session growth of learner mastery scores, proving the success of the adaptive feedback loop.
- **[Tier Unlock Progression](analytics/tier-unlock-progression-chart.png)**: Visualizes how many students successfully progressed from single letters to full words and sentences over the testing period.
