import 'package:flutter/material.dart';

class RiderMapCard extends StatelessWidget {
  const RiderMapCard({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Card(
      child: SizedBox(
        height: 300,
        child: Stack(
          children: <Widget>[
            const Center(child: Icon(Icons.route, size: 120)),
            Positioned(left: 24, top: 72, child: Icon(Icons.storefront, size: 42, color: primary)),
            Positioned(right: 24, bottom: 72, child: Icon(Icons.flag, size: 42, color: primary)),
            const Positioned(left: 18, right: 18, top: 18, child: Text('Mapa operacional', textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}
