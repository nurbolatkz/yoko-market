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
| GET | `/my-orders/{id}` | Bearer | OrderDetailScreen, ReorderScreen | partial |
| GET | `/products/{id}` | нет | ReorderScreen (параллельные запросы) | ready |

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

> ⚠️ **partial**: поле `product_id` в элементах `items` присутствует с момента
> запуска `checkout_service v2`. Заказы, созданные до этого обновления, содержат
> только `{name, qty, price, brand}` без `product_id`. ReorderScreen обрабатывает
> это: позиции без `product_id` показываются как «Нет в наличии».

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
