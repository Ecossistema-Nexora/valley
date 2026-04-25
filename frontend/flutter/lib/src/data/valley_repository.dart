import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:valley_super_app/src/data/valley_models.dart';

class ValleyRepository {
  const ValleyRepository();

  static const String _serverBaseUrl = 'https://valley-alpha.vercel.app';

  Future<ValleyAppData> load() async {
    final String manifestText = await _loadText(
      assetPath: 'assets/data/valley_mvp_manifest.v1.json',
      remoteUrl:
          '$_serverBaseUrl/assets/assets/data/valley_mvp_manifest.v1.json',
    );
    final String modulesText = await _loadText(
      assetPath: 'assets/data/modules_v47.json',
      remoteUrl: '$_serverBaseUrl/assets/assets/data/modules_v47.json',
    );
    final String adminText = await _loadText(
      assetPath: 'assets/data/valley_admin_data.json',
      remoteUrl: '$_serverBaseUrl/assets/assets/data/valley_admin_data.json',
    );

    final Map<String, dynamic> manifestJson =
        (jsonDecode(manifestText) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final Map<String, dynamic> modulesJson =
        (jsonDecode(modulesText) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final Map<String, dynamic> adminJson =
        (jsonDecode(adminText) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();

    final MvpManifest manifest = MvpManifest.fromJson(manifestJson);
    final Set<String> activeModuleCodes = manifest.activeModuleCodes;

    return ValleyAppData(
      manifest: manifest,
      modules: (modulesJson['modules'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic item) => ModuleRecord.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .where(
            (ModuleRecord module) => activeModuleCodes.contains(module.code),
          )
          .toList(),
      release: ReleaseSummary.fromJson(
        (adminJson['release_summary'] as Map<dynamic, dynamic>? ??
                <dynamic, dynamic>{})
            .cast<String, dynamic>(),
      ),
    );
  }

  Future<String> _loadText({
    required String assetPath,
    required String remoteUrl,
  }) async {
    try {
      final http.Response response = await http
          .get(Uri.parse(remoteUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          response.bodyBytes.isNotEmpty) {
        return utf8.decode(response.bodyBytes);
      }
    } catch (_) {
      // Fallback local mantem o shell operacional quando a rede falha.
    }

    return rootBundle.loadString(assetPath);
  }
}
