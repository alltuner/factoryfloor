// Sprite sheet rendering engine for pixel art characters and office furniture.
// Each char_N.png is 112x96: 7 columns x 3 rows, each frame 16x32.

export type Direction = 'down' | 'up' | 'right' | 'left';

const FRAME_W = 16;
const FRAME_H = 32;
const SHEET_COLS = 7;

const DIRECTION_ROW: Record<Exclude<Direction, 'left'>, number> = {
  down: 0,
  up: 1,
  right: 2,
};

const PALETTE_COUNT = 6;

function assetPath(relative: string): string {
  return `assets/${relative}`;
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`Failed to load image: ${src}`));
    img.src = src;
  });
}

export class SpriteEngine {
  private charSheets: Map<number, HTMLImageElement> = new Map();
  private floorTile: HTMLImageElement | null = null;
  private deskImage: HTMLImageElement | null = null;
  private pcImage: HTMLImageElement | null = null;
  private loaded = false;

  async loadAll(): Promise<void> {
    if (this.loaded) return;

    const charPromises: Promise<void>[] = [];
    for (let i = 0; i < PALETTE_COUNT; i++) {
      charPromises.push(
        loadImage(assetPath(`characters/char_${i}.png`)).then((img) => {
          this.charSheets.set(i, img);
        }),
      );
    }

    const floorPromise = loadImage(assetPath('floors/floor_0.png')).then(
      (img) => {
        this.floorTile = img;
      },
    );

    const deskPromise = loadImage(assetPath('furniture/DESK_FRONT.png')).then(
      (img) => {
        this.deskImage = img;
      },
    );

    const pcPromise = loadImage(
      assetPath('furniture/PC_FRONT_ON_1.png'),
    ).then((img) => {
      this.pcImage = img;
    });

    await Promise.all([...charPromises, floorPromise, deskPromise, pcPromise]);
    this.loaded = true;
  }

  isLoaded(): boolean {
    return this.loaded;
  }

  getFloorTile(): HTMLImageElement | null {
    return this.floorTile;
  }

  getDeskImage(): HTMLImageElement | null {
    return this.deskImage;
  }

  getPcImage(): HTMLImageElement | null {
    return this.pcImage;
  }

  drawCharacter(
    ctx: CanvasRenderingContext2D,
    palette: number,
    direction: Direction,
    frameIndex: number,
    x: number,
    y: number,
    zoom: number,
  ): void {
    const sheet = this.charSheets.get(palette);
    if (!sheet) return;

    ctx.imageSmoothingEnabled = false;

    const flipH = direction === 'left';
    const row = DIRECTION_ROW[flipH ? 'right' : direction];
    const col = Math.min(frameIndex, SHEET_COLS - 1);
    const sx = col * FRAME_W;
    const sy = row * FRAME_H;
    const dw = FRAME_W * zoom;
    const dh = FRAME_H * zoom;

    if (flipH) {
      ctx.save();
      ctx.translate(x + dw, y);
      ctx.scale(-1, 1);
      ctx.drawImage(sheet, sx, sy, FRAME_W, FRAME_H, 0, 0, dw, dh);
      ctx.restore();
    } else {
      ctx.drawImage(sheet, sx, sy, FRAME_W, FRAME_H, x, y, dw, dh);
    }
  }

  drawFurniture(
    ctx: CanvasRenderingContext2D,
    image: HTMLImageElement,
    x: number,
    y: number,
    zoom: number,
  ): void {
    ctx.imageSmoothingEnabled = false;
    const dw = image.width * zoom;
    const dh = image.height * zoom;
    ctx.drawImage(image, x, y, dw, dh);
  }
}
