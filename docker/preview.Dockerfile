# Ubuntu's Qt, only to render screenshots of the QML offscreen (tools/preview.sh).
# The reMarkable SDK's host Qt ships no QPA plugins, so it cannot do this.
FROM ubuntu:24.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        qml-qt6 qml6-module-qtquick qml6-module-qtquick-window qml6-module-qtqml-workerscript \
        qt6-qpa-plugins fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*
ENV QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
