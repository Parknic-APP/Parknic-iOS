#!/usr/bin/env python3
"""디자인 원본(docs/design/source/Critter.dc.html, ParkBadge.dc.html)의 스케치 룩을 SVG 에셋으로 옮긴다.

임시 에셋 생성기다. 최종 손그림 에셋이 나오면 같은 이름(character-N, badge-<type>, login-hero)으로
Assets.xcassets의 imageset 파일만 교체하면 되고, 이 스크립트는 지워도 된다.

    python3 tools/generate_art.py
"""
import json
import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Parknic/Resources/Assets.xcassets"
INK = "#2B2620"
BW = 3.2   # 스케치 룩 외곽선(크기 100 기준)
LW = 3.5   # 눈·입 선


def f(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def expand(vals):
    if len(vals) == 1:
        return vals * 4
    if len(vals) == 2:
        return [vals[0], vals[1], vals[0], vals[1]]
    if len(vals) == 3:
        return [vals[0], vals[1], vals[2], vals[1]]
    return vals


def parse_radius(css):
    """CSS border-radius('a b c d / e f g h')를 모서리별 (rx, ry) 비율(0~1) 4개로 바꾼다."""
    parts = css.split("/")
    hs = expand([float(v.strip("%")) / 100 for v in parts[0].split()])
    vs = expand([float(v.strip("%")) / 100 for v in parts[1].split()]) if len(parts) > 1 else hs
    return list(zip(hs, vs))


def rrect_path(x, y, w, h, radius):
    (tlx, tly), (trx, try_), (brx, bry), (blx, bly) = [(rx * w, ry * h) for rx, ry in radius]

    def corner(rx, ry, px, py):
        # 반지름 0인 호는 CoreSVG가 거부하므로 직선으로 잇는다.
        return f"A{f(rx)} {f(ry)} 0 0 1 {f(px)} {f(py)}" if rx > 0 and ry > 0 else f"L{f(px)} {f(py)}"

    return (
        f"M{f(x + tlx)} {f(y)}H{f(x + w - trx)}{corner(trx, try_, x + w, y + try_)}"
        f"V{f(y + h - bry)}{corner(brx, bry, x + w - brx, y + h)}"
        f"H{f(x + blx)}{corner(blx, bly, x, y + h - bly)}"
        f"V{f(y + tly)}{corner(tlx, tly, x + tlx, y)}Z"
    )


def polygon_path(x, y, w, h, points):
    return "M" + "L".join(f"{f(x + px * w)} {f(y + py * h)}" for px, py in points) + "Z"


def shape(x, y, w, h, fill, radius=None, points=None, rotate=0, stroke=None, sw=0):
    d = polygon_path(x, y, w, h, points) if points else rrect_path(x, y, w, h, parse_radius(radius or "0%"))
    attrs = f'd="{d}" fill="{fill}"'
    if stroke:
        attrs += f' stroke="{stroke}" stroke-width="{f(sw)}" stroke-linejoin="round"'
    if rotate:
        attrs += f' transform="rotate({rotate} {f(x + w / 2)} {f(y + h / 2)})"'
    return f"<path {attrs}/>"


def smile(x, y, w, h, color, up=False):
    """border-bottom(또는 border-top)만 있는 반원 선."""
    sweep = 1 if up else 0
    return (f'<path d="M{f(x)} {f(y + h / 2)}A{f(w / 2)} {f(h / 2)} 0 0 {sweep} {f(x + w)} {f(y + h / 2)}" '
            f'fill="none" stroke="{color}" stroke-width="{LW}" stroke-linecap="round"/>')


# ── 캐릭터 ──────────────────────────────────────────────────────────────────

PAL = {
    "cheese": dict(kind="cat", c="#F5B45E", d="#DB913A", inner="#FFC9B8", stripes="#D98A33"),
    "black": dict(kind="cat", c="#3B3936", d="#262422", inner="#C98A86", eyeRing="#E4EE8A"),
    "calico": dict(kind="cat", c="#FBF5EE", d="#E4DACD", inner="#F7BDB4",
                   patches=[(16, 20, 32, 30, "#F0A452", "60% 40% 55% 45%"), (56, 18, 30, 26, "#3B3936", "45% 60% 40% 55%")]),
    "tuxedo": dict(kind="cat", c="#33363A", d="#222427", inner="#C98A86", mask="#FFFFFF"),
    "shiba": dict(kind="dog", ears="tri", c="#E39A4C", d="#C47A30", inner="#FFF1DE", cheeks="#FFF4E4", brows=True),
    "maltese": dict(kind="dog", ears="flop", c="#FFFFFF", d="#E3DDD4", ec="#F1EAE0", bow="#FF8FA3"),
    "beagle": dict(kind="dog", ears="long", c="#D9A066", d="#B98245", ec="#8E5B32", blaze="#FFFFFF"),
    "corgi": dict(kind="dog", ears="big", c="#F0A04B", d="#D3832F", inner="#FFE3C9", blaze="#FFFFFF"),
}
TRI = [(0.5, 0), (1, 1), (0, 1)]


def critter(animal, mood="happy"):
    """100×100 좌표계의 스케치 룩 캐릭터(<g>)."""
    P = PAL[animal]
    out = []
    ears = "cat" if P["kind"] == "cat" else P["ears"]
    if ears in ("cat", "tri", "big"):
        big = ears == "big"
        L = (4, -8, 36, 48) if big else (10, 2, 32, 36)
        R = (60, -8, 36, 48) if big else (58, 2, 32, 36)
        for (bx, by, bw, bh), r in ((L, -14), (R, 14)):
            out.append(shape(bx - 2, by - 3, bw + 4, bh + 5, INK, points=TRI, rotate=r))
            out.append(shape(bx, by, bw, bh, P["c"], points=TRI, rotate=r))
            if P.get("inner"):
                out.append(shape(bx + bw * .27, by + bh * .3, bw * .46, bh * .5, P["inner"], points=TRI, rotate=r))
    out.append(shape(7, 14, 86, 84, P["c"], radius="50% 50% 46% 46% / 54% 54% 46% 46%", stroke=INK, sw=BW))
    for (l, t, w, h, c, r) in P.get("patches", []):
        out.append(shape(l, t, w, h, c, radius=r))
    if P.get("stripes"):
        for (l, t, w, h) in ((44, 17, 4, 10), (49, 16, 4, 12), (54, 17, 4, 10)):
            out.append(shape(l, t, w, h, P["stripes"], radius="2%"))
    if P.get("mask"):
        out.append(shape(20, 42, 60, 52, P["mask"], radius="50% 50% 46% 46% / 60% 60% 40% 40%"))
    if P.get("cheeks"):
        out.append(shape(14, 52, 40, 40, P["cheeks"], radius="50%"))
        out.append(shape(46, 52, 40, 40, P["cheeks"], radius="50%"))
    if P.get("blaze"):
        out.append(shape(44, 18, 12, 40, P["blaze"], radius="50% 50% 50% 50% / 15% 15% 50% 50%"))
        out.append(shape(27, 50, 46, 42, P["blaze"], radius="50%"))
    if P.get("bow"):
        out.append(shape(58, 8, 12, 12, P["bow"], points=[(0, 0), (1, .5), (0, 1)]))
        out.append(shape(70, 8, 12, 12, P["bow"], points=[(1, 0), (0, .5), (1, 1)]))
        out.append(shape(67, 11, 5, 6, "#E8607A", radius="50%"))
    if ears == "flop":
        out.append(shape(-2, 30, 28, 44, P["ec"], radius="50%", rotate=16, stroke=INK, sw=BW))
        out.append(shape(74, 30, 28, 44, P["ec"], radius="50%", rotate=-16, stroke=INK, sw=BW))
    if ears == "long":
        r = "50% 50% 45% 45%"
        out.append(shape(-4, 26, 26, 56, P["ec"], radius=r, rotate=12, stroke=INK, sw=BW))
        out.append(shape(78, 26, 26, 56, P["ec"], radius=r, rotate=-12, stroke=INK, sw=BW))
    eye_top = 46
    ring = P.get("eyeRing")
    line_color = "#E4EE8A" if ring else INK
    for i, x in enumerate((31, 61)):
        if P.get("brows"):
            out.append(shape(x + 1, eye_top - 8, 7, 4, "#FFF4E4", radius="50%"))
        if mood == "sleep":
            out.append(smile(x - 2, eye_top + 3, 12, 5, line_color))
            continue
        if ring:
            out.append(shape(x - 2.5, eye_top - 2.5, 13, 15, ring, radius="50%"))
        out.append(shape(x, eye_top, 8, 10, INK, radius="50%"))
        out.append(shape(x + 4, eye_top + 1.5, 2.6, 3, "#fff", radius="50%"))
        if mood == "sad":
            rot = 16 if i else -16
            out.append(f'<path d="M{f(x - 3)} {f(eye_top - 7)}h13" stroke="{line_color}" stroke-width="{LW}" '
                       f'stroke-linecap="round" transform="rotate({rot} {f(x + 3.5)} {f(eye_top - 7)})"/>')
    blush = ".3" if mood == "sad" else ".5"
    out.append(f'<g opacity="{blush}">{shape(16, 60, 14, 8, "#FF9C8A", radius="50%")}'
               f'{shape(70, 60, 14, 8, "#FF9C8A", radius="50%")}</g>')
    mouth = "#E4EE8A" if ring or (P["c"] == "#33363A") else INK
    if P["kind"] == "cat":
        out.append(shape(45.5, 57, 9, 6, "#FF8FA0", points=[(0, 0), (1, 0), (.5, 1)]))
        if mood == "sad":
            out.append(smile(43, 66, 14, 6, mouth, up=True))
        else:
            out.append(smile(40.5, 60, 10, 6, mouth))
            out.append(smile(49.5, 60, 10, 6, mouth))
    else:
        out.append(shape(43, 55, 14, 9, INK, radius="50% 50% 45% 45% / 40% 40% 60% 60%"))
        if mood == "sad":
            out.append(smile(43, 67, 14, 6, INK, up=True))
        else:
            out.append(shape(49.2, 63, 1.6, 5, INK))
            out.append(smile(41, 63, 10, 7, INK))
            out.append(smile(49, 63, 10, 7, INK))
            if mood == "happy":
                out.append(shape(46, 69, 8, 8, "#FF8C8C", radius="0% 0% 50% 50%"))
    return '<g transform="rotate(-3 50 50)">' + "".join(out) + "</g>"


def character_svg(animal, mood="happy"):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 124 116" width="248" height="232">'
            f'<g transform="translate(12 12)">{critter(animal, mood)}</g></svg>')


