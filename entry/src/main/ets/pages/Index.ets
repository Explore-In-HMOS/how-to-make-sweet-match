import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  applyGravity,
  areNeighbours,
  colOf,
  COLS,
  createBoard,
  EMPTY,
  FallResult,
  findMatches,
  hasMove,
  index,
  MatchResult,
  playable,
  ROWS,
  rowOf,
  SIZE,
  swapped
} from '../game/Board';

const CELL: number = 25;
const GAP: number = 4;
const STEP: number = CELL + GAP;
const BOARD: number = COLS * CELL + (COLS - 1) * GAP;
const CANDY: number = 20;
const TOTAL_MOVES: number = 20;
const TARGET: number = 2000;
const RING: number = 4;
const SECTION: number = 7;

const BODY_COLORS: string[] = ['#FF3B63', '#FF8A1F', '#FFD23F', '#2FD46A', '#2E9BFF', '#B36BFF'];
const GLOW_COLORS: string[] = ['#66FF3B63', '#66FF8A1F', '#66FFD23F', '#662FD46A', '#662E9BFF', '#66B36BFF'];

@Entry
@Component
struct Index {
  @State board: number[] = [];
  @State scales: number[] = [];
  @State offsets: number[] = [];
  @State selected: number = -1;
  @State score: number = 0;
  @State moves: number = TOTAL_MOVES;
  @State combo: number = 0;
  @State busy: boolean = false;
  @State finished: boolean = false;
  @State won: boolean = false;
  private rows: number[] = [];
  private cols: number[] = [];
  private timers: number[] = [];

  aboutToAppear(): void {
    for (let r = 0; r < ROWS; r++) {
      this.rows.push(r);
    }
    for (let c = 0; c < COLS; c++) {
      this.cols.push(c);
    }
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTimers();
  }

  reset(): void {
    this.stopTimers();
    const scales: number[] = [];
    const offsets: number[] = [];
    for (let i = 0; i < SIZE; i++) {
      scales.push(1);
      offsets.push(0);
    }
    this.board = createBoard();
    this.scales = scales;
    this.offsets = offsets;
    this.selected = -1;
    this.score = 0;
    this.moves = TOTAL_MOVES;
    this.combo = 0;
    this.busy = false;
    this.finished = false;
    this.won = false;
  }

  private later(action: () => void, delay: number): void {
    this.timers.push(setTimeout(action, delay));
  }

  private stopTimers(): void {
    for (let i = 0; i < this.timers.length; i++) {
      clearTimeout(this.timers[i]);
    }
    this.timers = [];
  }

  private buzz(duration: number): void {
    const effect: vibrator.VibrateTime = { type: 'time', duration: duration };
    const attribute: vibrator.VibrateAttribute = { id: 0, usage: 'physicalFeedback' };
    try {
      vibrator.startVibration(effect, attribute, (err: BusinessError) => {
      });
    } catch (err) {
    }
  }

  private onTap(i: number): void {
    if (this.busy || this.finished || !playable(i) || this.board[i] === EMPTY) {
      return;
    }
    if (this.selected === -1) {
      this.selected = i;
      this.buzz(10);
      return;
    }
    if (this.selected === i) {
      this.selected = -1;
      return;
    }
    if (areNeighbours(this.selected, i)) {
      const from: number = this.selected;
      this.selected = -1;
      this.trySwap(from, i);
    } else {
      this.selected = i;
    }
  }

  private onSwipe(i: number, dx: number, dy: number): void {
    if (this.busy || this.finished || !playable(i) || this.board[i] === EMPTY) {
      return;
    }
    let r: number = rowOf(i);
    let c: number = colOf(i);
    if (Math.abs(dx) > Math.abs(dy)) {
      c = dx > 0 ? c + 1 : c - 1;
    } else {
      r = dy > 0 ? r + 1 : r - 1;
    }
    if (r < 0 || r >= ROWS || c < 0 || c >= COLS) {
      return;
    }
    const target: number = index(r, c);
    if (!playable(target)) {
      return;
    }
    this.selected = -1;
    this.trySwap(i, target);
  }

  private trySwap(a: number, b: number): void {
    this.busy = true;
    const candidate: number[] = swapped(this.board, a, b);
    this.board = candidate;
    if (findMatches(candidate).count === 0) {
      this.buzz(24);
      this.later(() => {
        this.board = swapped(this.board, a, b);
        this.busy = false;
      }, 220);
      return;
    }
    this.moves = this.moves - 1;
    this.combo = 0;
    this.later(() => {
      this.resolve();
    }, 130);
  }

  private resolve(): void {
    const found: MatchResult = findMatches(this.board);
    if (found.count === 0) {
      if (!hasMove(this.board)) {
        this.board = createBoard();
      }
      this.combo = 0;
      this.busy = false;
      this.checkEnd();
      return;
    }

    this.combo = this.combo + 1;
    this.score = this.score + found.score * this.combo;
    this.buzz(this.combo > 1 ? 30 : 16);

    this.getUIContext().animateTo({ duration: 150, curve: Curve.FastOutSlowIn }, () => {
      for (let i = 0; i < SIZE; i++) {
        if (found.cleared[i]) {
          this.scales[i] = 0;
        }
      }
    });

    this.later(() => {
      for (let i = 0; i < SIZE; i++) {
        if (found.cleared[i]) {
          this.board[i] = EMPTY;
          this.scales[i] = 1;
        }
      }
      const dropped: FallResult = applyGravity(this.board);
      this.board = dropped.board;
      for (let i = 0; i < SIZE; i++) {
        this.offsets[i] = -dropped.fall[i] * STEP;
      }
      this.getUIContext().animateTo({ duration: 240, curve: Curve.Friction }, () => {
        for (let i = 0; i < SIZE; i++) {
          this.offsets[i] = 0;
        }
      });
      this.later(() => {
        this.resolve();
      }, 250);
    }, 160);
  }

