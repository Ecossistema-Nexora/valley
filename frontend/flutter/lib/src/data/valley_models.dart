class ValleyAppData {
  const ValleyAppData({
    required this.manifest,
    required this.modules,
    required this.release,
  });

  final MvpManifest manifest;
  final List<ModuleRecord> modules;
  final ReleaseSummary release;

  List<ModuleRecord> get includedModuleRecords {
    final Set<String> included = manifest.includedModules.toSet();
    final List<ModuleRecord> matches =
        modules
            .where((ModuleRecord module) => included.contains(module.code))
            .toList()
          ..sort(
            (ModuleRecord a, ModuleRecord b) => a.number.compareTo(b.number),
          );
    return matches;
  }

  List<ModuleRecord> get excludedModuleRecords {
    final Set<String> excluded = manifest.excludedModules.toSet();
    final List<ModuleRecord> matches =
        modules
            .where((ModuleRecord module) => excluded.contains(module.code))
            .toList()
          ..sort(
            (ModuleRecord a, ModuleRecord b) => a.number.compareTo(b.number),
          );
    return matches;
  }

  PhaseRecord? phaseByKey(String key) {
    for (final PhaseRecord phase in manifest.phases) {
      if (phase.key == key) {
        return phase;
      }
    }
    return null;
  }

  List<ModuleRecord> recordsForCodes(Iterable<String> codes) {
    final Set<String> wanted = codes.toSet();
    final List<ModuleRecord> matches =
        modules
            .where((ModuleRecord module) => wanted.contains(module.code))
            .toList()
          ..sort(
            (ModuleRecord a, ModuleRecord b) => a.number.compareTo(b.number),
          );
    return matches;
  }

  ModuleRecord? moduleByCode(String code) {
    for (final ModuleRecord module in modules) {
      if (module.code == code) {
        return module;
      }
    }
    return null;
  }
}

class MvpManifest {
  const MvpManifest({
    required this.summary,
    required this.centralPrinciple,
    required this.includedModules,
    required this.excludedModules,
    required this.phases,
    required this.metrics,
    required this.goldenRules,
    required this.identityComponents,
  });

