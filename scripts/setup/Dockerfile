# Debian, not Alpine like the spec image: the brick needs mason, whose Dart only runs on glibc.
FROM mikefarah/yq:4.53.6 AS yq
FROM ghcr.io/jqlang/jq:1.8.2 AS jq
FROM ghcr.io/charmbracelet/gum:v2.0.2 AS gum
FROM dart:3.13.4 AS dart
FROM debian:13.7-slim

# gh the way its docs install it on Debian, since Debian's own is years behind.
RUN keyring=/etc/apt/keyrings/githubcli-archive-keyring.gpg arch="$(dpkg --print-architecture)" \
  && apt-get update \
  && apt-get install --yes --no-install-recommends ca-certificates git wget \
  && mkdir -p -m 755 /etc/apt/keyrings \
  && wget -nv -O "${keyring}" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && chmod go+r "${keyring}" \
  && echo "deb [arch=${arch} signed-by=${keyring}] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update \
  && apt-get install --yes --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

# Debian's yq is another tool with the same name, and its jq is older.
COPY --from=yq /usr/bin/yq /usr/local/bin/yq
COPY --from=jq /jq /usr/local/bin/jq
COPY --from=gum /usr/local/bin/gum /usr/local/bin/gum

# The dart image's SDK, which is built on this same Debian.
COPY --from=dart /usr/lib/dart /usr/lib/dart
ENV PUB_CACHE=/opt/pub-cache PATH="/usr/lib/dart/bin:/opt/pub-cache/bin:${PATH}"
RUN dart pub global activate mason_cli
