# ApolLens

Offline visual repair assistance for situations where internet access is limited or unavailable.

ApolLens combines live component detection, an on-device language model, and spoken instructions. Built around the challenge of maintaining equipment beyond Earth, the current prototype uses laptop hardware as its demonstration.

## How it works

1. Point the phone’s camera at the equipment.
2. Review and confirm the detected components.
3. Describe the problem.
4. Follow spoken, step-by-step guidance while keeping the camera visible.
5. Record completed actions and provide updates when something changes.

For supported RAM and storage replacement steps, users can open a component close-up and mark numbered screws or clips. The instructions then refer to those locations.

Fastener locations are currently marked by the user, not automatically detected.

## Features

- Live detection of RAM, storage drives, batteries, and cooling fans.
- Local reasoning based on confirmed parts, symptoms, and repair progress.
- Offline text-to-speech with visible instructions.
- Component-focused visual references and numbered mounting points.
- Galaxy-themed interface.
- React companion workspace for local procedure drafts and progress.

The browser workspace does not currently synchronize with phone sessions.

## Models and technology

| Area | Implementation |
| --- | --- |
| Mobile app | Flutter and Dart |
| Computer vision | Custom YOLOX-Nano component detector, exported to ONNX |
| Vision inference | ONNX Runtime on the device |
| Supported iOS devices | Apple Foundation Models when available |
| Android and iOS fallback | Qwen3-1.7B through LiteRT-LM |
| Offline speech | Installed Android/iOS system voices through flutter_tts |
| Web companion | React, TypeScript, and Vite |

The language models are existing pretrained models. Our work integrates them into the repair workflow; we did not train the underlying language models from scratch.

## Offline operation

Camera processing, local reasoning, and system speech run on the device.

The Qwen fallback requires an initial model download of approximately 1 GB. Required models and voices must be installed before using the app without internet access.

Online voice services are optional and are not required for the offline workflow.

## Development

### Mobile

Requires Flutter with Dart 3.12 or newer.

    cd mobile
    flutter pub get
    flutter test
    flutter run

iPhone installation requires macOS, Xcode, development signing, and Developer Mode. The current iOS deployment target is 16.0; Apple Foundation Models requires a compatible device and system configuration.

### Web

Requires a current Node.js installation.

    cd web
    npm ci
    npm run dev

Production build and lint:

    npm run build
    npm run lint

## Team

- **Gavin Couch:** Flutter application, local language-model integration, computer-vision training and mobile integration, UI development, and device testing.
- **Aditya Baisakh:** React dashboard and reusable web components, dataset validation tooling, and text-to-speech improvements.
- **Indigo Brown:** Backend API development, authentication, and online voice-service integration.
- **Eric Chau:** Image collection and dataset preparation, with model-training support.

## AI assistance disclosure

AI tools were used heavily to develop the local language-model integration for both iOS and Android, including application logic, debugging, and testing.

Computer-vision image preparation and training workflows, along with UI design, were partially AI-assisted. AI assistance was also used for integration work, text-to-speech fixes, and testing.

## Current limitations

This is a hackathon prototype. Laptop components are the current demonstration, rather than general recognition of arbitrary equipment.

Detection can miss or misidentify parts. Component recognition does not establish which part has failed. Guidance is constrained by the implemented repair workflows, and user confirmations do not independently verify a successful repair.

Live camera operation has been confirmed on the development iPhone. Android hardware validation and broader device testing remain outstanding.

## Credits

The project uses third-party models, datasets, libraries, and imagery. See the included model cards, license files, and notices for attribution and usage details.

The galaxy image is credited in the app to NASA, ESA, S. Beckwith (STScI), and The Hubble Heritage Team (STScI/AURA).

