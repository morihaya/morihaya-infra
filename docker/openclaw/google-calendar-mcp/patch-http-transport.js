#!/usr/bin/env node
//
// 上流バグの回避パッチ (@cocal/google-calendar-mcp の HTTP モード)
//
// ■ 症状
//   コンテナ起動後、MCP の POST は **1 回目だけ成功し、2 回目以降は必ず
//   HTTP 500 (本文なし)** になる。気づきにくい壊れ方をする:
//     - サーバは正常に起動し、トークンも読める
//     - /health は 200 を返し続けるので healthcheck は緑のまま
//     - アプリ側の catch が発火しないため、ログには何も出ない
//   OpenClaw からは "Streamable HTTP error: Error POSTing to endpoint:" と
//   だけ見える。initialize の次の tools/list で落ちるので、事実上使えない。
//
// ■ 原因
//   上流の src/transports/http.ts は connect() の中で
//   StreamableHTTPServerTransport を 1 個だけ生成し、全リクエストで
//   使い回している。MCP SDK はステートレスモード (sessionIdGenerator:
//   undefined) では **リクエストごとに新しい transport** を要求するため、
//   2 回目以降が SDK の内部で落ちる。
//
// ■ 対処
//   ディスパッチ箇所を、リクエストごとに transport を生成して繋ぐ形に
//   書き換える。透過的な差し替えなので上流の他の挙動には触れない。
//
//   ただし SDK は「1 つの Protocol に 1 つの transport」を強制しており、
//   閉じずに繋ぎ直すと次で弾かれる:
//
//     Already connected to a transport. Call close() before connecting to a
//     new transport, or use a separate Protocol instance per connection.
//
//   そのため **前の transport を閉じてから** 新しいものを繋ぐ。
//
//   ■ 制約: 逐次リクエストを前提にしている
//     並行リクエストが来ると、後発が先発の transport を閉じてしまう。
//     この用途 (OpenClaw 1 クライアントからの逐次呼び出し) では問題ない。
//     複数クライアントから同時に叩く構成にする場合はこの方式を見直すこと。
//     本来は上流が「リクエストごとに Server ごと作る」のが正しい。
//
// ■ 更新時の注意
//   アンカーが見つからなければ **build を失敗させる**。上流が直したり
//   構造を変えたりしたときに、パッチが黙って無効化されるのを防ぐため。
//   その場合はまず上流の修正状況を確認すること (直っていればこのファイルと
//   Dockerfile の COPY/RUN ごと削除できる)。

const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const globalRoot = execFileSync('npm', ['root', '-g'], { encoding: 'utf8' }).trim();
const target = path.join(globalRoot, '@cocal/google-calendar-mcp/build/index.js');

if (!fs.existsSync(target)) {
  console.error(`[patch] バンドルが見つからない: ${target}`);
  process.exit(1);
}

const source = fs.readFileSync(target, 'utf8');

// 単一の共有 transport を使っているディスパッチ箇所。
const anchor = /^([ \t]*)await transport\.handleRequest\(req, res\);[ \t]*$/gm;
const hits = source.match(anchor);

if (!hits) {
  console.error('[patch] アンカーが見つからない。上流の構造が変わった可能性がある。');
  console.error('[patch] 上流の修正状況を確認すること。直っていればこのパッチは不要。');
  process.exit(1);
}
if (hits.length !== 1) {
  console.error(`[patch] アンカーが一意でない (${hits.length} 箇所)。手で確認すること。`);
  process.exit(1);
}

// 念のため、パッチ対象の前提 (単一 transport の生成) が実在することも確かめる。
if (!source.includes('new StreamableHTTPServerTransport({')) {
  console.error('[patch] StreamableHTTPServerTransport の生成箇所が見つからない。');
  process.exit(1);
}

const patched = source.replace(anchor, (_match, indent) =>
  [
    `${indent}// [morihaya-infra] リクエストごとに transport を作り直す (上流バグ回避)`,
    `${indent}// SDK は 1 Protocol に 1 transport しか許さないので、先に前のものを閉じる。`,
    `${indent}const previousTransport = this.__perRequestTransport ?? transport;`,
    `${indent}try {`,
    `${indent}  await previousTransport.close();`,
    `${indent}} catch {}`,
    `${indent}const perRequestTransport = new StreamableHTTPServerTransport({`,
    `${indent}  sessionIdGenerator: void 0`,
    `${indent}});`,
    `${indent}this.__perRequestTransport = perRequestTransport;`,
    `${indent}await this.server.connect(perRequestTransport);`,
    `${indent}await perRequestTransport.handleRequest(req, res);`,
  ].join('\n'),
);

fs.writeFileSync(target, patched);
console.log(`[patch] 適用した: ${target}`);
