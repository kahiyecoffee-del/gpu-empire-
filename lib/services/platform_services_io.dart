import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import 'ad_service.dart';
import 'admob_ad_service.dart';
import 'iap_store_service.dart';
import 'mock_ad_service.dart';
import 'mock_store_service.dart';
import 'store_service.dart';

bool get _mobile => Platform.isAndroid || Platform.isIOS;

AdService createAdService(GlobalKey<NavigatorState> navigatorKey) =>
    _mobile ? AdMobAdService() : MockAdService(navigatorKey);

StoreService createStoreService(GlobalKey<NavigatorState> navigatorKey) =>
    _mobile ? IapStoreService() : MockStoreService(navigatorKey);
