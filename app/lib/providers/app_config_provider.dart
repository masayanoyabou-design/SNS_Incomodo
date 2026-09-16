import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_config_service.dart';

final appConfigServiceProvider = Provider<AppConfigService>(
  (ref) => AppConfigService(FirebaseFirestore.instance),
);

final minimumBuildProvider = StreamProvider<int?>(
  (ref) => ref.watch(appConfigServiceProvider).watchMinimumBuild(),
);
