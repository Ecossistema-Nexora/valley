import 'package:flutter/material.dart';

class RiderSimplePanel extends StatelessWidget {
  const RiderSimplePanel({super.key, required this.title, required this.icon, required this.lines});

  final String title;
  final IconData icon;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(icon),
                    const SizedBox(width: 10),
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 14),
                for (final String line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(line),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
