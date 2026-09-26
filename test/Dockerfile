# Not ShellSpec's own image: that one is amd64 only, and ShellSpec misfires under emulation.
FROM alpine:3.24
RUN apk add --no-cache bash git jq shellspec yq
WORKDIR /work
ENTRYPOINT ["shellspec"]
