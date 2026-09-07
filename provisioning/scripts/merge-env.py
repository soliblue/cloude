#!/usr/bin/env python3
import argparse
import os
import re
import stat
import tempfile
from collections import OrderedDict

KEY = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$")


def parse(path):
    values = OrderedDict()
    if not os.path.exists(path):
        return values
    with open(path, encoding="utf-8") as file:
        lines = file.readlines()
    index = 0
    while index < len(lines):
        match = KEY.match(lines[index].rstrip("\n"))
        if not match:
            index += 1
            continue
        name, raw = match.groups()
        if raw[:1] in ("'", '"'):
            quote = raw[0]
            value = raw[1:]
            while not value.endswith(quote) or (len(value[:-1]) - len(value[:-1].rstrip("\\"))) % 2 == 1:
                index += 1
                if index >= len(lines):
                    raise ValueError(f"unterminated quoted value: {name}")
                next_line = lines[index].rstrip("\n")
                if quote == '"' and value.endswith("\\"):
                    value = value[:-1] + next_line
                else:
                    value += "\n" + next_line
            value = value[:-1]
            if quote == '"':
                decoded = []
                cursor = 0
                escapes = {"\\": "\\", '"': '"', "`": "`", "$": "$"}
                while cursor < len(value):
                    if value[cursor] == "\\" and cursor + 1 < len(value) and value[cursor + 1] in escapes:
                        decoded.append(escapes[value[cursor + 1]])
                        cursor += 2
                    else:
                        decoded.append(value[cursor])
                        cursor += 1
                value = "".join(decoded)
        else:
            value = raw.rstrip()
        values[name] = value
        index += 1
    return values


def render(name, value):
    if value and all(character not in value for character in " \t\r\n'\"\\#"):
        return f"{name}={value}\n"
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'{name}="{escaped}"\n'


def write(existing, generated, output):
    values = parse(existing)
    values.update(parse(generated))
    parent = os.path.dirname(output) or "."
    fd, temporary = tempfile.mkstemp(prefix=".merged-env-", dir=parent, text=True)
    try:
        os.fchmod(fd, stat.S_IRUSR | stat.S_IWUSR)
        with os.fdopen(fd, "w", encoding="utf-8") as file:
            for name, value in values.items():
                file.write(render(name, value))
        os.replace(temporary, output)
        os.chmod(output, stat.S_IRUSR | stat.S_IWUSR)
    except BaseException:
        if os.path.exists(temporary):
            os.unlink(temporary)
        raise


parser = argparse.ArgumentParser()
parser.add_argument("--get")
parser.add_argument("existing")
parser.add_argument("generated", nargs="?")
parser.add_argument("output", nargs="?")
args = parser.parse_args()
if args.get:
    value = parse(args.existing).get(args.get, "")
    print(value, end="")
elif args.generated and args.output:
    write(args.existing, args.generated, args.output)
else:
    parser.error("provide --get KEY existing or existing generated output")
