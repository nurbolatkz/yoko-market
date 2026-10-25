import 'dart:io';

import 'package:dio/dio.dart';

/// Returns true when [e] is a connectivity failure (no network, timeout).
bool isNetworkError(Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.unknown:
        return e.error is SocketException;
      default:
        return false;
    }
  }
  return e is SocketException;
}

/// Returns true when [e] is a server-side failure (5xx).
bool isServerError(Object e) =>
    e is DioException && (e.response?.statusCode ?? 0) >= 500;

/// Human-readable subtitle for an API error.
/// Pass [isCart] to append the cart-persistence note.
String networkErrorMessage(Object e, {bool isCart = false}) {
  if (isNetworkError(e)) {
    const base = 'Проверьте интернет и попробуйте ещё раз.';
    return isCart ? '$base Содержимое корзины сохранено.' : base;
  }
  if (isServerError(e)) return 'Что-то пошло не так. Попробуйте позже.';
  return 'Не удалось загрузить. Попробуйте позже.';
}
