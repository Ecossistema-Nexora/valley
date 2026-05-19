import 'package:flutter/material.dart';

class RiderStatusCard extends StatelessWidget {
  const RiderStatusCard({super.key, required this.online, required this.onChanged});

  final bool online;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Icon(online ? Icons.radio_button_checked : Icons.power_settings_new),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                online ? 'Online recebendo rotas' : 'Entrar em operação',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Switch.adaptive(value: online, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
