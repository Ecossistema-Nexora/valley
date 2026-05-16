<!--
PROPOSITO: Definir o DESIGN.md enviado ao Stitch para o projeto novo Valley ERP.
CONTEXTO: Base visual v060 para projeto novo criado no Stitch a partir da especificacao mestre e da logomarca Valley.
REGRAS: Preservar marca Valley, evitar UI monocromatica, manter ERP denso e entregar superficies responsivas Web + Android.
-->

# Valley ERP Design System v060

## Brand

- Product name: Valley.
- Assistant name: Helena.
- Currency/token name: V-Coin.
- Official logo reference: `assets/brand/logo-valley-official.png`.
- Preserve the logo proportions; do not crop the mountain, star, or Valley signature.
- Small surfaces may use the logo as a square mark with controlled 8px radius and enough contrast.

## Palette

- Night: `#07051F`
- Cosmic: `#151047`
- Violet: `#6F2CFF`
- Lilac: `#BB8CFF`
- Cyan: `#20C8F3`
- Snow: `#FFFFFF`
- Work Surface: `#F6F8FB`
- Ink: `#15151D`
- Muted Ink: `#667085`
- Line: `#D9DEE8`
- Success Green: `#1E8A5A`
- Courier Green: `#0F7A4A`
- Warning Amber: `#C98205`
- Critical Red: `#D04437`

Use Night, Snow and Ink as the base. Violet and Cyan are brand accents, not the whole interface. Use green primarily for courier/logistics surfaces, route status and delivery completion states.

## Typography

- Preferred family: Inter or Google Sans.
- Letter spacing: `0`.
- Dense ERP panels should use compact headings, not hero-scale headings.
- Tables, filters and operational surfaces must prioritize scanning and comparison.

## Shape And Spacing

- Default radius: `8px`.
- Compact controls: 36px to 44px height.
- Icon buttons for common tools.
- Cards only for repeated items, modals or framed tools.
- No decorative orbs, bokeh blobs or nested cards.

## Interaction

- Every primary button must execute a real command or open a real form/state.
- Required states: empty, loading, error, success, saving, saved and audit/history.
- Destructive commands require soft delete, suspension or auditable cancellation.
- Helena should appear as contextual assistance with subtle glow or inline guidance, never an invasive popup.

## Product Surfaces

- Admin: dense control-plane workspace, total module governance, rules, APIs, users, tokens, audit and God Mode.
- Merchant: Valley ERP operational surfaces for onboarding, products, stock, orders, labels, finance, scheduling, integrations and branches.
- Customer Android: modular MVP home, Stock, Marketplace, checkout, purchases, favorites, profile and support chats.
- Courier Android: green logistics theme, pickup requests, delivery status, incidents, customer private rating, commissions and blocked addresses.

## Data Rules

- Every screen must respect `tenant_id`.
- Branch-scoped screens must include `branch_id` or `branch_key`.
- Do not expose raw cost, markup formulas or margin to end customers.
- Financial, audit, commission and delivery event trails are append-only in the UI model.
- Comments from courier ratings below 4 stars are private to Valley admin and the merchant associated with the delivery.