# ── 배지 ────────────────────────────────────────────────────────────────────

ICON = {
    "NEIGHBORHOOD": "M5 19c0-8 6-14 14-14 0 8-6 14-14 14z M5 19l7-7",
    "CHILDREN": "M12 3l2.6 5.6 6.1.7-4.5 4.1 1.2 6-5.4-3-5.4 3 1.2-6-4.5-4.1 6.1-.7z",
    "SMALL": "M12 21v-8 M12 13c0-4-3-7-7-7 0 4 3 7 7 7z M12 11c0-4 3-7 7-7 0 4-3 7-7 7z",
    "SPORTS": "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18z M12 3c-3.5 4-3.5 14 0 18 M12 3c3.5 4 3.5 14 0 18 M3 12h18",
    "WATERFRONT": "M3 8c2-2 4-2 6 0s4 2 6 0 4-2 6 0 M3 13c2-2 4-2 6 0s4 2 6 0 4-2 6 0 M3 18c2-2 4-2 6 0s4 2 6 0 4-2 6 0",
    "CULTURE": "M9 18V6l10-2v12 M9 18a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0z M19 16a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0z",
    "HISTORY": "M3 8h18 M5 4.5h14 M6 8v12 M18 8v12 M10 20v-6h4v6 M3 20h18",
}
SCALLOP = [(.5 + (.44 if i % 2 else .5) * math.cos(i / 28 * math.tau),
            .5 + (.44 if i % 2 else .5) * math.sin(i / 28 * math.tau)) for i in range(28)]
