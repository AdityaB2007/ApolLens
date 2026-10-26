# ApolLens

Offline visual repair assistance for situations where internet access is limited or unavailable.

ApolLens combines live component detection, an on-device language model, and spoken instructions. Built around the challenge of maintaining equipment beyond Earth, the current prototype uses laptop hardware as its demonstration.

## How it works

1. Point the phone's camera at the equipment.
2. Review and confirm the detected components.
3. Describe the problem.
4. Follow spoken, step-by-step guidance while keeping the camera visible.
5. Record completed actions and provide updates when something changes.

For supported RAM and storage replacement steps, users can open a component close-up and mark numbered screws or clips. Instructions then refer to those locations. Fastener locations are currently marked by the user, not automatically detected.

## Features

- Live detection of RAM, storage drives, batteries, and cooling fans.
- Local reasoning based on confirmed parts, symptoms, and repair progress.
- Offline text-to-speech with pause, resume, replay, mute, and visible instructions.
- Component-focused visual references and numbered mounting points.
- Galaxy-themed phone interface and dark web workspace.
- React companion workspace for local procedure drafts and progress.

The browser workspace saves drafts in this browser. It does not currently synchronize with phone sessions or receive a live camera feed.

## Models and technology

| Area | Implementation |
| --- | --- |
| Mobile app | Flutter and Dart |
| Computer vision | Custom YOLOX-Nano component detector, exported to ONNX |
| Vision inference | ONNX Runtime on the device |
| Compatible iOS devices | Apple Foundation Models when available |
| Android and iOS fallback | Qwen3-1.7B through LiteRT-LM |
| Offline speech | Installed Android/iOS system voices through flutter_tts |
| Web companion | React, TypeScript, and Vite |

The language models are existing pretrained models. Our work integrates them into the repair workflow; we did not train the underlying language models from scratch. The computer-vision detector is trained for the four supported component classes, not arbitrary equipment or automatic fastener recognition.

## Offline operation

Camera processing, local reasoning, and system speech run on the device. The Qwen fallback requires an initial model download of approximately 1 GB. Required models and English system voices must be installed before using the app without internet access.

The core phone flow does not require a backend. Online voice services are optional; ElevenLabs integration is separate from offline system speech. No provider credentials belong in the mobile or web source.

The web workspace uses browser storage for drafts and progress. Clearing that storage removes the drafts. It is a companion workspace, not a browser implementation of the native local AI engines.

## Development

### Mobile

Requires Flutter with Dart 3.12 or newer, plus the native toolchain for the target platform.

```sh
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

For iPhone installation, use macOS and Xcode with development signing and Developer Mode enabled on the phone. The iOS deployment target is 16.0; Apple Foundation Models requires a compatible device and system configuration. Other supported devices use the downloaded Qwen fallback.

For Android, install the Android SDK and connect an emulator or a physical device. Native inference performance and installed voice availability depend on the device.

### Web

Requires Node.js 22.6 or newer.

```sh
cd web
npm ci
npm run dev
```

Validation and production build:

```sh
npm test
npm run lint
npm run build
npm run preview
```

Create a procedure, add steps, and use Session to record confirmations. Changes save locally. Editing a step invalidates its prior confirmation so modified instructions do not inherit completed status.

### Vision training and evaluation

The `vision/` directory contains dataset preparation, training, evaluation, and export utilities. See [YOLOX setup](vision/YOLOX_SETUP.md), the [model card](vision/models/laptop-components/model_card.json), and the included license notices for the model and data details.

## Team

- **Gavin Couch:** Flutter application, local language-model integration, computer-vision training and mobile integration, UI development, and device testing.
- **Aditya Baisakh:** React dashboard and reusable web components, dataset validation tooling, and text-to-speech improvements.
- **Eric Chau:** Image collection and dataset preparation, with model-training support.
- **Indigo Brown:** Backend API development, authentication, and online voice-service integration.

## AI assistance disclosure

AI tools were used heavily to develop the local language-model integration for both iOS and Android, including application logic, debugging, and testing.

Computer-vision image preparation and training workflows, along with UI design, were partially AI-assisted. AI assistance was also used for integration work, text-to-speech fixes, web integration, and testing.

## Current limitations

This is a hackathon prototype. Laptop components are the current demonstration, rather than general recognition of arbitrary equipment.

Detection can miss or misidentify parts. Component recognition does not establish which part has failed. Guidance is constrained by the implemented repair workflows, and user confirmations do not independently verify a successful repair. Marked fasteners are a frozen visual reference, not automatic proof that a screw or clip was removed.

Live camera operation has been confirmed on the development iPhone. The revised TTS behavior is covered by automated platform fixtures and an iOS build; listening and interruption checks on physical Android and iOS devices remain necessary. Android hardware validation and broader device testing remain outstanding.

## Credits

The project uses third-party models, datasets, libraries, and imagery. See the included model cards, license files, and notices for attribution and usage details.

Whirlpool Galaxy M51 image: NASA, ESA, S. Beckwith (STScI), and The Hubble Heritage Team (STScI/AURA), from [ESA/Hubble](https://esahubble.org/images/heic0506a/), used under [CC BY 4.0](https://esahubble.org/copyright/). The app presents a crop and animation and includes the attribution offline. No NASA or ESA endorsement is implied.

## Presentation Link
Feel free to view our presentation here! : [Link](https://docs.google.com/presentation/d/1EFC7ZZD0hXRFcot35KNYO3bxi_sgULUzy2CbTzwGbvU/edit?slide=id.h4ea6fe05bf18c190_0_0#slide=id.h4ea6fe05bf18c190_0_0)
