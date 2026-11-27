# API Contract — Yo Market Mobile

Этот файл — единственный источник правды о контракте между Flutter-приложением и бэкендом.

**Статусы:**
- `ready` — эндпоинт существует и работает
- `awaiting-backend` — эндпоинт ещё не реализован; приложение использует Mock-реализацию
- `partial` — эндпоинт существует, но возвращает не все поля из контракта ниже

Базовый URL: `https://<host>/api` (из `AppConfig.baseUrl`)  
Авторизация (где указано): заголовок `Authorization: Bearer <access_token>`

---

## Сводная таблица эндпоинтов

| Метод | Путь | Авторизация | Используется в | Статус |
|---|---|---|---|---|
| GET | `/my-orders` | Bearer | OrdersScreen, ProfileScreen | ready |
| GET | `/my-orders/{id}` | Bearer | OrderDetailScreen, ReorderScreen | partial (нет variant_id) |
| GET | `/products/{id}` | нет | ReorderScreen (параллельные запросы) | ready |
| DELETE | `/auth/account` | Bearer | DeleteAccountScreen | ready |
| PATCH | `/profile` | Bearer | ProfileSetupScreen, PersonalDataScreen | ready |
| POST | `/support/account-recovery` | нет | AccountRecoveryScreen | awaiting-backend |
| GET | `/settings/delivery` | нет | DeliveryInfoScreen, Checkout, Home | partial (нет `schedule`, `express`, `pickup_points`) |
| POST | `/checkout/estimate` | Bearer | Cart, Checkout | partial (нет `delivery_type`, `delivery.eta`, `delivery.express`, `gift_*`) |
| POST | `/checkout` | Bearer | Checkout | partial (нет `delivery_type`, `pickup_point_id`, `use_gift_balance`) |
| GET | `/profile` | Bearer | Profile, PersonalDataScreen | partial (нет `birth_date`, `children`) |
| POST | `/profile/referral-code` | Bearer | InviteScreen, Profile | ready (нужен формат кода из 4 символов) |
| GET | `/profile/referral-stats` | Bearer | InviteScreen | ready |
| POST | `/profile/activate-referral` | Bearer | InviteCodeScreen, Cart | ready |
| GET | `/banners` | нет | Home (hero, «Специальные предложения») | partial (нет `placement`) |
| GET | `/loyalty/rules` | нет | YoCoin, Wallet, Profile, Home | partial (старая форма уровней; нужна месячная модель) |
| GET | `/wallet` | Bearer | WalletScreen, Profile, Checkout | awaiting-backend |
| GET | `/wallet/history` | Bearer | WalletScreen | awaiting-backend |
| POST | `/gift-cards/activate` | Bearer | WalletScreen (шит активации) | awaiting-backend |
| POST | `/gift-cards/purchase` | Bearer | GiftCardPurchaseScreen | awaiting-backend (после интеграции оплаты) |
| GET | `/gift-cards/sent` | Bearer | GiftCardsScreen | awaiting-backend |

> Добавляй строку в таблицу при каждом новом эндпоинте. Ниже размещай полное описание секцией.

---

---

### GET /my-orders

**Статус:** ready  
**Авторизация:** Bearer token  
**Используется в:** OrdersScreen, ProfileScreen (_ReorderButton — последний delivered)

#### Запрос
Нет тела. Query-параметры отсутствуют (лимит: последние 20 заказов).

#### Успешный ответ (200)
```json
[
  {
    "id": "uuid",
    "order_number": "A-1098",
    "status": "delivered",
    "total_amount": 11980,
    "items": [
      {
        "product_id": "uuid",
        "name": "Подгузники Huggies Elite Soft",
        "qty": 2,
        "price": 5990,
        "brand": "yoko"
      }
    ],
    "address": "Алматы, ул. Абая 1, кв 5",
    "created_at": "2026-10-01T10:00:00+06:00",
    "promo_code_used": null,
    "promo_discount": 0,
    "bonus_used": 0
  }
]
```

> ⚠️ **partial**: поле `product_id` присутствует с момента запуска checkout_service v2.
> Старые заказы содержат только `{name, qty, price, brand}`.
>
> ❌ **Отсутствует `variant_id`** — см. требование ниже.

