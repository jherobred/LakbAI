# Submission (Cerebral Valley form)

Paste each answer into the matching field. Deadline: 10:00 AM, 10 October 2026.

## The project

**Project name:** LakbAI

**Short description:** An offline contract checker for Overseas Filipino Workers. It compares the DMW-verified contract with the one handed over abroad, explains every change, and builds a formal incident report. All AI runs on the phone.

**Team members:** tigerBytes. Justin Lars Adriano Ham, Kristina Irish Matignas, Irelle Jann Miranda, Jhems Robert B. Reduta (@jherobred).

**Public GitHub repository:** https://github.com/jherobred/LakbAI

## The proof

**Demo video:** _upload the ~1 minute video and paste its link here_.

**X / LinkedIn video URL:** _paste the post link here_.

**What runs locally:** the language model (Qwen3 0.6B built into the installer, or optional Qwen3 0.6B full and Gemma 4 E2B, all via LiteRT-LM), speech-to-text (Whisper base built in, Whisper tiny optional), contract text recognition (Google ML Kit, bundled model), clause comparison and minimum-standard checks (a rule engine in Dart), legal knowledge search over a 47-entry cited knowledge base, PDF incident report generation, and saved chat history. Everything works in airplane mode from the first launch.

**What requires internet:** nothing for the core app. Optional bigger models download once from Hugging Face. Calling the 1348/1343 hotlines needs mobile signal, and sharing a report needs a connection only when the worker chooses to share.

## The disclosures

**Models used:** Qwen3 0.6B (Alibaba Qwen, Apache-2.0), Gemma 4 E2B (Google, Apache-2.0), Whisper base and tiny (OpenAI, MIT), all as LiteRT conversions by litert-community on Hugging Face. Google ML Kit Text Recognition v2 (Latin script, bundled on-device model).

**Technologies and frameworks:** Flutter and Dart; flutter_edge_ai, flutter_edge_ai_litertlm and flutter_edge_ai_speech (LiteRT-LM runtime); google_mlkit_text_recognition; camera; image_picker; record; pdf; share_plus; flutter_animate; animations; shared_preferences; path_provider; crypto; url_launcher; file_picker; flutter_launcher_icons (app icon). GitHub Actions builds the iOS app, and GitHub Releases hosts the installers.

**APIs and cloud services:** Hugging Face only, to fetch model files at build time and for the optional bigger models. No other cloud services, no analytics, no accounts and no telemetry.

**Existing code and assets:** Flutter's app template. The WAV-to-PCM helper follows the flutter_edge_ai speech documentation. The legal knowledge base, the synthetic sample contracts (marked "SAMPLE ONLY") and the LakbAI logo were made by the team during the hackathon.

**AI development tools:** Claude Code (Anthropic), used for ideation, prior-art research, writing code and preparing the demo video during the hackathon.

## Why does this product benefit from running AI locally?

Contract substitution happens at an agency desk or on arrival abroad. There the worker may have no SIM, no data or Wi-Fi, and an employer who checks their phone. LakbAI's language model, speech recognition and text recognition run on the device in airplane mode. The contracts, which carry passport numbers and salaries, never leave the phone, and there is no cloud account or server copy to find. Saved chats stay on the phone behind a PIN lock, and the worker can delete one chat or all of them. On-device inference also makes every scan and question free for low-income workers.

## Demo video plan (~1 minute)

Record on the phone with its screen recorder. Keep airplane mode on for the whole take.

1. **0–8 s:** "OFWs get their contract swapped abroad. LakbAI catches it, offline." Switch on airplane mode on screen.
2. **8–25 s:** Compare contracts. Scan both papers, or use Try with sample contracts, and let the "changes against you" count run up. Scroll the red cards.
3. **25–38 s:** Type "kinuha ang passport ko". The *passport* chip appears, the chat filters, and the local AI answers with the law cited.
4. **38–50 s:** Open My options and pick step 1, then Make report, Speak it, and Create PDF.
5. **50–60 s:** "No cloud, no account, no trace. LakbAI." Show the airplane mode icon again.

## Social post (X or LinkedIn)

Attach the demo video. Tag Devin and Cognition by picking their official accounts from the autocomplete.

> OFWs sometimes get their verified contract swapped for a worse one abroad, often with no data and an employer watching their phone.
>
> We built LakbAI for #AppBuildersPH: it scans both contracts, flags every change against the worker, and builds a formal incident report. The AI, voice input and text recognition all run on the phone, in airplane mode.
>
> Code: https://github.com/jherobred/LakbAI
>
> @Devin @Cognition #AppBuildersPH #LocalAI
