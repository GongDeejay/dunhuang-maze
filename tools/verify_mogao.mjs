// Verify compatibility entry: the retired pattern-gate preview is now the full cave chapter.
// URL=http://127.0.0.1:8067/ NODE_PATH=... node tools/verify_mogao.mjs
process.env.URL ||= 'http://127.0.0.1:8067/';
await import('./verify_cave_chapter.mjs');
