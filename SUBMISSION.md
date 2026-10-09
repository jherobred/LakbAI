# Submission notes (Cerebral Valley form)

**Project name:** LakbAI

**Short description:** An offline contract checker for Overseas Filipino Workers. It compares the DMW-verified contract with the one handed over abroad, explains every change, and builds a formal incident report. All AI runs on the phone.

**Why does this product benefit from running AI locally?**
Contract substitution happens at an agency desk or on arrival abroad. There the worker may have no SIM, no data or Wi-Fi, and an employer who checks their phone. LakbAI's language model, speech recognition and text recognition run on the device in airplane mode. The contracts, which carry passport numbers and salaries, never leave the phone, and there is no cloud account or chat log to find. On-device inference also makes every scan and question free for low-income workers.

**What runs locally:** the language model (Qwen3 0.6B or Gemma 4 E2B, LiteRT-LM), speech-to-text (Whisper), contract text recognition (ML Kit), clause comparison, legal knowledge search, and PDF report generation.

**What requires internet:** nothing for the core app, since the AI and voice models ship inside the installer. Optional bigger models download once from Hugging Face. Phone calls to hotlines and sharing a report need signal.

**Models used:** Qwen3 0.6B (Apache-2.0), Gemma 4 E2B (Apache-2.0), Whisper tiny/base (MIT), Google ML Kit Text Recognition v2.

**Technologies and frameworks:** Flutter, flutter_edge_ai (LiteRT-LM), google_mlkit_text_recognition, camera, record, pdf.

**APIs and cloud services:** Hugging Face for fetching model files at build time and for optional bigger models. Nothing else.

**Existing code and assets:** the Flutter app template and the WAV-to-PCM helper pattern from the flutter_edge_ai docs. The knowledge base and synthetic sample contracts were made during the hackathon.

**AI development tools:** Claude Code (Anthropic).

## 1-minute demo video plan

1. **0–8 s:** "OFWs get their contract swapped abroad. LakbAI catches it, offline." Switch on airplane mode on screen.
2. **8–25 s:** Compare contracts. Scan both papers (or use the samples) and the "6 changes against you" screen counts up. Scroll the red cards.
3. **25–38 s:** Type "kinuha ang passport ko". The *passport* chip appears, the chat filters, and the local AI answers with the law cited.
4. **38–50 s:** Open My options and pick step 1, then Make report, Speak it, and Create PDF.
5. **50–60 s:** "No cloud, no account, no trace. LakbAI." Show the airplane mode icon again.

Post it on X or LinkedIn tagging Devin / Cognition with **#AppBuildersPH**.
