# Tapperoni's Android toolchain: headless Godot + export templates, JDK 17, Android SDK, adb.
# Everything needed to export the APK and install it on the phone, so nothing is installed on
# the host. Built and run by bin/phone (bin/phone build-image).
FROM eclipse-temurin:17.0.21_9-jdk-noble

ARG GODOT_VERSION=4.7.2
ARG GODOT_SHA512=9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65
ARG TEMPLATES_SHA512=ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079
ARG CMDLINE_TOOLS=commandlinetools-linux-16111833_latest.zip
ARG CMDLINE_TOOLS_SHA1=e025545c62a8e64c7559119566a569fb1dec5f60

RUN apt-get update && apt-get install -y --no-install-recommends unzip ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

ENV ANDROID_HOME=/opt/android-sdk
# HOME for uid 1000 (the base image's "ubuntu" user = adam on the host, so outputs are adam's)
ENV HOME=/home/ubuntu
ENV PATH=/opt/godot:/opt/android-sdk/platform-tools:/opt/android-sdk/cmdline-tools/latest/bin:$PATH

# Android SDK: only what a pre-built-APK export needs (no NDK/CMake; those are for Gradle builds)
RUN curl -fsSL -o /tmp/ct.zip https://dl.google.com/android/repository/$CMDLINE_TOOLS \
 && echo "$CMDLINE_TOOLS_SHA1  /tmp/ct.zip" | sha1sum -c \
 && mkdir -p $ANDROID_HOME/cmdline-tools && unzip -q /tmp/ct.zip -d /tmp/ct \
 && mv /tmp/ct/cmdline-tools $ANDROID_HOME/cmdline-tools/latest && rm -rf /tmp/ct /tmp/ct.zip \
 && yes | sdkmanager --licenses >/dev/null \
 && sdkmanager --install "platform-tools" "build-tools;35.0.1" "platforms;android-35" >/dev/null \
 && chown -R 1000:1000 $ANDROID_HOME

# Godot (run with --headless) and its Android export templates only (the full .tpz is ~1 GB)
RUN curl -fsSL -o /tmp/godot.zip https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
 && echo "$GODOT_SHA512  /tmp/godot.zip" | sha512sum -c \
 && unzip -q /tmp/godot.zip -d /opt/godot && mv /opt/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /opt/godot/godot \
 && rm /tmp/godot.zip \
 && curl -fsSL -o /tmp/t.tpz https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz \
 && echo "$TEMPLATES_SHA512  /tmp/t.tpz" | sha512sum -c \
 && T=$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable && mkdir -p $T \
 && unzip -q -j /tmp/t.tpz 'templates/android_*' 'templates/version.txt' -d $T && rm /tmp/t.tpz \
 && chown -R 1000:1000 $HOME/.local

# Editor settings: SDK, JDK and the debug keystore (kept on the host in ~/.android, mounted at
# $HOME/.android, so the signature stays the same across image rebuilds)
RUN mkdir -p $HOME/.config/godot && printf '%s\n' \
  '[gd_resource type="EditorSettings" format=3]' '' '[resource]' \
  'export/android/android_sdk_path = "/opt/android-sdk"' \
  'export/android/java_sdk_path = "/opt/java/openjdk"' \
  'export/android/debug_keystore = "/home/ubuntu/.android/debug.keystore"' \
  'export/android/debug_keystore_user = "androiddebugkey"' \
  'export/android/debug_keystore_pass = "android"' \
  > $HOME/.config/godot/editor_settings-4.7.tres \
 && chown -R 1000:1000 $HOME/.config

USER 1000:1000
WORKDIR /project