---

### ТРЕБОВАНИЕ БЭКЕНДУ: добавить `variant_id` в ответ /my-orders и /my-orders/{id}

**Статус:** awaiting-backend  
**Затрагивает:** `GET /my-orders`, `GET /my-orders/{id}`

В массиве `items` каждого заказа необходимо возвращать:

```json
{
  "product_id": "uuid-основного-товара-или-группы",
  "variant_id": "uuid-конкретного-варианта-размера",
  "name": "Подгузники YokoSun",
  "size": "M",
  "qty": 2,
  "price": 5990,
  "brand": "yoko"
}
```

**Почему:** сейчас `product_id` в JSONB хранит UUID конкретной строки `Product`
(которая и является вариантом размера), что достаточно для ReorderScreen.
Однако явный `variant_id` + `size` позволит:
- надёжно определять размер без парсинга имени (который ломается при нестандартных названиях);
- корректно работать при будущей нормализации схемы (отдельная таблица вариантов);
- избавиться от поиска-по-имени в _searchFallback.

**Текущий workaround в приложении:**
- новые заказы (есть `product_id`): `GET /products/{product_id}` возвращает нужный вариант напрямую, т.к. `product_id` = строка конкретного размера;
- старые заказы (нет `product_id`): поиск по `GET /products?search=<имя без размера>`, затем парсинг размера из имени через суффиксы (S/M/L/XL/XXL/XXXL/NB/ONE); при неоднозначности показывается ChipGroup для ручного выбора.

#### Коды ошибок
| Код | Тело | Когда |
|---|---|---|
| 401 | `{"detail": "unauthorized"}` | Невалидный / истёкший токен |

---

### GET /my-orders/{id}

**Статус:** partial  
**Авторизация:** Bearer token  
**Используется в:** OrderDetailScreen, ReorderScreen (через OrdersProvider.getOrder)

Возвращает одну запись в том же формате, что и элемент списка `/my-orders`.

#### Коды ошибок
| Код | Тело | Когда |
|---|---|---|
| 401 | `{"detail": "user_not_found"}` | Невалидный токен |
| 404 | `{"detail": "order_not_found"}` | Заказ не существует или не принадлежит пользователю |

---

### GET /products/{id}

**Статус:** ready  
**Авторизация:** нет (публичный)  
**Используется в:** ReorderScreen (параллельные запросы для каждой позиции заказа)

#### Успешный ответ (200)
```json
{
  "id": "uuid",
  "name": "Подгузники Huggies Elite Soft",
  "price": 5990,
  "promo_price": null,
  "stock_qty": 15,
  "is_active": true,
  "size": "M",
  "category": "Подгузники",
  "brand": "yoko",
  "description": "...",
  "images": [{"url": "https://..."}],
  "variants": [
    {"id": "uuid2", "size": "S", "price": 5490, "stock_qty": 8}
  ]
}
```

#### Коды ошибок
| Код | Тело | Когда |
|---|---|---|
| 404 | `{"detail": "not_found"}` | Товар удалён или не существует |

> ReorderScreen обрабатывает 404: позиция считается недоступной.

---

### DELETE /auth/account

**Статус:** ready  
**Авторизация:** Bearer token  
**Используется в:** DeleteAccountScreen

Мягкое удаление аккаунта: анонимизирует PII пользователя.  
Заказы в статусах `pending_payment`, `confirmed`, `payment_received`, `shipped` **блокируют** удаление — клиент проверяет это заранее и не показывает кнопку, бэкенд вернёт 400.

#### Запрос
Тело отсутствует.

#### Успешный ответ (200)
```json
{"ok": true, "deleted": true}
```

#### Коды ошибок
| Код | Тело | Когда |
|---|---|---|
| 400 | `{"detail": "active_orders"}` | Есть заказы в статусе pending_payment / confirmed / payment_received / shipped |
| 401 | `{"detail": "unauthorized"}` | Невалидный / истёкший токен |

> Клиент перед запросом показывает экран подтверждения + OTP-проверку.  
> После успешного ответа: клиент очищает токены, корзину, избранное, адреса.

