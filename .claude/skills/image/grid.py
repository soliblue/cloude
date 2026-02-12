#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path
from PIL import Image, ImageDraw


def create_template(grid, cell_size, border, output):
    rows, cols = grid
    width = cols * cell_size + (cols + 1) * border
    height = rows * cell_size + (rows + 1) * border
    img = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(img)

    for i in range(cols + 1):
        x = i * (cell_size + border)
        draw.rectangle([x, 0, x + border - 1, height - 1], fill="black")

    for j in range(rows + 1):
        y = j * (cell_size + border)
        draw.rectangle([0, y, width - 1, y + border - 1], fill="black")

    img.save(output, "PNG")
    print(f"Template: {output} ({width}x{height}, {rows}x{cols} grid, {border}px borders)")
    return output


def split_image(input_path, grid, border, output_dir, prefix):
    rows, cols = grid
    img = Image.open(input_path)
    w, h = img.size

    cell_w = (w - (cols + 1) * border) // cols
    cell_h = (h - (rows + 1) * border) // rows

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    paths = []
    n = 1
    for r in range(rows):
        for c in range(cols):
            x = border + c * (cell_w + border)
            y = border + r * (cell_h + border)
            cell = img.crop((x, y, x + cell_w, y + cell_h))
            out = output_dir / f"{prefix}-{n}.png"
            cell.save(out, "PNG")
            paths.append(str(out))
            n += 1

    for p in paths:
        print(p)
    return paths


def parse_grid(s):
    parts = s.lower().split("x")
    if len(parts) != 2:
        raise argparse.ArgumentTypeError(f"Grid must be ROWSxCOLS (e.g. 2x2), got: {s}")
    return int(parts[0]), int(parts[1])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command")

    c = sub.add_parser("create")
    c.add_argument("--grid", type=parse_grid, default="2x2")
    c.add_argument("--cell-size", type=int, default=1024)
    c.add_argument("--border", type=int, default=6)
    c.add_argument("--output", required=True)

    s = sub.add_parser("split")
    s.add_argument("--input", required=True)
    s.add_argument("--grid", type=parse_grid, default="2x2")
    s.add_argument("--border", type=int, default=6)
    s.add_argument("--output-dir", required=True)
    s.add_argument("--prefix", default="image")

    args = parser.parse_args()

    if args.command == "create":
        create_template(args.grid, args.cell_size, args.border, args.output)
    elif args.command == "split":
        split_image(args.input, args.grid, args.border, args.output_dir, args.prefix)
    else:
        parser.print_help()
        sys.exit(1)