BADGE = {
    "NEIGHBORHOOD": dict(c="#34B36B", radius="50%"),
    "CHILDREN": dict(c="#FFB627", radius="32%"),
    "SMALL": dict(c="#F58BA6", points=SCALLOP),
    "SPORTS": dict(c="#5C7CF0", points=[(.25, .04), (.75, .04), (1, .5), (.75, .96), (.25, .96), (0, .5)]),
    "WATERFRONT": dict(c="#4FB3E8", radius="50% 50% 50% 50% / 58% 58% 42% 42%"),
    "CULTURE": dict(c="#A57FE6", points=[(.3, 0), (.7, 0), (1, .3), (1, .7), (.7, 1), (.3, 1), (0, .7), (0, .3)]),
    "HISTORY": dict(c="#C9824F", radius="22% 22% 50% 50% / 16% 16% 58% 58%"),
    "ACHIEVEMENT": dict(c="#FFC533", radius="50%"),  # 아이콘 없이 앱에서 글자를 얹는다
}
LOCKED_FILL = "#F1EBDD"
LOCKED_ICON = "#A79C8C"


def badge_svg(kind, locked=False):
    t = BADGE[kind]
    kw = dict(radius=t.get("radius"), points=t.get("points"))
    body = (
        shape(2.8, 4.2, 100, 100, INK, **kw)
        + shape(0, 0, 100, 100, INK, **kw)
        + shape(6, 6, 88, 88, LOCKED_FILL if locked else t["c"], **kw)
    )
    if kind in ICON:
        body += (f'<g transform="translate(28 28) scale({44 / 24:.4f})"><path d="{ICON[kind]}" fill="none" '
                 f'stroke="{LOCKED_ICON if locked else INK}" stroke-width="2.2" stroke-linecap="round" '
                 f'stroke-linejoin="round"/></g>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 114 114" width="228" height="228">'
            f'<g transform="translate(6 6)"><g transform="rotate(-4 50 50)">{body}</g></g></svg>')


