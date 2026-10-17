# Not ShellSpec's own image: that one is amd64 only, and ShellSpec misfires under emulation.
FROM alpine:3.24
# util-linux-misc for script, which gives setup.sh's spec a terminal.
RUN apk add --no-cache bash git jq nodejs npm shellspec util-linux-misc yq
# For dcm-rules.sh, which parses a JS bundle with it.
RUN npm install --global acorn@8.19.0
WORKDIR /work
ENTRYPOINT ["shellspec"]
