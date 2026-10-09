# Builds and serves the city for local testing.
#   web   : browser build served by nginx (http://localhost:8080)
#   tests : headless tests + screenshots written to ./docker-out
ARG GODOT_VERSION=4.6.3

# --- Godot editor binary (headless capable) ---------------------------------------
FROM ubuntu:24.04 AS godot
ARG GODOT_VERSION
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip \
        xvfb xauth libgl1 libgl1-mesa-dri libegl1 \
        libxcursor1 libxinerama1 libxrandr2 libxi6 libxkbcommon0 libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /tmp/godot.zip \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    && unzip -q /tmp/godot.zip -d /tmp/godot \
    && mv /tmp/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
    && rm -rf /tmp/godot /tmp/godot.zip
WORKDIR /project

# --- Project imported (models converted once) ---------------------------------------
FROM godot AS project
COPY . /project
RUN godot --headless --import

# --- Tests ---------------------------------------------------------------------------
FROM project AS tests
CMD ["/project/docker/run-tests.sh"]

# --- Web export templates (only the two web templates are kept) -----------------------
FROM godot AS templates
ARG GODOT_VERSION
RUN curl -fsSL -o /tmp/templates.tpz \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" \
    && dir="/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" \
    && mkdir -p "$dir" \
    && unzip -q -j /tmp/templates.tpz \
        templates/version.txt templates/web_release.zip templates/web_nothreads_release.zip -d "$dir" \
    && rm /tmp/templates.tpz

# --- Web export -------------------------------------------------------------------------
FROM templates AS export
COPY --from=project /project /project
RUN mkdir -p build/web/lite && touch build/.gdignore \
    && godot --headless --export-release "Web" build/web/index.html \
    && godot --headless --export-release "Web Lite" build/web/lite/index.html \
    && test -f build/web/index.pck && test -f build/web/lite/index.pck

# --- Web server -----------------------------------------------------------------------------
FROM nginx:1.27-alpine AS web
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=export /project/build/web /usr/share/nginx/html
EXPOSE 80
