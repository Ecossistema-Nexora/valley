import 'package:flutter/material.dart';

class RiderJobCard extends StatelessWidget {
  const RiderJobCard({super.key, required this.onAccept});

  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Rota disponivel', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Origem: Valley Hub'),
            const Text('Destino: Jardim Alto'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onAccept, child: const Text('Aceitar')),
          ],
        ),
      ),
    );
  }
}
