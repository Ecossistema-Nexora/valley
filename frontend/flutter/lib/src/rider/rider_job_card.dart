import 'package:flutter/material.dart';

class RiderJobCard extends StatefulWidget {
  const RiderJobCard({super.key, required this.onAccept});

  final VoidCallback onAccept;

  @override
  State<RiderJobCard> createState() => _RiderJobCardState();
}

class _RiderJobCardState extends State<RiderJobCard> {
  int step = 0;

  void next() {
    widget.onAccept();
    setState(() => step = step >= 3 ? 0 : step + 1);
  }

  String get title {
    if (step == 1) return 'Siga para coleta';
    if (step == 2) return 'Siga para entrega';
    if (step == 3) return 'Entrega concluida';
    return 'Rota disponivel';
  }

  String get action {
    if (step == 1) return 'Confirmar coleta';
    if (step == 2) return 'Finalizar entrega';
    if (step == 3) return 'Voltar ao mapa';
    return 'Aceitar rota';
  }

  IconData get icon {
    if (step == 1) return Icons.inventory_2;
    if (step == 2) return Icons.flag;
    if (step == 3) return Icons.verified;
    return Icons.swipe_right_alt;
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Origem: Valley Hub'),
            const Text('Destino: Jardim Alto'),
            const SizedBox(height: 8),
            Text('Valor do Rider: R\$ 16,80', style: TextStyle(color: primary, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('BR-PRO-001 ativo: custos internos nao sao exibidos.'),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: next, icon: Icon(icon), label: Text(action)),
          ],
        ),
      ),
    );
  }
}
