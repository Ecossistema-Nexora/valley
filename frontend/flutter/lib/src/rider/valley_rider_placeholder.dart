import 'package:flutter/material.dart';

class ValleyRiderPlaceholder extends StatelessWidget {
  const ValleyRiderPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Valley Rider',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('VALLEY RIDER')),
        body: const Center(
          child: Text('Valley Rider - Logistics'),
        ),
      ),
    );
  }
}
