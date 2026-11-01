# =====================================================================
#  صورة بيئة التطوير لتطبيق «جايك» — جاهزة للنقل لأي جهاز
#  Flutter 3.47.8 + JDK 17 + Android SDK 36 + NDK 28.2.13676358 + Chrome
#  목표: شريكتك تنزل المستودع وتشغل docker compose وتشتغل مثل جهازك تماماً.
# =====================================================================
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

USER root
ARG DEBIAN_FRONTEND=noninteractive
ARG FLUTTER_VERSION=3.47.8
ARG ANDROID_CMDLINE_TOOLS=11076708_latest
ARG ANDROID_PLATFORM=android-36
ARG ANDROID_BUILD_TOOLS=36.0.0
ARG ANDROID_NDK=ndk;28.2.13676358
ARG CHROME_VERSION=latest

# 1) أدوات نظام + JDK 17 + كروم (للاختبار على المتصفح)
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-17-jdk-headless \
        curl git unzip xz-utils zip ca-certificates \
        wget gnupg2 software-properties-common \
        fonts-liberation libnss3 libatk1.0-0 libatk-bridge2.0-0 \
        libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 \
        libxfixes6 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 \
        libasound2 \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - 2>/dev/null || true \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV FLUTTER_HOME=/opt/flutter
ENV CHROME_BIN=/usr/bin/google-chrome
ENV PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/android-sdk/tools/bin:$PATH

# 2) Android SDK command line tools
RUN mkdir -p $ANDROID_HOME/cmdline-tools \
    && curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}.zip \
         -o /tmp/cmdtools.zip \
    && unzip -q /tmp/cmdtools.zip -d $ANDROID_HOME/cmdline-tools \
    && mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest \
    && rm /tmp/cmdtools.zip

# 3) حزم SDK مطابقة لجهازك بالضبط
RUN yes | sdkmanager --licenses > /dev/null 2>&1 || true \
    && sdkmanager --install \
        "platform-tools" \
        "platforms;${ANDROID_PLATFORM}" \
        "build-tools;${ANDROID_BUILD_TOOLS}" \
        "${ANDROID_NDK}" \
    > /dev/null 2>&1

# 4) Flutter SDK — نفس نسختك وفي CI
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz \
         -o /tmp/flutter.tar.xz \
    && tar -xJf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && chown -R vscode:vscode /opt/flutter /opt/android-sdk

# 5) تمكين الويب والسطح وأ aceptar تراخيص
USER vscode
RUN flutter config --no-analytics \
    && flutter enable-web \
    && flutter doctor -v \
    && git config --global --add safe.directory '*'

WORKDIR /workspace

# متغيرات اختيارية لـ Supabase (إذا شريكتك تريد تشغيل مع Supabase لاحقاً)
ENV SUPABASE_URL=""
ENV SUPABASE_ANON_KEY=""
