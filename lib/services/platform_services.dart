// Picks real ad and store services on phones and test ones elsewhere.
export 'platform_services_web.dart'
    if (dart.library.io) 'platform_services_io.dart';
