# Murmur — Colors

Six values. Warm paper, deep ink, one mute red for recording, one quiet green for confirmation, and two greys for hierarchy. The palette is built for editorial restraint — there are no gradients, no neon, no second accent fighting for attention.

## The palette

| Name           | Hex       | Used for                                                            |
|----------------|-----------|---------------------------------------------------------------------|
| Paper          | `#F8F4EE` | Primary background. App canvas, marketing surfaces.                 |
| Card           | `#FFFBF5` | Card surfaces, icon plate, modal sheets — one step lighter than paper. |
| Ink            | `#1A1A1A` | Primary text, the wordmark, glyph fills. Not pure black.            |
| Mute red       | `#C2362F` | Recording indicator, the decay dot in the icon, accent rules.       |
| Success green  | `#3F7A4A` | Successful transcription. Confirmation states only.                 |
| Muted gray     | `#7A7670` | Secondary text, metadata, dividers (use at 18px+ regular).          |

## Pairing rules

- Ink on paper, ink on card — always safe. Reads at 14.9:1, well above WCAG AAA.
- Mute red on card or paper — safe for accents and headings 16px and up.
- **Never** place mute red text on ink. The contrast fails and the color reads as alarming.
- Success green is a confirmation color only. It must never share a moment of UI with mute red — the two states are mutually exclusive.
- Muted gray at body weight needs to darken to `#5E5B57` below 18px.

## In practice

The landing page uses a slightly warmer paper (`#EFE9DD`) for print-newspaper feel. The app itself uses the values above. When writing about Murmur, the safe palette is **Paper, Ink, Mute red** — those three carry the brand on their own.
