# =====================================================================
#  صورة بيئة التطوير لتطبيق «جايك» — Flutter 3.47.8 + Android SDK
#  تُستخدم في: VS Code Dev Containers، و docker build / docker run
#  الهدف: نقل المشروع بالكامل إلى أي جهاز ويعمل كما يعمل لديك.
# =====================================================================
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

USER root

ARG FLUTTER_VERSION=3.47.8
ARG DEBIAN_FRONTEND=noninteractive

# 1) JDK 17 (مطلوب لـ Gradle/AGP) + أدوات أساسية
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-17-jdk-headless curl git unzip xz-utils zip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV FLUTTER_HOME=/opt/flutter
ENV PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:$PATH

# 2) Android SDK — command line tools
RUN mkdir -p $ANDROID_HOME/cmdline-tools \
    && curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
         -o /tmp/cmdtools.zip \
    && unzip -q /tmp/cmdtools.zip -d $ANDROID_HOME/cmdline-tools \
    && mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest \
    && rm /tmp/cmdtools.zip

# 3) حزم SDK المطابقة للمشروع (compileSdk/targetSdk 36، NDK 28.2.13676358)
RUN yes | sdkmanager --licenses > /dev/null \
    && sdkmanager --install \
        "platform-tools" \
        "platforms;android-36" \
        "build-tools;36.0.0" \
        "ndk;28.2.13676358"

# 4) Flutter SDK — نفس نسختك محلياً وفي CI (3.47.8 stable)
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz \
         -o /tmp/flutter.tar.xz \
    && tar -xJf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && chown -R vscode:vscode /opt/flutter /opt/android-sdk

USER vscode
RUN flutter config --no-analytics \
    && flutter --version \
    && git config --global --add safe.directory '*'

WORKDIR /workspace
