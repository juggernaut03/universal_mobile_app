# Offer Module — End-to-End Implementation & Port Plan

**Source:** PatelMart (`/Users/gauravpawar/Documents/Development/code/Shalvi/patelmart/PatelMartRevamp`)
**Target:** GrahakPeth (`/Users/gauravpawar/Documents/Development/code/Shalvi/grahak_peth/GrahakPeth`)
**Scope:** Steal Deals / cart-driven offers shown on Home (interleaved with Best Sellers) and Cart (tabbed), plus the supporting cart-side slabs that power the persistent cart bar teaser and the auto-removal of offer products when an offer locks back.

---

## 1. What this module does

The offer module fetches a list of contextual offers from the backend on every (debounced) cart change. Each offer carries:

- A **threshold** (`min_order_value`) the cart has to reach to "unlock" it.
- A **product list** (`offer_p_code`) the customer can add at the offer price once unlocked.
- Fully **API-driven styling** (panel + per-offer colors), so a backend tweak restyles the UI without an app release.

The cart screen shows offers as **auto-advancing tabs**, the home feed shows each offer as a **horizontal product row interleaved with best sellers**, and the cart provider derives **offer slabs** for the persistent cart bar teaser and **auto-removes** offer products if the user drops below an unlocked threshold.

There is also a separate `OfferModel` for a simple banner image (`/get_offerscreen`), but the heavy lifting is the `StealDealOffer` flow.

---

## 2. File map (PatelMart)

