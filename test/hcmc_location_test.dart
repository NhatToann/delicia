import 'package:delicia/domain/models/hcmc_location.dart';
import 'package:delicia/domain/models/lat_lng_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HcmcLocation', () {
    test('isInHcmc correctly validates HCMC coordinates', () {
      // District 1 (Ben Nghe)
      expect(HcmcLocation.isInHcmc(10.7769, 106.7009), isTrue);

      // Tan Binh (Tran Mai Ninh)
      expect(HcmcLocation.isInHcmc(10.7915, 106.6525), isTrue);

      // Thu Duc
      expect(HcmcLocation.isInHcmc(10.8500, 106.7700), isTrue);

      // Binh Chanh
      expect(HcmcLocation.isInHcmc(10.6800, 106.5800), isTrue);

      // Outside HCMC: (0, 0)
      expect(HcmcLocation.isInHcmc(0.0, 0.0), isFalse);

      // Outside Vietnam: Moscow, Russia (~55.75, 37.61)
      expect(HcmcLocation.isInHcmc(55.7558, 37.6173), isFalse);

      // Outside Vietnam: Mountain View, USA (~37.42, -122.08)
      expect(HcmcLocation.isInHcmc(37.4220, -122.0841), isFalse);

      // Outside HCMC: Hanoi (21.0285, 105.8542)
      expect(HcmcLocation.isInHcmc(21.0285, 105.8542), isFalse);
    });

    test('sanitize keeps HCMC coordinates intact and clamps foreign coordinates', () {
      // HCMC location remains untouched
      final hcmcPoint = HcmcLocation.sanitize(10.7915, 106.6525);
      expect(hcmcPoint.latitude, 10.7915);
      expect(hcmcPoint.longitude, 106.6525);

      // Russia coordinates get sanitized to Delicia restaurant in District 1, HCMC
      final russiaPoint = HcmcLocation.sanitize(55.7558, 37.6173);
      expect(russiaPoint.latitude, HcmcLocation.defaultDriverLocation.latitude);
      expect(russiaPoint.longitude, HcmcLocation.defaultDriverLocation.longitude);
      expect(russiaPoint.latitude, 10.7769);
      expect(russiaPoint.longitude, 106.7009);

      // Custom fallback works
      const customFallback = LatLngPoint(latitude: 10.7717, longitude: 106.7009);
      final sanitizedCustom = HcmcLocation.sanitize(0.0, 0.0, fallback: customFallback);
      expect(sanitizedCustom, customFallback);
    });
  });
}

