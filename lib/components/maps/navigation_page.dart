// navigation_page.dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

class NavigationPage extends StatelessWidget {
  final mp.MapWidget mapWidget;
  final double routeDistance; // in meters
  final double routeDuration; // in seconds
  final String startLocationName;
  final String endLocationName;
  final VoidCallback onExitNavigation;

  const NavigationPage({
    super.key,
    required this.mapWidget,
    required this.routeDistance,
    required this.routeDuration,
    required this.startLocationName,
    required this.endLocationName,
    required this.onExitNavigation,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate estimated arrival time (current time + route duration)
    final currentTime = DateTime.now();
    final arrivalTime =
        currentTime.add(Duration(seconds: routeDuration.toInt()));
    final arrivalTimeString =
        "${arrivalTime.hour}:${arrivalTime.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      body: Stack(
        children: [
          // Map widget as the background
          mapWidget,
          // Top navigation instruction panel
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_right_alt,
                    color: Colors.white,
                    size: 30,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "84 m", // This could be dynamic based on the next maneuver
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Harrison St",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Spotify widget placeholder
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.music_note,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Speed limit indicator
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            left: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.8),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: const Text(
                    "60",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "59",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom route metrics panel
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Distance
                  Column(
                    children: [
                      Text(
                        "${(routeDistance / 1000).toStringAsFixed(1)} km",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Distance",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  // Duration
                  Column(
                    children: [
                      Text(
                        "${(routeDuration / 60).toStringAsFixed(0)} min",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Duration",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  // Estimated arrival time
                  Column(
                    children: [
                      Text(
                        arrivalTimeString,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Arrival",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Exit button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: onExitNavigation,
            ),
          ),
        ],
      ),
    );
  }
}
