class BranchCity {
  const BranchCity({required this.code, required this.name});
  final String code;
  final String name;

  factory BranchCity.fromJson(Map<String, dynamic> j) => BranchCity(
        code: j['code'] as String,
        name: j['name'] as String,
      );
}

class EstimateItem {
  const EstimateItem({
    required this.productId,
    required this.name,
    required this.serverPrice,
    required this.qty,
    required this.lineTotal,
  });

  final String productId;
  final String name;
  final int serverPrice;
  final int qty;
  final int lineTotal;

  factory EstimateItem.fromJson(Map<String, dynamic> j) => EstimateItem(
        productId: j['product_id'] as String,
        name: j['name'] as String,
        serverPrice: (j['server_price'] as num).toInt(),
        qty: (j['qty'] as num).toInt(),
        lineTotal: (j['line_total'] as num).toInt(),
      );
}

class EstimateDelivery {
  const EstimateDelivery({
    required this.status,
    required this.fee,
    required this.freeAbove,
    required this.shortfall,
  });

  final String status;
  final int? fee;
  final int freeAbove;
  final int shortfall;

  bool get isFree => status == 'free';

  factory EstimateDelivery.fromJson(Map<String, dynamic> j) => EstimateDelivery(
        status: j['status'] as String,
        fee: (j['fee'] as num?)?.toInt(),
        freeAbove: (j['free_above'] as num).toInt(),
        shortfall: (j['shortfall'] as num).toInt(),
      );
}

// Thrown by CheckoutApi.placeOrder when the server returns 409 — an active
// pending order already exists within the 30-minute TTL window.
class PendingOrderException implements Exception {
  const PendingOrderException({required this.orderNumber, required this.total});
  final String orderNumber;
  final int total;
}

// Thrown when the server recalculates a different total than the client confirmed.
// Carries the updated estimate so the screen can refresh without a second round-trip.
class PriceChangedException implements Exception {
  const PriceChangedException({
    required this.newEstimate,
    required this.confirmedTotal,
  });
  final CheckoutEstimate newEstimate;
  final int confirmedTotal;
}

// Successful response from POST /checkout.
class PlaceOrderResult {
  const PlaceOrderResult({
    required this.orderNumber,
    required this.total,
    required this.notified,
    this.botUsername,
  });

  final String orderNumber;
  final int total;
  // Whether the Telegram bot successfully delivered the order notification.
  final bool notified;
  final String? botUsername;

  factory PlaceOrderResult.fromJson(Map<String, dynamic> j) => PlaceOrderResult(
        orderNumber: j['order_number'] as String,
        total: (j['total'] as num).toInt(),
        notified: j['notified'] as bool? ?? false,
        botUsername: j['bot_username'] as String?,
      );
}

class CheckoutEstimate {
  const CheckoutEstimate({
    required this.items,
    required this.subtotal,
    required this.promoDiscount,
    required this.bonusApplied,
    required this.itemsTotal,
    required this.delivery,
    this.promoError,
    this.orderTotal,
  });

  final List<EstimateItem> items;
  final int subtotal;
  final int promoDiscount;
  final int bonusApplied;
  final int itemsTotal;
  final EstimateDelivery delivery;
  final String? promoError;
  // null when delivery cost is unknown — never substitute 0 or treat itemsTotal
  // as the final charge in that case.
  final int? orderTotal;

  factory CheckoutEstimate.fromJson(Map<String, dynamic> j) => CheckoutEstimate(
        items: (j['items'] as List<dynamic>)
            .map((e) => EstimateItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (j['subtotal'] as num).toInt(),
        promoDiscount: (j['promo_discount'] as num).toInt(),
        bonusApplied: (j['bonus_applied'] as num).toInt(),
        itemsTotal: (j['items_total'] as num).toInt(),
        delivery: EstimateDelivery.fromJson(j['delivery'] as Map<String, dynamic>),
        promoError: j['promo_error'] as String?,
        orderTotal: (j['order_total'] as num?)?.toInt(),
      );
}
