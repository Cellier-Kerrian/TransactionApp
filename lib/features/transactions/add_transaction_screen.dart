import 'package:flutter/material.dart';
import 'transaction_form.dart';
import '../../user_config.dart';

class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Ajouter une transaction', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: const TransactionForm(),
          ),
        ),
      ],
    );
  }
}