| Layer | File | LOC | Role |
|---|---|---|---|
| Model | [lib/data/models/offer_model.dart](lib/data/models/offer_model.dart) | 14 | Minimal `OfferModel { imageUrl }` for banner image |
| API contract | [lib/data/services/api_service.dart:128-201](lib/data/services/api_service.dart#L128-L201) | ~75 | `getOffer()` + `getOfferScreen()` |
| API response | [lib/data/services/api_service.dart:204-221](lib/data/services/api_service.dart#L204-L221) | ~18 | `OfferApiResponse` (offers + panel colors) |
| Endpoints | [lib/core/constants/app_constants.dart:18-19](lib/core/constants/app_constants.dart#L18-L19) | 2 | `getOffer`, `getOfferScreen` URLs |
| Provider | [lib/presentation/providers/steal_deals_provider.dart](lib/presentation/providers/steal_deals_provider.dart) | 290 | `stealDealsOffersProvider`, `offerProductCodesProvider`, `allOfferProductCodesProvider`, `offerPanelColorsProvider`, `_debouncedCartProvider` |
| Cart derivations | [lib/presentation/providers/cart_provider.dart:808-895](lib/presentation/providers/cart_provider.dart#L808-L895) | ~90 | `offerSlabsProvider`, `nextOfferSlabProvider`, `offerSlabsStatusProvider`, `offerProductAutoRemovalProvider` |
| Home UI | [lib/presentation/features/home/widgets/single_offer_section_widget.dart](lib/presentation/features/home/widgets/single_offer_section_widget.dart) | 526 | `SingleOfferSectionWidget` + `_OfferProductCard` (3D flip animation) |
| Cart UI | [lib/presentation/features/cart/widgets/tabbed_offers_widget.dart](lib/presentation/features/cart/widgets/tabbed_offers_widget.dart) | 151 | `TabbedOffersWidget` (auto-advancing tabs over `SingleOfferSectionWidget`) |
| Render sites | [lib/presentation/features/home/home_screen.dart:857,943](lib/presentation/features/home/home_screen.dart#L857), [lib/presentation/features/cart/cart_screen.dart:370](lib/presentation/features/cart/cart_screen.dart#L370) | — | Where the widgets are mounted |

---

## 3. Data flow

```
User cart change
      │
      ▼
cartProvider (StateNotifier<List<CartItem>>)
      │
      ▼  (800ms debounce)
_debouncedCartProvider (snapshot: items, total, count)
      │
      ▼
stealDealsOffersProvider (FutureProvider.autoDispose<List<StealDealOffer>>)
      │  reads: selectedOutletProvider, centralizedAuthManagerProvider,
      │         sharedPreferencesProvider (temp_order_id)
      ▼
ApiService.getOffer({ temp_order_id, access_key, store_code,
                       ipo_order_amount, cart_items })
      │  POST /get_offer
      ▼
OfferApiResponse { offers[], panel colors }
      │  for each offer.offer_p_code:
      │    productRepository.getProductByCode(pCode, storeCode)
      ▼
List<StealDealOffer { offer: Map, products: List<ProductModel> }>
      │
      ├──> Home: SingleOfferSectionWidget (one per offer, interleaved)
      │
      ├──> Cart: TabbedOffersWidget (tabs over SingleOfferSectionWidget)
      │
      ├──> offerProductCodesProvider (unlocked pcodes) ───> cart max-qty enforcement
      ├──> allOfferProductCodesProvider (all pcodes)    ───> offer vs. regular detection
      ├──> offerSlabsProvider                            ───> persistent cart bar teaser
      └──> offerProductAutoRemovalProvider               ───> auto-removes products when offer re-locks
```

---

## 4. API contract — POST /get_offer

**Endpoint:** `${baseUrl}/get_offer` (project code auto-injected by `ApiClient.post`)

**Request body**
```json
{
  "temp_order_id": "ORD_...",
  "access_key": "<auth token>",
  "store_code": "KUD",
  "ipo_order_amount": 36.0,
  "cart_items": [
    {
      "pcode": "16708",
      "product_name": "...",
      "product_mrp": 10,
      "selling_price": 9,
      "package_size": 15,
      "package_unit": "GM",
      "stock_message": "Yes",
      "price_alert_message": "Yes",
      "quantity": 2,
      "product_image_link": "..."
    }
  ],
  "project_code": "RET3163"
}
```

**Response (new format)**
```json
{
  "offer_pannel_bg": "#FFFFFF",
  "offer_pannel_heading_txt_color": "#000000",
  "offer_pannel_descript_txt_color": "#555555",
  "offer_pannel_unlock_txt_color": "#FFFFFF",
  "offer_pannel_unlock_bg": "#4CAF50",
  "offer_list": [
    {
      "offer_id": "...",
      "offer_name": "...",
      "offer_heading_text": "Add ₹50 more to unlock",
      "offer_desc": "...",
      "offer_condition_text": "...",
      "offer_coupon_code": "...",
      "offer_coupon_value": "10",
      "offer_p_code": ["12345", "67890"],
      "offer_status": "locked" | "unlocked",
      "offer_visible": "true" | "false",
      "min_order_value": 100,
      "max_order_value": 500,
      "ipo_order_amount": 36,
      "img_path": "...",
      "offer_heading_bg_color": "#F4BB44",
      "offer_heading_text_color": "#000000",
      "offer_card_bg_color": "#FFFFFF",
      "offer_progress_fill_color": "#4CAF50",
      "offer_locked_badge_color": "#CCCCCC",
      "offer_unlocked_badge_color": "#4CAF50",
      "offer_claim_bg_color": "#E8F5E9"
    }
  ]
}
```

**Legacy format** (still supported) — a plain array equivalent to `offer_list`.

`OfferApiResponse` parses both shapes — see [api_service.dart:156-179](lib/data/services/api_service.dart#L156-L179).

---

## 5. Models (defined inside the provider file, not in `models/`)

`StealDealOffer` and `OfferPanelColors` live in [steal_deals_provider.dart](lib/presentation/providers/steal_deals_provider.dart). The Explore confirmed:

- `StealDealOffer { Map<String, dynamic> offer; List<ProductModel> products }` exposes typed getters (`offerStatus`, `isUnlocked`, `minOrderValue`, `headingBgColor`, …) over the raw API map. Putting it next to the provider keeps the API map untyped on the wire and avoids a code-gen step.
- `OfferPanelColors` is a plain holder for the five panel-level colors, stored in a `StateProvider` and read via a wrapper `Provider`.

Reuse this pattern verbatim in GrahakPeth — there's no benefit in splitting it across files.

---

## 6. Render sites

### Home — interleaved with best-seller rows

In [home_screen.dart:855-949](lib/presentation/features/home/home_screen.dart#L855-L949), a `Consumer` watches `stealDealsOffersProvider`, falls back to the previous (cached) value during loading, then walks an interleaved loop:

- `popular_category_section_{2..5}` for `i ∈ {0..3}`
- `BestSellerWidget(i+1)` for `i < 4`
- `SingleOfferSectionWidget(offer: displayOffers[i])` for `i < displayOffers.length`

`maxPairs = max(displayOffers.length, 4)` so all offers render even past the four best-seller slots.

### Cart — auto-advancing tabs

In [cart_screen.dart:370](lib/presentation/features/cart/cart_screen.dart#L370), a single `TabbedOffersWidget()` sits at the top of the cart. Internally it watches `stealDealsOffersProvider`, builds one `Tab` per offer using `offerHeadingText`, and uses a `TabController` + `Timer.periodic(4s)` to auto-advance until the user taps a tab (then auto-advance pauses).

---

## 7. Cart-side derivations (still in `cart_provider.dart`)

These are derived from `stealDealsOffersProvider` and consumed by other parts of the cart UX. Port them **inside** GrahakPeth's existing `cart_provider.dart` so the dependency direction matches (`cart_provider` depends on `steal_deals_provider`, not the reverse):

- `offerSlabsProvider` — flattens each offer to a `{ threshold, discount, headingText, name, conditionText, status, colors… }` slab.
- `nextOfferSlabProvider` — the first locked slab; powers the persistent cart bar teaser ("Add ₹X more to unlock…").
- `offerSlabsStatusProvider` — full status list for an offers bottom sheet.
- `offerProductAutoRemovalProvider` — silently removes a cart item whose pcode is in `allOfferProductCodesProvider` but no longer in `offerProductCodesProvider` (i.e., the offer was unlocked, the user added the offer product, then the cart dropped back below the threshold).

`offerProductAutoRemovalProvider` only runs if something **watches** it — mount it from a top-level widget (home screen / shell) once during the port.

---

## 8. The home widget (`SingleOfferSectionWidget`) in detail

A `ConsumerWidget` that paints a vertical section per offer:

- Header row: `offer.offerHeadingText` styled with `headingBgColor` + `headingTextColor`.
- Horizontal `ListView.builder` of `_OfferProductCard` (≈210px height) over `offer.products`.

`_OfferProductCard` is the interesting bit:

- A `StatefulWidget` driven by an `AnimationController(900ms, easeInOutCubic)` flipping the card via a `Matrix4.rotationY(π · t)` transform.
- **Front face** — image, name, package size, `ourPrice` badge + strikethrough MRP, conditional `+` Add button.
- **Back face** — solid `claimBgColor` background with a check mark and "Offer Claimed!" message.
- Tap on card → `context.push('/product/<pCode>')`.
- Tap on `+` → `cartProvider.notifier.addItem(product)` then `controller.forward()` to flip; the button is hidden if the product is already in the cart or the offer is locked.
- Watches `cartProvider` (to know if the product is already in cart) and `isCartEnabledProvider` (to disable add during validation).
- Hex parsing uses a small private helper that accepts `#RRGGBB`/`#AARRGGBB` and falls back to a constant.

Image fallback uses `ApiConstants.fallbackImageUrl` — GrahakPeth needs an equivalent constant (its `app_constants.dart` likely already has one; check before porting).

---

## 9. The cart widget (`TabbedOffersWidget`) in detail

A `ConsumerStatefulWidget`. State holds:

- `TabController? _tabController` (recreated if `displayOffers.length` changes)
- `Timer? _autoSwitchTimer` (4s periodic, advances `_tabController.index = (index + 1) % length`)
- `bool _userInteracted` (set on tap → cancels the timer; never resumed within the session)
- `int _lastLength` (so list-length changes recreate the controller cleanly)

Rendering:

- A horizontal `TabBar` with `tabAlignment: start`, primary background on the active tab, neutral on inactive.
- An `AnimatedSwitcher` (400ms slide + fade) that renders `SingleOfferSectionWidget(offer: displayOffers[index])` for the current tab.

If `displayOffers.isEmpty`, returns `SizedBox.shrink()`.

---

## 10. Order placement integration

Already in both codebases: `OrderService.confirmOrderWithPaymentStatusDetection(... String offerDetails = "No Offer", ...)` writes `offer_applicable_details` into the order body.

The current PatelMart cart **does not** yet thread the user's chosen offer into that string — it's still a hardcoded `"No Offer"`. The port should preserve that behavior. Threading a real `offer_id` through would be a follow-up task (separate from this port), and the cleanest place to hold the selection is a new `selectedOfferProvider` on the cart screen.

---

## 11. GrahakPeth — current state and gap

Verified with `find` / `grep`:

| Component | GrahakPeth status | Action |
|---|---|---|
| `lib/data/models/offer_model.dart` | Present, identical | No change |
| `ApiConstants.getOfferScreen` | Present | No change |
| `ApiConstants.getOffer` | **Missing** | Add constant |
| `ApiService.getOfferScreen()` | Present | No change |
| `ApiService.getOffer()` | **Missing** | Add method |
| `OfferApiResponse` | **Missing** | Add response class |
| `steal_deals_provider.dart` | **Missing** | Create |
| `single_offer_section_widget.dart` | **Missing** | Create |
| `tabbed_offers_widget.dart` | **Missing** | Create |
| Cart-side derivations (slabs / auto-removal) | **Missing** | Append to `cart_provider.dart` |
| `productRepository.getProductByCode(pCode, storeCode)` | Present | Use as-is |
| `selectedOutletProvider`, `centralizedAuthManagerProvider`, `sharedPreferencesProvider` | Present | Use as-is |
| `OrderService.offerDetails` param + `offer_applicable_details` body field | Present | No change |
| `home_screen.dart` interleaving | Doesn't render offers | Add `Consumer` + `SingleOfferSectionWidget` loop |
| `cart_screen.dart` offer slot | Doesn't render offers | Mount `TabbedOffersWidget` |
| `fallbackImageUrl` in `ApiConstants` | Verify before porting | Either reuse or add |

GrahakPeth already has the full supporting infrastructure (auth, outlet selection, product repo, cart provider, order service). The port is **additive** — no breaking changes to existing flows.

---

## 12. Port plan — step by step

Do these in order. Each step is independent enough to verify (build/analyze + a manual smoke check) before moving on.

### Step 1 — API plumbing

**File:** `GrahakPeth/lib/core/constants/app_constants.dart`
- Add `static const String getOffer = '$baseUrl/get_offer';` next to `getOfferScreen`.
- Confirm `fallbackImageUrl` exists; if not, add one with the GrahakPeth product CDN.

**File:** `GrahakPeth/lib/data/services/api_service.dart`
- Copy `getOffer()` (`api_service.dart:128-184`) verbatim.
- Copy `OfferApiResponse` (`api_service.dart:204-221`) to the bottom of the file (or a sibling file — match GrahakPeth's existing convention).

**Verify:** `flutter analyze` clean.

### Step 2 — `steal_deals_provider.dart`

**File:** `GrahakPeth/lib/presentation/providers/steal_deals_provider.dart` (new)
- Copy [steal_deals_provider.dart](lib/presentation/providers/steal_deals_provider.dart) verbatim.
- Confirm the imports resolve in GrahakPeth (same package layout); fix any rename mismatches (e.g., `apiServiceProvider`, `productRepositoryProvider`, `selectedOutletProvider`, `centralizedAuthManagerProvider`, `sharedPreferencesProvider`).
- Keep the 800ms debounce and the `ref.keepAlive()` — they were chosen specifically to prevent flicker on bulk add/remove.

**Verify:** `flutter analyze`. The provider is `autoDispose` and not mounted yet, so it won't fire — that's expected.

### Step 3 — Cart-side derivations

**File:** `GrahakPeth/lib/presentation/providers/cart_provider.dart`
- Append the four providers from PatelMart's `cart_provider.dart:808-895`:
  - `offerSlabsProvider`
  - `nextOfferSlabProvider`
  - `offerSlabsStatusProvider`
  - `offerProductAutoRemovalProvider`
- Also append the `OfferSlab` / `OfferSlabStatus` data classes that sit just above them.
- Add `import '...steal_deals_provider.dart';` at the top.

**Verify:** `flutter analyze`. Still not wired into UI; no behavior change yet.

### Step 4 — Home widget

**File:** `GrahakPeth/lib/presentation/features/home/widgets/single_offer_section_widget.dart` (new)
- Copy [single_offer_section_widget.dart](lib/presentation/features/home/widgets/single_offer_section_widget.dart) verbatim.
- Confirm imports: `cart_provider.dart` (for `cartProvider`, `isCartEnabledProvider`), `steal_deals_provider.dart` (for `StealDealOffer`), `app_constants.dart` (for `fallbackImageUrl`), and the GoRouter import for `context.push`.
- If GrahakPeth's product detail route is not `/product/<pCode>`, adjust the path.

**Verify:** Widget compiles. Still not mounted.

### Step 5 — Cart widget

**File:** `GrahakPeth/lib/presentation/features/cart/widgets/tabbed_offers_widget.dart` (new)
- Copy [tabbed_offers_widget.dart](lib/presentation/features/cart/widgets/tabbed_offers_widget.dart) verbatim.
- Imports: `steal_deals_provider.dart`, `single_offer_section_widget.dart`, GrahakPeth's primary color (the file uses `AppColors.primary` / `AppColors.neutral700` — match GrahakPeth's naming; rename if it uses `AppColors.primaryColor`).

**Verify:** Compile.

### Step 6 — Wire up Home

**File:** `GrahakPeth/lib/presentation/features/home/home_screen.dart`
- Find the section where best-sellers / popular categories render and replicate the interleave pattern from [home_screen.dart:855-949](lib/presentation/features/home/home_screen.dart#L855-L949). If GrahakPeth's home doesn't have an interleave loop, the simpler port is:
  ```dart
  Consumer(builder: (context, ref, _) {
    final offersAsync = ref.watch(stealDealsOffersProvider);
    final offers = offersAsync.valueOrNull ?? [];
    return Column(
      children: [
        for (final o in offers)
          RepaintBoundary(child: SingleOfferSectionWidget(offer: o)),
      ],
    );
  })
  ```
  Place it wherever the design wants offer rows.
- Also mount `offerProductAutoRemovalProvider` once near the top: `ref.watch(offerProductAutoRemovalProvider);` in the home screen's `build`. Without a watcher it never fires.

**Verify:** Run the app, add items to cart, watch the home offer row appear/refresh after the 800ms debounce.

### Step 7 — Wire up Cart

**File:** `GrahakPeth/lib/presentation/features/cart/cart_screen.dart`
- Add `const TabbedOffersWidget()` near the top of the cart's scroll view (matches PatelMart's [cart_screen.dart:370](lib/presentation/features/cart/cart_screen.dart#L370)).
- Optional: wire `nextOfferSlabProvider` into the persistent cart bar to show the "Add ₹X more" teaser.

**Verify:** Add cart items, see the tabs appear, watch them auto-advance every 4s, tap a tab and confirm auto-advance pauses.

### Step 8 — Smoke matrix

| Scenario | Expected |
|---|---|
| Empty cart | No offers; widgets hide gracefully |
| Cart below all thresholds | All offers locked; add buttons hidden |
| Cart crosses a threshold | Offer flips to unlocked; add button appears |
| Add offer product → cross back below threshold | `offerProductAutoRemovalProvider` removes it silently |
| Rapid add/remove | API fires once after 800ms idle, not per tap |
| Cart contents identical, screen rebuilds | No refetch (cached); no flicker thanks to `previousOffers` fallback |
| `offer_visible: "false"` from API | Offer hidden from list |
| Backend returns legacy array shape | Still parsed; panel colors empty |
| Backend changes a color | UI restyles next refresh, no rebuild needed |

---

## 13. Risk notes

- **Auth/outlet timing.** If `centralizedAuthManagerProvider` or `selectedOutletProvider` aren't ready when `stealDealsOffersProvider` first runs, the API call will go out with empty fields and the backend will likely return an empty list. The provider tolerates that (returns `[]`); just make sure home renders after splash/onboarding.
- **Debounce interplay with checkout.** The 800ms debounce means the cart total used for offer eligibility can lag the visible total briefly. Don't read offer data on the very last frame before navigation to checkout — read the cart total instead.
- **`offerProductAutoRemovalProvider` must be watched.** It's a `Provider<void>` that performs a side effect; it does nothing unless something `ref.watch`es it. Mounting in the home screen build is enough.
- **Image fallback URL.** PatelMart's `fallbackImageUrl` points at the PatelMart CDN. GrahakPeth must use its own, or you'll get a foreign-domain image on missing products.
- **Color parsing.** The hex parser accepts `#RRGGBB`, `#AARRGGBB`, and bare hex. Bad strings fall back to a constant. Don't tighten this — backend has historically sent inconsistent formats.

---

## 14. Out of scope (deliberately)

- **Actually applying** a chosen offer's discount in the order body. `offer_applicable_details` is still `"No Offer"` in PatelMart. Wiring this end-to-end (selection UI → cart provider → order service) is a separate effort.
- The `/get_offerscreen` banner endpoint. Already present in GrahakPeth and unrelated to the steal-deals flow.
- Analytics for offer impressions/claims. Not present in PatelMart either.

---

## 15. Quick file checklist (for the port PR)

```
GrahakPeth/
├── lib/core/constants/app_constants.dart            (edit: add getOffer URL, verify fallbackImageUrl)
├── lib/data/services/api_service.dart               (edit: add getOffer() + OfferApiResponse)
├── lib/presentation/providers/steal_deals_provider.dart      (new)
├── lib/presentation/providers/cart_provider.dart            (edit: append OfferSlab classes + 4 providers)
├── lib/presentation/features/home/widgets/single_offer_section_widget.dart  (new)
├── lib/presentation/features/cart/widgets/tabbed_offers_widget.dart         (new)
├── lib/presentation/features/home/home_screen.dart  (edit: render offers + watch auto-removal)
└── lib/presentation/features/cart/cart_screen.dart  (edit: mount TabbedOffersWidget)
```

Eight files: two new providers, two new widgets, four edits. No model changes, no order-flow changes, no breaking changes to existing screens.
