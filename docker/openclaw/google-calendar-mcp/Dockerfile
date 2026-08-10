# Google カレンダー MCP サーバ (@cocal/google-calendar-mcp)
#
# OpenClaw 本体とは別コンテナで動かす。エージェントはシェルを持つので、同居させると
# OAuth トークンのファイルをエージェント自身 (= プロンプトインジェクションの経路) から
# 読めてしまう。別コンテナにすると触れるのは MCP のツール面だけになる。
#
# 上流は「リポジトリを clone して build」を案内しているが、ここでは npm から
# バージョン固定で入れるだけの薄いイメージにしている。VM 上にソースツリーを
# 抱えずに済み、更新は下の ARG を上げるだけで完結する。
FROM node:22-bookworm-slim

# 上流のリリースに追従して上げる。
# https://www.npmjs.com/package/@cocal/google-calendar-mcp
ARG GCAL_MCP_VERSION=2.6.2

RUN npm install -g "@cocal/google-calendar-mcp@${GCAL_MCP_VERSION}" \
    && npm cache clean --force

# トークンの置き場。compose 側でホストのディレクトリを載せる。
# node ユーザ (uid 1000) が書き込むので所有者を合わせておく。
RUN install -d -o node -g node /data

USER node
WORKDIR /home/node

EXPOSE 3000

# slim イメージに curl は入っていないので Node の fetch で叩く。
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["google-calendar-mcp", "start"]