  private checkEnd(): void {
    if (this.score >= TARGET) {
      this.finished = true;
      this.won = true;
      this.buzz(80);
    } else if (this.moves <= 0) {
      this.finished = true;
      this.won = false;
      this.buzz(60);
    }
  }

  private bodyColor(t: number): string {
    return t < 0 ? '#00000000' : BODY_COLORS[t];
  }

  private glowColor(t: number): string {
    return t < 0 ? '#00000000' : GLOW_COLORS[t];
  }

  private slotColor(i: number): string {
    if (!playable(i)) {
      return '#00000000';
    }
    return this.selected === i ? '#2EFFFFFF' : '#0DFFFFFF';
  }

  private bodySize(t: number): number {
    const shape: number = t < 0 ? 0 : t % 3;
    if (shape === 0) {
      return CANDY;
    }
    if (shape === 1) {
      return CANDY - 2;
    }
    return CANDY - 5;
  }

  private bodyRadius(t: number): number {
    const shape: number = t < 0 ? 0 : t % 3;
    if (shape === 0) {
      return CANDY / 2;
    }
    if (shape === 1) {
      return 6;
    }
    return 4;
  }

  private bodyAngle(t: number): number {
    const shape: number = t < 0 ? 0 : t % 3;
    return shape === 2 ? 45 : 0;
  }

  @Builder
  Candy(i: number) {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(this.bodySize(this.board[i]))
        .height(this.bodySize(this.board[i]))
        .backgroundColor(this.bodyColor(this.board[i]))
        .borderRadius(this.bodyRadius(this.board[i]))
        .rotate({ angle: this.bodyAngle(this.board[i]) })
        .shadow({ radius: 6, color: this.glowColor(this.board[i]), offsetX: 0, offsetY: 0 })

      Circle()
        .width(5)
        .height(5)
        .fill('#4DFFFFFF')
        .offset({ x: -5, y: -5 })
    }
    .width(CELL)
    .height(CELL)
    .scale({ x: this.scales[i], y: this.scales[i] })
    .translate({ y: this.offsets[i] })
    .visibility(this.board[i] === EMPTY ? Visibility.Hidden : Visibility.Visible)
  }

  @Builder
  Slot(i: number) {
    Stack({ alignContent: Alignment.Center }) {
      if (playable(i)) {
        this.Candy(i)
      }
    }
    .width(CELL)
    .height(CELL)
    .borderRadius(8)
    .backgroundColor(this.slotColor(i))
    .borderWidth(this.selected === i ? 2 : 0)
    .borderColor('#FFFFFF')
    .onClick(() => {
      this.onTap(i);
    })
    .gesture(
      PanGesture({ distance: 8 })
        .onActionEnd((event: GestureEvent) => {
          this.onSwipe(i, event.offsetX, event.offsetY);
        })
    )
  }

  @Builder
  BoardView() {
    Column({ space: GAP }) {
      ForEach(this.rows, (r: number) => {
        Row({ space: GAP }) {
          ForEach(this.cols, (c: number) => {
            this.Slot(index(r, c))
          }, (c: number) => c.toString())
        }
      }, (r: number) => r.toString())
    }
    .width(BOARD)
    .height(BOARD + GAP)
  }

  @Builder
  Header() {
    Row({ space: 5 }) {
      Text('SCORE')
        .fontSize(8)
        .fontColor('#7A8496')
        .letterSpacing(1)
      Text(this.score.toString())
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
      if (this.combo > 1) {
        Text(`x${this.combo}`)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD23F')
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  Footer() {
    Row({ space: 5 }) {
      Text(this.moves.toString())
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.moves <= 3 ? '#FF3B63' : '#FFFFFF')
      Text('MOVES')
        .fontSize(8)
        .fontColor('#7A8496')
        .letterSpacing(1)
      Text('NEW')
        .fontSize(8)
        .letterSpacing(1)
        .fontColor('#9AA3B2')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .borderRadius(10)
        .backgroundColor('#1AFFFFFF')
        .onClick(() => {
          this.reset();
        })
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  Overlay() {
    Column({ space: 5 }) {
      Text(this.won ? 'LEVEL CLEAR' : 'OUT OF MOVES')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.won ? '#2FD46A' : '#FF3B63')
      Text(`${this.score} pts`)
        .fontSize(11)
        .fontColor('#FFFFFF')
      Text(`TARGET ${TARGET}`)
        .fontSize(8)
        .fontColor('#7A8496')
        .letterSpacing(1)
      Text('PLAY AGAIN')
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1)
        .fontColor('#05070E')
        .padding({ left: 16, right: 16, top: 7, bottom: 7 })
        .borderRadius(16)
        .backgroundColor('#FFD23F')
        .margin({ top: 6 })
        .onClick(() => {
          this.reset();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#D9000000')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Progress({ value: Math.min(this.score, TARGET), total: TARGET, type: ProgressType.Ring })
        .width('100%')
        .height('100%')
        .color('#FFD23F')
        .backgroundColor('#14FFFFFF')
        .style({ strokeWidth: RING })

      Column({ space: SECTION }) {
        this.Header()
        this.BoardView()
        this.Footer()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)

      if (this.finished) {
        this.Overlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#05070E')
  }
}