  factory MvpManifest.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> objective =
        (json['objective'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();
    final Map<String, dynamic> capabilities =
        (json['cross_cutting_capabilities'] as Map<dynamic, dynamic>? ??
                <dynamic, dynamic>{})
            .cast<String, dynamic>();
    final Map<String, dynamic> uniqueIdentity =
        (capabilities['unique_identity'] as Map<dynamic, dynamic>? ??
                <dynamic, dynamic>{})
            .cast<String, dynamic>();
    return MvpManifest(
      summary: objective['summary'] as String? ?? '',
      centralPrinciple: objective['central_principle'] as String? ?? '',
      includedModules:
          (json['included_modules'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      excludedModules:
          (json['excluded_modules'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      phases: (json['phases'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic item) => PhaseRecord.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .toList(),
      metrics: (json['metrics'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
      goldenRules: (json['golden_rules'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
      identityComponents:
          (uniqueIdentity['components'] as List<dynamic>? ?? <dynamic>[])
              .map(
                (dynamic item) => IdentityComponent.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
                ),
              )
              .toList(),
    );
  }

  final String summary;
  final String centralPrinciple;
  final List<String> includedModules;
  final List<String> excludedModules;
  final List<PhaseRecord> phases;
  final List<String> metrics;
  final List<String> goldenRules;
  final List<IdentityComponent> identityComponents;

  Set<String> get activeModuleCodes {
    final Set<String> excluded = excludedModules.toSet();
    return includedModules
        .where((String code) => !excluded.contains(code))
        .toSet();
  }
}

class PhaseRecord {
  const PhaseRecord({
    required this.key,
    required this.label,
    required this.goal,
    required this.modules,
    required this.successGates,
    this.runtimeRules = const <String>[],
    this.stockMarketplaceModel,
  });

  factory PhaseRecord.fromJson(Map<String, dynamic> json) {
    return PhaseRecord(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      goal: json['goal'] as String? ?? '',
      modules: (json['modules'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
      successGates: (json['success_gates'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
      runtimeRules: (json['runtime_rules'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
      stockMarketplaceModel: json['stock_marketplace_model'] == null
          ? null
          : StockMarketplaceModel.fromJson(
              (json['stock_marketplace_model'] as Map<dynamic, dynamic>)
                  .cast<String, dynamic>(),
            ),
    );
  }

  final String key;
  final String label;
  final String goal;
  final List<String> modules;
  final List<String> successGates;
  final List<String> runtimeRules;
  final StockMarketplaceModel? stockMarketplaceModel;
}

class StockMarketplaceModel {
  const StockMarketplaceModel({
    required this.referenceBehavior,
    required this.valleyIdentityRule,
    required this.visualDirection,
    required this.mustHaveSurfaces,
    required this.adminApiIntegrations,
    required this.adminApiFields,
    required this.blueprint,
  });

  factory StockMarketplaceModel.fromJson(Map<String, dynamic> json) {
    return StockMarketplaceModel(
      referenceBehavior:
          (json['reference_behavior'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      valleyIdentityRule: json['valley_identity_rule'] as String? ?? '',
      visualDirection: json['visual_direction'] as String? ?? '',
      mustHaveSurfaces:
          (json['must_have_surfaces'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      adminApiIntegrations:
          (json['admin_api_integrations'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      adminApiFields:
          (json['admin_api_fields'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      blueprint: DropshippingBlueprint.fromJson(
        (json['dropshipping_production_blueprint'] as Map<dynamic, dynamic>? ??
                <dynamic, dynamic>{})
            .cast<String, dynamic>(),
      ),
    );
  }

  final List<String> referenceBehavior;
  final String valleyIdentityRule;
  final String visualDirection;
  final List<String> mustHaveSurfaces;
  final List<String> adminApiIntegrations;
  final List<String> adminApiFields;
  final DropshippingBlueprint blueprint;
}

class DropshippingBlueprint {
  const DropshippingBlueprint({
    required this.specPath,
    required this.supplierApis,
    required this.marketPriceSources,
    required this.requiredCapabilities,
    required this.databaseMigration,
  });

  factory DropshippingBlueprint.fromJson(Map<String, dynamic> json) {
    return DropshippingBlueprint(
      specPath: json['spec_path'] as String? ?? '',
      supplierApis: (json['supplier_apis'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
      marketPriceSources:
          (json['market_price_sources'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      requiredCapabilities:
          (json['required_capabilities'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      databaseMigration: json['database_migration'] as String? ?? '',
    );
  }

  final String specPath;
  final List<String> supplierApis;
  final List<String> marketPriceSources;
  final List<String> requiredCapabilities;
  final String databaseMigration;
}

class IdentityComponent {
  const IdentityComponent({
    required this.key,
    required this.label,
    required this.deliveryMode,
    required this.objective,
    required this.owners,
    required this.evidenceEntities,
    required this.eventTopics,
  });

  factory IdentityComponent.fromJson(Map<String, dynamic> json) {
    return IdentityComponent(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      deliveryMode: json['delivery_mode'] as String? ?? '',
      objective: json['objective'] as String? ?? '',
      owners: (json['owners'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
      evidenceEntities:
          (json['evidence_entities'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      eventTopics: (json['event_topics'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
    );
  }

  final String key;
  final String label;
  final String deliveryMode;
  final String objective;
  final List<String> owners;
  final List<String> evidenceEntities;
  final List<String> eventTopics;
}

class ModuleRecord {
  const ModuleRecord({
    required this.number,
    required this.code,
    required this.name,
    required this.subtitle,
    required this.domain,
    required this.tier,
    required this.dataHome,
    required this.automationStatus,
    required this.description,
    required this.dependsOn,
    required this.integratesWith,
  });

  factory ModuleRecord.fromJson(Map<String, dynamic> json) {
    return ModuleRecord(
      number: (json['number'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      tier: json['tier'] as String? ?? '',
      dataHome: json['data_home'] as String? ?? '',
      automationStatus: json['automation_status'] as String? ?? '',
      description: json['description_ptbr'] as String? ?? '',
      dependsOn: (json['depends_on'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
      integratesWith: (json['integrates_with'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
    );
  }

  final int number;
  final String code;
  final String name;
  final String subtitle;
  final String domain;
  final String tier;
  final String dataHome;
  final String automationStatus;
  final String description;
  final List<String> dependsOn;
  final List<String> integratesWith;
}

class ReleaseSummary {
  const ReleaseSummary({
    required this.modulesTotal,
    required this.modulesCompleted,
    required this.modulesWithPending,
    required this.checklistItemsTotal,
    required this.checklistItemsDone,
    required this.checklistItemsPending,
    required this.checklistCompletionPercentage,
    required this.averageModuleReadinessPercentage,
    required this.topModulesWithPending,
  });

  factory ReleaseSummary.fromJson(Map<String, dynamic> json) {
    return ReleaseSummary(
      modulesTotal: (json['modules_total'] as num?)?.toInt() ?? 0,
      modulesCompleted: (json['modules_completed'] as num?)?.toInt() ?? 0,
      modulesWithPending: (json['modules_with_pending'] as num?)?.toInt() ?? 0,
      checklistItemsTotal:
          (json['checklist_items_total'] as num?)?.toInt() ?? 0,
      checklistItemsDone: (json['checklist_items_done'] as num?)?.toInt() ?? 0,
      checklistItemsPending:
          (json['checklist_items_pending'] as num?)?.toInt() ?? 0,
      checklistCompletionPercentage:
          (json['checklist_completion_percentage'] as num?)?.toDouble() ?? 0,
      averageModuleReadinessPercentage:
          (json['average_module_readiness_percentage'] as num?)?.toDouble() ??
          0,
      topModulesWithPending:
          (json['top_modules_with_pending'] as List<dynamic>? ?? <dynamic>[])
              .map(
                (dynamic item) => PendingModule.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
                ),
              )
              .toList(),
    );
  }

  final int modulesTotal;
  final int modulesCompleted;
  final int modulesWithPending;
  final int checklistItemsTotal;
  final int checklistItemsDone;
  final int checklistItemsPending;
  final double checklistCompletionPercentage;
  final double averageModuleReadinessPercentage;
  final List<PendingModule> topModulesWithPending;
}

class PendingModule {
  const PendingModule({
    required this.number,
    required this.code,
    required this.name,
    required this.tier,
    required this.statusLabel,
    required this.checklistDone,
    required this.checklistPending,
    required this.checklistTotal,
    required this.moduleReadinessPercentage,
  });

  factory PendingModule.fromJson(Map<String, dynamic> json) {
    return PendingModule(
      number: (json['number'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tier: json['tier'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? '',
      checklistDone: (json['checklist_done'] as num?)?.toInt() ?? 0,
      checklistPending: (json['checklist_pending'] as num?)?.toInt() ?? 0,
      checklistTotal: (json['checklist_total'] as num?)?.toInt() ?? 0,
      moduleReadinessPercentage:
          (json['module_readiness_percentage'] as num?)?.toDouble() ?? 0,
    );
  }

  final int number;
  final String code;
  final String name;
  final String tier;
  final String statusLabel;
  final int checklistDone;
  final int checklistPending;
  final int checklistTotal;
  final double moduleReadinessPercentage;
}
