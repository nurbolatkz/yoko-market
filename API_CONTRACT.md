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

Мягкое удаление аккаунта: анонимизирует PII пользователя, отменяет заказы со статусом `pending_payment`.  
Заказы в статусах `confirmed`, `payment_received`, `shipped` **блокируют** удаление (бэкенд вернёт 400).

#### Запрос
Тело отсутствует.

#### Успешный ответ (200)
```json
{"ok": true, "deleted": true}
```

#### Коды ошибок
| Код | Тело | Когда |
|---|---|---|
| 400 | `{"detail": "active_orders"}` | Есть заказы в статусе confirmed / payment_received / shipped |
| 401 | `{"detail": "unauthorized"}` | Невалидный / истёкший токен |

> Клиент перед запросом показывает экран подтверждения + OTP-проверку.  
> После успешного ответа: клиент очищает токены, корзину, избранное, адреса.

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
