import 'dart:math' show asin, cos, max, min, pi, sin, sqrt;

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MyMapScreen extends StatefulWidget {
  @override
  _MyMapScreenState createState() => _MyMapScreenState();
}

class _MyMapScreenState extends State<MyMapScreen> {
  CameraPosition _initialLocation = CameraPosition(target: LatLng(0.0, 0.0));
  GoogleMapController? mapController;
  Position? _currentPosition;
  TextEditingController startAddressController = TextEditingController();
  String _currentAddress = '';
  Set<Marker> markers = {};
  Map<PolylineId, Polyline> polylines = {};
  LatLng? startPoint;
  LatLng? endPoint;
  String? distance;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialLocation,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
            zoomGesturesEnabled: true,
            zoomControlsEnabled:  true ,
scrollGesturesEnabled: true,
            onMapCreated: _onMapCreated,
            markers: markers,
            polylines: Set<Polyline>.of(polylines.values),
            onTap: _onMapTapped,
          ),
          Positioned(
            top: 16.0,
            left: 16.0,
            right: 16.0,
            child: Container(
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Text(
                distance != null
                    ? 'Distance: $distance km'
                    : 'Tap on the map to select start and end points.',
                style: TextStyle(fontSize: 16.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _onMapTapped(LatLng latLng) async {
    setState(() {
      if (startPoint == null) {
        startPoint = latLng;
        _addMarker(latLng, 'Start');
      } else if (endPoint == null) {
        endPoint = latLng;
        _addMarker(latLng, 'End');
        _updateDistanceBox(); // Calculate and update the distance
        _getPolylines(); // Fetch and display the polyline
      } else {
        startPoint = latLng;
        endPoint = null;
        markers.clear();
        polylines.clear();
        _addMarker(latLng, 'Start');
        distance = null; // Clear the distance value
      }
    });
  }

  void _addMarker(LatLng latLng, String markerId) {
    final newMarker = Marker(
      markerId: MarkerId(markerId),
      position: latLng,
      infoWindow: InfoWindow(title: markerId),
    );
    setState(() {
      markers.add(newMarker);
    });
  }

  void _updateDistanceBox() {
    if (startPoint != null && endPoint != null) {
      double calculatedDistance = _getDistance(startPoint!, endPoint!);
      setState(() {
        distance = calculatedDistance
            .toStringAsFixed(2); // Format distance to 2 decimal places
      });
    }
  }

  double _getDistance(LatLng start, LatLng end) {
    const int earthRadius = 6371; // in kilometers
    double lat1 = start.latitude;
    double lon1 = start.longitude;
    double lat2 = end.latitude;
    double lon2 = end.longitude;

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * asin(sqrt(a));

    double distance = earthRadius * c;
    return distance;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  void _getPolylines() async {
    if (startPoint != null && endPoint != null) {
      PolylineResult result = await PolylinePoints().getRouteBetweenCoordinates(
        'YOUR_API_KEY_HERE', // Replace with your Google Maps API key
        PointLatLng(startPoint!.latitude, startPoint!.longitude),
        PointLatLng(endPoint!.latitude, endPoint!.longitude),
      );

      if (result.points.isNotEmpty) {
        List<LatLng> polylineCoordinates = [];

        result.points.forEach((PointLatLng point) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        });

        final polylineId = PolylineId('polyline');
        final polyline = Polyline(
          polylineId: polylineId,
          color: Colors.red,
          width: 3,
          points: polylineCoordinates,
        );

        setState(() {
          polylines.clear(); // Clear existing polylines
          polylines[polylineId] = polyline; // Add new polyline
        });

        LatLngBounds bounds = _calculateLatLngBounds(polylineCoordinates);

        mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50.0),
        );
      }
    }
  }

  LatLngBounds _calculateLatLngBounds(List<LatLng> polylineCoordinates) {
    double minLat = double.infinity;
    double minLng = double.infinity;
    double maxLat = double.negativeInfinity;
    double maxLng = double.negativeInfinity;

    for (LatLng point in polylineCoordinates) {
      minLat = min(minLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLat = max(maxLat, point.latitude);
      maxLng = max(maxLng, point.longitude);
    }

    LatLng southwest = LatLng(minLat, minLng);
    LatLng northeast = LatLng(maxLat, maxLng);

    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  void _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 18.0,
            ),
          ),
        );
      });
      await _getAddress();
    } catch (e) {
      print(e);
    }
  }

  Future<void> _getAddress() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress =
          "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";
          startAddressController.text = _currentAddress;
        });
      }
    } catch (e) {
      print(e);
    }
  }
}