---

---

### POST /support/account-recovery

**Статус:** awaiting-backend  
**Авторизация:** нет (публичный)  
**Используется в:** AccountRecoveryScreen  
**Mock-флаг:** `MOCK_RECOVERY=true` (по умолчанию `true`)

#### Запрос
```json
{
  "order_number": "A-1098",
  "contact": "+77771234567"
}
```

#### Успешный ответ (200)
```json
{"ok": true}
```

#### Коды ошибок
| Код | Тело | Когда |
|---|---|---|
| 400 | `{"detail": "invalid_input"}` | Пустые или некорректные поля |
| 429 | `{"detail": "too_many_requests"}` | Слишком частые запросы |

---

### PATCH /profile

**Статус:** ready  
**Авторизация:** Bearer token  
**Используется в:** ProfileSetupScreen, PersonalDataScreen  

#### Запрос
```json
{
  "full_name": "Айгерим Сейткали",
  "city": "almaty"
}
```

> Поле `city` — это `code` из GET /checkout/cities (например `"almaty"`). Бэкенд сохраняет `user.city = code` и автоматически подбирает `user.branch_id` по активным филиалам.

> **Ответ PATCH** возвращает `{"ok": true, "referral_applied": false}` — не UserProfile. Клиент вызывает GET /profile следом, чтобы получить обновлённые данные.

#### Успешный ответ (200)
```json
{"ok": true, "referral_applied": false}
```

#### Коды ошибок
| Код | Тело | Когда |
|---|---|---|
| 401 | `{"detail": "unauthorized"}` | Невалидный токен |

---

# Релиз 1.2–1.3: новый дизайн, доставка, промокод друга, подарочные карты

**Принцип:** UI сначала работает на существующих эндпоинтах. Все новые поля в существующих ответах — **необязательные**: если поля нет, приложение скрывает соответствующий блок (ничего не ломается). Для новых эндпоинтов (`/wallet`, `/gift-cards/*`) приложение использует Mock-реализацию, пока статус — `awaiting-backend`.

**Деньги:** все суммы — целые тенге (`int`). Клиент никогда не считает итог сам — только из `POST /checkout/estimate`.

**Время:** все даты и время — по Алматы (`Asia/Almaty`). Дату доставки считает **сервер** (с учётом графика, cut-off и праздников); клиент только показывает.

---

### GET /settings/delivery — новые поля

**Статус:** partial (существующие поля `orders_enabled`, `free_delivery_threshold`, `cities`, `payment_methods` — без изменений)  
**Авторизация:** нет  
**Используется в:** DeliveryInfoScreen (блок «График работы»), Home (плитка доставки), Checkout (самовывоз, экспресс)

> ⚠️ Значения ниже — **пример**. Реальные цифры зависят от ответов бизнеса (вопросы по доставке в работе).

#### Успешный ответ (200) — добавить
```json
{
  "schedule": [
    {"weekday": 1, "label": "Пн", "works": true,  "from": "10:00", "to": "20:00", "same_day_cutoff": "14:00"},
    {"weekday": 2, "label": "Вт", "works": true,  "from": "10:00", "to": "20:00", "same_day_cutoff": "14:00"},
    {"weekday": 3, "label": "Ср", "works": true,  "from": "10:00", "to": "20:00", "same_day_cutoff": "14:00"},
    {"weekday": 4, "label": "Чт", "works": true,  "from": "10:00", "to": "20:00", "same_day_cutoff": "14:00"},
    {"weekday": 5, "label": "Пт", "works": true,  "from": "10:00", "to": "20:00", "same_day_cutoff": "14:00"},
    {"weekday": 6, "label": "Сб", "works": true,  "from": "10:00", "to": "18:00", "same_day_cutoff": "12:00"},
    {"weekday": 7, "label": "Вс", "works": false, "from": null,    "to": null,    "same_day_cutoff": null}
  ],
  "schedule_note": "Заказы после 14:00 доставляем на следующий рабочий день",
  "express": {
    "enabled": true,
    "fee": 1500,
    "duration_label": "за 2–3 часа",
    "hours_label": "Ежедневно 09:00–17:00"
  },
  "pickup_points": [
    {"id": 1, "city": "almaty", "address": "Алматы, Бухтарминская 24/3", "hours_label": "Пн–Сб 10:00–20:00", "ready_in_label": "через 2 часа"}
  ]
}
```

