# LakbAI

**An offline contract checker for Overseas Filipino Workers.** LakbAI compares the contract the DMW verified with the one a worker is handed abroad, explains every change in Filipino or English, and turns it into a formal incident report. The language model, speech recognition and text recognition all run on the phone.

Built for AppBuildersPH Hackathon 2026 (theme: Local AI), 9–10 October 2026.

## Download

| Platform | Download | Install |
|---|---|---|
| **Android 11+** (64-bit phones) | [**lakbai-android.apk**](https://github.com/jherobred/LakbAI/releases/latest/download/lakbai-android.apk) | Open the file on your phone, allow **Install unknown apps** for your browser or Files app, then tap **Install**. If Play Protect warns about an unknown developer, tap **Install anyway**. This is a hackathon build. |
| **iOS 16+** | [**lakbai-ios-unsigned.ipa**](https://github.com/jherobred/LakbAI/releases/latest/download/lakbai-ios-unsigned.ipa) | Apple does not allow installing unsigned apps directly. Re-sign it with your Apple ID using [AltStore](https://altstore.io) or [Sideloadly](https://sideloadly.io), or build from source in Xcode (see [iOS](#ios)). |

All builds are on the [Releases page](https://github.com/jherobred/LakbAI/releases). The AI model (Qwen3 0.6B) and the voice model (Whisper base) are inside the installer, so LakbAI works in airplane mode from the first launch with nothing else to download.

## The problem

Contract substitution means swapping a DMW-verified contract for a worse one, usually right before departure or after arrival. It is illegal under Labor Code Art. 34(i) and RA 8042 Sec. 6, but workers sign under pressure without spotting lower pay, fewer rest days or a different job. Many never act because they are abroad, afraid, and have no proof.

LakbAI covers three gaps:

1. **Noticing.** It scans both contracts and flags every clause that changed against the worker.
2. **Proof.** Photos are fingerprinted (SHA-256) and saved privately with a timestamped record.
3. **A safe next step.** It offers six options from "keep it quiet" to "criminal case". It defaults to the quietest, because the Philippine agency stays liable (RA 8042 Sec. 10) and money claims last 3 years (Labor Code Art. 306). A worker can act after coming home.

## Why this product benefits from running AI locally

- **The moment of substitution is offline.** It happens at an agency desk or on arrival abroad, where the worker may have no local SIM, no data and no Wi-Fi. LakbAI works in airplane mode.
- **The phone may be watched.** Employers sometimes check or take workers' phones. Nothing is uploaded, so there is no cloud account, chat log or server copy to find. The app has a PIN lock and a one-tap quick exit.
- **The documents are sensitive.** Contracts carry passport numbers, employer names and salaries. Sending them to a cloud AI would hand that data to a third party.
- **It is free to use.** On-device inference costs nothing per scan or question, which matters for low-income workers.

## What runs locally and what needs internet

| Feature | Runs on the phone | Needs internet |
|---|---|---|
| Chat answers (language model) | Yes: Qwen3 0.6B or Gemma 4 E2B via LiteRT-LM | No |
| Voice input (speech-to-text) | Yes: Whisper tiny/base via LiteRT | No |
| Contract reading (OCR) | Yes: Google ML Kit text recognition (bundled model) | No |
| Clause comparison and minimum-standard checks | Yes: rule engine in Dart | No |
| Legal knowledge search | Yes: 34-entry cited knowledge base, BM25 search | No |
| PDF incident report | Yes: generated on the phone | No |
| Built-in models (Qwen3 0.6B, Whisper base) | Yes, inside the installer | No |
| Optional bigger models (Qwen3 0.6B full, Gemma 4 E2B) | — | **Once**, from Hugging Face |
| Calling hotlines (1348, 1343) | — | Mobile signal |
| Sharing the report | — | Only when the worker chooses |

## Features

- **Home is a chat with the local AI.** Typing words like *sahod*, *passport* or *day off* turns them into live filter chips. The chat filters to that topic, related legal cards appear, and the answer focuses on it. Answers show the law they rely on.
- **Microphone.** Speak in Filipino or English, and Whisper transcribes it on the phone.
- **Document camera.** It has a page guide, tap-to-focus, torch and multi-page capture, plus gallery import and bundled sample contracts.
- **Contract comparison.** Rules compare salary, currency, work and rest hours, rest days, leave, duration, job, employer, worksite, food, lodging, airfare, deductions and passport retention. They also check the new contract against DMW and host-country minimums. Numbers come from rules, not from the language model.
- **Plain-language explanation** of the changes, written offline by the model. A template takes over if no model is installed.
- **Options screen** with six steps, from quietest to most formal, and tap-to-call hotlines.
- **Formal incident report (PDF).** It covers parties, a comparison table, the worker's statement (dictated, optionally tidied by the AI without changing facts), evidence fingerprints, legal basis, where to file, and an attestation and jurat block.
- **Recruiter check** for illegal recruiters and abusive handlers. It scores warning signs, shows a trafficking emergency banner, and builds a report.
- **Know your rights** browser with topic filters and search.
- **Light and dark mode, blue "trust" palette, Material 3 motion,** and a Lite motion mode that switches on automatically on low-RAM phones.
- **Low-end first.** The app reads the phone's RAM and recommends a 345 MB model for 3–4 GB phones and Gemma 4 E2B for 8 GB+ phones. Low-RAM phones run the model on the CPU.
- **Privacy.** It offers a salted PIN, a quick exit, per-case delete and "delete everything".

## Run it

Requirements: Flutter 3.47.2 (Dart 3.13), Android SDK 36, and an **Android 11+ arm64 phone**. LiteRT-LM ships arm64 only and needs API 30.

```bash
flutter pub get
bash tool/fetch_models.sh   # packs the AI and voice models into the installer (~420 MB, once)
flutter run --release
```

The model files are not in git (GitHub's 100 MB limit). Without `tool/fetch_models.sh` the app still builds and offers a one-time download on first launch instead. Airplane mode works from the first launch. To try the comparison without paper, open **Compare contracts → Try with sample contracts**.

Tests for the contract reader: `flutter test`.

### iOS

The codebase targets iOS 16+, and a Mac with Xcode is needed:

1. `flutter pub get`, then `flutter build ios` once so CocoaPods generates `ios/Podfile`.
2. In `ios/Podfile`, set `platform :ios, '16.0'` and use `use_frameworks! :linkage => :static`.
3. `ios/Runner/Runner.entitlements` is already linked to the Runner target. It requests Extended Virtual Addressing and Increased Memory Limit for the model. If your signing team cannot use those capabilities, remove them and use the Qwen3 0.6B Lite model.
4. Build with `flutter run --release` on a physical iPhone.

## Disclosures

**Models**
- Qwen3 0.6B (Alibaba Qwen, Apache-2.0), LiteRT-LM conversion by `litert-community`.
- Gemma 4 E2B (Google, Apache-2.0), LiteRT-LM conversion by `litert-community`.
- Whisper tiny / base (OpenAI, MIT), LiteRT conversion by `litert-community`, tokenizers from `openai/whisper-*`.
- Google ML Kit Text Recognition v2 (Latin script, bundled on-device model).

**Frameworks and libraries:** Flutter; flutter_edge_ai, flutter_edge_ai_litertlm and flutter_edge_ai_speech (LiteRT-LM runtime); google_mlkit_text_recognition; camera; image_picker; record; pdf; share_plus; flutter_animate; animations; shared_preferences; path_provider; crypto; url_launcher; file_picker.

**APIs and cloud services:** Hugging Face is used only to fetch model files at build time, and for the optional bigger models. There are no other cloud services, no analytics, no accounts and no telemetry.

**Existing code and assets**
- Flutter's app template.
- The WAV-to-PCM helper follows the flutter_edge_ai speech documentation.
- The legal knowledge base (`assets/kb/knowledge.json`) was written during the hackathon from public legal sources, each entry citing its source.
- The sample contracts in `tool/samples/` are synthetic and marked "SAMPLE ONLY".

**AI development tools:** Claude Code (Anthropic) was used for ideation, prior-art research and writing code during the hackathon.

## Limitations

- Legal information, not legal advice. Laws and DMW rules change, so confirm with the MWO, DMW or a lawyer.
- Text recognition reads Latin-script (English) contracts. Arabic or Chinese-only pages are not read.
- Small on-device models can be wrong. Answers are grounded in a cited knowledge base, and all numbers in comparisons come from rules.
- The DMW US$500 domestic-worker minimum (2025) was introduced with a transition period, so LakbAI reports it as "check with the MWO" rather than a violation.
- LakbAI cannot verify agency licenses offline. It links to the DMW list.

## Team

**tigerBytes**

- Jhems Robert B. Reduta ([@jherobred](https://github.com/jherobred))
- _Add the other members here (must match the AppBuildersPH list)._
