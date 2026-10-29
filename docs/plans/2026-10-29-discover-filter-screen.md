# Discover and category-filter screen

## Goal

Match the supplied 5.1-A food/snacks reference in the Discover tab. Category
buttons opened from Home must navigate to Discover and carry the selected
category into the screen. The same category controls remain usable on Discover.

## Layout

- Yellow search header at the top, with a compact white search field.
- Orange horizontal category rail with circular category artwork and a clear
  selected state.
- Light content sheet with rounded top corners, Popular sort control, and a
  working filter action.
- Wide product cards with landscape food photography, name, rating, price, and
  tap-through to product details.
- Shared bottom navigation with Discover selected.

## Figma 5.1-A visual details

- Keep the header compact: a 26 px search pill, the 20 px filter glyph, then
  the 26 px cart, notification, and profile action assets. Do not stretch the
  search field across the full row or replace the action row with one large
  cart button.
- The orange category rail has no synthetic “All” item. Its first five
  entries follow the Figma order: Snacks, Meal, Vegan, Dessert, Drinks; map
  them to the stable catalogue IDs and localized labels in presentation.
- Open Discover on the Snacks selection when no category was supplied by the
  caller. A caller-provided category still takes precedence.
- Product cards use the inset landscape layout from the reference. Keep the
  rating badge over the photo and do not add a separate plus button beside
  the price.

## Behavior

- Home category rail and category-filter sheet both open `/client/search-category`
  with the selected `Category` as route extra.
- Discover starts a clean search session scoped to that category.
- Selecting another category immediately updates the product list; selecting
  the active category again clears it.
- Search is combined with the selected category. Popular, price, rating, and
  discount filters sort or narrow the current results locally.
- The cart remains reachable from the app bottom navigation.