| Поле | Если отсутствует |
|---|---|
| `schedule`, `schedule_note` | Блок «График работы» скрыт |
| `express` / `express.enabled=false` | Экспресс нигде не показывается |
| `pickup_points` пустой | Опция «Самовывоз» скрыта |

---

### POST /checkout/estimate — новые поля

**Статус:** partial  
**Авторизация:** Bearer token  
**Используется в:** CartScreen, CheckoutScreen («Оплата»)

#### Запрос — добавить
```json
{
  "items": [{"product_id": "123", "name": "…", "qty": 1, "price": 6400}],
  "address": "Алматы, Бухтарминская 24/3",
  "bonus_used": 0,
  "promo_code": "DAUR",
  "delivery_type": "standard",
  "pickup_point_id": null,
  "use_gift_balance": true
}
```

| Поле | Значения | По умолчанию |
|---|---|---|
| `promo_code` | Скидочный промокод **или** 4-символьный код друга — сервер сам определяет тип | нет |
| `delivery_type` | `standard` \| `express` \| `pickup` | `standard` |
| `pickup_point_id` | `id` из `/settings/delivery → pickup_points`, только при `pickup` | `null` |
| `use_gift_balance` | Списать подарочный баланс | `false` |

#### Успешный ответ (200) — добавить
```json
{
  "subtotal": 6400,
  "promo_discount": 0,
  "promo_type": "referral",
  "promo_message": "Код DAUR применён: +1 000 YoCoin после первого заказа",
  "promo_error": null,
  "bonus_applied": 0,
  "gift_balance_available": 20000,
  "gift_applied": 6400,
  "bonus_to_earn": 140,
  "items_total": 6400,
  "order_total": 0,
  "delivery": {
    "type": "standard",
    "status": "free",
    "fee": 0,
    "free_above": 10000,
    "shortfall": 0,
    "eta": {
      "date": "2026-11-25",
      "from": "10:00",
      "to": "20:00",
      "label": "Понедельник, 25 ноября, 10:00–20:00",
      "short_label": "В понедельник",
      "off_hours_note": "Заказ оформлен в нерабочее время — доставим в первый рабочий день"
    },
    "express": {
      "available": true,
      "fee": 1500,
      "eta_label": "Сегодня до 18:00",
      "reason": null
    }
  }
}
```

| Поле | Смысл | Если отсутствует |
|---|---|---|
| `promo_type` | `discount` \| `referral` \| `gift` | Показывается только `promo_error` / скидка |
| `promo_message` | Зелёная строка под полем промокода | Строка скрыта |
| `gift_balance_available` | Сколько подарочного баланса есть у пользователя | Строка «Подарочный баланс» скрыта |
| `gift_applied` | Сколько списано подарочным балансом | 0 |
| `bonus_to_earn` | «Начисленные бонусы» в итогах корзины | Строка скрыта |
| `delivery.eta` | Дата доставки для выбранного `delivery_type` | Текст «Срок доставки подтвердит менеджер» |
| `delivery.eta.off_hours_note` | Подсказка, если заказ в нерабочее время | Скрыто |
| `delivery.express.available=false` + `reason` | Тумблер экспресса неактивен, под ним `reason` (например «Экспресс доступен с 09:00 до 17:00») | — |
| `delivery.express` отсутствует | Тумблер экспресса скрыт | — |

**Правила:**
- Бесплатная доставка от `free_above` действует только для `standard`; `express` всегда платный (уточняется у бизнеса).
- `order_total` уже включает доставку/экспресс и вычитает `promo_discount`, `bonus_applied`, `gift_applied`.

#### Коды ошибок (промокод не ломает расчёт — ошибка в `promo_error`, ответ 200)
| `promo_error` | Текст в UI |
|---|---|
| `invalid` | «Промокод не найден» |
| `own_code` | «Нельзя использовать свой код» |
| `already_referred` | «Код друга уже применён ранее» |
| `not_first_order` | «Код друга действует только на первый заказ» |
| `expired` | «Срок действия промокода истёк» |
| `too_many_attempts` | «Слишком много попыток, попробуйте через час» |

