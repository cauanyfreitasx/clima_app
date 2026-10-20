# App Clima (Flutter + Open-Meteo)

## Como rodar
1. Instale o Flutter SDK: https://docs.flutter.dev/get-started/install
2. Dentro desta pasta, gere as pastas de plataforma (android, ios, web...):
   flutter create --project-name clima_app .
3. Baixe as dependências:
   flutter pub get
4. Rode no emulador, no celular (USB) ou no navegador:
   flutter run
   flutter run -d chrome

## Gerar o APK para instalar no Android
   flutter build apk --release
O arquivo fica em build/app/outputs/flutter-apk/app-release.apk

## Testes
   flutter test

## Estrutura
- lib/main.dart  -> modelos, serviço (API), auxiliares e tela
- test/widget_test.dart -> testes unitários simples
