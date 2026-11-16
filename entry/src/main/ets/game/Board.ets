import { cryptoFramework } from '@kit.CryptoArchitectureKit';

export const ROWS: number = 6;
export const COLS: number = 6;
export const SIZE: number = ROWS * COLS;
export const TYPES: number = 6;
export const EMPTY: number = -1;
export const BLOCKED: number = -2;

const ROW_START: number[] = [1, 0, 0, 0, 0, 1];
const ROW_END: number[] = [4, 5, 5, 5, 5, 4];
const POOL_SIZE: number = 256;
const BYTE_LIMIT: number = 256 - (256 % TYPES);

const random: cryptoFramework.Random = cryptoFramework.createRandom();
let pool: Uint8Array = new Uint8Array(0);
let cursor: number = 0;

export class MatchResult {
  cleared: boolean[] = [];
  count: number = 0;
  score: number = 0;
}

export class FallResult {
  board: number[] = [];
  fall: number[] = [];
}

export function index(r: number, c: number): number {
  return r * COLS + c;
}

export function rowOf(i: number): number {
  return Math.floor(i / COLS);
}

export function colOf(i: number): number {
  return i % COLS;
}

export function playable(i: number): boolean {
  const r: number = rowOf(i);
  const c: number = colOf(i);
  return c >= ROW_START[r] && c <= ROW_END[r];
}

function topOf(c: number): number {
  for (let r = 0; r < ROWS; r++) {
    if (playable(index(r, c))) {
      return r;
    }
  }
  return ROWS;
}

function bottomOf(c: number): number {
  for (let r = ROWS - 1; r >= 0; r--) {
    if (playable(index(r, c))) {
      return r;
    }
  }
  return -1;
}

function isTile(value: number): boolean {
  return value >= 0;
}

function nextByte(): number {
  if (cursor >= pool.length) {
    pool = random.generateRandomSync(POOL_SIZE).data;
    cursor = 0;
  }
  const value: number = pool[cursor];
  cursor++;
  return value;
}

function randType(): number {
  let value: number = nextByte();
  while (value >= BYTE_LIMIT) {
    value = nextByte();
  }
  return value % TYPES;
}

function runScore(n: number): number {
  if (n === 3) {
    return 60;
  }
  if (n === 4) {
    return 150;
  }
  if (n === 5) {
    return 300;
  }
  return 500;
}

function emptyFlags(): boolean[] {
  const flags: boolean[] = [];
  for (let i = 0; i < SIZE; i++) {
    flags.push(false);
  }
  return flags;
}

export function findMatches(board: number[]): MatchResult {
  const result = new MatchResult();
  const flags: boolean[] = emptyFlags();
  let score = 0;

  for (let r = 0; r < ROWS; r++) {
    let run = 1;
    for (let c = 1; c <= COLS; c++) {
      const prev = board[index(r, c - 1)];
      const same = c < COLS && isTile(prev) && board[index(r, c)] === prev;
      if (same) {
        run++;
      } else {
        if (run >= 3) {
          for (let k = c - run; k < c; k++) {
            flags[index(r, k)] = true;
          }
          score += runScore(run);
        }
        run = 1;
      }
    }
  }

  for (let c = 0; c < COLS; c++) {
    let run = 1;
    for (let r = 1; r <= ROWS; r++) {
      const prev = board[index(r - 1, c)];
      const same = r < ROWS && isTile(prev) && board[index(r, c)] === prev;
      if (same) {
        run++;
      } else {
        if (run >= 3) {
          for (let k = r - run; k < r; k++) {
            flags[index(k, c)] = true;
          }
          score += runScore(run);
        }
        run = 1;
      }
    }
  }

  let count = 0;
  for (let i = 0; i < SIZE; i++) {
    if (flags[i]) {
      count++;
    }
  }

  result.cleared = flags;
  result.count = count;
  result.score = score;
  return result;
}

export function areNeighbours(a: number, b: number): boolean {
  if (!playable(a) || !playable(b)) {
    return false;
  }
  const dr = Math.abs(rowOf(a) - rowOf(b));
  const dc = Math.abs(colOf(a) - colOf(b));
  return dr + dc === 1;
}

export function swapped(board: number[], a: number, b: number): number[] {
  const next: number[] = board.slice();
  const tmp: number = next[a];
  next[a] = next[b];
  next[b] = tmp;
  return next;
}

export function hasMove(board: number[]): boolean {
  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      const i = index(r, c);
      if (!playable(i)) {
        continue;
      }
      if (c + 1 < COLS) {
        const right = index(r, c + 1);
        if (playable(right) && findMatches(swapped(board, i, right)).count > 0) {
          return true;
        }
      }
      if (r + 1 < ROWS) {
        const down = index(r + 1, c);
        if (playable(down) && findMatches(swapped(board, i, down)).count > 0) {
          return true;
        }
      }
    }
  }
  return false;
}

export function createBoard(): number[] {
  let board: number[] = [];
  for (let attempt = 0; attempt < 60; attempt++) {
    board = [];
    for (let i = 0; i < SIZE; i++) {
      board.push(playable(i) ? randType() : BLOCKED);
    }
    for (let pass = 0; pass < 40; pass++) {
      const found = findMatches(board);
      if (found.count === 0) {
        break;
      }
      for (let i = 0; i < SIZE; i++) {
        if (found.cleared[i]) {
          board[i] = randType();
        }
      }
    }
    if (findMatches(board).count === 0 && hasMove(board)) {
      return board;
    }
  }
  return board;
}

export function applyGravity(board: number[]): FallResult {
  const next: number[] = board.slice();
  const fall: number[] = [];
  for (let i = 0; i < SIZE; i++) {
    fall.push(0);
  }

  for (let c = 0; c < COLS; c++) {
    const top: number = topOf(c);
    const bottom: number = bottomOf(c);
    if (bottom < top) {
      continue;
    }
    let write = bottom;
    for (let r = bottom; r >= top; r--) {
      const value = next[index(r, c)];
      if (value !== EMPTY) {
        if (write !== r) {
          next[index(write, c)] = value;
          next[index(r, c)] = EMPTY;
          fall[index(write, c)] = write - r;
        }
        write--;
      }
    }
    const spawned = write - top + 1;
    for (let r = write; r >= top; r--) {
      next[index(r, c)] = randType();
      fall[index(r, c)] = spawned;
    }
  }

  const result = new FallResult();
  result.board = next;
  result.fall = fall;
  return result;
}
