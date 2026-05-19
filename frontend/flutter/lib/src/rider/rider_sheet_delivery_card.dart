import 'package:flutter/material.dart';

class RiderSheetDeliveryCard extends StatelessWidget {
  const RiderSheetDeliveryCard({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Entrega do Sheet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Venda local: SALE-LOCAL-2401'),
            const Text('Frete físico: criado'),
            const Text('Origem: loja local'),
            const Text('Destino: cliente final'),
            const SizedBox(height: 8),
            Text('Repasse Rider: R\$ 16,80', style: TextStyle(color: primary, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Fonte canônica: sheet_rider_delivery_truth_view'),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onNext, icon: const Icon(Icons.swipe_right_alt), label: const Text('Avançar fluxo')),
          ],
        ),
      ),
    );
  }
}
