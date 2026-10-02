import 'package:flutter/widgets.dart';

import 'ad_service.dart';
import 'mock_ad_service.dart';
import 'mock_store_service.dart';
import 'store_service.dart';

AdService createAdService(GlobalKey<NavigatorState> navigatorKey) =>
    MockAdService(navigatorKey);

StoreService createStoreService(GlobalKey<NavigatorState> navigatorKey) =>
    MockStoreService(navigatorKey);
