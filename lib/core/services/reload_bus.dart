import 'package:flutter/foundation.dart';

class TransactionsRefresher extends ChangeNotifier {
  TransactionsRefresher._();
  static final instance = TransactionsRefresher._();
  void reload() => notifyListeners();
}
