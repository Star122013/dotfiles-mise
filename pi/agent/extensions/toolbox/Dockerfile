# pi-toolbox:slim - 轻量基础 (typst+绘图, ~300MB)
FROM alpine:latest
RUN apk add --no-cache \
    typst bash git ripgrep curl wget ca-certificates \
    graphviz pandoc-cli \
    imagemagick ghostscript librsvg \
    font-noto font-noto-cjk font-noto-emoji \
  && rm -rf /var/cache/apk/*
WORKDIR /workspace
CMD ["sh"]
