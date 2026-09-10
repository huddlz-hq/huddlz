# Favicon mark

The filled `h` outline in `HuddlzWeb.OgImage.mark_svg/1` comes from
[Inter](https://github.com/google/fonts/tree/main/ofl/inter), weight 700,
optical size 14. Its SIL Open Font License is retained in `Inter-OFL.txt`.

The drawing preserves the site card's mark: a 168 px tile with a 40 px corner
radius, a centered 112 px glyph, and a baseline 121 px below the tile's top.
All coordinates are scaled to the favicon's 512 px viewBox. The glyph was
instantiated with fontTools and converted with SVGPathPen, translating from
font coordinates to SVG coordinates. No font is needed at runtime.

`test/fixtures/brand-mark.png` is the visual reference rendered from that
outline. Keep it independent of `mix huddlz.icons`: regenerating shipped icons
must not silently update the expected appearance. Review the reference visually
before replacing it when the brand changes.
