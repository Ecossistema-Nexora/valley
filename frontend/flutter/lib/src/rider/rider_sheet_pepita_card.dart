import 'package:flutter/material.dart';

class RiderSheetPepitaCard extends StatelessWidget {
  const RiderSheetPepitaCard({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Pepitas pós-entrega', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Fonte: sheet_rider_pepita_truth_view'),
            const Text('Status: confirmado no Sheet'),
            const SizedBox(height: 8),
            Text('10 pepitas · R\$ 30', style: TextStyle(color: primary, fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
