import 'package:flutter/material.dart';
import 'package:valley_super_app/src/rider/rider_job_card.dart';
import 'package:valley_super_app/src/rider/rider_map_card.dart';
import 'package:valley_super_app/src/rider/rider_sheet_delivery_card.dart';
import 'package:valley_super_app/src/rider/rider_sheet_pepita_card.dart';

class ValleyRiderPlaceholder extends StatelessWidget {
  const ValleyRiderPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Valley Rider',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: Scaffold(
        appBar: AppBar(title: const Text('VALLEY RIDER')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const RiderMapCard(),
            const SizedBox(height: 16),
            RiderSheetDeliveryCard(onNext: () {}),
            const SizedBox(height: 16),
            RiderJobCard(onAccept: () {}),
            const SizedBox(height: 16),
            const RiderSheetPepitaCard(),
          ],
        ),
      ),
    );
  }
}
