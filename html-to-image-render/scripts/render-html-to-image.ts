import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const API_URL = "https://html2image.hanfangyuan.cn/api/html2image";

type ImageType = "png" | "jpeg";

type RenderRequest = {
  html: string;
  image_type?: ImageType;
  device_scale_factor?: number;
  viewport_width?: number;
  viewport_height?: number;
  render_wait_ms?: number;
  element_id?: string;
  element_padding?: number;
};

type RenderResponse = {
  image_base64: string;
  image_type: ImageType;
  device_scale_factor: number;
  viewport_width: number;
  viewport_height: number;
  render_wait_ms: number;
  element_id: string | null;
  element_padding: number;
};

type CliOptions = {
  input: string;
  output: string;
  imageType?: ImageType;
  deviceScaleFactor?: number;
  viewportWidth?: number;
  viewportHeight?: number;
  renderWaitMs?: number;
  elementId?: string;
  elementPadding?: number;
};

function printHelp(): void {
  console.log(`Usage:
  render-html-to-image --input <file.html> --output <file.png|file.jpeg> [options]

Options:
  --input <path>                 Input HTML file path
  --output <path>                Output image file path
  --image-type <png|jpeg>        Image format
  --device-scale-factor <num>    Device pixel ratio
  --viewport-width <num>         Viewport width in px
  --viewport-height <num>        Viewport height in px
  --render-wait-ms <num>         Extra render wait time in ms
  --element-id <id>              Screenshot the specific element id
  --element-padding <num>        Padding around the target element (default: 0)
  --help                         Show this help
`);
}

function parseNumberArg(flag: string, value: string | undefined): number {
  if (!value) {
    throw new Error(`Missing value for ${flag}`);
  }

  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Invalid numeric value for ${flag}: ${value}`);
  }

  return parsed;
}

function parseArgs(argv: string[]): CliOptions {
  const options: Partial<CliOptions> = {};

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];

    if (arg === "--help") {
      printHelp();
      process.exit(0);
    }

    const next = argv[i + 1];

    switch (arg) {
      case "--input":
        options.input = next;
        i += 1;
        break;
      case "--output":
        options.output = next;
        i += 1;
        break;
      case "--image-type":
        if (next !== "png" && next !== "jpeg") {
          throw new Error(`Invalid --image-type: ${next ?? "<missing>"}`);
        }
        options.imageType = next;
        i += 1;
        break;
      case "--device-scale-factor":
        options.deviceScaleFactor = parseNumberArg(arg, next);
        i += 1;
        break;
      case "--viewport-width":
        options.viewportWidth = parseNumberArg(arg, next);
        i += 1;
        break;
      case "--viewport-height":
        options.viewportHeight = parseNumberArg(arg, next);
        i += 1;
        break;
      case "--render-wait-ms":
        options.renderWaitMs = parseNumberArg(arg, next);
        i += 1;
        break;
      case "--element-id":
        if (!next) {
          throw new Error("Missing value for --element-id");
        }
        options.elementId = next;
        i += 1;
        break;
      case "--element-padding":
        options.elementPadding = parseNumberArg(arg, next);
        i += 1;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!options.input) {
    throw new Error("Missing required --input");
  }

  if (!options.output) {
    throw new Error("Missing required --output");
  }

  return options as CliOptions;
}

async function renderHtmlToImage(options: CliOptions): Promise<void> {
  const html = await readFile(options.input, "utf8");

  const payload: RenderRequest = {
    html,
    image_type: options.imageType,
    device_scale_factor: options.deviceScaleFactor,
    viewport_width: options.viewportWidth,
    viewport_height: options.viewportHeight,
    render_wait_ms: options.renderWaitMs,
    element_id: options.elementId,
    element_padding: options.elementPadding ?? 0,
  };

  const response = await fetch(API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Render failed with ${response.status}: ${errorText}`);
  }

  const result = (await response.json()) as RenderResponse;

  if (!result.image_base64) {
    throw new Error("API response missing image_base64");
  }

  const imageBuffer = Buffer.from(result.image_base64, "base64");
  const outputDir = path.dirname(path.resolve(options.output));

  await mkdir(outputDir, { recursive: true });
  await writeFile(options.output, imageBuffer);

  console.log(`Saved ${result.image_type} image to ${path.resolve(options.output)}`);
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  await renderHtmlToImage(options);
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});