---

### POST /checkout — новые поля

**Статус:** partial  
**Авторизация:** Bearer token  
**Используется в:** CheckoutScreen («Оплата»)

#### Запрос — добавить
Те же поля, что в `estimate`: `promo_code`, `delivery_type`, `pickup_point_id`, `use_gift_balance`.

#### Успешный ответ (201) — добавить
```json
{
  "order_number": "A-1042",
  "total": 0,
  "delivery_eta_label": "Понедельник, 25 ноября, 10:00–20:00",
  "off_hours_note": "Заказ оформлен в нерабочее время — доставим в первый рабочий день"
}
```

#### Коды ошибок — добавить
| Код | Тело | Когда |
|---|---|---|
| 422 | `{"detail": {"code": "express_unavailable", "reason": "…"}}` | Экспресс стал недоступен между estimate и checkout |
| 422 | `{"detail": {"code": "gift_balance_changed"}}` | Подарочный баланс изменился — клиент повторяет estimate |

---

### GET /profile, PATCH /profile — новые поля

**Статус:** partial  
**Авторизация:** Bearer token  
**Используется в:** PersonalDataScreen («Мои данные»)

#### PATCH — запрос, добавить (все поля необязательные)
```json
{
  "birth_date": "1995-03-14",
  "children": [
    {"name": "Алихан", "birth_date": "2025-06-01", "sex": "m"}
  ]
}
```

#### GET — ответ, добавить
```json
{
  "phone": "+77003281388",
  "birth_date": "1995-03-14",
  "children": [{"id": 7, "name": "Алихан", "birth_date": "2025-06-01", "sex": "m"}]
}
```

> `phone` в «Мои данные» только для чтения. `sex`: `m` \| `f` \| `null`. Возраст ребёнка клиент показывает из `birth_date`.

---

### Реферальный код (существующие эндпоинты)

**Статус:** ready — `POST /profile/referral-code`, `GET /profile/referral-stats`, `POST /profile/activate-referral`  
**Используется в:** InviteScreen, Profile (баннер с кодом), InviteCodeScreen (после входа), Cart (поле промокода)

#### Изменение на бэкенде: формат кода
- **4 символа** из алфавита `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (без `O 0 I 1 L`) — легко продиктовать и набрать.
- Генерирует сервер, уникальный, без пересечения со скидочными промокодами.
- Ввод нечувствителен к регистру; кириллические двойники (`А В С Е Н К М О Р Т Х`) сервер приводит к латинице.
- Бонусы обоим — **после первого оплаченного/доставленного заказа** друга (поэтому короткий код безопасен).
- Лимит ввода: 5 попыток в час на пользователя → `429 too_many_attempts`.
- `invite_link` можно оставить для обратной совместимости — новый UI показывает только код.

#### Ответ `POST /profile/referral-code` (без изменений по полям)
```json
{"referral_code": "DAUR", "invite_link": "https://…/invite/DAUR", "bonus_referrer": 300, "bonus_user": 1000}
```

> Суммы `bonus_referrer` / `bonus_user` — источник правды для текста «+1 000 YoCoin вам и другу». Клиент не хардкодит цифры.

---

### GET /banners — новое поле `placement`

**Статус:** partial (остальные поля без изменений)  
**Авторизация:** нет  
**Используется в:** Home — верхняя карусель и блок «Специальные предложения» (дизайн YO market)

| Поле | Значения | Если отсутствует |
|---|---|---|
| `placement` | `hero` — верхняя карусель; `special` — карточки «Специальные предложения» (по две в ряд) | `hero` |

Для `special` карточка показывает: `discount_badge` (или `badge`) — плашка «До −30%» / «2+1», `title`, `subtitle`, стрелку и `image_url` справа. **`image_url` для `special` — вырезанное фото товара на прозрачном фоне (PNG/WebP, ~600×600)**, а не готовый баннер с текстом: текст рисует приложение.

```json
{"id": 12, "title": "Выгода на товары Yokosun", "subtitle": "Подгузники, трусики и не только",
 "discount_badge": "До −30%", "image_url": "https://…/yokosun-pack.png", "placement": "special",
 "promo_type": "promotion", "bg_color": "#FFFFFF"}