# ── 로그인 일러스트 ──────────────────────────────────────────────────────────

def place(animal, x, y, size, mood="happy"):
    return f'<g transform="translate({f(x)} {f(y)}) scale({size / 100:.4f})">{critter(animal, mood)}</g>'


def login_hero_svg():
    sun = (f'<circle cx="300" cy="62" r="30" fill="#FFD77A" stroke="{INK}" stroke-width="3"/>'
           f'<g stroke="{INK}" stroke-width="3" stroke-linecap="round">'
           '<path d="M300 14V4M348 62h10M334 28l7-7M266 28l-7-7M334 96l7 7"/></g>')
    cloud = (f'<path d="M30 112q4-22 26-20q10-16 30-6q18-6 24 12q10 4 8 14H34q-8 0-4-0z" fill="#fff" '
             f'stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>')
    back = (f'<path d="M-10 250Q90 200 190 232T410 214V330H-10Z" fill="#CDEBC4"/>'
            f'<path d="M-10 250Q90 200 190 232T410 214" fill="none" stroke="{INK}" stroke-width="3"/>')
    front = (f'<path d="M-10 290Q120 246 220 270T410 262V330H-10Z" fill="#9FDCB4"/>'
             f'<path d="M-10 290Q120 246 220 270T410 262" fill="none" stroke="{INK}" stroke-width="3"/>'
             f'<g stroke="{INK}" stroke-width="3" stroke-linecap="round" fill="none">'
             '<path d="M40 304l5-8l5 8M330 300l5-8l5 8"/></g>')
    critters = (place("maltese", 40, 168, 70) + place("calico", 292, 178, 62) + place("corgi", 350, 236, 34)
                + place("cheese", 132, 146, 130))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 393 330" width="393" height="330">'
            f'{sun}{cloud}{back}{critters}{front}</svg>')


# ── 카탈로그 쓰기 ────────────────────────────────────────────────────────────

def write_imageset(name, svg):
    folder = CATALOG / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{name}.svg").write_text(svg, encoding="utf-8")
    contents = {
        "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def main():
    animals = ["cheese", "black", "calico", "tuxedo", "shiba", "maltese", "beagle", "corgi"]  # 서버 캐릭터 ID 1~8 순서
    for i, animal in enumerate(animals, start=1):
        write_imageset(f"character-{i}", character_svg(animal))
    write_imageset("character-default", character_svg("cheese"))
    write_imageset("character-sad", character_svg("cheese", "sad"))
    for kind in BADGE:
        write_imageset(f"badge-{kind.lower()}", badge_svg(kind))
        write_imageset(f"badge-{kind.lower()}-locked", badge_svg(kind, locked=True))
    write_imageset("login-hero", login_hero_svg())
    print("생성 완료:", len(animals) + 2 + len(BADGE) * 2 + 1, "개")


if __name__ == "__main__":
    main()
