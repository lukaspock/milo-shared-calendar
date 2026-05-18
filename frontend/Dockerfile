FROM debian:bookworm-slim AS build
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip xz-utils ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Shallow-clone the stable Flutter branch (no history, no Android/iOS SDK)
RUN git clone --depth 1 --branch stable \
    https://github.com/flutter/flutter.git /opt/flutter

ENV PATH="/opt/flutter/bin:$PATH"

# Download only the web engine artifacts
RUN flutter config --no-analytics --enable-web \
    && flutter precache --web

# Cache pub dependencies separately from source
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Add web/ directory if it wasn't committed
RUN flutter create . --platforms web 2>/dev/null || true

RUN flutter build web --release

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