```

---

### GET /loyalty/rules — месячная модель кэшбэка

**Статус:** partial — эндпоинт есть, но отдаёт старую форму (`tiers[].min/max/discount_pct`, `redemption.max_pct_of_order`). `HttpLoyaltyApi` понимает обе формы.  
**Авторизация:** нет  
**Используется в:** новые экраны «Мой кошелёк», карточка кэшбэка в профиле, плитка «Бонусы за покупку» на главной  
**Mock-флаг:** `MOCK_LOYALTY=true` (по умолчанию `true`) — цифры из Figma (AGENTS.md §9)

> Текущие экраны YoCoin (`YoCoinScreen`, `YoCoinHistoryScreen`) пока работают с реальным эндпоинтом через `YoCoinLegacyApi`, чтобы не показывать пользователям тестовые данные.

#### Успешный ответ (200) — новая форма
```json
{
  "tiers": [
    {"min_monthly_spend": 50000,  "percent": 3,  "label": "от 50 000 ₸"},
    {"min_monthly_spend": 100000, "percent": 5,  "label": "от 100 000 ₸"},
    {"min_monthly_spend": 200000, "percent": 10, "label": "от 200 000 ₸"}
  ],
  "max_pay_with_bonus_pct": 100,
  "registration_bonus": 1000,
  "referral_bonus": 300,
  "free_delivery_threshold": 10000
}
```

| Поле | Смысл |
|---|---|
| `tiers` | Уровни кэшбэка по сумме покупок **за календарный месяц**; YoCoin начисляются после окончания месяца |
| `max_pay_with_bonus_pct` | Сколько % заказа можно оплатить YoCoin (1 YoCoin = 1 ₸) |
| `registration_bonus` / `referral_bonus` | YoCoin за регистрацию / за приглашённого друга |
| `free_delivery_threshold` | Бесплатная доставка от этой суммы в зоне доставки |

> Текущий месяц (сколько потрачено, сколько до следующего уровня, предварительный кэшбэк) — в `GET /wallet → cashback`.

---

### GET /wallet

**Статус:** awaiting-backend  
**Авторизация:** Bearer token  
**Используется в:** WalletScreen («Мой кошелёк»), Profile (строка «Мой кошелёк»), Checkout  
**Mock-флаг:** `MOCK_WALLET=true` (по умолчанию `true`)

#### Успешный ответ (200)
```json
{
  "gift_balance": 20000,
  "gift_expires_at": "2027-11-23",
  "yocoin_balance": 1250,
  "cashback": {
    "month_label": "Ноябрь",
    "month_spent": 62500,
    "current_percent": 3,
    "next_percent": 5,
    "next_threshold": 100000,
    "left_to_next": 37500,
    "days_left": 7,
    "preview_amount": 1875
  }
}
```

> Подарочный баланс (₸) и YoCoin хранятся **раздельно**: подарочная карта — оплаченные деньги, YoCoin — бонус. `cashback` — предварительный кэшбэк за текущий месяц (см. AGENTS.md §9).

---

### GET /wallet/history

**Статус:** awaiting-backend  
**Авторизация:** Bearer token  
**Используется в:** WalletScreen (блок «История»)  
**Mock-флаг:** `MOCK_WALLET=true`

#### Запрос
Query: `?cursor=<id>&limit=20`

#### Успешный ответ (200)
```json
{
  "items": [
    {"id": 91, "kind": "gift",   "amount": 20000, "reason": "gift_card_activated", "title": "Подарок от Асель", "created_at": "2026-11-23T10:12:00+05:00"},
    {"id": 90, "kind": "gift",   "amount": -6400, "reason": "order_payment",       "title": "Заказ A-1042",     "created_at": "2026-11-22T18:40:00+05:00"},
    {"id": 88, "kind": "yocoin", "amount": 140,   "reason": "monthly_cashback",    "title": "Кэшбэк за октябрь", "created_at": "2026-11-01T00:05:00+05:00"},
    {"id": 85, "kind": "yocoin", "amount": 300,   "reason": "referral_reward",     "title": "Друг сделал первый заказ", "created_at": "2026-10-28T12:00:00+05:00"}
  ],
  "next_cursor": 84
}
```

`reason`: `gift_card_activated`, `order_payment`, `order_refund`, `monthly_cashback`, `referral_reward`, `registration_bonus`, `birthday_bonus`, `expired`, `manual`.

---

### POST /gift-cards/activate

**Статус:** awaiting-backend  
**Авторизация:** Bearer token  
**Используется в:** WalletScreen → шит «Активировать карту»  
**Mock-флаг:** `MOCK_WALLET=true`

#### Запрос
```json
{"code": "K7QM-29XT-H4PB"}
```
> Код 12 символов (тот же алфавит без `O 0 I 1 L`), дефисы необязательны. QR на карте содержит этот же код.

#### Успешный ответ (200)
```json
{"amount": 20000, "gift_balance": 20000, "expires_at": "2027-11-23", "from_name": "Асель", "message": "С днём рождения малыша!"}
```

#### Коды ошибок
| Код | Тело | Текст в UI |
|---|---|---|
| 400 | `{"detail": "invalid_code"}` | «Карта не найдена — проверьте код» |
| 400 | `{"detail": "already_activated"}` | «Карта уже активирована» |
| 400 | `{"detail": "not_sold"}` | «Карта ещё не активна — обратитесь к продавцу» |
| 400 | `{"detail": "expired"}` | «Срок действия карты истёк» |
| 400 | `{"detail": "blocked"}` | «Карта заблокирована» |
| 429 | `{"detail": "too_many_attempts"}` | «Слишком много попыток, попробуйте через час» |

**Статусы карты на сервере:** `issued` → `sold` → `activated` → `partially_used` → `used`; а также `expired`, `blocked`. Физическая карта активируется только после статуса `sold`.

---

### POST /gift-cards/purchase

**Статус:** awaiting-backend (зависит от интеграции Kaspi / Halyk)  
**Авторизация:** Bearer token  
**Используется в:** GiftCardPurchaseScreen («Подарить карту»)  
**Mock-флаг:** `MOCK_WALLET=true`

#### Запрос
```json
{"amount": 20000, "recipient_phone": "+77011234567", "message": "С днём рождения малыша!", "payment_method": "kaspi"}
```
`amount` — один из номиналов: `5000`, `10000`, `20000`, `50000`. `recipient_phone` необязателен: без него покупатель получает код, чтобы отправить сам.

#### Успешный ответ (201)
```json
{"gift_card_id": 314, "payment_url": "https://…", "code": null}
```
> `code` возвращается только после успешной оплаты и только если `recipient_phone` не указан. Получатель с номером телефона получает SMS/push, баланс зачисляется при входе.

---

### GET /gift-cards/sent

**Статус:** awaiting-backend  
**Авторизация:** Bearer token  
**Используется в:** GiftCardsScreen («Подарочные карты» → «Отправленные»)  
**Mock-флаг:** `MOCK_WALLET=true`

#### Успешный ответ (200)
```json
[
  {"id": 314, "amount": 20000, "recipient_label": "+7 701 ••• 45 67", "status": "activated", "created_at": "2026-11-20T14:00:00+05:00"}
]
```

---

## Шаблон описания эндпоинта

```
### [МЕТОД] /путь/к/эндпоинту

**Статус:** awaiting-backend | ready | partial  
**Авторизация:** Bearer token / нет  
**Используется в:** ScreenName  

#### Запрос
\`\`\`json
// тело запроса (для POST/PATCH) или query-параметры (для GET)
\`\`\`

#### Успешный ответ (200)
\`\`\`json
// пример JSON
\`\`\`

#### Коды ошибок
| Код | Тело | Когда |
|---|---|---|
| 400 | `{"detail": "..."}` | … |
| 401 | `{"detail": "unauthorized"}` | Невалидный / истёкший токен |
| 404 | `{"detail": "not_found"}` | … |
```

---
